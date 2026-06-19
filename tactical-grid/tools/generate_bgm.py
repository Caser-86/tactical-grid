#!/usr/bin/env python3
"""
生成游戏BGM（使用合成方式生成循环音乐）
"""
import os
import numpy as np
from pydub import AudioSegment
from pydub.generators import Sine, Square, Sawtooth, WhiteNoise

# 设置ffmpeg路径
try:
    import imageio_ffmpeg
    AudioSegment.converter = imageio_ffmpeg.get_ffmpeg_exe()
except:
    pass

OUTPUT_DIR = "client/assets/audio/bgm"

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)

def save_ogg(audio, filename):
    path = os.path.join(OUTPUT_DIR, filename)
    audio.export(path, format="ogg", codec="libvorbis")
    print(f"  Created: {filename}")

def create_melody_segment(notes, tempo=120):
    """根据音符列表创建旋律"""
    beat_duration = 60000 // tempo
    result = AudioSegment.silent(duration=0)
    
    for note, duration in notes:
        if note == 0:
            # 休止符
            result += AudioSegment.silent(duration=beat_duration * duration)
        else:
            # 音符
            tone = Sine(note).to_audio_segment(duration=beat_duration * duration)
            tone = tone.fade_out(min(50, beat_duration * duration - 10))
            result += tone
    
    return result

def create_loop(base, target_length):
    """循环音频到目标长度"""
    loops = target_length // len(base) + 1
    result = base * loops
    return result[:target_length]

# 主菜单BGM - 神秘电子氛围
def create_bgm_menu():
    notes = [
        (220, 2), (0, 1), (262, 2), (0, 1),
        (330, 2), (0, 1), (262, 2), (0, 1),
        (220, 2), (0, 1), (196, 2), (0, 1),
        (220, 4), (0, 2),
    ]
    melody = create_melody_segment(notes, tempo=80)
    # 添加低音
    bass = Sine(110).to_audio_segment(duration=len(melody)).fade_out(500) - 15
    result = melody.overlay(bass)
    return create_loop(result, 60000) - 8  # 60秒

# 小型战斗BGM - 紧张电子
def create_bgm_battle_small():
    notes = [
        (330, 1), (330, 1), (0, 1), (330, 1),
        (440, 1), (0, 1), (392, 1), (0, 1),
        (330, 1), (330, 1), (0, 1), (330, 1),
        (494, 1), (440, 1), (392, 2),
    ]
    melody = create_melody_segment(notes, tempo=130)
    bass = Sine(165).to_audio_segment(duration=len(melody)).fade_out(300) - 12
    result = melody.overlay(bass)
    return create_loop(result, 60000) - 6

# 中型战斗BGM - 激烈电子摇滚
def create_bgm_battle_medium():
    notes = [
        (440, 1), (0, 1), (440, 1), (523, 1),
        (0, 1), (494, 1), (440, 1), (0, 1),
        (392, 1), (0, 1), (392, 1), (440, 1),
        (0, 1), (494, 1), (440, 2),
    ]
    melody = create_melody_segment(notes, tempo=140)
    bass = Sine(220).to_audio_segment(duration=len(melody)).fade_out(200) - 10
    result = melody.overlay(bass)
    return create_loop(result, 60000) - 5

# 大型战斗BGM - 史诗管弦电子
def create_bgm_battle_large():
    notes = [
        (523, 1), (523, 1), (659, 1), (523, 1),
        (0, 1), (494, 1), (440, 1), (392, 1),
        (523, 1), (523, 1), (659, 1), (784, 1),
        (659, 1), (523, 2), (0, 1),
    ]
    melody = create_melody_segment(notes, tempo=145)
    bass = Sine(262).to_audio_segment(duration=len(melody)).fade_out(200) - 8
    result = melody.overlay(bass)
    return create_loop(result, 90000) - 5

# Boss战BGM - 黑暗工业电子
def create_bgm_boss():
    notes = [
        (196, 1), (196, 1), (233, 1), (196, 1),
        (175, 1), (196, 2), (0, 1),
        (165, 1), (165, 1), (196, 1), (165, 1),
        (147, 1), (165, 2), (0, 1),
    ]
    melody = create_melody_segment(notes, tempo=150)
    bass = Sine(98).to_audio_segment(duration=len(melody)).fade_out(200) - 8
    result = melody.overlay(bass)
    return create_loop(result, 120000) - 5

# 基地BGM - 平静Lo-fi
def create_bgm_base():
    notes = [
        (330, 2), (0, 1), (392, 2), (0, 1),
        (440, 2), (0, 1), (392, 2), (0, 2),
        (330, 2), (0, 1), (294, 2), (0, 1),
        (330, 4), (0, 2),
    ]
    melody = create_melody_segment(notes, tempo=75)
    bass = Sine(165).to_audio_segment(duration=len(melody)).fade_out(800) - 15
    result = melody.overlay(bass)
    return create_loop(result, 60000) - 10

# 胜利BGM - 胜利号角
def create_bgm_victory():
    notes = [
        (523, 1), (659, 1), (784, 1), (1047, 2),
        (0, 1), (784, 1), (1047, 3),
    ]
    melody = create_melody_segment(notes, tempo=120)
    return melody - 6

# 失败BGM - 忧伤
def create_bgm_defeat():
    notes = [
        (330, 2), (294, 2), (262, 2), (220, 4),
    ]
    melody = create_melody_segment(notes, tempo=80)
    return melody - 8

def main():
    ensure_dir(OUTPUT_DIR)
    
    print("生成BGM背景音乐...")
    
    save_ogg(create_bgm_menu(), "bgm_menu.ogg")
    save_ogg(create_bgm_battle_small(), "bgm_battle_small.ogg")
    save_ogg(create_bgm_battle_medium(), "bgm_battle_medium.ogg")
    save_ogg(create_bgm_battle_large(), "bgm_battle_large.ogg")
    save_ogg(create_bgm_boss(), "bgm_boss.ogg")
    save_ogg(create_bgm_base(), "bgm_base.ogg")
    save_ogg(create_bgm_victory(), "bgm_victory.ogg")
    save_ogg(create_bgm_defeat(), "bgm_defeat.ogg")
    
    print(f"\n完成！共生成 {len(os.listdir(OUTPUT_DIR))} 个BGM文件")

if __name__ == "__main__":
    main()
