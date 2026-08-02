# Tactical Grid 第一章成品实施路线图

> **执行要求：** 后续智能体必须按本文任务 ID 执行；复杂任务使用 `superpowers:executing-plans`，每项完成前使用 `superpowers:verification-before-completion`。
>
> 状态：Active
> 负责人：项目负责人
> 更新日期：2026-08-01
> 适用范围：`main` 分支、第一章 M1-M6、Windows 第一章候选版
> 产品规格：[第一章战术网络重设计](superpowers/specs/2026-07-30-chapter-one-tactical-network-redesign.md)
> 唯一开发基线：`main`

## 1. 最终目标

把第一章完成为普通玩家无需 Godot 编辑器、Node 服务或外部说明即可启动、理解、完整游玩并正常结束的 Windows 单机战术游戏。

第一章的核心循环固定为：

> 观察已侦测敌人的意图，争夺战术网络节点，控制摄像头、门、炮塔、电力和增援信标，用战场本身击破敌军计划。

第一章候选版使用 `0.x` 版本号。只有后续章节全部完成并通过各自发布门后，项目才进入 `1.0` 评估。

## 2. 当前事实基线

### 2.1 已完成并进入 `main`

- Godot 4.7.1 纯离线项目，主场景为 `res://scenes/boot.tscn`。
- 主菜单、基地、战斗、对话、教程、设置、暂停、失败、结算和六关流程存在。
- 任务目标唯一权威、行动系统骨架、地图校验、迷雾状态、敌方意图状态、战术网络、警戒状态已接入代码库。
- M1 已完成 CH1-070/080：22×16、三个紧凑遭遇区、7-9 名敌人、最多 3 名同时活跃、两个遭遇检查点、教学、失败重试、上传和撤离流程。
- CH1-010 至 CH1-060 的代码与自动化契约已完成：统一行动、地图 v2/稳定 ID/RNG、真实输入 E2E、迷雾、敌方意图、战术网络和警戒表现。
- CH1-090 已完成中继塔地标、选择/扫描/上传/撤离 VFX、中文 UI 字体、潜入/交战/高警戒三层战斗音乐和第一轮网络/意图/职业色饰程序化表现；警报本地化、顶部状态分区、右侧单位面板停靠、网络节点迷雾约束、地标越界保护、底部快捷键提示、基地角色详情职业纹理和对话头像/选项布局已修复；视觉快照工具现已覆盖首帧、选中、网络、意图、上传、撤离六个运行阶段，并支持 720p/1080p、灰度和色觉检查；当前仍未签核。
- 四套环境组件、角色和敌人图、HUD 图标、对话、VFX 与程序化 WAV 可作为正式生产底材。
- 导出预设、Windows 构建脚本、包验证脚本和自动化发布门已进入版本控制。
- 旧后端、旧路线图、旧 QA、旧文档归档和无生产引用的 API 客户端已从当前树移除；历史仍可从 Git 提交记录追溯。

### 2.2 尚未完成

- CH1-090 的代码与资源接入已完成第一轮；网络节点不再穿透战争迷雾，右侧敌方意图摘要已纳入 HUD 位置回归测试，基地角色详情已按职业加载真实单位纹理并纳入 15 项自动契约，对话头像/文本/选项布局已纳入 10 项自动契约，完整流程截图和对话快照已覆盖 1280×720/1920×1080；尚未完成角色/敌军正式方向辨识的人工确认、M1 三区域表现的双分辨率/灰度/色觉人工检查和音频听感验收。
- H1 首次玩家硬门尚未执行，M1 还没有 3 名首次玩家的理解、时长和趣味性记录。
- M2-M6 仍以旧内容为基线，没有达到新设计的正式关卡标准。
- 四名玩家角色和五类敌人尚未全部具备轮廓、能力、动画与战术职责区分。
- 六关独特地标、最终 VFX、SFX、分层音乐、字体和许可证记录尚未完成。
- 全章平衡、连续通关、干净账户安装和发布包验收尚未完成。

### 2.3 当前结论

**No-go。** 当前是可运行的第一章开发基线，不是第一章发布候选版，也不是正式成品。

## 3. 不可变产品边界

### 3.1 必须保留

- 离线单人、方格回合制、移动额度加 2AP。
- 六个手工任务、四名正式角色、五类敌军职责和章节 Boss。
- 未探索、已记录、正在观察、最后已知位置四层信息状态。
- 已观察敌方意图、战术网络节点、五类设施和事件驱动警戒。
- 基地编队与成长、设置、存档、检查点、失败重试、结算徽章和章节结局。
- 左键上下文操作、右键取消、`Tab` 切换单位、`Space` 结束回合、`G` 网络层、`Home` 聚焦。

### 3.2 第一章不做

- 在线服务、账号、遥测和云存档。
- 程序随机主线地图和运行时下载关卡。
- 独立黑客小游戏、新战斗货币和随机装备词条。
- 逐回合回退、永久死亡和复杂伤员系统。
- 实时潜行、大规模破坏、时间线编排和大量同时部署角色。

### 3.3 复用原则

