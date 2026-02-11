# App Store 审核说明文档

## 中文版

### 致 App Store 审核团队

感谢您对「拾音FM」的审核反馈。我们就应用中涉及的第三方音频流媒体问题做全面说明。

---

### 关于我们的服务

**「拾音FM」** 是一款电台发现工具，将用户连接到 Radio Browser 数据库，这是一个由社区驱动的合法网络电台目录。

**核心定位：**
- 我们是**电台发现工具**，不是内容托管商或分发平台
- 我们**不托管、不上传、不分发**任何音频流内容
- 所有音频流均直接从电台服务器播放

---

### 我们的内容政策

**1. 只收录公开可用的网络电台**
- 我们只接入 Radio Browser 社区验证过的、明确允许第三方播放的网络电台
- 不包含任何需要特殊授权的付费内容或会员专享内容

**2. 严格的过滤规则**

我们实施了多层过滤机制，自动屏蔽以下内容：

| 过滤类型 | 屏蔽内容 |
|---------|---------|
| 电视台音频流 | CCTV、CGTN、所有省级卫视、凤凰卫视等 |
| 新闻直播 | 新闻联播、国际新闻、本地新闻联播等 |
| 明确禁止转播的内容 | 已被社区标记为禁止转播的电台 |
| 电视伴音 | 各类电视节目的音频伴音流 |

**3. 过滤实现方式**

- **本地关键词过滤**：应用内置关键词库，在展示电台列表前自动匹配和过滤
- **在线黑名单同步**：定期从服务器拉取最新的黑名单（UUID + 关键词）
- **用户举报机制**：用户可随时举报不当电台，我们承诺 24 小时内审核并更新全局黑名单

---

### 第三方服务授权

| 服务 | 授权状态 |
|-----|---------|
| **音乐识别** | 使用 Shazam SDK（Apple 官方） - 已获授权 |
| **高级识别** | 使用 ACRCloud - 已获得商业使用许可 |
| **电台目录** | 使用 Radio Browser API (AGPL-3.0) - 原样使用，未作修改，符合开源许可要求 |

---

### 合规措施

**1. 技术层面**
- 自动关键词过滤（本地 + 远程双重校验）
- 实时黑名单同步机制
- 用户举报系统（支持举报理由说明）

**2. 内容审核**
- 人工审核用户举报内容
- 定期扫描社区黑名单更新
- 快速响应版权投诉（24 小时内处理）

**3. 用户协议**
- 服务条款（EULA）明确版权免责声明
- 隐私政策说明不收集用户个人数据
- 用户可随时举报不当内容

**4. 举报通道**
- 播放页面提供"屏蔽此电台"和"屏蔽并举报"两个选项
- 举报数据实时上传至服务器进行人工审核
- 审核通过后加入全局黑名单，所有用户生效

---

### 承诺与保证

我们郑重承诺：

1. **零容忍政策**：对版权侵权、色情、暴力、仇恨言论等内容实行零容忍
2. **快速响应**：收到版权投诉后 24 小时内审核并处理
3. **持续监控**：定期审查和更新过滤规则
4. **透明沟通**：如有特定电台或类别需移除，我们立即配合

---

### 联系方式

如需进一步沟通或核实任何具体电台信息，请通过以下方式联系我们：

- GitHub Issues: https://github.com/longhaiqwe/RadioApp/issues
- 邮箱: [待补充]

此致，

**拾音FM 团队**

---

## English Version

### To the App Store Review Team

Thank you for your review feedback regarding **拾音FM (Shiyin FM)**. We would like to provide comprehensive clarification regarding third-party audio streaming in our app.

---

### About Our Service

**拾音FM (Shiyin FM)** is a radio discovery tool that connects users to the Radio Browser database, a community-driven directory of legitimate internet radio stations.

**Core Position:**
- We are a **radio discovery tool**, not a content host or distribution platform
- We **do not host, upload, or redistribute** any audio streaming content
- All audio streams are played directly from the radio station's servers

---

### Our Content Policy

**1. Only Publicly Available Internet Radio Stations**
- We only index internet radio stations verified by the Radio Browser community that explicitly allow third-party playback
- No paid content or member-exclusive content requiring special authorization

**2. Strict Filtering Rules**

We have implemented a multi-layer filtering mechanism to automatically block the following content:

| Filter Type | Blocked Content |
|-----------|----------------|
| TV Audio Streams | CCTV, CGTN, all provincial satellite TV stations, Phoenix TV, etc. |
| News Live Streams | News simulcasts, international news, local news broadcasts, etc. |
| Explicitly Banned Content | Stations marked by the community as not allowing rebroadcasting |
| TV Audio Accompaniment | Audio accompaniment streams from various TV programs |

**3. Filtering Implementation**

- **Local Keyword Filtering**: Built-in keyword library that automatically matches and filters before displaying station lists
- **Online Blacklist Sync**: Periodic syncing of the latest blacklist (UUIDs + keywords) from the server
- **User Reporting Mechanism**: Users can report inappropriate stations at any time; we commit to reviewing and updating the global blacklist within 24 hours

---

### Third-Party Service Authorizations

| Service | Authorization Status |
|---------|---------------------|
| **Music Recognition** | Shazam SDK (Apple official) - Authorized |
| **Advanced Recognition** | ACRCloud - Commercial use license obtained |
| **Radio Directory** | Radio Browser API (AGPL-3.0) - Used as-is without modification, compliant with open source license requirements |

---

### Compliance Measures

**1. Technical Level**
- Automatic keyword filtering (dual verification: local + remote)
- Real-time blacklist sync mechanism
- User reporting system (supports specifying reasons for reporting)

**2. Content Moderation**
- Manual review of user-reported content
- Periodic scanning of community blacklist updates
- Quick response to copyright complaints (handled within 24 hours)

**3. User Agreements**
- End User License Agreement (EULA) explicitly states copyright disclaimers
- Privacy Policy clarifies that we do not collect user personal data
- Users can report inappropriate content at any time

**4. Reporting Channels**
- Player page provides "Block this station" and "Block and report" options
- Report data is uploaded to the server in real-time for manual review
- After review approval, the station is added to the global blacklist, effective for all users

---

### Our Commitments and Guarantees

We solemnly commit to:

1. **Zero Tolerance Policy**: Zero tolerance for copyright infringement, pornography, violence, hate speech, and similar content
2. **Rapid Response**: Review and process copyright complaints within 24 hours of receipt
3. **Continuous Monitoring**: Periodic review and updating of filtering rules
4. **Transparent Communication**: Immediate cooperation if specific stations or categories need to be removed

---

### Contact Information

If you need further communication or verification of any specific station information, please contact us through:

- GitHub Issues: https://github.com/longhaiqwe/RadioApp/issues
- Email: [To be added]

Best regards,

**The 拾音FM Team**
