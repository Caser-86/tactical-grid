#!/usr/bin/env python3
"""
对话台词提取工具（Python版本）
从 dialogues.json 提取所有台词，输出为 TTS 可用的 CSV
"""
import json
import csv
import sys

# 读取JSON文件
with open('client/data/dialogues.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# 角色声线配置
voice_config = {
    'alpha':      {'voice_id': 'alpha_male',      'gender': 'M', 'age': '25-30'},
    'commander':  {'voice_id': 'commander_male',  'gender': 'M', 'age': '30-35'},
    'lila':       {'voice_id': 'lila_female',     'gender': 'F', 'age': '22-25'},
    'doctor':     {'voice_id': 'doctor_male',     'gender': 'M', 'age': '45-50'},
    'sentinel':   {'voice_id': 'sentinel_neutral', 'gender': 'N', 'age': 'N/A'},
    'shadow':     {'voice_id': 'shadow_male',     'gender': 'M', 'age': '28-32'},
    'architect':  {'voice_id': 'architect_neutral', 'gender': 'N', 'age': 'N/A'},
    'system':     {'voice_id': 'system_female',   'gender': 'F', 'age': 'N/A'},
}

# 情感→TTS参数映射
emotion_params = {
    'serious':     {'speed': 0.9, 'pitch': -2, 'emphasis': 0.8},
    'neutral':     {'speed': 1.0, 'pitch': 0,  'emphasis': 0.5},
    'happy':       {'speed': 1.1, 'pitch': 2,  'emphasis': 0.7},
    'surprised':   {'speed': 1.0, 'pitch': 4,  'emphasis': 0.9},
    'angry':       {'speed': 1.0, 'pitch': -3, 'emphasis': 1.0},
    'cold':        {'speed': 0.85, 'pitch': -4, 'emphasis': 0.3},
    'confident':   {'speed': 0.95, 'pitch': 1,  'emphasis': 0.8},
    'determined':  {'speed': 0.9, 'pitch': -1, 'emphasis': 0.9},
    'calm':        {'speed': 0.85, 'pitch': 0,  'emphasis': 0.3},
    'intrigued':   {'speed': 0.9, 'pitch': 1,  'emphasis': 0.6},
    'urgent':      {'speed': 1.2, 'pitch': 2,  'emphasis': 1.0},
    'conflicted':  {'speed': 0.9, 'pitch': 0,  'emphasis': 0.4},
    'challenging': {'speed': 0.85, 'pitch': -1, 'emphasis': 0.7},
    'shocked':     {'speed': 1.1, 'pitch': 4,  'emphasis': 0.9},
    'triumphant':  {'speed': 1.0, 'pitch': 3,  'emphasis': 0.8},
    'relieved':    {'speed': 0.9, 'pitch': 1,  'emphasis': 0.4},
    'hopeful':     {'speed': 0.95, 'pitch': 2,  'emphasis': 0.6},
    'tired':       {'speed': 0.8, 'pitch': -1, 'emphasis': 0.3},
    'caring':      {'speed': 0.85, 'pitch': 1,  'emphasis': 0.5},
    'nostalgic':   {'speed': 0.85, 'pitch': 0,  'emphasis': 0.4},
    'amused':      {'speed': 1.0, 'pitch': 2,  'emphasis': 0.6},
    'warm':        {'speed': 0.9, 'pitch': 1,  'emphasis': 0.5},
    'embarrassed': {'speed': 1.0, 'pitch': 1,  'emphasis': 0.4},
}

# 输出CSV - 写文件
with open('tools/dialogues.csv', 'w', encoding='utf-8', newline='') as csvfile:
    writer = csv.writer(csvfile)
    writer.writerow(['id', 'speaker', 'voice_id', 'emotion', 'text', 'speed', 'pitch', 'emphasis', 'output_file'])

    index = 0

    # 遍历所有对话
    for dialogue_id, dialogue in data['dialogues'].items():
        # 处理台词
        for i, line in enumerate(dialogue.get('lines', [])):
            speaker = line['speaker']
            voice = voice_config.get(speaker, voice_config['system'])
            emotion = emotion_params.get(line.get('emotion', 'neutral'), emotion_params['neutral'])
            
            output_file = f"voice/dialogue/{dialogue_id}_{speaker}_{i}.ogg"
            
            writer.writerow([
                index,
                speaker,
                voice['voice_id'],
                line.get('emotion', 'neutral'),
                line['text'],
                emotion['speed'],
                emotion['pitch'],
                emotion['emphasis'],
                output_file
            ])
            index += 1
        
    # 处理选项回复
    if 'choices' in dialogue:
        for ci, choice in enumerate(dialogue['choices']):
            if 'response' in choice:
                line = choice['response']
                speaker = line['speaker']
                voice = voice_config.get(speaker, voice_config['system'])
                emotion = emotion_params.get(line.get('emotion', 'neutral'), emotion_params['neutral'])
                
                output_file = f"voice/dialogue/{dialogue_id}_choice_{ci}_{speaker}.ogg"
                
                writer.writerow([
                    index,
                    speaker,
                    voice['voice_id'],
                    line.get('emotion', 'neutral'),
                    line['text'],
                    emotion['speed'],
                    emotion['pitch'],
                    emotion['emphasis'],
                    output_file
                ])
                index += 1

    # 战斗播报
    system_lines = [
        ('turn_start_player', '玩家回合开始。'),
        ('turn_start_enemy', '敌人回合开始。'),
        ('reinforcement_1', '敌方增援到达！'),
        ('reinforcement_2', '精英增援到达！'),
        ('evac_activate', '撤离点已激活！三回合内撤离！'),
        ('victory', '任务完成。'),
        ('defeat', '任务失败。'),
        ('unit_down', '单位阵亡。'),
        ('critical_hit', '暴击命中！'),
        ('dodge', '闪避成功！'),
        ('mark', '目标已被标记。'),
        ('suppress', '目标被压制。'),
        ('armor_pierce', '护甲穿透！'),
        ('cover_destroy', '掩体被破坏。'),
        ('heal', '治疗完成。'),
        ('revive', '复活成功。'),
        ('overwatch_trigger', '警戒射击触发！'),
        ('level_up', '等级提升！'),
        ('first_clear', '首次通关奖励！'),
        ('timeout', '回合超时。'),
        ('stealth', '进入潜行状态。'),
        ('trap_placed', '陷阱已布置。'),
    ]

    for event, text in system_lines:
        output_file = f"voice/system/{event}.ogg"
        writer.writerow([
            index,
            'system',
            'system_female',
            'neutral',
            text,
            1.0,
            0,
            0.5,
            output_file
        ])
        index += 1

print(f"Total: {index} voice lines extracted", file=sys.stderr)