- 保留通过测试的 `GridSystem`、`Pathfinding`、`VisionSystem`、`TurnManager`、`MissionObjectiveState`、`EnemyDirector`、战斗公式、效果、存档迁移和设置系统。
- 保留现有环境、单位、肖像、UI、VFX 和音频作为源材料；允许重绘、分层、调色、切图和重混。
- 不重建平行核心系统；新能力必须扩展现有权威状态。
- 客户端锁定 JSON 是正式地图唯一来源。
- 未接入运行时、未记录来源或未在游戏内验证的资源不计为完成。

## 4. 成品内容定义

| 任务 | 正式定位 | 首次目标时长 | 玩家阵容 | 关键新内容 |
|---|---|---:|---|---|
| M1 回声失联 | 单人潜入并救出侦察兵 | 15-20 分钟 | 突击→突击+侦察 | 基础操作、观察、摄像头、上传、撤离 |
| M2 熄灯协议 | 三人切断能源封锁 | 20-25 分钟 | 突击+侦察+狙击 | 电力、炮塔、盾卫、路线选择 |
| M3 断轨营救 | 营救重装并改变列车路线 | 20-25 分钟 | 三人→四人 | 倒计时、工程师、警戒射击、列车路由 |
| M4 囚笼密钥 | 三选四渗透监区 | 25-30 分钟 | 自选三人 | 门控网络、临时盟友、营救取舍 |
| M5 反向猎杀 | 敌军主动反夺网络 | 25-30 分钟 | 自选四人中的三人 | 猎手、失联区域、节点争夺、撤退取舍 |
| M6 零号终端 | 三阶段网络 Boss | 30-35 分钟 | 四人 | 多节点控制、污染、熔毁、章节结局 |

第一章首次流程目标为 3-4 小时；完成可选徽章目标为 4-5 小时。

## 5. 全局完成标准

每个功能只有同时满足以下条件才可勾选：

1. 生产代码、场景、数据和资源已真实接入。
2. 新增或更新的自动化测试通过。
3. `tests/run_release_gate.ps1` 全量通过，0 非预期 warning/error。
4. 1280×720 与 1920×1080 下完成对应人工路径，无裁切或不可读信息。
5. 玩家可从游戏内反馈理解规则，不依赖 README 或开发者解释。
6. 资源来源、生成方式、许可证和修改记录已写入 `data/RESOURCE_MANIFEST.md`。
7. 任务对应文档和状态已更新，不创建第二份路线图。

任何测试失败都先修复根因，不修改测试来迁就错误行为。

## 6. 执行依赖

```text
R0 仓库收口
  -> R1 行动/输入/地图状态基础
  -> R2 信息战与战术网络表现
  -> R3 M1 正式垂直切片
  -> H1 M1 首次玩家硬门
  -> R4 共享角色/敌军/基地/美术音频
  -> R5 M2 -> M3 -> M4 -> M5 -> M6
  -> H2 全章平衡与连续通关
  -> R6 发布候选版
```

M1 真人门未通过前，不批量改造 M2-M6。共享系统可先设计和测试，但不得用未验证的 M1 模板批量铺关。

## 7. 任务清单

### R0 仓库和文档收口

#### CH1-000 单主线清理

- 状态：本轮完成
- 执行者：Terra medium/high
- 内容：
  - 只保留 `main` 活跃分支。
  - 删除旧后端、无引用 API 客户端、旧 QA、旧路线图和旧文档归档。
  - 删除本地可再生 Godot 缓存、旧导出、日志和测试产物。
  - README、项目状态、文档索引和规格统一为纯离线 Godot。
  - 清除旧 stash 和归档 tag；历史由主分支 Git 提交记录保留。
- 文件：
  - `README.md`
  - `docs/README.md`
  - `docs/DOCUMENTATION_POLICY.md`
  - `docs/PROJECT_TAKEOVER_ROADMAP.md`
  - `tactical-grid/README.md`
  - `tactical-grid/PROJECT_STATUS.md`
  - `tactical-grid/start.bat`
- 验证：
  - `git branch -a` 只有 `main` 和 `origin/main`。
  - `git stash list` 与 `git tag --list` 为空。
  - `rg "server|api_client|docs/archive|docs/qa" README.md docs tactical-grid -g "*.md" -g "*.gd" -g "*.bat"` 不含活跃依赖描述。
  - 完整发布门通过。

### R1 行动、输入与可序列化基础

#### CH1-010 统一行动事务

- 状态：代码与自动化验证完成，等待 M1 真人验收
- 依赖：CH1-000
- 执行者：Sol xhigh
- 目标：移动、攻击、技能、物品、警戒和网络操作全部使用同一条查询、校验、提交路径。
- 修改：
  - `scripts/game/action_system.gd`
  - `scripts/game/targeting_controller.gd`
  - `scripts/game/battle_controller.gd`
  - `scripts/ui/hud.gd`
  - `scripts/ui/action_menu.gd`
- 接口契约：

```gdscript
func query_action(request: Dictionary) -> Dictionary
func validate_action(preview: Dictionary) -> Dictionary
func commit_action(preview: Dictionary) -> Dictionary
```

