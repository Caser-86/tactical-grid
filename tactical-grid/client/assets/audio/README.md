# Audio Assets

此目录用于存放游戏音频资源。AudioManager 会自动查找 .ogg 和 .wav 格式文件。

## 目录结构

### bgm/ - 背景音乐
需要的文件：
- `bgm_menu.ogg` - 主菜单BGM
- `bgm_battle_small.ogg` - 小型战斗BGM
- `bgm_battle_medium.ogg` - 中型战斗BGM
- `bgm_battle_large.ogg` - 大型战斗BGM
- `bgm_boss.ogg` - Boss战BGM
- `bgm_base.ogg` - 基地界面BGM
- `bgm_victory.ogg` - 胜利BGM
- `bgm_defeat.ogg` - 失败BGM

### sfx/ - 音效
需要的文件：
- `sfx_ui_click.ogg` - UI点击
- `sfx_ui_hover.ogg` - UI悬停
- `sfx_select_unit.ogg` - 选择单位
- `sfx_unit_land.ogg` - 单位移动落地
- `sfx_combat_pistol.ogg` - 手枪射击
- `sfx_combat_shotgun.ogg` - 霰弹枪射击
- `sfx_combat_sniper.ogg` - 狙击枪射击
- `sfx_combat_rifle.ogg` - 步枪射击
- `sfx_hit_flesh.ogg` - 命中音效
- `sfx_critical_hit.ogg` - 暴击音效
- `sfx_unit_down.ogg` - 单位倒下
- `sfx_explosion.ogg` - 爆炸
- `sfx_cover_destroy.ogg` - 掩体破坏
- `sfx_skill_cast.ogg` - 技能释放
- `sfx_heal_effect.ogg` - 治疗效果
- `sfx_overwatch_trigger.ogg` - 警戒触发
- `sfx_turn_player_start.ogg` - 玩家回合开始
- `sfx_turn_enemy_start.ogg` - 敌人回合开始
- `sfx_mission_victory.ogg` - 任务胜利
- `sfx_mission_defeat.ogg` - 任务失败
- `sfx_level_up.ogg` - 升级
- `sfx_item_pickup.ogg` - 拾取物品

### ambient/ - 环境音
需要的文件：
- `ambient_wind.ogg` - 风声
- `ambient_battle.ogg` - 战场环境音

## 格式要求
- 优先使用 .ogg 格式（Vorbis编码）
- 备选 .wav 格式
- 采样率：44100Hz
- 比特率：128-192kbps
