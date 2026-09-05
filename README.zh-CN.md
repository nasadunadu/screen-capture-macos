<p align="center">
  <img src="ScreenCapture/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png" width="128" alt="Screen Capture 应用图标">
</p>

<h1 align="center">Screen Capture for macOS</h1>

<p align="center">
  原生、高清、本地优先的 macOS 截图与滚动长截图工具。<br>
  Retina 像素输入，清晰 PNG 输出。
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="docs/PRIVACY.md">隐私</a> ·
  <a href="CONTRIBUTING.md">参与贡献</a> ·
  <a href="LICENSE">Apache-2.0</a>
</p>

## 为什么做这个项目？

Screen Capture 专注两个高频任务：快速完成带标注的普通截图，以及可靠地生成滚动长图。应用使用 Swift、SwiftUI、AppKit、ScreenCaptureKit、Vision 和 Core Graphics 原生构建，不使用 WebView，不需要账户，没有统计分析、云上传或第三方运行时依赖。

## 主要能力

- 区域、窗口、全屏、上次区域、预设尺寸和延时截图
- Retina 原生分辨率捕获，默认使用无损 PNG
- 矩形、圆形、直线、前粗后细箭头、画笔和文字标注
- 全局颜色与线宽调节、元素选择、撤销与重做
- 截图区域外暗化，选区四角可再次缩放，也可以整体移动
- 左侧实时滚动、右侧无边框预览的长截图工作区
- 针对快速滚动、固定顶部内容、低信息画面的拼接容错
- 长图内存上限、确定性拼接，以及全流程 `Escape` 取消
- 菜单栏入口、可修改全局快捷键和无打扰启动
- 所有截图像素只在本机处理

本项目明确不包含录屏、录音、翻译、OCR、账号、遥测和云上传。

<p align="center">
  <img src="docs/images/settings.png" width="880" alt="原生设置页面与可编辑快捷键">
</p>

<p align="center"><em>原生设置页面与可编辑快捷键。图中快捷键是本机配置示例。</em></p>

## 当前状态

从 [GitHub Releases](https://github.com/nasadunadu/screen-capture-macos/releases/latest) 下载已签名、公证的应用。打开 DMG，将 ScreenCapture 拖入“应用程序”即可；同时提供 ZIP 下载。普通用户无需安装 Xcode。

`0.4.12` 是本个人独立维护的开源项目的稳定性修复版。各版本说明列出了验证结果及兼容性边界；自动化验证不代表所有受支持 Mac 都已完成实机验收。

## 环境要求

- macOS 14 或更高版本
- 开发时使用 Xcode 26 或更高版本
- 第一次截图时允许“屏幕与系统音频录制”权限

## 构建与运行

使用 Xcode 打开 `ScreenCapture.xcodeproj`，如果 Xcode 提示签名，请选择你自己的开发团队，然后按 `Command-R`。

不依赖签名的命令行构建：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ScreenCapture.xcodeproj \
  -scheme ScreenCapture \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
```

应用启动后不会主动弹出主窗口，可以从 Dock 或菜单栏图标调用。只有第一次真正开始截图时，macOS 才会请求屏幕录制权限。

## 默认快捷键

| 操作 | 快捷键 |
| --- | --- |
| 普通区域截图 | `Command-4` |
| 滚动长截图 | `Command-5` |
| 取消当前截图流程 | `Escape` |

所有截图快捷键都可以在 **设置 → 截图** 中修改。

## 测试

```sh
./scripts/ci.sh
```

该脚本会检查配置文件、运行完整单元测试、执行 Xcode 静态分析，并生成未签名的双架构 Release 构建。人工验收、签名和公证要求见[发布检查表](docs/RELEASE_CHECKLIST.md)与[发行说明](docs/DISTRIBUTION.md)。

## 已知限制

- 长截图依赖相邻画面存在可识别重叠；视频、持续动画、大幅横向移动或每帧都会重绘的内容可能无法可靠拼接。
- macOS 将截图能力归入屏幕录制权限，但本应用不会录制视频。
- 系统授权、跨显示器和完整交互仍需真机验收，无法全部由单元测试覆盖。

## 参与贡献与安全问题

提交代码前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。安全或隐私问题请按照 [SECURITY.md](SECURITY.md) 私下报告，不要直接创建公开 Issue。

## 许可证

项目使用 [Apache License 2.0](LICENSE) 开源。

Screen Capture 是个人独立项目，与 Apple 或 iShot 不存在隶属、授权或背书关系。