- 行为：
  - 查询返回目标格、AP/移动消耗、命中、伤害范围、警戒变化、设施变化和风险。
  - 提交前重验单位、回合、资源和目标版本；过期预览必须拒绝。
  - 安全移动和普通攻击直接提交；会触发友伤、不可逆目标或显著警戒升级时只确认一次。
  - HUD 不直接改生命、AP、目标、节点或任务状态。
- 测试：
  - 扩展 `tests/action_system_test.gd`。
  - 扩展 `tests/targeting_controller_test.gd`。
  - 扩展 `tests/battle_hud_contract_test.gd`。
  - 断言预览与提交结果一致、过期预览拒绝、取消不扣资源、所有生产玩家行动均调用 `commit_action`。
- 退出门：生产控制器不存在绕过统一提交的玩家行动路径。

#### CH1-020 地图模式、稳定 ID 与战斗状态

- 状态：代码与自动化验证完成，等待 M1 真人验收
- 依赖：CH1-010
- 执行者：Sol xhigh
- 目标：关卡、检查点和测试使用确定、可迁移的数据身份。
- 修改：
  - `scripts/core/locked_map_validator.gd`
  - `scripts/map/map_loader.gd`
  - `scripts/game/unit.gd`
  - `scripts/game/battle_controller.gd`
  - `scripts/network/save_manager.gd`
  - `data/locked_maps/_index.json`
  - `data/locked_maps/ch1_m1.json` 至 `ch1_m6.json`
- 新增：
  - `scripts/game/encounter_checkpoint_state.gd`
  - `tests/encounter_checkpoint_state_test.gd`
  - `tests/encounter_checkpoint_state_test.tscn`
- 地图模式必须含：

```json
{
  "schema_version": 2,
  "mission_id": "ch1_m1",
  "entities": [],
  "network_nodes": [],
  "facilities": [],
  "connections": [],
  "encounters": [],
  "checkpoints": []
}
```

- 行为：
  - 单位、目标物、节点、设施、遭遇和检查点均由数据提供稳定 ID。
  - 随机行为只使用战斗状态持有的可注入 RNG，不从节点名或运行时顺序推导。
  - 检查点保存阵容、生命/AP、警戒、迷雾记忆、敌人、节点、设施、目标阶段和 RNG 状态。
  - 只在遭遇边界写入检查点，不实现逐回合回退。
- 测试：
  - 扩展 `tests/locked_map_validator_test.gd`，验证重复 ID、悬空连接、无效检查点和旧模式拒绝/迁移。
  - 新测试验证检查点序列化往返一致、RNG 恢复后结果一致。
- 退出门：六张第一章地图通过模式校验；同一检查点重复恢复产生相同初始战局。

#### CH1-030 真实输入 E2E 与操作教学

- 状态：代码与自动化验证完成，等待 720p/1080p 人工输入验收
- 依赖：CH1-010
- 执行者：Terra high
- 修改：
  - `scripts/game/input_bindings.gd`
  - `scripts/game/battle_camera_controller.gd`
  - `scripts/game/battle_controller.gd`
  - `scripts/ui/hud.gd`
  - `scripts/ui/tutorial_hint.gd`
  - `scenes/tutorial_hint.tscn`
  - `tests/chapter_one_e2e_test.gd`
- 行为：
  - 通过 `InputEventMouseButton`、`InputEventKey` 和可重映射动作完成主菜单→基地→M1→选择→移动→攻击→节点操作→结束回合→暂停。
  - 第一次可操作时在地图附近显示单一下一步；玩家完成动作后立即收起并进入下一提示。
  - 底部常驻显示左键、右键、`Tab`、`G`、`Home` 和 `Space` 的用途，避免首次玩家依赖外部说明。
  - 右键始终逐级取消，`Esc` 只在无目标模式时暂停。
  - 不用直接调用内部执行函数冒充输入 E2E。
- 测试：E2E 断言真实事件改变选择、单位位置、敌人生命、节点状态、回合和暂停状态。
- 人工：720p 与 1080p 各走一遍完整输入链。
- 退出门：不看外部说明可完成第一个完整回合。

### R2 信息战、敌军意图与网络表现

#### CH1-040 迷雾运行时闭环

- 状态：代码与自动化验证完成，等待 M1 真人理解验收
- 依赖：CH1-020
- 执行者：Sol xhigh
- 修改：
  - `scripts/game/visibility_state.gd`
  - `scripts/core/vision_system.gd`
  - `scripts/game/battle_controller.gd`
  - `scripts/game/tactical_tile.gd`
  - `scripts/game/unit_sprite.gd`
- 新增：
  - `scripts/game/visibility_renderer.gd`
  - `tests/visibility_renderer_test.gd`
  - `tests/visibility_renderer_test.tscn`
- 行为：
  - 未探索为实黑遮挡；已记录区域显示降饱和地形；正在观察区域显示实时单位与设施。
  - 离开视野的敌人只保留最后已知位置、回合戳和不确定标记，不泄露实时移动、生命或意图。
  - 摄像头接管扩展观察区；摄像头失效后回到已记录状态。
  - 所有目标和交互校验使用真实可见性状态，而非遮罩颜色。
