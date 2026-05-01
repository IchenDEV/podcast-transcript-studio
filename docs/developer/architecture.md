# 开发架构

这份文档说明当前代码结构和开发边界。

## 目标

Podcast Transcript Studio 采用本地优先架构，核心目标是：

- 普通用户可以先通过 Web 入口完成转写
- macOS 入口复用同一套转写能力
- transcript 数据结构、用户模式、worker 执行逻辑保持清晰边界
- 模型推理细节集中在 Python worker 内部

## 技术架构图

当前系统有两个入口：Web app 和 macOS app。两者可以导入本地文件，也可以先把公开播客链接解析成音频文件。之后都启动 Python worker，worker 生成 `transcript.txt` 和 `transcript.json`，再由入口层展示、解析或导出。

```mermaid
flowchart TB
    User["用户"]

    subgraph WebEntry["Web 入口"]
        WebPage["HTML 页面<br/>podcast_web/templates"]
        FastAPI["FastAPI 路由<br/>podcast_web/app.py"]
        PodcastFetcher["链接解析<br/>packages/podcast_fetcher"]
        WebRepo["JobRepository<br/>SQLite + data/jobs"]
        WebService["转写服务<br/>后台线程 + subprocess"]
    end

    subgraph MacEntry["macOS 入口"]
        SwiftUI["SwiftUI App<br/>Sources/PodcastTranscriptStudioApp"]
        MacCore["Core 层<br/>任务 / 解析 / 导出"]
        PodcastImporter["链接解析<br/>PodcastAudioImporter"]
        CommandBuilder["WorkerCommandBuilder<br/>ProcessWorkerRunner"]
        AppSupport["Application Support<br/>jobs / exports / logs"]
    end

    subgraph SharedRules["共享规则"]
        Modes["用户模式<br/>quick -> lite<br/>standard -> balanced<br/>high_quality -> production"]
        TranscriptCore["稿件结构<br/>Segment / Section / Document"]
    end

    subgraph Worker["Python worker"]
        DevCLI["开发态 CLI<br/>packages/python_worker/cli.py"]
        BundledCLI["打包资源 CLI<br/>Resources/Scripts/cli.py"]
        ModelDownloader["模型下载脚本<br/>Resources/Scripts/download_models.py"]
        WorkerScript["转写脚本<br/>transcribe_with_speaker_segmentation.py"]
        Presets["worker preset<br/>lite / balanced / production"]
        Models["运行时模型<br/>Application Support/Models"]
        BundledModels["内置模型<br/>Resources/Models"]
        Outputs["输出文件<br/>transcript.txt + transcript.json"]
    end

    Packager["scripts/package_models.sh"]

    User --> WebPage --> FastAPI
    User --> SwiftUI --> MacCore

    FastAPI --> PodcastFetcher
    PodcastFetcher --> WebService
    FastAPI --> Modes
    FastAPI --> WebRepo
    FastAPI --> WebService
    WebService --> DevCLI

    MacCore --> PodcastImporter
    PodcastImporter --> AppSupport
    MacCore --> CommandBuilder
    CommandBuilder --> BundledCLI
    CommandBuilder --> AppSupport
    MacCore --> ModelDownloader
    ModelDownloader --> Models

    DevCLI --> WorkerScript
    BundledCLI --> WorkerScript
    WorkerScript --> Presets
    WorkerScript --> Models
    WorkerScript --> BundledModels
    WorkerScript --> Outputs

    Outputs --> WebRepo
    Outputs --> MacCore
    FastAPI --> TranscriptCore
    MacCore --> TranscriptCore

    Packager --> BundledCLI
    Packager --> BundledModels
```

图里有三个关键边界：

- Web 开发态直接调用 `packages/python_worker/cli.py`。
- Web 链接导入通过 `packages/podcast_fetcher/` 下载公开音频，再交给转写服务。
- macOS 链接导入通过 `PodcastAudioImporter` 下载公开音频到 Application Support，再交给 `WorkerCommandBuilder`。
- macOS 通过 `WorkerCommandBuilder` 调用 `Resources/Scripts/cli.py`，优先使用设置页配置的模型目录，也兼容 DMG 内置模型。
- 设置页通过 `Resources/Scripts/download_models.py` 下载模型到 Application Support 或用户指定目录。
- `scripts/package_models.sh` 负责把 worker 脚本和 Hugging Face cache 中的模型复制为 DMG 内置资源。
- `packages/core/` 和 `packages/transcriber/` 只放共享数据结构与用户模式映射，UI 层不要重复定义底层 preset。

## 分层

### Web 入口

路径：

- `podcast_web/`

职责：

- 上传文件
- 解析公开播客链接并下载音频
- 创建任务
- 查看任务状态
- 展示结果
- 提供下载

Web 层不维护独立的 transcript 协议，也不直接管理模型参数。

### transcript 核心

路径：

- `packages/core/transcript.py`

职责：

- `TranscriptSegment`
- `TranscriptSection`
- `TranscriptDocument`
- 可读稿生成逻辑

Web、macOS 和未来 CLI 都应复用这套结构。

### 用户模式

路径：

- `packages/transcriber/modes.py`

职责：

- 定义 `quick`
- 定义 `standard`
- 定义 `high_quality`
- 把用户可理解的模式映射到 worker preset

UI 层只展示模式，不重复定义底层参数。

### Python worker

路径：

- `packages/python_worker/`

职责：

- worker CLI
- ASR preset 配置
- 文本清理
- 转写脚本

`packages/python_worker/transcribe_with_speaker_segmentation.py` 是当前 Python worker 主脚本。macOS 资源目录中的脚本由 `scripts/package_models.sh` 复制生成。

### macOS 核心

路径：

- `Sources/PodcastTranscriptStudioCore/`

职责：

- 任务模型
- 任务存储
- 公开播客链接解析与音频下载
- worker 命令构建
- worker 进程执行
- transcript 解析
- 导出格式
- 打包计划

### macOS 界面

路径：

- `Sources/PodcastTranscriptStudioApp/`

职责：

- SwiftUI app 入口
- 导入文件
- 导入公开播客链接
- 展示任务列表与任务详情
- 展示设置页
- 修改本地目录配置
- 下载本地模型

## 数据目录

默认本地运行数据：

- `data/uploads/`
- `data/jobs/`
- `data/podcast_web.sqlite3`

这些文件属于运行产物，不应作为源代码提交。

## 测试入口

Python：

```bash
source .venv/bin/activate
python -m pytest tests -v
```

Swift：

```bash
swift test
```

## 开发顺序

建议优先检查共享层，再检查入口层：

1. `packages/core/`
2. `packages/transcriber/`
3. `packages/python_worker/`
4. `podcast_web/`
5. `Sources/PodcastTranscriptStudioCore/`
6. `Sources/PodcastTranscriptStudioApp/`

这样可以减少重复逻辑，也能让 Web 和 macOS 的行为更一致。
