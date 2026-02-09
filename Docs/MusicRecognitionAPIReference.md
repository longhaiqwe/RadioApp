# 音乐识别 API 返回信息参考

本文档记录 Shazam 和 ACRCloud 两个音乐识别服务返回的所有可用信息，供后续功能开发参考。

---

## Shazam (ShazamKit)

### 已使用字段

| 字段 | 类型 | 说明 | 使用场景 |
|-----|------|------|---------|
| `title` | String | 歌曲名 | 主显示 |
| `artist` | String | 歌手 | 主显示 |
| `artworkURL` | URL | 专辑封面 | 展示封面 |
| `predictedCurrentMatchOffset` | TimeInterval | 当前播放进度(秒) | 歌词同步 |

### 可用但未使用字段

| 字段 | 类型 | 说明 | 潜在功能 |
|-----|------|------|---------|
| `appleMusicID` | String | Apple Music ID | 跳转 Apple Music |
| `appleMusicURL` | URL | Apple Music 链接 | 一键听歌 |
| `webURL` | URL | Shazam 网页链接 | 分享歌曲 |
| `genres` | [String] | 音乐流派 | 流派统计/分类 |
| `isrc` | String | 国际标准录音代码 | 跨平台匹配 |
| `albumTitle` | String | 专辑名 | 专辑信息卡片 |
| `composer` | String | 作曲者 | 古典/原声展示 |
| `videoURL` | URL | MV 链接 | 观看 MV |
| `releaseDate` | Date | 发行日期 | ⭐ 时光机功能 |
| `shazamID` | String | Shazam 唯一 ID | 收藏/去重 |
| `explicitContent` | Bool | 露骨内容标记 | 家长模式 |
| `subtitle` | String | 副标题 | 附加信息展示 |

---

## ACRCloud

### 已使用字段

| 字段 | JSON 路径 | 说明 | 使用场景 |
|-----|----------|------|---------|
| `title` | `metadata.music[].title` | 歌曲名 | 主显示 |
| `langs` | `metadata.music[].langs[]` | 多语言名称 | 中文优先选择 |
| `artists` | `metadata.music[].artists[].name` | 歌手 | 主显示 |
| `play_offset_ms` | `metadata.music[].play_offset_ms` | 播放进度(毫秒) | 歌词同步 |

### 可用但未使用字段

| 字段 | JSON 路径 | 说明 | 潜在功能 |
|-----|----------|------|---------|
| `album.name` | `metadata.music[].album.name` | 专辑名 | 专辑信息卡片 |
| `release_date` | `metadata.music[].release_date` | 发行日期 | ⭐ 时光机功能 |
| `duration_ms` | `metadata.music[].duration_ms` | 歌曲总时长 | 剩余时间显示 |
| `score` | `metadata.music[].score` | 匹配置信度(0-100) | 识别可信度提示 |
| `genres` | `metadata.music[].genres[].name` | 音乐流派 | 流派统计 |
| `label` | `metadata.music[].label` | 唱片公司 | 数据统计 |
| `external_ids.spotify` | `metadata.music[].external_ids.spotify` | Spotify ID | 跳转 Spotify |
| `external_ids.isrc` | `metadata.music[].external_ids.isrc` | ISRC 码 | 跨平台匹配 |
| `external_metadata.spotify` | `metadata.music[].external_metadata.spotify` | Spotify 详情 | 一键跳转 |
| `external_metadata.deezer` | `metadata.music[].external_metadata.deezer` | Deezer 详情 | 一键跳转 |
| `external_metadata.youtube` | `metadata.music[].external_metadata.youtube` | YouTube 详情 | 观看 MV |

---

## 功能规划清单

### 优先级 P0 (推荐优先实现)
- [ ] **时光机** - 显示歌曲发行年代，计算"xx年前的歌"
- [ ] **剩余时间显示** - 利用 duration_ms 预估歌曲还剩多久
- [ ] **多平台跳转** - Apple Music / Spotify / QQ音乐

### 优先级 P1
- [ ] **置信度提示** - score < 80 时提示"识别可能不准"
- [ ] **流派统计** - 生成用户听歌风格报告
- [ ] **专辑信息卡片** - 展示专辑名、封面、发行信息

### 优先级 P2
- [ ] **MV 快捷入口** - 识别后可快速观看 MV
- [ ] **家长模式** - 跳过露骨内容
- [ ] **歌曲收藏** - 利用 shazamID/isrc 去重

---

## 代码位置参考

- Shazam 识别: `RadioApp/Services/ShazamMatcher.swift`
- ACRCloud 识别: `RadioApp/Services/ACRCloudMatcher.swift`
- 音乐平台服务: `RadioApp/Services/ShazamMatcher.swift` (MusicPlatformService)