- 测试：扩展 `tests/visibility_state_test.gd`，新增渲染状态映射、最后已知信息和摄像头切换断言。
- 退出门：玩家能区分“从未去过、去过但看不到、正在看见”，隐藏敌人不泄密。

#### CH1-050 AI 规划与公开意图

- 状态：代码与自动化验证完成，等待 M1 真人理解验收
- 依赖：CH1-010、CH1-040
- 执行者：Sol xhigh
- 修改：
  - `scripts/ai/enemy_planner.gd`
  - `scripts/ai/enemy_director.gd`
  - `scripts/ai/enemy_templates.gd`
  - `scripts/game/enemy_intent_state.gd`
  - `scripts/game/battle_controller.gd`
  - `scripts/game/unit_sprite.gd`
  - `scripts/ui/hud.gd`
- 新增：
  - `scripts/game/enemy_intent_renderer.gd`
- 行为：
  - 敌回合结束时生成下一回合计划，执行前仅因明确事件重算。
  - 观察到的敌人显示移动目标、攻击目标/区域、守卫、夺点或增援意图。
  - 离开观察后冻结最后已知意图并标记为过期。
  - 高伤害、范围控制和增援行为至少提前一回合给出可读信号。
- 测试：
  - 扩展 `tests/enemy_intent_state_test.gd`。
  - 扩展 `tests/chapter_one_e2e_test.gd`，验证玩家可通过移动、击退、门控或节点操作改变已知计划结果。
- 退出门：结束回合前能从地图识别最危险的已知敌人和预计结果。

#### CH1-060 战术网络与警戒表现闭环

- 状态：代码与自动化验证完成，等待 M1 人工视觉/听感验收
- 依赖：CH1-010、CH1-040
- 执行者：Terra high；视觉资源由 ImageGen 批次 A 提供
- 修改：
  - `scripts/game/tactical_network_state.gd`
  - `scripts/game/alert_state.gd`
  - `scripts/game/action_system.gd`
  - `scripts/game/tactical_effect.gd`
  - `scripts/data/art_catalog.gd`
  - `scripts/ui/hud.gd`
  - `scenes/battle.tscn`
- 行为：
  - 摄像头改变可见性，门改变路线，炮塔改变火力，电力改变设施可用性，信标改变增援。
  - 接管、禁用、过载均在预览中说明即时结果、持续时间和警戒代价。
  - 网络层只在需要时显示连接；节点四状态同时用颜色、形状和动画区分，且节点/连接线只在两端格子已观察时显示。
  - HUD 显示当前警戒等级、距离下一级事件和下一项具体后果。
- 测试：
  - 扩展 `tests/tactical_network_state_test.gd`。
  - 扩展 `tests/alert_state_test.gd`。
  - 扩展 `tests/battle_hud_contract_test.gd`。
- 退出门：五类设施都至少能改变视线、路线、火力或增援之一，且预览与结果一致。

### R3 M1 正式垂直切片

#### CH1-070 M1 三遭遇区重建

- 状态：代码与自动化验证完成，等待 M1 真人流程验收
- 依赖：CH1-020、CH1-040、CH1-050、CH1-060
- 执行者：Sol xhigh 负责遭遇设计和整合；Terra high 负责数据施工
- 修改：
  - `data/locked_maps/ch1_m1.json`
  - `data/levels.json`
  - `data/dialogues.json`
  - `scripts/game/mission_objective_state.gd`
  - `scripts/game/battle_controller.gd`
  - `tests/chapter_one_objectives_test.gd`
  - `tests/chapter_one_balance_test.gd`
- 正式结构：
  - 约 22×16，不用空走扩图。
  - A 区：突击单人进入，教学移动、掩体和第一次攻击。
  - B 区：接管摄像头发现侦察兵，出现第一条路线取舍并完成双人会合。
  - C 区：利用门/摄像头破坏守卫计划，上传后撤离。
  - 全场 7-9 名敌人，同时活跃不超过 3 名。
  - 每个遭遇区至少两种处理路线，每 3-5 分钟出现新信息或战术变化。
  - A→B、B→C 边界建立检查点；失败默认从最近遭遇重试，也可重开任务。
- 测试：
  - 验证地图尺寸、三遭遇区、路径、出生、检查点、敌人总量/活跃上限和任务阶段。
  - 验证无战斗软锁、目标不会提前完成、撤离仅在上传后开放。
- 退出门：自动化完整通过，负责人可从主菜单连续完成 M1。

#### CH1-080 M1 教学、对话、结算与失败体验

- 状态：代码与自动化验证完成，等待 M1 首次玩家可理解性验收
- 依赖：CH1-030、CH1-070
- 执行者：Terra high
- 修改：
  - `data/dialogues.json`
  - `data/achievements.json`
  - `scripts/ui/dialogue_system.gd`
  - `scripts/ui/tutorial_hint.gd`
  - `scripts/ui/mission_result.gd`
  - `scripts/game/game_manager.gd`
  - `scenes/mission_result.tscn`
