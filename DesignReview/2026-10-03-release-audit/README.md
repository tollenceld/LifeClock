# 刻度 · 成熟度与发行前审查

2026-10-03。在现有未提交成果上直接改进，没有重建工程、安装依赖或发布。

结论：核心体验已有明确的产品表达，本轮补齐了本地数据保护、日期语义、退出与错误路径、辅助字号和计算说明。可以进入真机与发行账号验收；仍不能直接视为可提交的已签名版本。

## 本轮审查路径

截图来自本轮实际运行，`before/` 是开始修改前的捕获，`after/` 是修正后的标准屏，`compact/` 是紧凑屏复测。部分相同页面以最后一轮截图更新。没有把历史截图当成本轮证据。

| 步骤 | 用户路径 | 当前健康度 | 主要证据 |
| --- | --- | --- | --- |
| 1 | 启动与存储恢复 | 良好：失败可重试，保留原存储 | [存储不可用](after/audit-13-storage-recovery.png)，注入失败与旧磁盘迁移测试 |
| 2 | 首次设置生日与预计寿命 | 良好：日期边界、术语与重复提交保护已补齐 | [引导](after/audit-01-onboarding.png) |
| 3 | 人生、日、月、年与前后台 | 良好：两组事实同时存在，真实进度与连续层纹 | [当前四尺度](../../StoreAssets/Screenshots/zh-Hans/current-6.9-inch/contact-sheet.jpg)，[原速录屏](motion/four-scales-native.mp4) |
| 4 | 设置与生日／寿命校准 | 良好：到期可表达，不擅自延长寿命；最大字号可操作 | [设置](after/audit-06-settings.png)，[生日最大字号](after/audit-24-birthday-large-text.png)，[寿命最大字号](after/audit-25-lifespan-large-text.png) |
| 5 | 刻点查找、创建、编辑、退出、删除 | 良好：草稿保护、历史规则和防重复提交 | [空状态](after/audit-08-empty-library.png)，[草稿退出](after/audit-14-unsaved-draft.png)，[大字号重复规则](after/audit-22-editor-large-text.png) |
| 6 | 本地备份与确认恢复 | 良好：格式验证、大小限制、替换确认、失败回滚 | [本地数据](after/audit-15-local-data.png)，[恢复预览](after/audit-19-restore-preview.png)，[导出系统界面](after/audit-16-data-export.png) |
| 7 | 计算依据、隐私与发行资料 | 应用内说明良好；发行资料待补 | [计算依据](after/audit-17-calculation.png)，[隐私](after/audit-18-privacy.png)，[提交预检](release-preflight.json) |

## 已修正的问题

### 日期与计算

- 生日原本只有绝对 `Date`，跨时区可能改变显示日期。现在存储可选公历日期元数据。
- 人生累计固定使用设定生日时的时区，旅行不会使已度过与预计终点跳变；日、月、年仍跟随设备当地日历。
- 周期刻点保存本地日期与钟点，一次性刻点保留绝对时刻；闰日、短月及 DST 使用统一日历规则。
- 生日修改保留用户设定的预计寿命。寿命允许 1–150 岁；到达设定终点后尚余为零，已度过继续增长。
- 旧数据缺少原始计算时区，迁移时采用设备当时显示的公历生日和时区；无法还原未曾记录的历史时区。保留原始字段与身份，新增元数据均为可选；原始磁盘模型迁移测试通过。

### 数据与退出路径

- 移除存储打开失败时直接崩溃的路径；显示恢复说明与重试，不删除存储、不静默切换临时数据。
- 导出版本化 JSON，备份可检查且无第三方依赖。明确说明文件未加密，保存位置由用户选择。
- 恢复前验证格式、版本、日期、重复 ID、规则与大小；最多读取 5 MB + 1 字节后判断超限。文件读取在后台执行。
- 恢复通过一次保存提交，提交期间关闭自动保存；同 ID 刻点复用对象，重复恢复不复制记录。失败时同时回滚存储并显式还原已加载对象的原值，避免 iOS 26 上界面缓存残留失败后的寿命值。
- 未保存草稿退出前提供明确的「继续编辑／放弃修改」提示，先收起键盘；阻止意外下拉退出。
- 首次引导和刻点保存均防重复提交；失败后仍可重试。

### 界面与辅助功能

- 主体验保持相界与时间层纹，未增加 Dashboard 或具象物体。
- 统一设置、引导、编辑器与确认界面的动态字体；辅助字号下重复规则纵向排列，选中背景随文字高度增长。
- 生日、寿命与刻点时间校准内容可滚动，确认按钮固定在底部。
- 触觉开关使用系统 Toggle，符号提供中文名称；清除搜索和交互控件保持可触达区域。
- 减少透明度使用实底导航，减少动态效果保留静态纹理。低电量时纹理上限降至 15fps；正常上限 30fps，暂停保留纹理相位。
- 未来通过层纹密度与明暗表达估计性质，数字保持清晰。辅助功能值不自动逐秒播报。

### 发行工程与说明

