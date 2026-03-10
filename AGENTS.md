# AGENTS.md

本文件为 Codex (Codex.ai/code) 在此代码库中工作时提供指导。

---

## 项目概述

**RadioApp (拾音 FM)** 是一个基于 SwiftUI 的互联网电台流媒体应用，具备音乐识别功能。支持 iOS、iPad 和 macOS（通过 Mac Catalyst），采用独特的霓虹赛博朋克/玻璃态设计主题。

### 核心功能
- 从 radio-browser.info API 流式播放电台
- 通过 ShazamKit 和 ACRCloud 进行音乐识别
- Pro 订阅（使用 StoreKit 2，终身制，配额 iCloud 同步）
- 使用 SwiftData 追踪历史记录
- 主屏幕小组件和实时活动（Live Activities）

---

## 构建和运行命令

### Xcode 项目
**项目文件：** `RadioApp.xcodeproj`

```bash
# 为 iOS 模拟器构建
xcodebuild -project RadioApp.xcodeproj -scheme RadioApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build

# 为 Mac (Catalyst) 构建
xcodebuild -project RadioApp.xcodeproj -scheme RadioApp -destination 'platform=macOS' build

# 清理构建文件夹
xcodebuild -project RadioApp.xcodeproj -scheme RadioApp clean

# 在模拟器上运行（打开 Xcode）
open RadioApp.xcodeproj
# 然后在 Xcode 中按 Cmd+R
```

### Python 脚本
```bash
# 获取预置电台数据用于离线回退
python3 fetch_preset.py

# 导入资源到 Assets.xcassets
python3 import_assets.py
```

---

## 架构

### 入口点流程
```
RadioApp.swift (App 入口)
    └── MainLayout (平台检测)
        ├── iPhone → ContentView (无 Tab，迷你播放器在底部)
        └── iPad/Mac → SidebarLayout (侧边栏导航 + 详情视图)
```

### Manager 层（单例模式）
所有 manager 都是 `@MainActor` 类，使用 `static let shared`：

| Manager | 职责 | 关键 Published 属性 |
|---------|---------------|--------------------------|
| `AudioPlayerManager` | AVPlayer 播放、播放列表、睡眠定时器、正在播放信息 | `isPlaying`, `currentStation`, `volume`, `playlistStations` |
| `FavoritesManager` | 用户收藏的电台 | `favoriteStations` |
| `SubscriptionManager` | StoreKit 2 购买、Pro 状态、配额 iCloud 同步 | `isPro`, `currentCredits` |
| `HistoryManager` | SwiftData 持久化播放历史 | `historyEntries` |
| `ShazamMatcher` | 通过 ShazamKit + ACRCloud 回退进行音乐识别 | `isMatching`, `lastMatch`, `lyrics` |
| `StationBlockManager` | 已屏蔽电台（本地 + Supabase 上报） | `blockedStationIds` |

### Service 层
| Service | 用途 |
|---------|---------|
| `RadioService` | 从 radio-browser.info API 获取电台，带镜像故障转移 |
| `StreamSampler` | 捕获音频样本用于音乐识别 |
| `LRCParser` | 解析 .lrc 歌词文件 |
| `MusicPlatformService` | 在网易云/QQ 音乐上查找歌曲 ID 用于深度链接 |
| `AppleMusicService` | Apple Music 目录查找和歌单操作 |
| `PostHogManager` | 分析事件追踪 |

### 视图通信模式
视图通过 `@ObservedObject` 直接观察 manager：
```swift
@ObservedObject var playerManager = AudioPlayerManager.shared
@ObservedObject var favoritesManager = FavoritesManager.shared
```

**重要：** 永远不要在本地创建 manager 实例。始终使用 `.shared`。

### 平台条件编译
```swift
#if targetEnvironment(macCatalyst)
// Mac 特定代码（窗口大小、侧边栏始终可见）
#elseif os(iOS)
if UIDevice.current.userInterfaceIdiom == .phone {
    // iPhone 布局
} else {
    // iPad 布局
}
#endif
```

---

## 关键模式和约定

### 状态管理
- `@State` - 本地 UI 状态（如 `showPlayer`, `isPressed`）
- `@ObservedObject` - Manager 引用（始终使用 `.shared`）
- `@StateObject` - 视图拥有（用于 ViewModels）
- `@Binding` - 子视图通信
- `@Published` - 在 manager 中用于可观察属性

### 导航
- **iPhone：** 无标准 NavigationView。使用自定义 sheet/fullScreenCover 展示。
- **iPad/Mac：** 带侧边栏的 `NavigationSplitView`。
- Mac 上播放器覆盖层使用 ZStack 分层而非 fullScreenCover，以避免尺寸问题。

### 异步图片加载
始终使用 `StationAvatarView` 加载电台封面 - 它处理：
- 远程 URL 加载，8 秒超时
- Bundle 资源引用（`bundle://` 前缀）
- 优雅回退到渐变 `PlaceholderView`

### Pro 功能控制模式
```swift
if subscriptionManager.isPro {
    // 显示 Pro 功能
} else {
    showProUpgrade = true
}
```