- 行为：
  - 只教学选择、移动、攻击、观察、接管和结束回合。
- 对话不遮挡目标格，战斗中短句可快速跳过且不会吞掉下一次点击；选项按钮放行真实鼠标按下/释放事件并进入对应回应分支。
  - 失败页明确说明最近失败原因，并提供“从遭遇重试/重新开始/返回基地”。
  - 结算固定为任务、情报、小队三个徽章，并说明每项取得或失去原因。
- 测试：扩展 `tests/chapter_one_e2e_test.gd` 和 `tests/chapter_one_objectives_test.gd`。
- 退出门：首次玩家不会因教程面板、失败重试或结算规则中断流程。

#### CH1-090 M1 正式表现批次

- 状态：进行中；中继塔、四类 VFX、中文字体、职业色饰和三层音乐已接入，警报/意图 HUD、网络迷雾约束、底部操作提示、基地角色职业纹理和对话头像/选项布局已修复，正式角色方向表现与人工验收未完成
- 依赖：CH1-070
- 执行者：ImageGen + 图像处理工具 + Terra high 接入；人工视觉/听感验收
- 视觉范围：
  - 突击、侦察、哨兵、无人机的正面/侧向轮廓与职业色饰。
  - 摄像头节点四状态、门和终端状态、五类敌方意图、四级警戒。
  - M1 独特主地标“失联中继塔”和三个区域的环境差异。
  - 选择、扫描、接管、禁用、上传、撤离 VFX。
- 音频范围：
  - 选择、移动确认、命中、扫描、接管、禁用、警戒升级、目标完成 SFX。
  - 潜入/交战/高警戒三个可无缝切换音乐层。
- 处理要求：
  - 透明背景、统一透视、切图边界、像素密度、过滤、mipmap、缩放和动画帧均在 Godot 内验证。
  - 玩家蓝青、普通敌军橙红；角色还必须靠体型、武器、姿态和装备区分。
  - 更新 `data/RESOURCE_MANIFEST.md`、角色与环境美术 Bible。
- 退出门：720p/1080p、灰度和色觉模式均可区分阵营、职业、节点和意图；没有运行时占位图。

#### H1 M1 首次玩家硬门

- 状态：阻塞，等待 CH1-090 收口
- 依赖：CH1-070、CH1-080、CH1-090
- 执行者：至少 3 名未看过文档的真人玩家
- 记录：更新 `data/chapter1_playtest_matrix.json`
- 每名玩家记录：
  - 完成时间、回合、失败/重试、误操作、停顿超过 20 秒的位置。
  - 是否理解移动/攻击/结束回合、摄像头价值、已知敌方意图和撤离条件。
  - 最喜欢的决策、最困惑的信息、是否愿意继续 M2。
- 通过条件：
  - 3 人均无需口头教学完成 M1。
  - 中位完成时间 15-20 分钟。
  - 无 P0/P1 操作阻断。
  - 至少 2 人能复述“观察意图→控制网络→改变敌方计划”的循环。
  - 至少 2 人愿意继续下一关。
- 未通过处理：只回到对应 R1-R3 任务修正；不得开始批量 M2-M6。

### R4 共享正式内容

#### CH1-110 四名角色与成长

- 依赖：H1
- 执行者：Sol xhigh 设计/平衡；Terra high 实现；ImageGen 批次 B
- 修改：
  - `data/jobs.json`
  - `data/skills.json`
  - `data/weapons.json`
  - `scripts/game/action_system.gd`
  - `scripts/game/unit.gd`
  - `scripts/game/unit_sprite.gd`
  - `scripts/game/progression_manager.gd`
  - `scripts/ui/character_panel.gd`
- 职责：
  - 突击：近中距推进、击退、制造安全入口。
  - 侦察：观察、3 格有视线远程接入、揭示意图。
  - 狙击：远距精确、标记、处理关键敌人。
  - 重装：掩护、压制、抵挡正面威胁。
- 每人要求：基础攻击、2 个主动技能、1 个被动、2 选 1 的两层升级；无冗余同义技能。
- 美术要求：灰度只看轮廓也能辨认；职业色饰覆盖头肩、武器和背部至少两处；动画至少含待机、移动、攻击、受击、技能、倒地。
- 测试：扩展行动、动画契约、E2E 和平衡测试。
- 退出门：每名角色至少在一个常见局面中是最佳选择，但没有一名角色成为全场必选。

#### CH1-120 五类敌军与编组

- 依赖：CH1-050、H1
- 执行者：Sol xhigh 设计/AI；Terra high 实现；ImageGen 批次 C
- 修改：
  - `data/enemies.json`
  - `scripts/ai/enemy_templates.gd`
  - `scripts/ai/enemy_planner.gd`
  - `scripts/ai/enemy_director.gd`
  - `scripts/game/unit_sprite.gd`
- 职责：
  - 哨兵：稳定射线威胁，迫使使用掩体和位移。
  - 无人机：高速侦测与侧翼，低耐久。
  - 盾卫：正面防御并保护同伴，迫使换位。
  - 协议工程师：修复/反夺节点并改变设施。
  - 猎手：追踪最后已知位置，制造失联区压力。
