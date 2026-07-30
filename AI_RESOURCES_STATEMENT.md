# AI 生成资源声明

本文件登记 Tactical Grid 项目中所有由人工智能模型生成的资源，以确保来源透明、可追溯。

## 1. 总体声明

- 2026-06-17 的 16 张遗留 SDXL 图片仅作为内部风格参考，不进入发行包。
- `client/assets/generated/chapter1/` 下的新资源由项目工作流独立生成。只有完成去背、切图、尺寸校验、Godot 导入、资源登记和实机检查的文件才可进入运行时目录。
- 未处理的风格板和生成拼版保存在 `client/assets/generated/chapter1/source/`，由导出预设排除。
- 当前 Codex 图像生成工具未向项目暴露精确后端模型 ID，因此登记为“Codex 内置 Image Generation”，不虚构具体模型版本。

## 2. AI 生成图片清单

### 2.1 角色肖像（10 张）

| 文件路径 | 内容描述 | 生成日期 | 模型 | 用途 |
|---|---|---|---|---|
| client/assets/characters/游戏Boss肖像_数据哨兵_巨型机械守卫_蓝红配色_发光眼睛_2026-06-17T18-15-39.png | Boss 数据哨兵肖像 | 2026-06-17 | SDXL | 风格参考 |
| client/assets/characters/游戏敌人肖像_攻击无人机_红色机械飞行单位_低多边形风格_正_2026-06-17T18-14-43.png | 攻击无人机肖像 | 2026-06-17 | SDXL | 风格参考 |
| client/assets/characters/游戏敌人肖像_隐形刺客_暗红色兜帽角色_手持能量刃_神秘感__2026-06-17T18-15-12.png | 隐形刺客肖像 | 2026-06-17 | SDXL | 风格参考 |
| client/assets/characters/游戏最终Boss肖像_架构师_巨型AI核心_全息投影人形_蓝_2026-06-17T18-16-07.png | 最终 Boss 架构师肖像 | 2026-06-17 | SDXL | 风格参考 |
| client/assets/characters/游戏角色肖像_侦察兵职业_AI叛逃者角色_穿着黑色潜行服_手_2026-06-17T18-13-45.png | 侦察兵肖像 | 2026-06-17 | SDXL | 风格参考 |
| client/assets/characters/游戏角色肖像_医疗兵职业_男性科学家角色_穿着白色实验服和蓝_2026-06-17T18-13-09.png | 医疗兵肖像 | 2026-06-17 | SDXL | 风格参考 |
| client/assets/characters/游戏角色肖像_敌方哨兵机器人_红色配色_机械外观_低多边形风_2026-06-17T18-05-21.png | 哨兵机器人肖像 | 2026-06-17 | SDXL | 风格参考 |
| client/assets/characters/游戏角色肖像_狙击手职业_女性角色_穿着蓝色潜行作战服_手持_2026-06-17T18-04-51.png | 狙击手肖像 | 2026-06-17 | SDXL | 风格参考 |
| client/assets/characters/游戏角色肖像_突击兵职业_男性士兵_穿着蓝色战术背心_手持霰_2026-06-17T18-04-22.png | 突击兵肖像 | 2026-06-17 | SDXL | 风格参考 |
| client/assets/characters/游戏角色肖像_重装兵职业_壮汉角色_穿着重型装甲_手持机枪__2026-06-17T18-14-15.png | 重装兵肖像 | 2026-06-17 | SDXL | 风格参考 |

### 2.2 特效（3 张）

| 文件路径 | 内容描述 | 生成日期 | 模型 | 用途 |
|---|---|---|---|---|
| client/assets/effects/游戏枪口闪光特效_明亮黄色光芒_低多边形风格_透明背景_游戏_2026-06-17T18-17-04.png | 枪口闪光 | 2026-06-17 | SDXL | 风格参考 |
| client/assets/effects/游戏烟雾弹特效_灰色烟雾云_低多边形风格_透明背景_游戏素材_2026-06-17T18-17-30.png | 烟雾弹 | 2026-06-17 | SDXL | 风格参考 |
| client/assets/effects/游戏爆炸特效_橙红色火球_低多边形风格_透明背景_游戏素材_2026-06-17T18-16-36.png | 爆炸特效 | 2026-06-17 | SDXL | 风格参考 |

### 2.3 地形贴图（1 张）

| 文件路径 | 内容描述 | 生成日期 | 模型 | 用途 |
|---|---|---|---|---|
| client/assets/tiles/战棋游戏地形贴图集_俯视角_低多边形风格_包含平地_道路_森_2026-06-17T18-06-17.png | 地形贴图集 | 2026-06-17 | SDXL | 风格参考 |

### 2.4 UI 资源（2 张）

| 文件路径 | 内容描述 | 生成日期 | 模型 | 用途 |
|---|---|---|---|---|
| client/assets/ui/战术战棋游戏主菜单背景_废墟城市夜景_赛博朋克风格_蓝色和橙_2026-06-17T18-06-45.png | 主菜单背景 | 2026-06-17 | SDXL | 风格参考 |
| client/assets/ui/游戏UI图标集_战术战棋游戏_包含移动_攻击_技能_物品_警_2026-06-17T18-05-49.png | UI 图标集 | 2026-06-17 | SDXL | 风格参考 |

### 2.5 已处理并接入的项目生成资源