### 颜色和样式
- **永远不要硬编码颜色。** 使用 `DesignSystem.swift` 中的 `NeonColors.*`
- 主强调色：`NeonColors.cyan` (#00D9FF)
- 次强调色：`NeonColors.magenta` (#FF006E)
- 背景：`NeonColors.darkBg` (#0A0A0F)
- 对交互元素使用 `.neonGlow()` 修饰符

---

## 数据持久化

| 存储 | 用途 |
|---------|-------|
| SwiftData | 播放历史 |
| UserDefaults | 设置、收藏缓存、购买状态 |
| iCloud Key-Value | Pro 配额跨设备同步 |
| NSFileCoordinator | 当前未使用 |

---

## Widget 扩展

**位置：** `RadioAppWidget/`

- 使用 `AppIntent` 深度链接到主应用
- 实时活动支持"正在播放"
- 通过 App Group 共享 `HistoryManager`

---

## API 集成说明

### Radio Service
- 使用 radio-browser.info API
- 多个镜像服务器自动故障转移
- `PresetStationData.swift` 中的预置数据用于离线回退

### 音乐识别
- 主要：ShazamKit（内置，免费）
- 回退：ACRCloud（消耗 Pro 配额，中文歌曲效果更好）
- 当 Shazam 未命中且用户有配额时触发高级匹配

### 音乐平台深度链接
- 网易云：`orpheus://song/{id}` 或搜索
- QQ 音乐：自定义 JSON scheme 或搜索
- Apple Music：标准 `music://` URL

---

## 常见问题和解决方案

### Mac Catalyst 窗口大小
如果窗口不可调整大小：
```swift
#if targetEnvironment(macCatalyst)
.frame(minWidth: 800, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
.defaultSize(width: 1000, height: 750)
#endif
```

### Mac 上的播放器覆盖层
不要在 Mac 上使用 `.fullScreenCover()` - 它会导致尺寸问题。使用 ZStack 覆盖层配合 `.zIndex(200)`。

### 音频会话中断
`AudioPlayerManager` 处理电话和其他音频中断。`handleInterruption` 观察者会在适当时恢复播放。

### ShazamKit 匹配
- 必须在播放电台前开始匹配以获得最佳效果
- 每 2 秒捕获一次流样本
- 匹配持续约 30 秒后超时

---

## Figma 集成（设计系统）

将 Figma 设计转换为 SwiftUI 代码时，参考以下设计令牌和模式。

### 颜色令牌（`NeonColors` 结构体）
**位置：** `RadioApp/Views/Components/DesignSystem.swift`

```swift
// 主色
static let cyan = Color(hex: "00D9FF")
static let magenta = Color(hex: "FF006E")
static let purple = Color(hex: "8338EC")

// 背景色
static let darkBg = Color(hex: "0A0A0F")
static let cardBg = Color(hex: "151520")
static let surfaceBg = Color(hex: "1A1A2E")
```

### 排版比例
```swift
.font(.system(size: 42, weight: .bold))   // 页面标题
.font(.system(size: 28, weight: .bold))   // 大标题
.font(.system(size: 20, weight: .bold))   // 分区标题
.font(.system(size: 16, weight: .medium)) // 正文
.font(.system(size: 14))                  // 小标签
```

### 间距和圆角
- 间距：4, 8, 12, 16（默认）, 20, 24, 32, 40
- 圆角：10（小）, 12-16（卡片）, 20-24（弹窗）

### 可复用组件
| 组件 | 用途 |
|-----------|---------|
| `GlassCard<Content>` | 玻璃态容器 |
| `PlayButton` | 主播放/暂停按钮带发光 |
| `NeonSlider` | 音量滑块 |
| `EnhancedVisualizerView` | 音频可视化条 |
| `PulsingView` | "正在播放"指示器 |
| `PlaceholderView` | 缺失图片的渐变占位符 |
| `StationAvatarView` | 带占位符的异步图片 |

### 关键视觉模式
```swift
// 玻璃态背景
GlassmorphicBackground(cornerRadius: 20, glowColor: NeonColors.cyan)

// 霓虹发光
.neonGlow(color: NeonColors.cyan, radius: 10)

// 动态网格背景
AnimatedMeshBackground()

// 噪点纹理
NoiseOverlay().opacity(0.03)
```

### Figma 转代码步骤
1. 将 Figma 填充映射到 `NeonColors.*`
2. 尽可能使用现有组件
3. 对交互元素应用 `.neonGlow()`
4. 对容器使用玻璃态
5. 为交互添加弹性动画

### 组件使用示例
```swift
GlassCard(glowColor: NeonColors.cyan) {
    VStack(alignment: .leading, spacing: 12) {
        Text("标题")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
        Text("副标题")
            .font(.system(size: 14))
            .foregroundColor(NeonColors.cyan.opacity(0.8))
    }
}
```

---

## 文件组织

```
RadioApp/
├── RadioApp.swift          # App 入口，PostHog 初始化
├── ContentView.swift       # iPhone 根视图 + MiniPlayerBar
├── Models/                 # Codable, Identifiable 结构体
├── Views/
│   ├── MainLayout.swift    # 平台检测路由
│   ├── SidebarView.swift   # 导航侧边栏
│   ├── HomeView.swift      # 主发现页 + NeonStationCard
│   ├── PlayerView.swift    # 全屏播放器 + Shazam 覆盖层
│   ├── SearchView.swift
│   ├── FavoritesView.swift
│   ├── HistoryView.swift
│   ├── SettingsView.swift
│   └── Components/
│       ├── DesignSystem.swift        # NeonColors，可复用组件
│       ├── PlaceholderView.swift     # 渐变占位符
│       ├── StationAvatarView.swift   # 异步图片加载
│       └── ...
├── Services/               # 单例 manager (@MainActor)
├── Managers/               # StationBlockManager
└── Assets.xcassets/        # 图片，颜色集
```

---

## 命名约定

| 类型 | 约定 | 示例 |
|------|------------|---------|
| Views | PascalCase | `PlayerView`, `MiniPlayerBar` |
| Components | PascalCase + 前缀 | `NeonStationCard`, `GlassCard` |
| Managers | PascalCase + 后缀 | `AudioPlayerManager` |
| Models | PascalCase | `Station`, `RecognizedSong` |
| State 变量 | camelCase | `isPlaying`, `showProUpgrade` |
| Colors | PascalCase | `NeonColors.cyan` |
