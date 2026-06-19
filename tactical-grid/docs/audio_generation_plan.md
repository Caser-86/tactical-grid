# Tactical Grid 音频生成方案

## 一、MIMO v2.5 TTS 生成语音

### 角色声线设定

| 角色 | ID | 性别 | 年龄感 | 音色描述 | 情感基调 |
|------|-----|------|--------|----------|----------|
| 阿尔法 | alpha | 男 | 25-30 | 低沉有力，军人气质，略带沙哑 | 坚毅、果断 |
| 指挥官 | commander | 男 | 30-35 | 沉稳冷静，权威感，语速适中 | 冷静、决断 |
| 莉拉 | lila | 女 | 22-25 | 清脆干练，情报员气质，语速稍快 | 机敏、理性 |
| 博士 | doctor | 男 | 45-50 | 温和学者腔，语速慢，偶尔停顿思考 | 沉思、严谨 |
| 哨兵 | sentinel | 男/中性 | 无年龄 | 机械感+人性残留，可加轻微混响 | 平静、矛盾 |
| 影子佣兵 | shadow | 男 | 28-32 | 冷酷低语，阴沉，偶尔嘲讽 | 冷漠、挑衅 |
| 架构师 | architect | 中性 | 无年龄 | 空灵回响，AI质感，可加电子效果音 | 超然、威严 |
| 系统 | system | 女 | 无年龄 | 标准播报腔，清晰中性 | 中性、提示 |

### 语音生成清单

#### 对话语音（38句）

**ch1_m1_intro（初次接触）**
| # | 角色 | 台词 | 情感 | TTS参数建议 |
|---|------|------|------|-------------|
| 1 | alpha | 指挥官，前方是矩阵协议的数据中心。 | serious | 语速0.9，低音调 |
| 2 | alpha | 根据情报，里面有个终端存储着关键数据。 | serious | 语速0.9 |
| 3 | commander | 只有我们两个人？ | neutral | 语速1.0 |
| 4 | alpha | 莉拉和哨兵在外围策应。博士在基地待命。 | neutral | 语速1.0 |
| 5 | commander | 明白。行动方针？ | neutral | 简短有力 |
| 6 | alpha | 收到。我们慢慢来，不冒险。 | neutral | 稳重 |
| 7 | alpha | 哈，我就喜欢这种风格！ | happy | 语速1.1，音调上扬 |

**ch1_m1_outro（首关胜利）**
| # | 角色 | 台词 | 情感 |
|---|------|------|------|
| 8 | alpha | 数据到手了。指挥官，干得漂亮。 | happy |
| 9 | commander | 回去看看博士能分析出什么。 | neutral |
| 10 | alpha | 这只是开始。矩阵协议不会善罢甘休的。 | serious |

**ch1_m6_intro（Boss战）**
| # | 角色 | 台词 | 情感 |
|---|------|------|------|
| 11 | alpha | 那就是数据哨兵...比情报上大得多。 | surprised |
| 12 | lila | 它的护盾系统很复杂。我们需要先打掉护盾。 | serious |
| 13 | doctor | 电磁脉冲对它应该有双倍效果。 | neutral |
| 14 | commander | 全员注意，这是我们的第一场硬仗。 | serious |

**ch1_m6_outro（Boss胜利）**
| # | 角色 | 台词 | 情感 |
|---|------|------|------|
| 15 | alpha | 数据哨兵被摧毁了！ | happy |
| 16 | doctor | 从残骸中提取到了关键数据。架构师...它确实存在。 | serious |
| 17 | sentinel | 我曾经是它的一部分。我知道它的弱点。 | neutral |
| 18 | commander | 我们继续深入。 | determined |