| 文件路径 | 内容描述 | 生成日期 | 模型/工具 | 用途与处理 |
|---|---|---|---|---|
| `client/assets/generated/chapter1/backgrounds/*.png` | 主菜单、启动、基地和结算背景 | 2026-07-28 至 2026-07-29 | Codex 内置 Image Generation | 项目原创背景；检查无文字和水印后由场景或 `ArtCatalog` 加载 |
| `client/assets/generated/chapter1/source/echo_yard_styleboard_v1.png` | 回声货场视觉与构图风格板 | 2026-07-30 | Codex 内置 Image Generation | 仅作内部参考；导出排除 |
| `client/assets/generated/chapter1/source/echo_yard_props_sheet_*.png` | 六种货场掩体/道具生成拼版及去背中间文件 | 2026-07-30 | Codex 内置 Image Generation + 色键处理工具 | 源文件；导出排除 |
| `client/assets/generated/chapter1/runtime/environment/echo_yard/prop/*.png` | 蓝/橙货箱、钢制路障、管束、电缆盘和控制箱 | 2026-07-30 | 上述拼版经 `process_echo_yard_prop_sheet.ps1` 切图 | 透明运行时资源；Godot 导入、目录契约和发布版实机画面已验证 |
| `client/assets/generated/chapter1/source/echo_yard_landmarks_sheet_*.png` | 龙门吊与照明塔生成拼版及去背中间文件 | 2026-07-30 | Codex 内置 Image Generation + 色键处理工具 | 源文件；导出排除 |
| `client/assets/generated/chapter1/runtime/environment/echo_yard/landmark/*.png` | 龙门吊与照明塔 | 2026-07-30 | 上述拼版经 `process_echo_yard_landmark_sheet.ps1` 切图 | 透明运行时资源；Godot 导入、目录契约和发布版实机画面已验证 |
| `client/assets/generated/chapter1/runtime/environment/cooling_works/*.png` | 冷却工坊的地面、边缘、掩体、危险贴花和地标 | 2026-07-30 | `generate_cooling_works_environment.ps1` 程序化绘制 | 不使用第三方素材；27 个运行时 PNG 已完成 Godot 导入，并由地图与资源加载契约验证 |
| `client/assets/generated/chapter1/runtime/environment/transit_hub/*.png` | 磁悬轨道枢纽的月台、导轨、站台掩体、贴花和地标 | 2026-07-30 | `generate_transit_hub_environment.ps1` 程序化绘制 | 不使用第三方素材；27 个运行时 PNG 已完成 Godot 导入，并由地图与资源加载契约验证 |
| `client/assets/generated/chapter1/runtime/environment/sentinel_core/*.png` | 哨兵核心的环形地面、相位掩体、回路贴花和核心地标 | 2026-07-30 | `generate_sentinel_core_environment.ps1` 程序化绘制 | 不使用第三方素材；27 个运行时 PNG 已完成 Godot 导入，并由地图与资源加载契约验证 |
| `client/assets/generated/chapter1/source/ch1_m1_units/*_source_v1.png` | 七名第一章首发单位（突击兵、狙击手、重装兵、基础哨兵、侦察无人机、狙击哨兵、突击无人机）的三视四分之三俯视源插画 | 2026-07-30 | Codex 内置 Image Generation | 源文件；纯绿幕背景；导出排除 |
| `client/assets/generated/chapter1/runtime/units/assault_96.png` 等 7 张 | 上述七名单位的透明 96×96 运行时精灵 | 2026-07-30 | 上述源图经 `process_chapter1_unit_art.ps1` 绿色主导色键去背、裁剪、缩放合成 | 透明运行时资源；已完成 Godot 导入、`ArtCatalog` 加载、尺寸/透明度/剪影差异契约和烟雾测试验证 |

## 3. 遗留参考图已知问题

1. 上述 2.1 至 2.4 的 16 张遗留图片均为 1024×1024、24 位 RGB，无 Alpha 通道，不能直接用于游戏精灵。
2. 这些遗留图片可观察到“图片由AI生成”水印。
3. 遗留地形图和 UI 图是展示拼版，不是规则网格化、可切片的生产素材。
4. 遗留特效图没有真实透明通道，部分包含烘焙棋盘格或黑底。
5. 遗留图片没有运行时引用，并由 Windows 导出预设明确排除。

## 4. 后续处理要求

- 任何新增 AI 生成资源必须在本文件和 `client/data/RESOURCE_MANIFEST.md` 中登记。
- 生成源图不得直接进入运行时；必须完成尺寸、透明通道、切图、Godot 导入和游戏内效果测试。
- 外部第三方资源必须在 `THIRD_PARTY_NOTICES.md` 中登记来源和许可证；项目原创 AI 资源不得伪装成第三方开源资源。
- 商业发布前需再次核对所用生成服务的届时条款与目标发行范围。

## 5. 修改记录

- 2026-07-27：初次创建 AI 资源声明，登记 16 张现有 AI 生成图片
- 2026-07-30：区分遗留参考图与新处理的项目生成资源，登记 Echo Yard 背景、道具、地标和源图排除策略
- 2026-07-30：登记 Cooling Works 的程序化运行时环境套件；其不属于 AI 图像生成资源，但在此声明中保留与 AI 资源并列的完整可追溯记录
- 2026-07-30：登记 Mag-Rail Transit Hub 的程序化运行时环境套件和其 `ch1_m3` 关卡接入
- 2026-07-30：登记 Sentinel Core 的程序化运行时环境套件和其 `ch1_m5` 关卡接入
- 2026-07-30：登记第一章首发七名单位（突击兵、狙击手、重装兵、基础哨兵、侦察无人机、狙击哨兵、突击无人机）的 96×96 运行时精灵；源图由 Codex Image Generation 生成，经 `process_chapter1_unit_art.ps1` 绿色主导色键去背并确定性合成
