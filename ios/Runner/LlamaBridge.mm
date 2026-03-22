#import "LlamaBridge.h"

#include "llama.h"
#include "ggml-backend.h"

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <string>
#include <thread>
#include <vector>
#include <unistd.h>
#include <TargetConditionals.h>

namespace {

template <typename T>
T clampValue(T value, T lower, T upper) {
  if (value < lower) {
    return lower;
  }
  if (value > upper) {
    return upper;
  }
  return value;
}

}

namespace {

struct LlamaBridgeState {
  llama_model* model = nullptr;
  llama_context* context = nullptr;
  llama_sampler* sampler = nullptr;
  const llama_vocab* vocab = nullptr;
  std::mutex mutex;
};

struct LoadParams {
  int contextLength = 2048;
  int threads = 0;
  int gpuLayers = 0;
  bool useGpu = false;
};

struct GenerationParams {
  int topK = 40;
  double topP = 0.95;
  double temperature = 0.7;
  double repeatPenalty = 1.0;
  int seed = LLAMA_DEFAULT_SEED;
};

LlamaBridgeState g_state;

int defaultThreads() {
  const auto detected = static_cast<int>(std::thread::hardware_concurrency());
  return std::max(1, detected);
}

std::string tokenToPiece(const llama_vocab* vocab, llama_token token) {
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

std::string buildFallbackPrompt(
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

std::string formatMessagesWithTemplate(
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

  size_t estimatedSize = 256;
  for (size_t i = 0; i < roles.size(); ++i) {
    messages.push_back({roles[i].c_str(), contents[i].c_str()});
    estimatedSize += roles[i].size() + contents[i].size() * 2 + 32;
  }

  std::vector<char> formatted(std::max<size_t>(estimatedSize, 1024));
  int32_t formattedLen = llama_chat_apply_template(
      tmpl,
      messages.data(),
      messages.size(),
      true,
      formatted.data(),
      static_cast<int32_t>(formatted.size()));

  if (formattedLen < 0) {
    return "";
  }

  if (static_cast<size_t>(formattedLen) > formatted.size()) {
    formatted.resize(static_cast<size_t>(formattedLen) + 1);
    formattedLen = llama_chat_apply_template(
        tmpl,
        messages.data(),
        messages.size(),
        true,
        formatted.data(),
        static_cast<int32_t>(formatted.size()));
    if (formattedLen < 0) {
      return "";
    }
  }

  return std::string(formatted.data(), static_cast<size_t>(formattedLen));
}

std::string buildPromptFromMessages(
    llama_model* model,
    const std::vector<std::string>& roles,
    const std::vector<std::string>& contents) {
  const std::string templated = formatMessagesWithTemplate(model, roles, contents);
  if (!templated.empty()) {
    return templated;
  }

  return buildFallbackPrompt(roles, contents);
}

void resetSamplerLocked(const GenerationParams& params = GenerationParams{}) {
  if (g_state.sampler != nullptr) {
    llama_sampler_free(g_state.sampler);
    g_state.sampler = nullptr;
  }

  const int topK = std::max(1, params.topK);
  const float topP = clampValue(static_cast<float>(params.topP), 0.05f, 1.0f);
  const float temperature = clampValue(static_cast<float>(params.temperature), 0.0f, 2.0f);
  const float repeatPenalty = clampValue(static_cast<float>(params.repeatPenalty), 0.0f, 2.0f);
  const uint32_t seed = params.seed >= 0 ? static_cast<uint32_t>(params.seed) : LLAMA_DEFAULT_SEED;

  auto samplerParams = llama_sampler_chain_default_params();
  g_state.sampler = llama_sampler_chain_init(samplerParams);
  llama_sampler_chain_add(g_state.sampler, llama_sampler_init_top_k(topK));
  llama_sampler_chain_add(g_state.sampler, llama_sampler_init_top_p(topP, 1));
  if (repeatPenalty > 0.0f && repeatPenalty != 1.0f) {
    llama_sampler_chain_add(g_state.sampler, llama_sampler_init_penalties(64, repeatPenalty, 0.0f, 0.0f));
  }
  llama_sampler_chain_add(g_state.sampler, llama_sampler_init_temp(temperature));
  llama_sampler_chain_add(g_state.sampler, llama_sampler_init_dist(seed));
}

void freeAllLocked() {
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

std::string generateFromPromptLocked(
    const std::string& prompt,
    int maxTokens,
    const GenerationParams& params) {
  if (g_state.model == nullptr || g_state.context == nullptr || g_state.vocab == nullptr) {
    return "";
  }

  if (prompt.empty()) {
    return "";
  }

  resetSamplerLocked(params);
  if (g_state.sampler == nullptr) {
    return "";
  }

  llama_sampler_reset(g_state.sampler);
  llama_memory_clear(llama_get_memory(g_state.context), false);

  const int nPrompt = -llama_tokenize(
      g_state.vocab,
      prompt.c_str(),
      static_cast<int32_t>(prompt.size()),
      nullptr,
      0,
      true,
      true);

  if (nPrompt <= 0) {
    return "";
  }

  std::vector<llama_token> promptTokens(static_cast<size_t>(nPrompt));
  if (llama_tokenize(
          g_state.vocab,
          prompt.c_str(),
          static_cast<int32_t>(prompt.size()),
          promptTokens.data(),
          static_cast<int32_t>(promptTokens.size()),
          true,
          true) < 0) {
    return "";
  }

  auto promptBatch = llama_batch_get_one(promptTokens.data(), static_cast<int32_t>(promptTokens.size()));
  if (llama_decode(g_state.context, promptBatch) != 0) {
    return "";
  }

  std::string output;
  const int maxGenerate = clampValue(maxTokens, 1, 2048);

  for (int i = 0; i < maxGenerate; ++i) {
    llama_token next = llama_sampler_sample(g_state.sampler, g_state.context, -1);
    if (llama_vocab_is_eog(g_state.vocab, next)) {
      break;
    }

    output += tokenToPiece(g_state.vocab, next);

    auto nextBatch = llama_batch_get_one(&next, 1);
    if (llama_decode(g_state.context, nextBatch) != 0) {
      break;
    }
  }

  return output;
}

}  // namespace

extern "C" bool LlamaBridgeLoadModel(const char* modelPath, int contextLength, int threads, int gpuLayers, bool useGpu) {
  if (modelPath == nullptr || modelPath[0] == '\0') {
    return false;
  }

  std::lock_guard<std::mutex> lock(g_state.mutex);

  freeAllLocked();

  ggml_backend_load_all();
  llama_backend_init();

  LoadParams params;
  params.contextLength = contextLength;
  params.threads = threads;
  params.gpuLayers = gpuLayers;
  params.useGpu = useGpu;

  auto modelParams = llama_model_default_params();
#if TARGET_OS_SIMULATOR
  modelParams.n_gpu_layers = 0;
#else
  modelParams.n_gpu_layers = params.useGpu ? (params.gpuLayers != 0 ? params.gpuLayers : -1) : 0;
#endif

  g_state.model = llama_model_load_from_file(modelPath, modelParams);
  if (g_state.model == nullptr) {
    freeAllLocked();
    llama_backend_free();
    return false;
  }

  auto ctxParams = llama_context_default_params();
  const int trainedCtx = llama_model_n_ctx_train(g_state.model);
  const int requestedCtx = clampValue(params.contextLength, 512, 8192);
  const int effectiveCtx = trainedCtx > 0 ? std::min(trainedCtx, requestedCtx) : requestedCtx;
  const int effectiveThreads = clampValue(params.threads > 0 ? params.threads : defaultThreads(), 1, 32);
  ctxParams.n_ctx = static_cast<uint32_t>(effectiveCtx);
  ctxParams.n_batch = static_cast<uint32_t>(std::min(effectiveCtx, 512));
  ctxParams.n_ubatch = static_cast<uint32_t>(std::min(effectiveCtx, 512));
  ctxParams.n_threads = effectiveThreads;
  ctxParams.n_threads_batch = effectiveThreads;

  g_state.context = llama_init_from_model(g_state.model, ctxParams);
  if (g_state.context == nullptr) {
    freeAllLocked();
    llama_backend_free();
    return false;
  }

  g_state.vocab = llama_model_get_vocab(g_state.model);
  resetSamplerLocked();

  if (g_state.vocab == nullptr || g_state.sampler == nullptr) {
    freeAllLocked();
    llama_backend_free();
    return false;
  }

  return true;
}

extern "C" void LlamaBridgeUnloadModel(void) {
  std::lock_guard<std::mutex> lock(g_state.mutex);
  freeAllLocked();
  llama_backend_free();
}

extern "C" bool LlamaBridgeIsLoaded(void) {
  std::lock_guard<std::mutex> lock(g_state.mutex);
  return g_state.model != nullptr && g_state.context != nullptr && g_state.sampler != nullptr;
}

extern "C" bool LlamaBridgeFileExists(const char* modelPath) {
  if (modelPath == nullptr) {
    return false;
  }
  return access(modelPath, F_OK) == 0;
}

extern "C" char* LlamaBridgeChat(
    const char* prompt,
    int maxTokens,
    double temperature,
    double topP,
    int topK,
    double repeatPenalty,
    int seed) {
  std::lock_guard<std::mutex> lock(g_state.mutex);

  GenerationParams params;
  params.temperature = temperature;
  params.topP = topP;
  params.topK = topK;
  params.repeatPenalty = repeatPenalty;
  params.seed = seed;

  std::string input = prompt == nullptr ? "" : std::string(prompt);
  std::string output = generateFromPromptLocked(input, maxTokens, params);

  if (output.empty()) {
    return nullptr;
  }

  char* raw = static_cast<char*>(std::malloc(output.size() + 1));
  if (raw == nullptr) {
    return nullptr;
  }

  std::memcpy(raw, output.c_str(), output.size() + 1);
  return raw;
}

extern "C" char* LlamaBridgeChatMessages(
    const char* const* roles,
    const char* const* contents,
    int count,
    int maxTokens,
    double temperature,
    double topP,
    int topK,
    double repeatPenalty,
    int seed) {
  std::lock_guard<std::mutex> lock(g_state.mutex);

  if (count <= 0 || roles == nullptr || contents == nullptr) {
    return nullptr;
  }

  std::vector<std::string> roleValues;
  std::vector<std::string> contentValues;
  roleValues.reserve(static_cast<size_t>(count));
  contentValues.reserve(static_cast<size_t>(count));

  for (int i = 0; i < count; ++i) {
    roleValues.emplace_back(roles[i] == nullptr ? "" : roles[i]);
    contentValues.emplace_back(contents[i] == nullptr ? "" : contents[i]);
  }

  GenerationParams params;
  params.temperature = temperature;
  params.topP = topP;
  params.topK = topK;
  params.repeatPenalty = repeatPenalty;
  params.seed = seed;

  const std::string prompt = buildPromptFromMessages(g_state.model, roleValues, contentValues);
  const std::string output = generateFromPromptLocked(prompt, maxTokens, params);
  if (output.empty()) {
    return nullptr;
  }

  char* raw = static_cast<char*>(std::malloc(output.size() + 1));
  if (raw == nullptr) {
    return nullptr;
  }

  std::memcpy(raw, output.c_str(), output.size() + 1);
  return raw;
}

extern "C" void LlamaBridgeFreeString(char* ptr) {
  if (ptr != nullptr) {
    std::free(ptr);
  }
}
