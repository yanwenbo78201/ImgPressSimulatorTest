# iOS 模拟器图片压缩测试工具

这是一个基于 iOS 模拟器的图片压缩测试自动化工具，用于测试和验证 iOS APP 的图片压缩方法。

## 📁 项目结构

```
ImgPressSimulatorTest/
├── ImgPressSimulatorTest.xcodeproj    # Xcode 项目
├── ImgPressSimulatorTest/             # iOS 应用代码
│   ├── ViewController.m               # 主界面，包含压缩测试逻辑
│   ├── ObjcImgPressAnTool.h/m         # 默认图片压缩工具类
│   ├── ImageCompressionManager.h/m    # 压缩管理器（支持切换压缩算法）
│   └── ImageCompressorProtocol.h      # 压缩器协议
├── wallpapers/                        # 测试图片目录（214张示例图片）
├── simulator_output/                  # 输出目录（自动生成）
│   ├── compression_report.txt         # 压缩报告
│   └── compressed/                    # 不合格压缩图片
├── run_simulator_test.sh              # 一键运行脚本
└── README.md                          # 说明文档
```

## 📋 系统要求

| 要求 | 说明 |
|------|------|
| 操作系统 | macOS 10.15+ |
| Xcode | 15.0+ |
| 命令行工具 | Xcode Command Line Tools |
| iOS 模拟器 | iPhone 模拟器（任意型号） |

## 🚀 快速开始

### 1. 安装依赖

在新电脑上首次使用前，确保已安装以下依赖：

```bash
# 安装 Xcode 命令行工具
xcode-select --install

# 如果提示需要同意许可协议，请打开 Xcode 并同意
```

### 2. 运行测试

```bash
# 进入项目目录
cd ImgPressSimulatorTest

# 运行自动化测试脚本（使用默认 wallpapers 目录）
./run_simulator_test.sh

# 或者指定自定义图片目录
./run_simulator_test.sh /path/to/your/images
```

### 3. 查看结果

测试完成后，结果将保存在 `simulator_output/` 目录中：

- **压缩报告**: `simulator_output/compression_report.txt`
- **不合格图片**: `simulator_output/compressed/`

## 🖼️ 支持的图片格式

脚本和应用支持以下图片格式（大小写不敏感）：
- JPG / JPEG
- PNG
- HEIC

## 📱 界面说明

iOS 应用启动后会自动执行压缩测试：

1. **Loading 阶段**：显示"压缩中"提示框（延迟3秒后开始）
2. **结果展示**：
   - 红色 Header 区域（固定）：显示标题和动态压缩条件
   - 统计信息：压缩器名称、图片数量、不合格数量、压缩率
   - 可滚动列表：不合格图片详细信息（文件名、原始大小/尺寸、压缩后大小/尺寸、输出路径）

## ⚠️ 常见错误及解决方案

### 错误 1: `xcrun: error: unable to find utility "simctl"`

**原因**：未安装 Xcode 命令行工具或环境变量未配置。

**解决方案**：

```bash
# 安装命令行工具
xcode-select --install

# 如果仍然失败，尝试指定 Xcode 路径
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### 错误 2: `未找到模拟器 'iPhone 16 Pro'`

**原因**：默认模拟器不存在。

**解决方案**：

脚本会自动检测可用模拟器并选择第一个可用的，无需手动干预。

如果没有可用模拟器，请按以下步骤创建：
1. 打开 Xcode
2. 点击 `Xcode` → `Settings` → `Platforms`
3. 确保已安装 iOS 模拟器
4. 打开 `Xcode` → `Open Developer Tool` → `Simulator`
5. 在 Simulator 中创建新设备

### 错误 3: `构建失败，未找到应用文件`

**原因**：Xcode 项目构建失败。

**解决方案**：

```bash
# 清理构建缓存
rm -rf ~/Library/Developer/Xcode/DerivedData

# 手动打开项目并构建一次
open ImgPressSimulatorTest.xcodeproj
# 在 Xcode 中按 Command+B 构建
```

### 错误 4: `Simulator device failed to install the application`

**原因**：应用安装失败，可能是 Bundle ID 冲突或权限问题。

**解决方案**：

```bash
# 先卸载旧应用
xcrun simctl uninstall <SIMULATOR_UDID> com.apply.ImgPressSimulatorTest

# 重启模拟器
xcrun simctl shutdown <SIMULATOR_UDID>
xcrun simctl boot <SIMULATOR_UDID>
```

### 错误 5: `无法读取输入目录`

**原因**：模拟器数据目录未正确初始化。

**解决方案**：

脚本会自动处理此问题，确保应用先启动一次以创建数据目录。

### 错误 6: `报告未生成`（超时）

**原因**：压缩测试执行时间过长或应用崩溃。

**解决方案**：

1. 检查模拟器是否正常运行
2. 减少测试图片数量
3. 手动打开应用查看是否有错误日志

### 错误 7: `permission denied: run_simulator_test.sh`

**原因**：脚本缺少可执行权限。

**解决方案**：

```bash
# 添加可执行权限
chmod +x /path/to/run_simulator_test.sh

