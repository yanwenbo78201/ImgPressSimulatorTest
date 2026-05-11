#!/bin/bash

# iOS模拟器图片压缩测试自动化脚本
# 使用方式：./run_simulator_test.sh [图片目录]

set -e

echo "=== iOS模拟器图片压缩测试自动化工具 ==="
echo ""

# 参数处理
if [ -n "$1" ]; then
    IMAGE_DIR="$1"
else
    IMAGE_DIR="wallpapers"
fi

if [ ! -d "$IMAGE_DIR" ]; then
    echo "错误：未找到图片目录: $IMAGE_DIR"
    exit 1
fi

# 配置
DEFAULT_SIMULATOR_NAME="iPhone 16 Pro"
APP_BUNDLE_ID="com.apply.ImgPressSimulatorTest"
PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BUILD_DIR="$PROJECT_DIR/build"

echo "项目目录: $PROJECT_DIR"
echo "图片目录: $IMAGE_DIR"
echo ""

# ============================================
# 检查Xcode命令行工具
# ============================================
echo "🔍 检查Xcode命令行工具..."
if ! command -v xcrun &> /dev/null; then
    echo "❌ 错误：未找到xcrun命令，请安装Xcode命令行工具"
    echo ""
    echo "请运行以下命令安装："
    echo "  xcode-select --install"
    exit 1
fi

# 检查simctl是否可用
SIMCTL_PATH="/Applications/Xcode.app/Contents/Developer/usr/bin/simctl"
if [ ! -x "$SIMCTL_PATH" ]; then
    echo "❌ 错误：simctl不可用，请确保已安装Xcode并配置好开发环境"
    echo ""
    echo "可能需要："
    echo "  1. 安装Xcode（从App Store）"
    echo "  2. 运行 xcode-select --install"
    echo "  3. 打开Xcode同意许可协议"
    exit 1
fi

echo "✅ Xcode命令行工具已就绪"
echo ""

# ============================================
# 自动检测可用模拟器
# ============================================
echo "🔍 检测可用模拟器..."

# 获取所有可用的iPhone模拟器列表（排除unavailable状态的）
AVAILABLE_SIMULATORS=$(/Applications/Xcode.app/Contents/Developer/usr/bin/simctl list devices | grep "iPhone" | grep -v "unavailable" | sort -r)

if [ -z "$AVAILABLE_SIMULATORS" ]; then
    echo "❌ 错误：未找到可用的iPhone模拟器"
    echo ""
    echo "请在Xcode中创建模拟器："
    echo "  1. 打开Xcode"
    echo "  2. 点击 Xcode -> Settings -> Platforms"
    echo "  3. 确保已安装iOS模拟器"
    echo "  4. 打开 Xcode -> Open Developer Tool -> Simulator"
    echo "  5. 在Simulator中创建新设备"
    exit 1
fi

# 尝试使用默认模拟器，若不存在则自动选择第一个可用的
SIMULATOR_NAME="$DEFAULT_SIMULATOR_NAME"
SIMULATOR_UDID=$(echo "$AVAILABLE_SIMULATORS" | grep "$DEFAULT_SIMULATOR_NAME" | grep -Eo "[0-9A-F-]{36}" | head -1)

if [ -z "$SIMULATOR_UDID" ]; then
    echo "⚠️  默认模拟器 '$DEFAULT_SIMULATOR_NAME' 不可用，自动选择可用模拟器..."
    # 选择第一个可用的iPhone模拟器
    SIMULATOR_UDID=$(echo "$AVAILABLE_SIMULATORS" | grep -Eo "[0-9A-F-]{36}" | head -1)
    SIMULATOR_NAME=$(echo "$AVAILABLE_SIMULATORS" | head -1 | sed 's/.*iPhone /iPhone /g' | sed 's/ (.*//g')
fi

echo "✅ 选中模拟器: $SIMULATOR_NAME"
echo ""

echo "模拟器UDID: $SIMULATOR_UDID"
echo ""

# 清理旧的输出文件
echo "清理旧的输出文件..."
OUTPUT_DIR="simulator_output"
REPORT_FILE="$OUTPUT_DIR/compression_report.txt"
COMPRESSED_DIR="$OUTPUT_DIR/compressed"

# 删除旧报告文件
if [ -f "$REPORT_FILE" ]; then
    rm "$REPORT_FILE"
    echo "  删除旧报告: $REPORT_FILE"
fi

