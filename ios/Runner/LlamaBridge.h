#import <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

bool LlamaBridgeLoadModel(const char* modelPath, int contextLength, int threads, int gpuLayers, bool useGpu);
void LlamaBridgeUnloadModel(void);
bool LlamaBridgeIsLoaded(void);
bool LlamaBridgeFileExists(const char* modelPath);
char* LlamaBridgeChat(
    const char* prompt,
    int maxTokens,
    double temperature,
    double topP,
    int topK,
    double repeatPenalty,
    int seed
);
char* LlamaBridgeChatMessages(
    const char* const* roles,
    const char* const* contents,
    int count,
    int maxTokens,
    double temperature,
    double topP,
    int topK,
    double repeatPenalty,
    int seed
);
void LlamaBridgeFreeString(char* ptr);

#ifdef __cplusplus
}
#endif
