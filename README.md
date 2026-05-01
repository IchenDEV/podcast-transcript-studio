# Podcast Transcript Studio

[English](README.en.md)

Podcast Transcript Studio 是一个本地优先的播客转写工具。项目提供网页入口、macOS 入口、Python worker，以及可复用的 transcript 数据结构，适合把播客、访谈、会议录音和本地视频转成可读文本。

## 当前状态

项目处在可运行开发版本，已经具备核心使用路径：

- 上传本地音频或视频文件
- 从公开播客链接导入音频，覆盖 Apple Podcasts、小宇宙、喜马拉雅公开 RSS/专辑页和直连音频
- 创建转写任务并查看任务状态
- 生成可读稿和逐字稿
- 导出 `TXT`、`JSON`、`SRT`、`MD`
- 提供快速、标准、高质量三种模式
- Web 与 macOS 入口共用 Python worker 设计

## 快速开始

推荐先使用网页入口。

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
```

```bash
python -m uvicorn podcast_web.app:app --reload
```

打开：

- <http://127.0.0.1:8000>

在首页上传文件，或粘贴公开播客链接，选择模式，然后创建任务。任务完成后可以在结果页查看文本并下载文件。

链接导入只处理公开可访问的音频页面、RSS 和直连音频地址；需要登录或付费权限的内容请先下载成本地文件。

## 模型文件

默认 ASR 模型为 `openai/whisper-tiny`。多说话人能力依赖 pyannote 相关模型，其中部分模型需要 Hugging Face 登录和模型许可。

本地模型资源目录：

```text
~/Library/Application Support/PodcastTranscriptStudio/Models/
```

macOS app 的设置页可以修改模型目录，并直接下载所需模型。需要使用多说话人能力时，先在 Hugging Face 接受 pyannote 相关模型许可，再在设置页填写 token。

如果需要把模型一起放进 DMG，可以先在本机完成 Hugging Face 登录和模型许可，再执行 `./scripts/package_models.sh`。该脚本会把模型复制到：

```text
Sources/PodcastTranscriptStudioCore/Resources/Models/
```

## 项目结构

```text
podcast_web/                  FastAPI 网页入口
packages/core/                transcript 数据结构和可读稿逻辑
packages/podcast_fetcher/     公开播客链接解析与音频下载
packages/transcriber/         用户模式与 worker preset 映射
packages/python_worker/       Python worker 入口和转写脚本
Sources/PodcastTranscriptStudioCore/  Swift 核心模块
Sources/PodcastTranscriptStudioApp/   SwiftUI macOS 入口
tests/                        Python 与 Swift 测试
scripts/                      打包和模型资源脚本
docs/developer/               开发架构文档
```

## 开发命令

Python 测试：

```bash
source .venv/bin/activate
python -m pytest tests -v
```

Swift 测试：

```bash
swift test
```

如果当前 `xcode-select` 指向 Command Line Tools，且测试时报 `no such module 'XCTest'`，使用完整 Xcode 路径：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

macOS 入口：

```bash
swift run PodcastTranscriptStudioApp
```

模型资源脚本：

```bash
./scripts/package_models.sh
```

单独运行设置页同款模型下载脚本：

```bash
python Sources/PodcastTranscriptStudioCore/Resources/Scripts/download_models.py \
  --models-dir "$HOME/Library/Application Support/PodcastTranscriptStudio/Models"
```

worker 推理依赖体积较大，需要时再安装：

```bash
python -m pip install -r requirements-worker.txt
```

worker 推理依赖建议使用 Python 3.10 到 3.12。

## 文档

- 开发架构：`docs/developer/architecture.md`
- macOS 说明：`docs/developer/macos-app.md`

## 适用场景

- 播客和访谈转写
- 会议录音整理
- 本地隐私优先的音视频文本化
- macOS 本地转写产品的继续开发
