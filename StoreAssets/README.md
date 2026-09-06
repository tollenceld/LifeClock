# 刻度 · 上架素材包

这是一套便于继续打磨的 1.0 草稿，不替代正式提交前的 App Store Connect 核对。

## 目录

- `AppIcon/AppIcon-Master.png`：最终主图标母版。
- `AppIcon/AppStore-Icon-1024.png`：无透明通道的 1024 × 1024 商店图标。
- `AppIcon/AppIcon-Tinted-Master.png`：系统着色外观母版。
- `AppIcon/icon-options-contact-sheet.png`：三种探索方向与最终方案总览。
- `AppIcon/prompts.md`：Codex 内置 ImageGen 的完整生成思路与提示词。
- `Screenshots/zh-Hans/iPhone-portrait/`：六张简体中文 iPhone 竖屏截图。
- `Screenshots/zh-Hans/screenshots-contact-sheet.png`：截图联系表。
- `metadata-zh-Hans.md`：名称、副标题、关键词、描述与更新说明草稿。
- `privacy-policy-zh-Hans.md`：隐私政策草稿。
- `app-review-notes-zh-Hans.md`：审核说明草稿。
- `release-checklist.md`：正式提交前仍需完成的事项。

## 工程接入

App 图标已写入 `Kedu/Resources/Assets.xcassets/AppIcon.appiconset`，包含默认、深色和着色三种外观。工程同时包含本地隐私清单，并声明不使用非豁免加密。

当前素材不含支持网址、公开隐私政策网址、正式 Bundle Identifier、签名团队和版权主体；这些项目留待正式上架整理时补齐。