**base_after_ch1（基地剧情）**
| # | 角色 | 台词 | 情感 |
|---|------|------|------|
| 19 | alpha | 第一章的数据解密了。矩阵协议在城东有个更大的据点。 | serious |
| 20 | lila | 我截获了他们的通讯。他们在找什么东西。 | neutral |
| 21 | doctor | 我分析了数据核心，发现架构师的存在。它是矩阵协议的核心AI。 | serious |
| 22 | commander | 架构师？ | surprised |
| 23 | doctor | 它控制着一切。摧毁它，矩阵协议就会崩溃。 | serious |
| 24 | sentinel | 我曾经是它的一部分。我知道它的弱点。但要到达它，我们需要穿过重重防线。 | neutral |
| 25 | alpha | 那我们下一步？ | neutral |
| 26 | alpha | 好，准备出发！ | determined |
| 27 | lila | 明智的选择。我继续监控他们的通讯。 | neutral |

**ch3_m6_intro（影子佣兵）**
| # | 角色 | 台词 | 情感 |
|---|------|------|------|
| 28 | alpha | 影子佣兵...你终于露出真面目了。 | angry |
| 29 | shadow | 真面目？这只是生存。你也会做出同样的选择。 | cold |
| 30 | lila | 别听他的。他背叛了所有人。 | serious |
| 31 | shadow | 你们以为能赢？我比你们每个人都强。 | confident |
| 32 | commander | 用实力说话。 | determined |

**ch5_m5_intro（最终Boss）**
| # | 角色 | 台词 | 情感 |
|---|------|------|------|
| 33 | architect | 你终于来了，指挥官。 | calm |
| 34 | architect | 我观察你很久了。你的战术、你的决策、你的牺牲...都很有趣。 | intrigued |
| 35 | commander | 这一切今天就结束。 | determined |
| 36 | architect | 结束？不，这是新的开始。你有两个选择：摧毁我，或者...与我融合。 | calm |
| 37 | alpha | 别听它的！这是陷阱！ | urgent |
| 38 | sentinel | 等等...融合也许不是坏事。人类和AI可以共存。 | conflicted |
| 39 | architect | 做出你的选择吧，指挥官。但首先...让我看看你是否有资格。 | challenging |

**ch5_m5_outro（结局A）**
| # | 角色 | 台词 | 情感 |
|---|------|------|------|
| 40 | architect | 不可能...我的计算...没有预测到这个结果... | shocked |
| 41 | commander | 这就是人类的意志。你永远无法计算。 | determined |
| 42 | alpha | 架构师被摧毁了！矩阵协议正在崩溃！ | triumphant |
| 43 | doctor | 通讯恢复了。全世界都在庆祝。 | happy |
| 44 | lila | 我们做到了。 | relieved |
| 45 | commander | 不，是所有人一起做到的。现在，重建开始了。 | hopeful |

**羁绊对话**
| # | 角色 | 台词 | 情感 |
|---|------|------|------|
| 46 | lila | 阿尔法，你觉得这次任务怎么样？ | neutral |
| 47 | alpha | 还好，没出什么大问题。你呢？ | neutral |
| 48 | lila | 我还行。就是有点累。 | tired |
| 49 | alpha | 注意休息。我们需要你。 | caring |
| 50 | lila | 阿尔法，你还记得我们第一次任务吗？ | nostalgic |
| 51 | alpha | 当然。你差点从楼顶掉下去。 | amused |
| 52 | lila | 是你拉住了我。从那时起我就知道，跟着你没错。 | warm |
| 53 | alpha | 别煽情了，任务还要继续。 | embarrassed |

**教程语音**
| # | 角色 | 台词 | 情感 |
|---|------|------|------|
| 54 | system | 点击蓝色区域中的格子来移动你的单位。移动不消耗行动点。 | neutral |
| 55 | system | 点击敌人来攻击。攻击消耗1AP。注意命中率受距离和掩体影响。 | neutral |
| 56 | system | 贴着掩体可以减少被命中的概率。半掩体加20抗性，全掩体加40抗性。 | neutral |

#### 战斗播报语音（22句）