# 或者设置所有用户可执行
chmod 755 /path/to/run_simulator_test.sh
```

### 错误 8: `simctl不可用，请确保已安装Xcode并配置好开发环境`

**原因**：`xcode-select` 指向的是仅命令行工具目录，而非完整的 Xcode 开发工具目录。

**解决方案**：

```bash
# 方法1：切换到完整的Xcode开发工具目录（需要sudo权限）
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# 方法2：脚本已内置处理，确保Xcode已安装在/Applications目录下
```

### 错误 9: `未找到可用的iPhone模拟器`

**原因**：脚本中的模拟器检测逻辑只匹配包含 "available" 或 "Booted" 状态的模拟器，而大部分模拟器处于 "Shutdown" 状态时无法被检测到。

**解决方案**：

脚本已更新修复，现在可以检测所有可用的模拟器（包括 Shutdown 状态的）。如果仍然遇到问题，可以手动检查：

```bash
# 查看所有可用的模拟器
/Applications/Xcode.app/Contents/Developer/usr/bin/simctl list devices | grep "iPhone"

# 确保没有标记为 "unavailable" 的模拟器
```

如果所有模拟器都显示为 "unavailable"，请尝试：

1. 重启模拟器：`xcrun simctl shutdown all`
2. 打开 Xcode -> Window -> Devices and Simulators
3. 删除有问题的模拟器，重新创建

### 错误 10: `一直在等待中，没有启动模拟器`

**原因**：
1. 模拟器启动时间不足，脚本继续执行后续操作导致失败
2. 模拟器未真正启动成功就执行安装/启动应用操作
3. 测试执行没有超时机制，导致无限等待

**解决方案**：

脚本已更新修复，添加了以下改进：

1. **模拟器启动等待**：脚本会轮询检查模拟器状态，直到模拟器完全启动（最多等待60秒）
2. **测试执行超时**：压缩测试最多等待5分钟，超时后会给出错误提示
3. **更详细的错误信息**：超时后会提示检查模拟器状态、应用状态和测试图片

如果仍然遇到问题，可以手动检查：

```bash
# 检查模拟器状态
/Applications/Xcode.app/Contents/Developer/usr/bin/simctl list devices | grep "Booted"

# 手动启动应用
/Applications/Xcode.app/Contents/Developer/usr/bin/simctl launch <SIMULATOR_UDID> com.apply.ImgPressSimulatorTest
```

### 错误 11: `需要更高版本的iOS`

**原因**：应用的最低 iOS 版本设置过高（当前设置为 18.5），而模拟器的 iOS 版本较低。

**解决方案**：

1. **方法1：自动修改（推荐）**
```bash
# 将最低版本从 18.5 修改为 15.0
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 18.5/IPHONEOS_DEPLOYMENT_TARGET = 15.0/g' ImgPressSimulatorTest.xcodeproj/project.pbxproj
```

2. **方法2：手动修改**
- 打开 `ImgPressSimulatorTest.xcodeproj`
- 在项目设置中找到 `Deployment Info`
- 将 `iOS Deployment Target` 设置为 15.0 或更低

## ⚙️ 配置说明

### 压缩参数（在 ViewController.m 的 viewDidLoad 方法中修改）

```objc
// 在 viewDidLoad 中初始化阈值属性
_minCompressedSizeKB = 200.0;   // 最小压缩后大小（KB）
_maxCompressedSizeKB = 600.0;   // 最大压缩后大小（KB）
_minLongEdge = 256;             // 最小长边像素
_maxLongEdge = 4096;            // 最大长边像素
```

> **注意**：阈值会动态显示在应用界面的 Header 区域，修改后无需手动更新界面文本。

### 添加自定义压缩器

1. 创建实现 `ImageCompressorProtocol` 协议的类
2. 在 `ImageCompressionManager` 中注册：

```objc
[manager registerCompressor:myCompressor withIdentifier:@"myCompressor"];
[manager setActiveCompressorWithIdentifier:@"myCompressor"];
```

## 📊 报告格式

压缩报告包含以下信息：

```
=== 压缩质量不合格报告 ===
检测目录：input_images
图片数量：214
质量阈值 - 最小:200KB 最大:600KB 最小长边:256 最大长边:4096

--- wallhaven-xxx.png ---
  原始大小：3517.38 KB
  原始宽高：2560 x 1440
  压缩后大小：285.98 KB
  压缩后宽高：2560 x 1440
  压缩后路径：compressed/wallhaven-xxx.png

=== 统计汇总 ===
原始总大小：743279.67 KB
压缩后总大小：79750.82 KB
质量不合格图片数量：49
总体压缩率：89.3%
```

## 📝 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！