- Release 不编译 UI 测试启动入口、测试资料或测试内存库；已检查最终可执行文件中不存在 `-uiTesting` 开关。
- 明确 iPhone 目标，保留 iOS 18 最低版本、已有开发 Team 和图标。
- 补齐 UserDefaults 的 CA92.1 理由，保留无追踪、无数据收集声明。依据 [Apple Required Reason API 文档](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)。
- 应用内新增计算依据与隐私说明，版本号读取真实 Bundle 信息。
- 商店文案与审核路径改为四尺度，准确说明周期刻点、历史每周记录与无通知行为；移除示例支持 URL。
- 新增六张 1320 × 2868 RGB 当前截图；历史五尺度截图明确停用。尺寸参考 [Apple 截图规格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)。

## 实际验证

环境：macOS 27 / Xcode 27。标准屏为 iPhone 17 Pro / iOS 27.0；紧凑屏为 iPhone SE 第三代 / iOS 26.3；截图设备为独立 iPhone 17 Pro Max / iOS 26.3。没有触碰真机数据。

| 运行 | 结果 | 用途 |
| --- | --- | --- |
| 修改前定向 UI | 4/4 通过 | 建立本轮截图与交互基线 |
| 首次完整回归 | 66/72 通过 | 暴露 6 项问题，保留 [原始结果](results/KeduMaturityFull.json) |
| 修正后完整回归 | 70/72 通过 | 剩余 2 项是文件取消定位与键盘滚动选择问题；[结果](results/KeduMaturityFinal.json) |
| 标准屏最终定向回归 | 52/52 通过，0 跳过 | 46 核心 + 6 UI，包含上述两项修正、新增最大字号校准及实时切换；[结果](results/KeduMaturityValidated.json) |
| 紧凑屏核心与流程 | 51/53 通过 | 发现 SwiftData 回滚未完整还原已加载寿命值，以及文件取消定位问题；[原始结果](results/KeduMaturityCompact.json) |
| 紧凑屏取消与编辑复测 | 2/2 通过 | 返回系统浏览页取消；[结果](results/KeduMaturityPickerNavigation.json) |
| 紧凑屏最终大字号复测 | 2/2 通过 | 编辑、隐私与校准确认；[结果](results/KeduMaturityCompactFinal.json) |
| 防重复提交后编辑回归 | 3/3 通过 | 增删改、历史规则转换、最大字号编辑；[结果](results/KeduMaturityEventCommit.json) |
| iOS 27 最终恢复回归 | 47/47 通过 | 46 核心 + 确认恢复；检查失败回滚后的界面对象、独立读取和再次保存；[结果](results/KeduMaturityRollback27.json) |
| iOS 26 回滚修正回归 | 46/47 通过 | 46 核心全通过；恢复已成功，测试随后滚动越过刻点集入口；[结果](results/KeduMaturityRollback26.json) |
| iOS 26 完整恢复路径复测 | 1/1 通过 | 缓慢按距离滚动后验证恢复、返回主屏与历史刻点；[结果](results/KeduMaturityRestoreCompact.json) |
| 当前原速动态捕获 | 1/1 通过 | 重复真实数字更新与四尺度切换，保存未加速录屏；[结果](results/KeduMaturityMotionCapture.json) |

iOS 26 的 46 项核心在显式恢复原值后全部通过。该轮恢复 UI 已完成数据确认，随后因测试的大幅滚动在刻点集入口两侧来回越过而失败；已将测试滚动改为随距离减小的慢速拖动，并单独复测完整返回路径。

去重后的覆盖为 **46 个核心测试与 27 个 UI 流程，已分批通过**。这不是一次性 73 项全绿运行；保留原始失败与修正后的定向证据，避免混淆。最终 Archive 构建成功（未签名），预检 9 项本地条件通过、6 项发行资料阻塞。

部分失败回归的 Xcode 诊断收集子进程阻塞在 `simctl diagnose`；测试本身已结束。仅终止该诊断子进程后，结果包正常完成，测试截图与失败记录保留。通过的定向运行正常结束。原生录屏桥接的 AXe 与当前 Xcode 不兼容，最终使用 `simctl io recordVideo` 捕获；完整录屏约 77.7 秒，包含启动与退出，时间没有加速。

## 尚未验证与正式提交条件

- 真机 VoiceOver 实际朗读、触觉和耗电／长期运行未测；自动化只验证标签、动作、阅读优先级、布局与生命周期。
- iOS 18 运行时未安装，降级代码编译通过但未实测；iOS 26.3 与 27 模拟器不替代最低系统真机。
- 核心备份往返、事务回滚、恢复 UI 与系统选择器取消已测；实际真机本地／iCloud／第三方文件提供者的完整读写与迁移仍需验收。
- 磁盘故障通过注入验证，未制造真实设备存储损坏；恢复页不尝试破坏性修复。
- 当前 Bundle ID 为开发占位，Archive 未签名。正式 ID、发行证书、公开支持与隐私网址、版权主体、SKU、App Privacy 与年龄分级问卷均需要发行账号资料。
- 需以已签名最终版本完成 Validate App；本地检查不等于 Apple 审核批准。参考 [审核指南](https://developer.apple.com/app-store/review/guidelines/)，详见 [发行清单](../../StoreAssets/release-checklist.md)。

运行 `python3 scripts/release_preflight.py --app /absolute/path/Kedu.app --output /absolute/path/report.json` 可重复预检，不签名、不联网、不上传；退出码 2 表示发行资料尚未齐备。
