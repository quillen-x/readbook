# 读本书

Mac 电子书阅读器，基于 Flutter 构建，支持 EPUB 与 MOBI 格式。

## 功能特性

- **本地书架** — 导入并管理电子书，自动记录阅读进度
- **多格式支持** — EPUB、MOBI（含 AZW / AZW3 导入，MOBI 自动转换为 EPUB 阅读）
- **在线下载** — 内置书源浏览与下载，下载后可直接加入书架
- **阅读体验** — 翻页阅读、目录导航、书签与高亮
- **个性化设置**
  - 界面主题：亮色 / 暗色 / 护眼
  - 阅读主题：白色 / 护眼 / 深色
  - 字体：阿里巴巴普惠体、苹方、思源宋体
  - 字号、行距、字重、页边距可调
  - 自定义书架背景图与透明度
- **桌面体验** — macOS 无边框窗口，支持拖拽移动

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.38+ |
| 状态管理 | Riverpod |
| EPUB 阅读器 | [katbook_epub_reader](packages/katbook_epub_reader)（内置包） |
| MOBI 解析 | kindle_unpack |
| 桌面窗口 | window_manager |

## 环境要求

- Flutter SDK `>=3.0.0 <4.0.0`（项目使用 [FVM](https://fvm.app/) 锁定为 **3.38.1**）
- macOS（主要目标平台，亦可在 Windows / Linux / iOS / Android 上运行）

## 快速开始

```bash
# 克隆项目后进入目录
cd readbook

# 使用 FVM 安装并切换 Flutter 版本（推荐）
fvm install
fvm use

# 安装依赖
fvm flutter pub get

# macOS 运行
fvm flutter run -d macos

# 构建 macOS 发布包
fvm flutter build macos --release
```

若未安装 FVM，可直接使用本地 Flutter：

```bash
flutter pub get
flutter run -d macos
```

## 使用说明

1. **导入书籍** — 点击右下角设置按钮 →「导入电子书」，选择 `.epub`、`.mobi`、`.azw`、`.azw3` 文件
2. **开始阅读** — 在书架点击书籍封面
3. **在线下载** — 点击左下角下载按钮，浏览书源并下载
4. **阅读设置** — 阅读界面点击屏幕唤起快捷设置（字体、主题、字号等）

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── screens/                  # 页面（书架、阅读器、设置、下载）
├── services/                 # 书籍与设置服务
├── downloads/                # 在线书源与下载
├── models/                   # 数据模型
├── providers/                # Riverpod 状态
├── theme/                    # 主题与文字样式
└── widgets/                  # 通用组件

packages/
└── katbook_epub_reader/      # 自研 EPUB 阅读引擎
```

## 开发

```bash
# 运行测试
fvm flutter test

# 生成应用图标
fvm flutter pub run flutter_launcher_icons
```

## 许可证

本项目为私有项目（`publish_to: 'none'`）。
