#!/bin/bash
set -euo pipefail

# =================配置区域=================
# 目标文件最小阈值 (大于此大小才切割)
LIMIT_SIZE="${LIMIT_SIZE:-90M}"
# 切割后的分片大小
CHUNK_SIZE="${CHUNK_SIZE:-49m}"
# 目录归档模式：目标目录、输出目录、归档名。
ARCHIVE_TARGET_DIR="${ARCHIVE_TARGET_DIR:-}"
ARCHIVE_OUTPUT_DIR="${ARCHIVE_OUTPUT_DIR:-}"
ARCHIVE_NAME="${ARCHIVE_NAME:-}"
ARCHIVE_KEEP_SOURCE="${ARCHIVE_KEEP_SOURCE:-1}"
# =========================================

if [ -n "$ARCHIVE_TARGET_DIR" ]; then
    if [ -z "$ARCHIVE_OUTPUT_DIR" ] || [ -z "$ARCHIVE_NAME" ]; then
        echo "❌ 目录归档模式需要同时提供 ARCHIVE_OUTPUT_DIR 和 ARCHIVE_NAME"
        exit 1
    fi

    if [ ! -d "$ARCHIVE_TARGET_DIR" ]; then
        echo "❌ 目录不存在: $ARCHIVE_TARGET_DIR"
        exit 1
    fi

    archive_parent="$(dirname "$ARCHIVE_TARGET_DIR")"
    archive_base="$(basename "$ARCHIVE_TARGET_DIR")"
    archive_output_dir="${ARCHIVE_OUTPUT_DIR%/}"
    archive_path="${archive_output_dir}/${ARCHIVE_NAME}"
    checksum_path="${archive_path}.sha256"

    mkdir -p "$archive_output_dir"
    rm -f "${archive_path}" "${archive_path}.part"* "$checksum_path"

    echo "=== 开始归档目录并切割 ==="
    echo "目录: $ARCHIVE_TARGET_DIR"
    echo "输出目录: $archive_output_dir"
    echo "归档文件: $archive_path"
    echo "分片大小: $CHUNK_SIZE"

    tar --exclude='.DS_Store' -C "$archive_parent" -cf - "$archive_base" | gzip -1 > "$archive_path"

    (
        cd "$archive_output_dir"
        shasum -a 256 "$(basename "$archive_path")" > "$(basename "$checksum_path")"
    )

    split -b "$CHUNK_SIZE" -d -a 3 "$archive_path" "${archive_path}.part"
    rm -f "$archive_path"

    if [ "$ARCHIVE_KEEP_SOURCE" != "1" ]; then
        echo "归档完成，删除原目录: $ARCHIVE_TARGET_DIR"
        rm -rf "$ARCHIVE_TARGET_DIR"
    else
        echo "归档完成，保留原目录: $ARCHIVE_TARGET_DIR"
    fi

    echo "----------------------------------------"
    echo "=== 目录归档切割完成 ==="
    exit 0
fi

echo "=== 开始递归扫描并切割文件 ==="
echo "阈值: >$LIMIT_SIZE | 分片大小: $CHUNK_SIZE"

# find 命令解释：
# .             : 从当前目录开始
# -type f       : 只查找文件
# -size +$LIMIT_SIZE : 查找大于 90M 的文件
# ! -name "*.part*"  : 排除掉名字里包含 .part 的文件（防止重复切割分片）
# -print0       : 处理文件名中的空格和特殊字符

find . -type f -size +$LIMIT_SIZE ! -name "*.part*" -print0 | while IFS= read -r -d '' file; do

    # 获取文件名（用于显示）
    filename=$(basename "$file")

    echo "----------------------------------------"
    echo "发现大文件: $file"
    echo "正在切割..."

    # 执行切割
    # -b: 大小
    # -d: 使用数字后缀
    # -a 3: 后缀长度为3位 (000, 001...)，防止文件过大时排序错乱
    # "$file.part": 输出的文件名前缀，路径与原文件保持一致
    split -b "$CHUNK_SIZE" -d -a 3 "$file" "$file.part"

    # 检查切割是否成功
    echo "切割成功，删除原文件: $filename"
    rm "$file"
done

echo "----------------------------------------"
echo "=== 所有操作完成 ==="
