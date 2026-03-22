cmake_minimum_required(VERSION 3.18.1)
project(model_loader_llama_bridge)

set(LLAMA_SRC "${CMAKE_CURRENT_LIST_DIR}/../../../../../third_party/llama.cpp")

if(DEFINED ANDROID_ABI)
    if(ANDROID_ABI STREQUAL "arm64-v8a")
        set(GGML_SYSTEM_ARCH "ARM")
        # Disable KleidiAI fetch path to keep Android NDK builds deterministic.
        set(GGML_CPU_KLEIDIAI OFF)
        set(GGML_OPENMP OFF)
    elseif(ANDROID_ABI STREQUAL "x86_64")
        set(GGML_SYSTEM_ARCH "x86")
        set(GGML_CPU_KLEIDIAI OFF)
        set(GGML_OPENMP OFF)
    else()
        message(FATAL_ERROR "Unsupported ABI: ${ANDROID_ABI}")
    endif()
endif()

set(GGML_CPU_KLEIDIAI ${GGML_CPU_KLEIDIAI} CACHE BOOL "" FORCE)
set(GGML_OPENMP ${GGML_OPENMP} CACHE BOOL "" FORCE)

set(LLAMA_BUILD_COMMON OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

add_subdirectory(${LLAMA_SRC} build-llama)

add_library(
    llama_bridge
    SHARED
    llama_jni.cpp
    llama_bridge.cpp
)

target_include_directories(
    llama_bridge
    PRIVATE
    ${LLAMA_SRC}/include
    ${LLAMA_SRC}/ggml/include
)

find_library(log-lib log)

target_link_libraries(
    llama_bridge
    PRIVATE
    llama
    ${log-lib}
)