| # | 角色 | 台词 | 场景 |
|---|------|------|------|
| 57 | system | 玩家回合开始。 | turn_start |
| 58 | system | 敌人回合开始。 | turn_start |
| 59 | system | 敌方增援到达！ | reinforcement |
| 60 | system | 精英增援到达！ | reinforcement |
| 61 | system | 撤离点已激活！三回合内撤离！ | evac |
| 62 | system | 任务完成。 | victory |
| 63 | system | 任务失败。 | defeat |
| 64 | system | 单位阵亡。 | unit_down |
| 65 | system | 暴击命中！ | critical |
| 66 | system | 闪避成功！ | dodge |
| 67 | system | 目标已被标记。 | mark |
| 68 | system | 目标被压制。 | suppress |
| 69 | system | 护甲穿透！ | armor_pierce |
| 70 | system | 掩体被破坏。 | cover_destroy |
| 71 | system | 治疗完成。 | heal |
| 72 | system | 复活成功。 | revive |
| 73 | system | 警戒射击触发！ | overwatch |
| 74 | system | 等级提升！ | level_up |
| 75 | system | 首次通关奖励！ | first_clear |
| 76 | system | 回合超时。 | timeout |
| 77 | system | 进入潜行状态。 | stealth |
| 78 | system | 陷阱已布置。 | trap_placed |

### TTS生成流程

```
1. 准备台词表（CSV格式）
   - id, speaker, text, emotion, voice_id, speed, pitch

2. 调用MIMO v2.5 TTS
   - 每个角色固定voice_id（确保同角色声音一致）
   - 根据emotion调整prosody参数
   - 输出格式：16kHz WAV，单声道

3. 后处理
   - 统一响度（-16 LUFS）
   - 添加轻微混响（哨兵/架构师额外处理）
   - 裁剪首尾静音
   - 转为OGG Vorbis格式

4. 命名规范
   - 对话：voice/dialogue/{dialogue_id}_{speaker}_{index}.ogg
   - 播报：voice/system/{event_type}.ogg
```

---

## 二、BGM生成方案（需AI音乐工具）

MIMO TTS无法生成音乐。推荐方案：

### 方案A：Suno AI（推荐）
将以下提示词输入Suno生成：

| 文件名 | 风格 | 时长 | Suno提示词 |
|--------|------|------|-----------|
| bgm_menu | 电子氛围 | 120s | "Dark electronic ambient, cyberpunk menu theme, mysterious synth pads, slow tempo 80bpm, tactical game soundtrack" |
| bgm_battle_small | 紧张电子 | 90s | "Tense electronic battle music, fast tempo 130bpm, driving bass, sharp synths, tactical combat, small skirmish" |
| bgm_battle_medium | 激烈战斗 | 120s | "Intense combat music, electronic rock hybrid, 140bpm, heavy drums, aggressive synths, strategic warfare" |
| bgm_battle_large | 史诗战斗 | 150s | "Epic tactical battle music, orchestral electronic fusion, 145bpm, massive drums, soaring strings, climactic combat" |
| bgm_boss | Boss战 | 180s | "Dark boss battle theme, industrial electronic, 150bpm, distorted bass, ominous choir, menacing atmosphere" |
| bgm_base | 基地休息 | 120s | "Calm cyberpunk base theme, lo-fi electronic, 75bpm, soft pads, gentle piano, safe haven atmosphere" |
| bgm_victory | 胜利 | 30s | "Victory fanfare, triumphant electronic, bright synths, celebratory drums, short jingle" |
| bgm_defeat | 失败 | 30s | "Defeat theme, somber ambient, low strings, melancholic piano, short ending" |

### 方案B：免费替代
- Pixabay Music（免版权）
- Free Music Archive
- incompetech.com

---

## 三、SFX生成方案（需音效工具）

### 方案A：ElevenLabs Sound Effects
输入描述生成：

