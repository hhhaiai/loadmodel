# llama.cpp Archive

这个目录用于保存 `third_party/llama.cpp/` 的压缩分片。

默认约定：

- 归档名：`third_party_llama_cpp.tar.gz`
- 分片大小：`49MB`
- 恢复命令：`./restore_llama_cpp.sh`
- 重新打包命令：`./pack_llama_cpp.sh`

说明：

- 分片文件会保留在仓库中。
- 本地解压后的 `third_party/llama.cpp/` 属于工作副本，不建议直接提交。
