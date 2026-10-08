# 刻度 · 上架素材包

这是一套便于继续打磨的 1.0 草稿，不替代正式提交前的 App Store Connect 核对。

## 目录

- `AppIcon/AppIcon-Master.png`：最终主图标母版。
- `AppIcon/AppStore-Icon-1024.png`：无透明通道的 1024 × 1024 商店图标。
- `AppIcon/AppIcon-Tinted-Master.png`：系统着色外观母版。
- `AppIcon/icon-options-contact-sheet.png`：三种探索方向与最终方案总览。
- `AppIcon/prompts.md`：Codex 内置 ImageGen 的完整生成思路与提示词。
- `Screenshots/zh-Hans/iPhone-portrait/`：历史五尺度截图，已过时，不可作为当前版本提交素材。
- `Screenshots/zh-Hans/current-6.9-inch/`：当前四尺度六张 1320 × 2868 RGB 截图与联系表。
- `Screenshots/zh-Hans/screenshots-contact-sheet.png`：截图联系表。
- `metadata-zh-Hans.md`：名称、副标题、关键词、描述与更新说明草稿。
- `privacy-policy-zh-Hans.md`：隐私政策草稿。
- `app-review-notes-zh-Hans.md`：审核说明草稿。
- `release-checklist.md`：正式提交前仍需完成的事项。
- `submission.json`：尚待发行账号信息补齐的字段，不包含虚构网址。

## 工程接入

App 图标已写入 `Kedu/Resources/Assets.xcassets/AppIcon.appiconset`，包含默认、深色和着色三种外观。工程同时包含本地隐私清单，并声明不使用非豁免加密。

工程保留已配置的开发 Team；发行签名尚未验证。正式 Bundle Identifier、支持网址、公开隐私政策网址、SKU 和版权主体仍需发行账号资料。当前织幅、截图与回归见 [时间织幅记录](../DesignReview/2026-10-07-weave/README.md)；数据成熟度与提交限制见 [成熟度审查](../DesignReview/2026-10-03-release-audit/README.md)。