- 每类要求：独立轮廓、武器、意图图标、声音、至少一条克制办法；差异不以单纯生命/伤害倍率实现。
- 测试：确定性计划、意图公开、编组上限、反夺节点和无预警致命行为禁止。
- 退出门：玩家只看地图轮廓和意图即可说明每类敌人的优先级。

#### CH1-130 基地、编队、成长与存档

- 依赖：CH1-110
- 执行者：Terra high；存档迁移由 Sol xhigh 复核
- 修改：
  - `scripts/ui/base_controller.gd`
  - `scripts/ui/character_panel.gd`
  - `scripts/ui/shop_panel.gd`
  - `scripts/game/progression_manager.gd`
  - `scripts/network/save_manager.gd`
  - `scenes/base.tscn`
  - `data/levels.json`
- 行为：
  - 基地只保留任务简报、三选四编队、技能升级、设置和出击。
  - 不引入库存整理；装备只作为少量明确侧向选择。
  - M1 解锁侦察，M2 解锁狙击，M3 解锁重装；后续可三选四。
  - 存档记录任务进度、徽章、升级、设置和当前遭遇检查点。
  - 损坏存档恢复不覆盖健康备份；未来版本存档只读拒绝。
- 测试：扩展 `tests/base_mission_list_test.gd`、`tests/save_recovery_test.gd` 和 E2E。
- 退出门：退出应用后可继续最近遭遇；升级和编队在任务中一致生效。

#### CH1-140 第一章共享美术与音频工具包

- 依赖：CH1-090、CH1-110、CH1-120
- 执行者：ImageGen + 图像处理/音频工具；Terra high 批量接入；人工验收
- 交付：
  - 四名角色、五类敌军、Boss 的完整战斗图集。
  - 六关各一个独特主地标和环境组合，不以整图换色代替。
  - 五类设施完整状态、敌方意图、网络、迷雾、风险、警戒统一视觉语言。
  - 至少 3 个可循环音乐层、Boss 三阶段音乐变化、胜负与阶段转换短句。
  - 全部高频动作 SFX，并设置同类音效并发上限和轻微音高变化。
  - 可商用简体中文字体、Godot 许可证和全部第三方通知。
- 每批流程：4 张小样→运行时场景验证→视觉批准→批量生成→透明/切图/压缩→导入→动画/碰撞/音频接线→双分辨率截图/录音验证。
- 退出门：资源清单可追溯，游戏内没有占位符、错切、白边、尺寸跳变或刺耳并发。

### R5 六关内容生产

#### CH1-200 M2 熄灯协议

- 依赖：CH1-110、CH1-120、CH1-130、CH1-140
- 执行者：Sol xhigh 设计/验收；Terra high 实现
- 文件：`data/locked_maps/ch1_m2.json`、`data/levels.json`、`data/dialogues.json`、目标/平衡/E2E 测试。
- 结构：约 22×16；三人阵容；电力分区、炮塔反转和盾卫；至少两条断电顺序；错误路线提高警戒但不立即判死。
- 完成门：20-25 分钟；至少两次设施改变战术；三名人工样本；无唯一正确解。

#### CH1-210 M3 断轨营救

- 依赖：CH1-200
- 执行者：Sol xhigh 设计/验收；Terra high 实现
- 文件：`data/locked_maps/ch1_m3.json`、`data/levels.json`、`data/dialogues.json`、目标/平衡/E2E 测试。
- 结构：约 24×16；营救重装；可见倒计时只在关键事件后启动；协议工程师反夺节点；改变列车路由；引入警戒射击。
- 完成门：20-25 分钟；倒计时有至少两种缓解手段；失败原因提前可见；三名人工样本。

#### CH1-220 M4 囚笼密钥

- 依赖：CH1-210
- 执行者：Sol xhigh 设计/验收；Terra high 实现
- 文件：`data/locked_maps/ch1_m4.json`、`data/levels.json`、`data/dialogues.json`、目标/平衡/E2E 测试。
- 结构：约 24×18；首次三选四；门控网络形成两条主要路线；营救临时盟友；情报与安全撤离有明确取舍。
- 完成门：25-30 分钟；不同三人组合均可通关且决策不同；三名人工样本。

#### CH1-230 M5 反向猎杀

- 依赖：CH1-220
- 执行者：Sol xhigh 设计/AI验收；Terra high 实现
- 文件：`data/locked_maps/ch1_m5.json`、`data/levels.json`、`data/dialogues.json`、敌人/网络/平衡/E2E 测试。
- 结构：约 24×18；猎手根据最后已知位置追踪；敌军主动反夺节点；局部失联；玩家在守点、转移和提前撤出之间取舍。
- 完成门：25-30 分钟；失联不等于隐藏规则；至少两种可行撤离节奏；三名人工样本。

#### CH1-240 M6 零号终端

- 依赖：CH1-230
- 执行者：Sol xhigh；Terra high 实现；ImageGen/音频工具完成 Boss 表现
- 文件：
  - `data/locked_maps/ch1_m6.json`
  - `data/bosses.json`
  - `data/dialogues.json`
  - `scripts/game/battle_controller.gd`
  - `tests/data_sentinel_boss_test.gd`
  - `tests/chapter_one_e2e_test.gd`
