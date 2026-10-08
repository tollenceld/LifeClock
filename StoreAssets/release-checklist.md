# 刻度 1.0 提交检查

更新：2026-10-03。开发完成与 App Store 提交资格分开验证。

## 本地已实现

- [x] 四尺度相界、终点状态与计算依据说明
- [x] 本地备份与确认恢复、保存失败回滚、存储启动重试
- [x] 旧 SwiftData 磁盘数据迁移兼容与历史每周记录
- [x] 隐私清单：无追踪、无数据收集；UserDefaults 声明 CA92.1
- [x] 非豁免加密声明为否
- [x] 当前功能的中文文案、隐私草稿与审核路径
- [x] iPhone 目标、iOS 18 最低版本、Release 中停用调试测试入口
- [x] 1024×1024 无透明商店图标与外观变体

测试和截图的实际结果以 `DesignReview/2026-10-03-release-audit/README.md` 为准，不能以清单代替验证。

## 发行账号与真机仍需完成

- [ ] 在发行账号注册正式 Bundle ID，替换 `com.local.Kedu`
- [ ] 核实当前开发 Team，配置发行证书与 provisioning profile
- [ ] 确认名称、创建 App Store Connect 记录与 SKU
- [ ] 公开支持网址、隐私政策网址、发行主体和版权
- [ ] 按最终功能填写 App Privacy 与年龄分级问卷
- [ ] 真机无调试器冷启动、升级保留数据、文件提供者读写
- [ ] 真机 VoiceOver 阅读顺序与触觉、耗电/持续运行验证
- [ ] iOS 18 最低运行时实测
- [ ] 使用已签名 Archive 完成 Validate App，再上传
- [ ] 按提交时的截图要求选择本轮当前界面图；旧五尺度截图禁止作为当前版本素材

Apple 依据：[审核指南](https://developer.apple.com/app-store/review/guidelines/)、[隐私 API 理由](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)、[截图规格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)。本地构建通过不等于已获审核批准。
