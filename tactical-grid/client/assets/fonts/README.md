# 字体使用说明

本项目优先使用开源可免费商用的字体。请将字体文件放入本目录，命名规则如下：

## 推荐字体

### 标题字体（科幻/力量感）
- **Orbitron** (SIL Open Font License)
  - 下载：https://fonts.google.com/specimen/Orbitron
  - 放置：`Orbitron-Bold.ttf`
- **Teko** (SIL Open Font License)
  - 下载：https://fonts.google.com/specimen/Teko
  - 放置：`Teko-Bold.ttf`

### 正文字体（中文）
- **思源黑体 Source Han Sans SC** (SIL Open Font License)
  - 下载：https://github.com/adobe-fonts/source-han-sans/releases
  - 放置：`SourceHanSansSC-Regular.otf`、`SourceHanSansSC-Bold.otf`
- **Noto Sans SC** (SIL Open Font License)
  - 下载：https://fonts.google.com/noto/specimen/Noto+Sans+SC
  - 放置：`NotoSansSC-Regular.otf`

## 命名约定

| 用途 | 文件名 | 优先级 |
|---|---|---|
| 标题 | `Orbitron-Bold.ttf` | 最高 |
| 标题备选 | `Teko-Bold.ttf` | 中 |
| 中文标题 | `SourceHanSansSC-Bold.otf` / `cn_title.ttf` | 低 |
| 正文 | `SourceHanSansSC-Regular.otf` | 最高 |
| 正文备选 | `NotoSansSC-Regular.otf` / `cn_body.ttf` | 中 |

> 如果以上字体都不存在，`FontManager` 会自动回退到 Godot 默认字体。

## 授权

所有推荐字体均为 SIL Open Font License 1.1 授权，可免费商用。
详细授权见 `FONT_LICENSE.md`。