- 三阶段：
  - 侦测：争夺观察节点，识别 Boss 暴露窗口。
  - 反制：Boss 污染连接并夺取设施，玩家切换网络路径。
  - 熔毁：有限回合内选择安全关闭或高风险过载结局。
- 要求：四人都拥有关键作用；阶段改变规则与目标，不只是提高生命和伤害；结局写入存档并返回完整章节结算。
- 完成门：30-35 分钟；三阶段决策明显不同；标准难度无强制指定解；三名人工样本。

### H2 全章平衡与连续通关

#### CH1-300 难度、经济和节奏收口

- 依赖：CH1-240
- 执行者：Sol xhigh
- 修改：`data/chapter1_playtest_matrix.json`、角色/敌人/技能/武器/关卡数据和平衡测试。
- 难度：
  - 剧情：降低惩罚，保留完整规则与 Boss 阶段。
  - 标准：设计基线。
  - 困难：更强编组和更严资源，不通过隐藏命中惩罚或纯血量膨胀实现。
- 指标：关卡时长、回合、倒地、重试、警戒峰值、节点使用、角色选择、技能使用、徽章和放弃点。
- 通过条件：
  - 每关每难度至少 3 个有效样本。
  - 一名玩家从新档连续完成 M1-M6。
  - 标准难度首次流程中位数 3-4 小时。
  - 无角色选择率或关键技能使用率显示明显必选/无用。
  - 每关至少两条有效处理路线。

#### CH1-310 可访问性、设置和控制器

- 依赖：CH1-240
- 执行者：Terra high；人工可访问性检查
- 修改：
  - `scripts/game/accessibility_settings.gd`
  - `scripts/game/input_bindings.gd`
  - `scripts/ui/settings_menu.gd`
  - `scenes/settings_menu.tscn`
  - HUD、单位、目标、设施相关场景
- 要求：
  - 全键盘操作、焦点导航、按键重映射和常见手柄。
  - 大字、减少闪烁/镜头移动、色觉模式、字幕和独立音量。
  - 阵营、职业、目标、设施和警戒不只依赖颜色。
  - 720p、1080p、1440p、21:9 不裁切关键控制。
- 完成门：所有设置重启后保持；鼠标、键盘和手柄各完成 M1。

#### CH1-320 全章回归与长时运行

- 依赖：CH1-300、CH1-310
- 执行者：Terra high 自动化；人工 QA
- 验证：
  - 完整发布门。
  - 新档、旧版本迁移档、损坏档恢复、未来版本拒绝。
  - 六关胜利、失败、遭遇重试、返回基地、继续游戏、章节结局。
  - 两小时长时运行，持续内存增长低于 10%，无输入、音频或场景切换失效。
  - 720p、1080p、1440p、21:9；窗口/全屏切换。
- 完成门：0 P0/P1 缺陷；P2 仅允许有书面接受且不影响通关的问题。

### R6 第一章发布候选版

#### CH1-330 发布包、许可证和干净环境

- 依赖：CH1-320
- 执行者：Terra high；项目负责人签核
- 文件：
  - `tactical-grid/client/export_presets.cfg`
  - `tactical-grid/client/tools/build_windows.ps1`
  - `tactical-grid/client/tests/verify_windows_package.ps1`
  - `tactical-grid/client/data/RESOURCE_MANIFEST.md`
  - README、隐私说明、第三方通知、版本说明
- 要求：
  - 从干净克隆执行导入、测试、导出和包验证。
  - 发布包不包含 `.godot`、源测试产物、开发日志、私有路径或旧服务端。
  - 包含 Godot MIT、Godot `COPYRIGHT.txt`、字体/资源许可证和 SHA-256 清单。
  - 干净 Windows 账户验证启动、设置、存档、继续、完整 M1、退出和卸载残留。
- 完成门：验证脚本通过；包内程序无需编辑器或额外运行时即可启动。

#### CH1-340 第一章候选版签核

- 依赖：CH1-330
- 执行者：项目负责人
- 签核证据：
  - 自动化发布门日志。
  - 全章连续通关记录。
  - M1 首次玩家与六关平衡样本。
  - 分辨率、可访问性、长时运行和干净账户记录。
  - 最终包 SHA-256、资源与许可证清单。
- Go 条件：
  - 第一章 M1-M6 可从新档完整通关并正常结束。
  - 无 P0/P1 缺陷，无已知存档破坏。
  - 游戏内操作、目标、敌方意图和失败原因可理解。
  - 没有占位资源或来源不明资源。
  - 发布包在无 Godot 编辑器的机器上独立运行。

## 8. 智能体派发分类

### 8.1 Sol xhigh

适合高耦合、高风险和需要全局游戏判断的任务：

- CH1-010、020、040、050
- CH1-070 的遭遇设计与最终整合
- CH1-110、120 的职责与平衡
- CH1-200 至 240 的关卡设计/验收
- CH1-300

