# 刻度 · LifeClock

一块安静、私密的个人时间仪表。

刻度把人生、日、月和年转换成统一的时间读数。人生是默认首页：只显示已度过或还剩的天数，小数部分包含小时、分钟和秒。暖琥珀色「生之时」与冷青色「死之时」并列相连，可点击状态或轻点读数翻面。

## 功能

- 人生、日、月、年四种时间尺度，支持点击和左右轻扫切换
- 四尺度共用 8 位小数天数读数，前台可见时实时更新
- 人生双面计时器：暖琥珀色累计、冷青色倒数，细刻度随真实秒数连续移动
- 底部人生入口与日月年／设置一体胶囊同步伸缩；iOS 26 使用原生液态玻璃，旧系统使用材质降级
- 从设置进入刻点集，支持搜索、本地新增、编辑与删除
- 新刻点支持一次性、每年、每月和每天重复；旧每周刻点保留在「历史刻点」，可查看、删除或主动转换规则
- 跟随系统、石墨与暖纸三种外观选项
- 动态字体、减少动态效果和 VoiceOver 支持
- 无账号、无广告、无网络请求、无第三方 SDK

生日、预期年龄、偏好设置和所有刻点仅保存在设备本地。预期年龄是可调整的个人参照；达到该年龄后，实际年龄继续增长，剩余时间归零。

## 技术栈

- Swift 6
- SwiftUI 与 Canvas
- SwiftData
- Swift Testing 与 XCTest
- XcodeGen
- 最低系统版本：iOS 18

## 项目结构

```text
Kedu/
├── App/                 App 入口、根视图与预览数据
├── Core/                时间快照、日历计算、主题与触觉反馈
├── Models/              SwiftData 模型、尺度定义与重复规则兼容
├── Resources/           图标、本地化与隐私清单
└── UI/
    ├── Components/      统一时间读数、刻度与通用控件
    └── Screens/         引导、主时钟、刻点集、编辑器与设置
KeduTests/               核心时间与布局逻辑测试
KeduUITests/             关键用户流程测试
DesignReview/            设计取舍、开发审阅截图与验证记录
StoreAssets/             App Store 文案与历史正式素材
```

## 本地开发

### 环境

- Xcode 26 或兼容版本
- XcodeGen
- 支持 iOS 18 或更高版本的模拟器

### 生成工程

仓库已经包含可直接打开的 `Kedu.xcodeproj`。修改 `project.yml` 后，可以重新生成工程：

```sh
xcodegen generate
```

### 构建

```sh
xcodebuild \
  -project Kedu.xcodeproj \
  -scheme Kedu \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

### 测试

```sh
xcodebuild \
  -project Kedu.xcodeproj \
  -scheme Kedu \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

核心测试覆盖真实日历区间、生日与闰日、时区、目标年龄边界、小数天数与跨日连续性及旧每周规则兼容。UI 测试覆盖首次引导、四尺度导航、实时数字、翻面、设置内刻点增删改与历史规则转换、大字号和固定导航。

本轮测试结果、运行证据和验证边界见 [设计与验证记录](DesignReview/README.md)。

辅助功能标签与动作已检查，尚未开启系统 VoiceOver 验证实际朗读；iOS 18 材质降级代码编译通过，但未在 iOS 18 运行时实测。

## 隐私

刻度完全离线运行，不收集、不上传、不共享个人数据，也不申请通讯录、日历、照片、位置、健康、麦克风、相机或通知权限。

隐私声明与上架材料位于 [`StoreAssets`](StoreAssets/README.md)。

## 许可证

本项目使用 [MIT License](LICENSE)。

## 最新设计改造

2026-09-15：人生聚焦八位小数天数与相连的双面状态，日月年共用相同设计语言；底部采用始终可直接访问的伸缩导航；移除周尺度，将刻点管理移入设置。见 [UI 改造说明](DesignReview/README.md)。

商店素材和 2026-09-08 开发截图是历史资料，尚未代表当前四尺度界面，本轮不涉及重新制作商店素材。