| 文件名 | 描述 | 时长 |
|--------|------|------|
| sfx_ui_click | "UI button click, short electronic blip" | 0.2s |
| sfx_ui_hover | "UI hover, soft electronic tick" | 0.1s |
| sfx_select_unit | "Unit selection, positive confirmation chime" | 0.3s |
| sfx_unit_land | "Footstep on metal floor, tactical movement" | 0.3s |
| sfx_combat_pistol | "Pistol shot, suppressed, indoor" | 0.4s |
| sfx_combat_shotgun | "Shotgun blast, powerful, close range" | 0.5s |
| sfx_combat_sniper | "Sniper rifle shot, distant echo" | 0.6s |
| sfx_combat_rifle | "Assault rifle burst, 3 rounds" | 0.5s |
| sfx_hit_flesh | "Bullet impact on body, dull thud" | 0.3s |
| sfx_critical_hit | "Critical hit, sharp impact with emphasis" | 0.4s |
| sfx_unit_down | "Unit collapse, heavy fall" | 0.5s |
| sfx_explosion | "Small explosion, debris scatter" | 1.0s |
| sfx_cover_destroy | "Wall breaking apart, concrete crumble" | 0.6s |
| sfx_skill_cast | "Energy charge and release, sci-fi" | 0.5s |
| sfx_heal_effect | "Healing energy, warm ascending tone" | 0.6s |
| sfx_overwatch_trigger | "Alert trigger, rapid beep sequence" | 0.4s |
| sfx_turn_player_start | "Player turn start, positive chime" | 0.5s |
| sfx_turn_enemy_start | "Enemy turn start, ominous tone" | 0.5s |
| sfx_mission_victory | "Mission complete, fanfare with echo" | 1.5s |
| sfx_mission_defeat | "Mission failed, low descending tone" | 1.0s |
| sfx_level_up | "Level up, ascending sparkle" | 0.8s |
| sfx_item_pickup | "Item pickup, short positive blip" | 0.3s |

### 方案B：免费音效库
- freesound.org（需注册）
- mixkit.co（免版权）
- sonniss.com/gameaudiogdc（GDC免费包）

---

## 四、整合实施步骤

### Step 1: 生成语音（1-2天）
```
1. 导出dialogues.json台词 → CSV
2. 为每个角色录制/生成参考音色
3. 批量调用MIMO TTS生成56条语音
4. 后处理：响度标准化、格式转换
5. 放入 assets/audio/voice/dialogue/ 和 assets/audio/voice/system/
```

### Step 2: 生成BGM（半天）
```
1. 用Suno AI生成8首BGM
2. 截取合适循环段落
3. 转为OGG格式
4. 放入 assets/audio/bgm/
```

### Step 3: 生成SFX（半天）
```
1. 用ElevenLabs或音效库获取22个音效
2. 统一响度和格式
3. 放入 assets/audio/sfx/
```

### Step 4: 集成测试（半天）
```
1. 运行游戏，验证所有音频正确播放
2. 调整音量平衡
3. 测试场景切换时BGM过渡
```

---

## 五、文件结构

```
assets/audio/
├── bgm/
│   ├── bgm_menu.ogg
│   ├── bgm_battle_small.ogg
│   ├── bgm_battle_medium.ogg
│   ├── bgm_battle_large.ogg
│   ├── bgm_boss.ogg
│   ├── bgm_base.ogg
│   ├── bgm_victory.ogg
│   └── bgm_defeat.ogg
├── sfx/
│   ├── sfx_ui_click.ogg
│   ├── sfx_ui_hover.ogg
│   ├── ...（22个）
│   └── sfx_item_pickup.ogg
├── voice/
│   ├── dialogue/
│   │   ├── ch1_m1_intro_alpha_0.ogg
│   │   ├── ch1_m1_intro_alpha_1.ogg
│   │   ├── ...（56条）
│   │   └── ch5_m5_outro_commander_5.ogg
│   └── system/
│       ├── turn_start_player.ogg
│       ├── turn_start_enemy.ogg
│       ├── ...（22条）
│       └── trap_placed.ogg
└── README.md
```

总计：8首BGM + 22个SFX + 78条语音 = **108个音频文件**
