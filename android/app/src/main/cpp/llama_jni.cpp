#include "llama_bridge.h"

#include <jni.h>
#include <android/log.h>
#include <string>
#include <unistd.h>
#include <vector>

#define LOG_TAG "ModelLoaderLlamaJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

namespace {

std::vector<std::string> to_string_vector(JNIEnv* env, jobjectArray values) {
  std::vector<std::string> output;
  if (values == nullptr) {
    return output;
  }

  const jsize length = env->GetArrayLength(values);
  output.reserve(static_cast<size_t>(length));

  for (jsize i = 0; i < length; ++i) {
    auto* value = static_cast<jstring>(env->GetObjectArrayElement(values, i));
    if (value == nullptr) {
      output.emplace_back();
      continue;
    }

    const char* raw = env->GetStringUTFChars(value, nullptr);
    output.emplace_back(raw == nullptr ? "" : raw);
    if (raw != nullptr) {
      env->ReleaseStringUTFChars(value, raw);
    }
    env->DeleteLocalRef(value);
  }

  return output;
}

}  // namespace

extern "C" JNIEXPORT jboolean JNICALL
Java_com_modelloader_model_1loader_ModelLoaderPlugin_nativeLoadLlamaModel(
    JNIEnv* env,
    jobject /*thiz*/,
    jstring model_path,
    jint context_length,
    jint threads,
    jint gpu_layers,
    jboolean use_gpu) {
  const char* raw_path = env->GetStringUTFChars(model_path, nullptr);
  std::string path = raw_path == nullptr ? "" : raw_path;
  if (raw_path != nullptr) {
    env->ReleaseStringUTFChars(model_path, raw_path);
  }

  model_loader::LoadParams params;
  params.context_length = static_cast<int>(context_length);
  params.threads = static_cast<int>(threads);
  params.gpu_layers = static_cast<int>(gpu_layers);
  params.use_gpu = use_gpu == JNI_TRUE;

  const bool ok = model_loader::load_model(path, params);
  LOGI("nativeLoadLlamaModel ok=%d", ok ? 1 : 0);
  return ok ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_modelloader_model_1loader_ModelLoaderPlugin_nativeLlamaFileExists(
    JNIEnv* env,
    jobject /*thiz*/,
    jstring model_path) {
  if (model_path == nullptr) {
    return JNI_FALSE;
  }

  const char* raw_path = env->GetStringUTFChars(model_path, nullptr);
  std::string path = raw_path == nullptr ? "" : raw_path;
  if (raw_path != nullptr) {
    env->ReleaseStringUTFChars(model_path, raw_path);
  }

  const bool exists = !path.empty() && access(path.c_str(), F_OK) == 0;
  return exists ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT void JNICALL
Java_com_modelloader_model_1loader_ModelLoaderPlugin_nativeUnloadLlamaModel(
    JNIEnv* /*env*/,
    jobject /*thiz*/) {
  model_loader::unload_model();
  LOGI("nativeUnloadLlamaModel");
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_modelloader_model_1loader_ModelLoaderPlugin_nativeIsLlamaLoaded(
    JNIEnv* /*env*/,
    jobject /*thiz*/) {
  return model_loader::is_loaded() ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_modelloader_model_1loader_ModelLoaderPlugin_nativeChatLlama(
    JNIEnv* env,
    jobject /*thiz*/,
    jstring prompt,
    jint max_tokens,
    jdouble temperature,
    jdouble top_p,
    jint top_k,
    jdouble repeat_penalty,
    jint seed) {
  const char* raw_prompt = env->GetStringUTFChars(prompt, nullptr);
  std::string prompt_str = raw_prompt == nullptr ? "" : raw_prompt;
  if (raw_prompt != nullptr) {
    env->ReleaseStringUTFChars(prompt, raw_prompt);
  }

  model_loader::GenerationParams params;
  params.temperature = static_cast<double>(temperature);
  params.top_p = static_cast<double>(top_p);
  params.top_k = static_cast<int>(top_k);
  params.repeat_penalty = static_cast<double>(repeat_penalty);
  params.seed = static_cast<int>(seed);

  const std::string response = model_loader::chat_once(
      prompt_str,
      static_cast<int>(max_tokens),
      params);

  return env->NewStringUTF(response.c_str());
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_modelloader_model_1loader_ModelLoaderPlugin_nativeChatLlamaMessages(
    JNIEnv* env,
    jobject /*thiz*/,
    jobjectArray roles,
    jobjectArray contents,
    jint max_tokens,
    jdouble temperature,
    jdouble top_p,
    jint top_k,
    jdouble repeat_penalty,
    jint seed) {
  const std::vector<std::string> role_vec = to_string_vector(env, roles);
  const std::vector<std::string> content_vec = to_string_vector(env, contents);

  model_loader::GenerationParams params;
  params.temperature = static_cast<double>(temperature);
  params.top_p = static_cast<double>(top_p);
  params.top_k = static_cast<int>(top_k);
  params.repeat_penalty = static_cast<double>(repeat_penalty);
  params.seed = static_cast<int>(seed);

  const std::string response = model_loader::chat_messages_once(
      role_vec,
      content_vec,
      static_cast<int>(max_tokens),
      params);

  return env->NewStringUTF(response.c_str());
}
