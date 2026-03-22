#pragma once

#include "llama.h"

#include <string>
#include <vector>

namespace model_loader {

struct LoadParams {
  int context_length = 2048;
  int threads = 0;
  int gpu_layers = 0;
  bool use_gpu = false;
};

struct GenerationParams {
  int top_k = 40;
  double top_p = 0.95;
  double temperature = 0.7;
  double repeat_penalty = 1.0;
  int seed = LLAMA_DEFAULT_SEED;
};

bool load_model(const std::string& model_path, const LoadParams& params);
void unload_model();
bool is_loaded();
std::string chat_once(const std::string& prompt, int max_tokens, const GenerationParams& params);
std::string chat_messages_once(
    const std::vector<std::string>& roles,
    const std::vector<std::string>& contents,
    int max_tokens,
    const GenerationParams& params);

}  // namespace model_loader
