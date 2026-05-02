#include "llama_bridge.h"

#include <android/log.h>
#include <algorithm>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#define BRIDGE_LOG_TAG "ModelLoaderBridge"
#define BRIDGE_LOGI(...) __android_log_print(ANDROID_LOG_INFO, BRIDGE_LOG_TAG, __VA_ARGS__)
#define BRIDGE_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, BRIDGE_LOG_TAG, __VA_ARGS__)

namespace model_loader {

namespace {

struct LlamaState {
  llama_model* model = nullptr;
  llama_context* context = nullptr;
  llama_sampler* sampler = nullptr;
  const llama_vocab* vocab = nullptr;
  std::mutex mutex;
};

LlamaState g_state;

int default_threads() {
  const auto detected = static_cast<int>(std::thread::hardware_concurrency());
  return std::max(1, detected);
}

std::string token_to_piece(const llama_vocab* vocab, llama_token token) {
  if (vocab == nullptr) {
    return "";
  }

  char buf[256];
  int n = llama_token_to_piece(vocab, token, buf, static_cast<int>(sizeof(buf)), 0, true);
  if (n < 0) {
    std::vector<char> large(static_cast<size_t>(-n) + 1);
    n = llama_token_to_piece(vocab, token, large.data(), static_cast<int>(large.size()), 0, true);
    if (n < 0) {
      return "";
    }
    return std::string(large.data(), static_cast<size_t>(n));
  }

  return std::string(buf, static_cast<size_t>(n));
}

std::string build_fallback_prompt(
    const std::vector<std::string>& roles,
    const std::vector<std::string>& contents) {
  std::string prompt;
  for (size_t i = 0; i < roles.size() && i < contents.size(); ++i) {
    prompt += roles[i];
    prompt += ": ";
    prompt += contents[i];
    prompt += "\n";
  }
  prompt += "assistant: ";
  return prompt;
}

std::string format_messages_with_template(
    llama_model* model,
    const std::vector<std::string>& roles,
    const std::vector<std::string>& contents) {
  if (model == nullptr || roles.empty() || roles.size() != contents.size()) {
    return "";
  }

  const char* tmpl = llama_model_chat_template(model, nullptr);
  if (tmpl == nullptr || tmpl[0] == '\0') {
    return "";
  }

  std::vector<llama_chat_message> messages;
  messages.reserve(roles.size());

  size_t estimated_size = 256;
  for (size_t i = 0; i < roles.size(); ++i) {
    messages.push_back({roles[i].c_str(), contents[i].c_str()});
    estimated_size += roles[i].size() + contents[i].size() * 2 + 32;
  }

  std::vector<char> formatted(std::max<size_t>(estimated_size, 1024));
  int32_t formatted_len = llama_chat_apply_template(
      tmpl,
      messages.data(),
      messages.size(),
      true,
      formatted.data(),
      static_cast<int32_t>(formatted.size()));

  if (formatted_len < 0) {
    return "";
  }

  if (static_cast<size_t>(formatted_len) > formatted.size()) {
    formatted.resize(static_cast<size_t>(formatted_len) + 1);
    formatted_len = llama_chat_apply_template(
        tmpl,
        messages.data(),
        messages.size(),
        true,
        formatted.data(),
        static_cast<int32_t>(formatted.size()));
    if (formatted_len < 0) {
      return "";
    }
  }

  return std::string(formatted.data(), static_cast<size_t>(formatted_len));
}

std::string build_prompt_from_messages(
    llama_model* model,
    const std::vector<std::string>& roles,
    const std::vector<std::string>& contents) {
  const std::string templated = format_messages_with_template(model, roles, contents);
  if (!templated.empty()) {
    return templated;
  }

  return build_fallback_prompt(roles, contents);
}

void reset_sampler_locked(const GenerationParams& params = GenerationParams{}) {
  if (g_state.sampler != nullptr) {
    llama_sampler_free(g_state.sampler);
    g_state.sampler = nullptr;
  }

  const int top_k = std::max(1, params.top_k);
  const float top_p = std::clamp(static_cast<float>(params.top_p), 0.05f, 1.0f);
  const float temperature = std::clamp(static_cast<float>(params.temperature), 0.0f, 2.0f);
  const float repeat_penalty = std::clamp(static_cast<float>(params.repeat_penalty), 0.0f, 2.0f);
  const uint32_t seed = params.seed >= 0 ? static_cast<uint32_t>(params.seed) : LLAMA_DEFAULT_SEED;

  auto sampler_params = llama_sampler_chain_default_params();
  g_state.sampler = llama_sampler_chain_init(sampler_params);
  llama_sampler_chain_add(g_state.sampler, llama_sampler_init_top_k(top_k));
  llama_sampler_chain_add(g_state.sampler, llama_sampler_init_top_p(top_p, 1));
  if (repeat_penalty > 0.0f && repeat_penalty != 1.0f) {
    llama_sampler_chain_add(g_state.sampler, llama_sampler_init_penalties(64, repeat_penalty, 0.0f, 0.0f));
  }
  llama_sampler_chain_add(g_state.sampler, llama_sampler_init_temp(temperature));
  llama_sampler_chain_add(g_state.sampler, llama_sampler_init_dist(seed));
}

void free_all_locked() {
  if (g_state.sampler != nullptr) {
    llama_sampler_free(g_state.sampler);
    g_state.sampler = nullptr;
  }

  if (g_state.context != nullptr) {
    llama_free(g_state.context);
    g_state.context = nullptr;
  }

  if (g_state.model != nullptr) {
    llama_model_free(g_state.model);
    g_state.model = nullptr;
  }

  g_state.vocab = nullptr;
}

std::string generate_from_prompt_locked(
    const std::string& prompt,
    int max_tokens,
    const GenerationParams& params) {
  if (g_state.model == nullptr || g_state.context == nullptr || g_state.vocab == nullptr) {
    return "";
  }

  if (prompt.empty()) {
    return "";
  }

  reset_sampler_locked(params);
  if (g_state.sampler == nullptr) {
    return "";
  }

  llama_sampler_reset(g_state.sampler);
  llama_memory_clear(llama_get_memory(g_state.context), false);

  const int n_prompt = -llama_tokenize(
      g_state.vocab,
      prompt.c_str(),
      static_cast<int32_t>(prompt.size()),
      nullptr,
      0,
      true,
      true);

  if (n_prompt <= 0) {
    return "";
  }

  std::vector<llama_token> prompt_tokens(static_cast<size_t>(n_prompt));
  if (llama_tokenize(
          g_state.vocab,
          prompt.c_str(),
          static_cast<int32_t>(prompt.size()),
          prompt_tokens.data(),
          static_cast<int32_t>(prompt_tokens.size()),
          true,
          true) < 0) {
    return "";
  }

  auto batch = llama_batch_get_one(prompt_tokens.data(), static_cast<int32_t>(prompt_tokens.size()));
  const int decode_prompt = llama_decode(g_state.context, batch);
  if (decode_prompt != 0) {
    return "";
  }

  std::string output;
  const int max_generate = std::max(1, max_tokens);

  for (int i = 0; i < max_generate; ++i) {
    llama_token next = llama_sampler_sample(g_state.sampler, g_state.context, -1);
    if (llama_vocab_is_eog(g_state.vocab, next)) {
      break;
    }

    output += token_to_piece(g_state.vocab, next);

    auto next_batch = llama_batch_get_one(&next, 1);
    if (llama_decode(g_state.context, next_batch) != 0) {
      break;
    }
  }

  return output;
}

}  // namespace

bool load_model(const std::string& model_path, const LoadParams& params) {
  std::lock_guard<std::mutex> lock(g_state.mutex);

  BRIDGE_LOGI("load_model called: path=%s, ctx=%d, threads=%d, gpu_layers=%d, use_gpu=%d",
      model_path.c_str(), params.context_length, params.threads, params.gpu_layers, params.use_gpu);

  free_all_locked();

  BRIDGE_LOGI("Calling ggml_backend_load_all()");
  ggml_backend_load_all();
  BRIDGE_LOGI("Calling llama_backend_init()");
  llama_backend_init();

  auto model_params = llama_model_default_params();
  model_params.n_gpu_layers = params.use_gpu ? std::max(0, params.gpu_layers) : 0;
  BRIDGE_LOGI("n_gpu_layers=%d", model_params.n_gpu_layers);

  BRIDGE_LOGI("Calling llama_model_load_from_file...");
  g_state.model = llama_model_load_from_file(model_path.c_str(), model_params);
  if (g_state.model == nullptr) {
    BRIDGE_LOGE("llama_model_load_from_file returned NULL");
    free_all_locked();
    return false;
  }
  BRIDGE_LOGI("Model loaded successfully");

  auto ctx_params = llama_context_default_params();
  const int trained_ctx = llama_model_n_ctx_train(g_state.model);
  const int requested_ctx = std::clamp(params.context_length, 512, 8192);
  const int effective_ctx = trained_ctx > 0 ? std::min(trained_ctx, requested_ctx) : requested_ctx;
  const int effective_threads = std::clamp(
      params.threads > 0 ? params.threads : default_threads(),
      1,
      32);
  ctx_params.n_ctx = static_cast<uint32_t>(effective_ctx);
  ctx_params.n_batch = static_cast<uint32_t>(std::min(effective_ctx, 512));
  ctx_params.n_ubatch = static_cast<uint32_t>(std::min(effective_ctx, 512));
  ctx_params.n_threads = effective_threads;
  ctx_params.n_threads_batch = effective_threads;

  BRIDGE_LOGI("Creating context: n_ctx=%d, n_batch=%d, n_threads=%d",
      ctx_params.n_ctx, ctx_params.n_batch, ctx_params.n_threads);
  g_state.context = llama_init_from_model(g_state.model, ctx_params);
  if (g_state.context == nullptr) {
    BRIDGE_LOGE("llama_init_from_model returned NULL");
    free_all_locked();
    return false;
  }
  BRIDGE_LOGI("Context created successfully");

  g_state.vocab = llama_model_get_vocab(g_state.model);
  reset_sampler_locked();

  const bool ok = g_state.sampler != nullptr && g_state.vocab != nullptr;
  BRIDGE_LOGI("load_model result: sampler=%p, vocab=%p, ok=%d",
      (void*)g_state.sampler, (void*)g_state.vocab, ok ? 1 : 0);
  return ok;
}

void unload_model() {
  std::lock_guard<std::mutex> lock(g_state.mutex);
  free_all_locked();
  llama_backend_free();
}

bool is_loaded() {
  std::lock_guard<std::mutex> lock(g_state.mutex);
  return g_state.model != nullptr && g_state.context != nullptr && g_state.sampler != nullptr;
}

std::string chat_once(const std::string& prompt, int max_tokens, const GenerationParams& params) {
  std::lock_guard<std::mutex> lock(g_state.mutex);
  return generate_from_prompt_locked(prompt, max_tokens, params);
}

std::string chat_messages_once(
    const std::vector<std::string>& roles,
    const std::vector<std::string>& contents,
    int max_tokens,
    const GenerationParams& params) {
  std::lock_guard<std::mutex> lock(g_state.mutex);
  if (roles.empty() || roles.size() != contents.size()) {
    return "";
  }

  const std::string prompt = build_prompt_from_messages(g_state.model, roles, contents);
  return generate_from_prompt_locked(prompt, max_tokens, params);
}

}  // namespace model_loader
