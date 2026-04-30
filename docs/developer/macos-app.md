# macOS App

macOS app 是桌面端入口，使用 SwiftUI 构建窗口界面，并通过 `PodcastTranscriptStudioCore` 调用本地 Python worker。

## 功能

- 导入本地音频或视频文件
- 创建本地转写任务
- 查看任务列表与任务详情
- 编辑说话人显示名
- 解析转写结果
- 导出 `TXT`、`JSON`、`MD`、`SRT`
- 使用打包脚本准备模型和 worker 资源

## 开发运行

```bash
swift run PodcastTranscriptStudioApp
```

## 构建 `.app`

```bash
./scripts/build_macos_app.sh
```

默认产物：

```text
dist/Podcast Transcript Studio.app
```

如果需要指定版本号、构建号或 Python 运行时：

```bash
APP_VERSION=0.1.0 \
BUILD_NUMBER=1 \
PYTHON_BIN=.worker-venv/bin/python \
./scripts/build_macos_app.sh
```

打包脚本默认从 `PYTHON_BIN` 推导 Python runtime，并复制当前环境的 `site-packages`。本地建议使用 Python 3.11 或 3.12 的 worker 环境：

```bash
python3.11 -m venv .worker-venv
.worker-venv/bin/python -m pip install --upgrade pip
.worker-venv/bin/python -m pip install -r requirements-worker.txt
```

## 构建 `.dmg`

```bash
./scripts/build_macos_dmg.sh
```

默认产物：

```text
dist/PodcastTranscriptStudio-0.1.0.dmg
dist/PodcastTranscriptStudio-0.1.0.dmg.sha256
```

常用参数：

- `APP_VERSION`：写入 `Info.plist`，也用于默认 DMG 文件名
- `BUILD_NUMBER`：写入 `Info.plist`
- `DMG_NAME`：自定义 DMG 文件名
- `PYTHON_BIN`：指定用于检测 runtime 与依赖目录的 Python
- `PYTHON_HOME_SRC`：手动指定 Python runtime 来源目录
- `PYTHON_SITE_PACKAGES_SRC`：手动指定依赖包来源目录
- `SKIP_PYTHON_RUNTIME_CHECK=1`：跳过 worker 依赖导入检查，只验证 app 和 DMG 结构
- `SKIP_CODESIGN=1`：跳过本地签名

默认签名方式是 ad-hoc signing。正式分发前还需要接入 Developer ID 签名和 notarization。

## GitHub Actions

`.github/workflows/macos-dmg.yml` 会在两种情况下构建 DMG：

- 手动运行 `macOS DMG` workflow
- 推送 `v*` tag，例如 `v0.1.0`

workflow 使用 `macos-15` runner、Swift release 构建和 Python 3.11 worker 依赖。产物会上传为 workflow artifact：

```text
PodcastTranscriptStudio-<version>-macOS
```

如果仓库配置了 `HF_TOKEN` secret，workflow 会先从 Hugging Face 下载模型并执行 `scripts/package_models.sh`，再构建 DMG。没有 `HF_TOKEN` 时，workflow 仍会构建不含模型资源的 DMG。

如果是 tag 触发，workflow 还会把 DMG 和 `.sha256` 文件上传到对应 GitHub Release。

## 测试

```bash
swift test
```

如果测试时报 `no such module 'XCTest'`，使用完整 Xcode 路径：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

## 模型与 worker 资源

先准备 Hugging Face 本地缓存，然后执行：

```bash
./scripts/package_models.sh
```

脚本会把模型快照和 worker 脚本复制到：

```text
Sources/PodcastTranscriptStudioCore/Resources/
```

## 已知边界

- 签名与公证流程还需要补齐
- Intel Mac 兼容性还需要真实设备验证
- 长音频样本还需要更多应用内验证