每次只派发一个高耦合任务；完成后回到 `main` 统一复核，不建立长期功能分支。

### 8.2 Terra high

适合边界明确的 Godot、数据、UI、测试和内容施工：

- CH1-030、060、080
- CH1-070 的地图数据施工
- CH1-090/140 的资源处理与接入
- CH1-130
- CH1-200 至 240 的关卡实现
- CH1-310、320、330

### 8.3 ImageGen 与图像处理工具

只负责路线图明确列出的视觉批次：

- 批次 A：节点、设施、意图、警戒与 M1 地标。
- 批次 B：四名玩家角色图集与职业色饰。
- 批次 C：五类敌军与 Boss 图集。
- 批次 D：M2-M6 六关地标、任务目标物与章节表现。

生成前先做 4 张小样；生成后必须由代码智能体完成透明、切图、尺寸、导入、动画、碰撞、运行时接线和双分辨率验证。

### 8.4 人工不可替代

- H1 M1 首次玩家硬门。
- 每关每难度的有效试玩样本。
- 灰度、色觉、字体、动画与听感验收。
- 一名玩家全章连续通关。
- 干净账户安装和最终 Go/No-go。

模型强度不能替代真人试玩，自动化数量不能替代趣味性证据。

## 9. 标准验证命令

在 `tactical-grid/client` 执行：

```powershell
powershell -ExecutionPolicy Bypass -File tests/run_release_gate.ps1
```

在 `tactical-grid/client` 执行 Windows 构建：

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_windows.ps1
```

在 `tactical-grid/client` 执行第一章视觉快照（窗口渲染，不使用 Godot 编辑器）。`qa-stage` 可选 `initial`、`selection`、`network`、`intent`、`upload`、`evac`；网络/上传/撤离阶段为便于构图检查会强制揭示地图，不代表正式玩法关闭迷雾：

```powershell
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --path (Get-Location).Path --display-driver windows --rendering-method gl_compatibility --resolution 1280x720 res://tests/chapter1_visual_snapshot.tscn -- --qa-size=1280x720 --qa-mode=none --qa-output=build/chapter1_visual_1280x720_none.png
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --path (Get-Location).Path --display-driver windows --rendering-method gl_compatibility --resolution 1280x720 res://tests/chapter1_visual_snapshot.tscn -- --qa-size=1280x720 --qa-mode=grayscale --qa-output=build/chapter1_visual_1280x720_grayscale.png
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --path (Get-Location).Path --display-driver windows --rendering-method gl_compatibility --resolution 1280x720 res://tests/chapter1_visual_snapshot.tscn -- --qa-size=1280x720 --qa-mode=none --qa-stage=selection --qa-output=build/chapter1_visual_1280x720_selection.png
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --path (Get-Location).Path --display-driver windows --rendering-method gl_compatibility --resolution 1280x720 res://tests/chapter1_visual_snapshot.tscn -- --qa-size=1280x720 --qa-mode=none --qa-stage=network --qa-output=build/chapter1_visual_1280x720_network.png
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --path (Get-Location).Path --display-driver windows --rendering-method gl_compatibility --resolution 1280x720 res://tests/chapter1_visual_snapshot.tscn -- --qa-size=1280x720 --qa-mode=none --qa-stage=intent --qa-output=build/chapter1_visual_1280x720_intent.png
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --path (Get-Location).Path --display-driver windows --rendering-method gl_compatibility --resolution 1280x720 res://tests/chapter1_visual_snapshot.tscn -- --qa-size=1280x720 --qa-mode=none --qa-stage=upload --qa-output=build/chapter1_visual_1280x720_upload.png
& 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe' --path (Get-Location).Path --display-driver windows --rendering-method gl_compatibility --resolution 1280x720 res://tests/chapter1_visual_snapshot.tscn -- --qa-size=1280x720 --qa-mode=none --qa-stage=evac --qa-output=build/chapter1_visual_1280x720_evac.png
```

`qa-mode` 可使用 `none`、`deuteranopia` 或 `grayscale`；截图只能证明首帧布局和可读性，不能替代完整 M1 真人验收。

验证发布包：

```powershell
powershell -ExecutionPolicy Bypass -File client/tests/verify_windows_package.ps1
```

每个任务提交前还必须运行与该任务同名或最接近的场景测试；不得只运行局部测试后声称全量完成。

## 10. 下一执行批次

严格按以下顺序：

1. 收口 CH1-090：完成角色/敌军正式辨识、三区域表现和人工表现验收；警报布局、地标迷雾边界和自动首帧快照已完成，中文字体与三层音乐代码已完成，只需确认完整流程中的游戏内效果。
2. 运行完整 M1 的 720p/1080p、灰度、色觉和音频听感检查；首帧快照不计作人工签核。
3. 通过 H1：至少 3 名首次玩家完成 M1 理解与趣味性测试。
4. H1 通过后，才进入 CH1-110、CH1-120、CH1-130、CH1-140 和 M2-M6。

后续所有完成状态只更新本文和 `tactical-grid/PROJECT_STATUS.md`；不得另建路线图、派发总表或平行完成度文档。
