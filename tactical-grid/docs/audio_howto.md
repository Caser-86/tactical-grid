# 音频生成操作手册

## 前置准备

### 1. 安装工具
```bash
# Python依赖（用于批量生成）
pip install requests pandas pydub

# ffmpeg（用于音频后处理）
# Windows: 下载 https://ffmpeg.org/download.html 解压后加入PATH
# 或用 scoop: scoop install ffmpeg
```

### 2. 启动MIMO v2.5 TTS服务
```bash
# 根据你的MIMO安装方式启动API服务
# 默认地址: http://localhost:8000
# 如果是远程服务，修改 generate_voice.py 中的 MIMO_API_URL
```

---

## 第一步：生成语音（MIMO TTS）

### 方式A：Python脚本批量生成
```bash
cd tactical-grid
python tools/generate_voice.py
```

脚本会：
- 读取 tools/dialogues.csv（78条台词）
- 调用MIMO TTS API逐条生成
- 自动转OGG格式
- 对哨兵/架构师角色添加混响效果
- 输出到 client/assets/audio/voice/

### 方式B：手动逐条生成（如果脚本有问题）
```bash
# 查看所有台词
cat tools/dialogues.csv

# 用curl调用MIMO API示例
curl -X POST http://localhost:8000/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mimo-v2.5-tts",
    "input": "指挥官，前方是矩阵协议的数据中心。",
    "voice": "zh_male_01",
    "speed": 0.9
  }' \
  --output alpha_01.wav
```

---

## 第二步：生成BGM（Suno AI）

打开 https://suno.com ，逐首生成：

### bgm_menu.ogg（主菜单）
```
提示词：Dark electronic ambient, cyberpunk menu theme, mysterious synth pads, slow tempo 80bpm, tactical game soundtrack, no vocals
风格标签：Electronic, Ambient, Dark
时长：2分钟
```

### bgm_battle_small.ogg（小战斗）
```
提示词：Tense electronic battle music, fast tempo 130bpm, driving bass, sharp synths, tactical combat, small skirmish, no vocals
风格标签：Electronic, Aggressive, Fast
时长：90秒
```

### bgm_battle_medium.ogg（中战斗）
```
提示词：Intense combat music, electronic rock hybrid, 140bpm, heavy drums, aggressive synths, strategic warfare, no vocals
风格标签：Electronic Rock, Intense
时长：2分钟
```

### bgm_battle_large.ogg（大战斗）
```
提示词：Epic tactical battle music, orchestral electronic fusion, 145bpm, massive drums, soaring strings, climactic combat, no vocals
风格标签：Epic, Orchestral Electronic
时长：2.5分钟
```

### bgm_boss.ogg（Boss战）
```
提示词：Dark boss battle theme, industrial electronic, 150bpm, distorted bass, ominous choir, menacing atmosphere, no vocals
风格标签：Industrial, Dark, Ominous
时长：3分钟
```

### bgm_base.ogg（基地）
```
提示词：Calm cyberpunk base theme, lo-fi electronic, 75bpm, soft pads, gentle piano, safe haven atmosphere, no vocals
风格标签：Lo-fi, Calm, Cyberpunk
时长：2分钟
```

### bgm_victory.ogg（胜利）
```
提示词：Victory fanfare, triumphant electronic, bright synths, celebratory drums, short jingle, no vocals
风格标签：Triumphant, Fanfare
时长：30秒
```

### bgm_defeat.ogg（失败）
```
提示词：Defeat theme, somber ambient, low strings, melancholic piano, short ending, no vocals
风格标签：Somber, Melancholic
时长：30秒
```

下载后放入 client/assets/audio/bgm/

---

## 第三步：生成SFX音效

### 方式A：ElevenLabs（推荐）
打开 https://elevenlabs.io/sound-effects ，输入描述生成：

| 文件名 | 描述 |
|--------|------|
| sfx_ui_click | "Short electronic button click, cyberpunk UI" |
| sfx_ui_hover | "Soft electronic hover tick, UI feedback" |
| sfx_select_unit | "Unit selection chime, positive confirmation" |
| sfx_unit_land | "Footstep on metal floor, tactical boot" |
| sfx_combat_pistol | "Suppressed pistol shot, indoor echo" |
| sfx_combat_shotgun | "Shotgun blast, powerful close range" |
| sfx_combat_sniper | "Sniper rifle shot with distant echo" |
| sfx_combat_rifle | "Assault rifle burst, 3 rounds" |
| sfx_hit_flesh | "Bullet impact, dull thud on body" |
| sfx_critical_hit | "Critical hit, sharp impact with emphasis" |
| sfx_unit_down | "Body collapse, heavy fall on ground" |
| sfx_explosion | "Small explosion with debris scatter" |
| sfx_cover_destroy | "Concrete wall breaking, crumble" |
| sfx_skill_cast | "Energy charge and release, sci-fi" |
| sfx_heal_effect | "Healing energy, warm ascending tone" |
| sfx_overwatch_trigger | "Alert trigger, rapid beep sequence" |
| sfx_turn_player_start | "Player turn, positive chime" |
| sfx_turn_enemy_start | "Enemy turn, ominous tone" |
| sfx_mission_victory | "Mission complete, fanfare with echo" |
| sfx_mission_defeat | "Mission failed, low descending tone" |
| sfx_level_up | "Level up, ascending sparkle" |
| sfx_item_pickup | "Item pickup, short positive blip" |

### 方式B：免费音效库
1. https://freesound.org - 搜索关键词下载
2. https://mixkit.co/free-sound-effects/ - 免版权
3. https://sonniss.com/gameaudiogdc - GDC免费游戏音效包

下载后放入 client/assets/audio/sfx/

---

## 第四步：验证

### 检查文件完整性
```bash
# 应该有 8 个 BGM
ls client/assets/audio/bgm/*.ogg | Measure-Object

# 应该有 22 个 SFX
ls client/assets/audio/sfx/*.ogg | Measure-Object

# 应该有 78 个语音
ls client/assets/audio/voice/dialogue/*.ogg | Measure-Object
ls client/assets/audio/voice/system/*.ogg | Measure-Object
```

### 运行游戏测试
```bash
cd tactical-grid/server
npm run dev

# 用Godot打开 client/project.godot，按F5运行
# 测试：主菜单BGM播放、战斗音效、对话语音
```

---

## 快速验证清单

- [ ] 78条语音文件已生成（voice/dialogue/ + voice/system/）
- [ ] 8首BGM已下载（bgm/）
- [ ] 22个SFX已下载（sfx/）
- [ ] 所有文件为.ogg格式
- [ ] 游戏中音频正常播放
- [ ] 音量平衡合理（语音 > SFX > BGM）