# 删除旧压缩图片
if [ -d "$COMPRESSED_DIR" ]; then
    rm -f "$COMPRESSED_DIR"/*
    echo "  清空压缩图片目录: $COMPRESSED_DIR"
fi

echo ""

# 构建应用
echo "1️⃣ 构建iOS应用..."
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project ImgPressSimulatorTest.xcodeproj -scheme ImgPressSimulatorTest -configuration Debug -sdk iphonesimulator SWIFT_VERSION=5.0 SWIFT_OBJC_BRIDGING_HEADER="ImgPressSimulatorTest/ImgPressSimulatorTest-Bridging-Header.h" build 2>&1 | tail -3

# 查找构建的应用（在DerivedData中，排除空的Index.noindex目录）
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ImgPressSimulatorTest.app" -type d | grep -E "Debug-iphonesimulator" | grep -v "Index.noindex" | head -1)
if [ -z "$APP_PATH" ]; then
    echo "错误：构建失败，未找到应用文件"
    exit 1
fi

echo "应用路径: $APP_PATH"
echo ""

# 启动模拟器（等待完全启动）
echo "2️⃣ 启动模拟器..."
/Applications/Xcode.app/Contents/Developer/usr/bin/simctl boot "$SIMULATOR_UDID" 2>/dev/null || echo "模拟器可能已启动"

# 等待模拟器完全启动（最多等待60秒）
echo "等待模拟器启动..."
BOOT_WAIT_COUNT=0
MAX_BOOT_WAIT=60
while true; do
    # 直接检查包含UDID的行是否包含Booted状态
    if /Applications/Xcode.app/Contents/Developer/usr/bin/simctl list devices | grep "$SIMULATOR_UDID" | grep -q "Booted"; then
        echo "✅ 模拟器已启动"
        break
    fi
    if [ $BOOT_WAIT_COUNT -ge $MAX_BOOT_WAIT ]; then
        echo "❌ 错误：模拟器启动超时"
        echo "请手动启动模拟器后重试，或增加等待时间"
        exit 1
    fi
    sleep 2
    BOOT_WAIT_COUNT=$((BOOT_WAIT_COUNT + 2))
    echo "等待中... ($BOOT_WAIT_COUNT/$MAX_BOOT_WAIT 秒)"
done

# 安装应用（先卸载旧版本）
echo "3️⃣ 安装应用..."
/Applications/Xcode.app/Contents/Developer/usr/bin/simctl uninstall "$SIMULATOR_UDID" "$APP_BUNDLE_ID" 2>/dev/null || echo "应用未安装，直接安装"
/Applications/Xcode.app/Contents/Developer/usr/bin/simctl install "$SIMULATOR_UDID" "$APP_PATH"
sleep 2

# 先启动应用一次（确保数据目录被创建）
echo "启动应用初始化数据目录..."
/Applications/Xcode.app/Contents/Developer/usr/bin/simctl launch "$SIMULATOR_UDID" "$APP_BUNDLE_ID"
sleep 3
/Applications/Xcode.app/Contents/Developer/usr/bin/simctl terminate "$SIMULATOR_UDID" "$APP_BUNDLE_ID"
sleep 1

# 创建输入目录并复制图片
echo "4️⃣ 准备测试图片..."
APP_CONTAINER=$(/Applications/Xcode.app/Contents/Developer/usr/bin/simctl get_app_container "$SIMULATOR_UDID" "$APP_BUNDLE_ID" data)
INPUT_DIR="$APP_CONTAINER/Documents/input_images"

echo "应用容器: $APP_CONTAINER"
echo "输入目录: $INPUT_DIR"

# 创建输入目录（直接在macOS端操作模拟器文件系统）
mkdir -p "$INPUT_DIR"

# 复制图片到模拟器（直接复制文件）
IMAGE_COUNT=0
# 启用大小写不敏感匹配
shopt -s nocaseglob
for img in "$IMAGE_DIR"/*.{jpg,jpeg,png,heic}; do
    if [ -f "$img" ]; then
        cp "$img" "$INPUT_DIR/"
        IMAGE_COUNT=$((IMAGE_COUNT + 1))
    fi
done
# 恢复大小写敏感匹配
shopt -u nocaseglob

echo "已复制 $IMAGE_COUNT 张图片"
echo ""

# 运行测试（通过URL Scheme触发）
echo "5️⃣ 运行压缩测试..."
/Applications/Xcode.app/Contents/Developer/usr/bin/simctl openurl "$SIMULATOR_UDID" "imgpress://compress"

# 等待测试完成（轮询检查报告是否生成）
echo "等待测试执行..."
WAIT_COUNT=0
MAX_WAIT=300  # 最大等待5分钟
REPORT_PATH=""
while true; do
    REPORT_PATH=$(/Applications/Xcode.app/Contents/Developer/usr/bin/simctl get_app_container "$SIMULATOR_UDID" "$APP_BUNDLE_ID" data)
    REPORT_PATH="$REPORT_PATH/Documents/compression_report.txt"
    if [ -f "$REPORT_PATH" ]; then
        echo "报告已生成"
        break
    fi
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        echo "❌ 错误：测试执行超时"
        echo "请检查："
        echo "  1. 模拟器是否正常运行"
        echo "  2. 应用是否在模拟器中正常启动"
        echo "  3. 测试图片是否已正确复制到模拟器"
        exit 1
    fi
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
    echo "等待中... ($WAIT_COUNT/$MAX_WAIT 秒)"
done

# 导出结果
echo "6️⃣ 导出测试结果..."
OUTPUT_DIR="$PROJECT_DIR/simulator_output"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# 复制报告（直接复制文件）
REPORT_PATH="$APP_CONTAINER/Documents/compression_report.txt"
cp "$REPORT_PATH" "$OUTPUT_DIR/" 2>/dev/null || echo "警告：未找到报告文件"

# 复制压缩后的图片（直接复制文件）
OUTPUT_IMG_DIR="$APP_CONTAINER/Documents/output_images"
if ls "$OUTPUT_IMG_DIR"/*.{jpg,jpeg,png} 2>/dev/null | grep -q .; then
    mkdir -p "$OUTPUT_DIR/compressed"
    cp "$OUTPUT_IMG_DIR"/*.{jpg,jpeg,png} "$OUTPUT_DIR/compressed/" 2>/dev/null
fi

echo ""
echo "=== 测试完成 ==="
echo "报告位置: $OUTPUT_DIR/compression_report.txt"
echo "压缩图片: $OUTPUT_DIR/compressed/"
echo ""

# 可选：关闭模拟器
# echo "关闭模拟器..."
# /Applications/Xcode.app/Contents/Developer/usr/bin/simctl shutdown "$SIMULATOR_UDID"

# 显示报告内容
echo "📋 测试报告摘要:"
echo "────────────────────────────────────────"
cat "$OUTPUT_DIR/compression_report.txt"