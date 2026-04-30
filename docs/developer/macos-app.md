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

## 构建 `.dmg`

```bash
./scripts/build_macos_dmg.sh
```

默认产物：

```text
dist/Podcast Transcript Studio.dmg
```

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
