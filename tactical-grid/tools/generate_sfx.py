#!/usr/bin/env python3
"""
生成游戏SFX音效（使用合成方式）
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

OUTPUT_DIR = "client/assets/audio/sfx"

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)

def save_ogg(audio, filename):
    path = os.path.join(OUTPUT_DIR, filename)
    audio.export(path, format="ogg", codec="libvorbis")
    print(f"  Created: {filename}")

# UI音效
def create_ui_click():
    tone = Sine(800).to_audio_segment(duration=50).fade_out(30)
    return tone - 10

def create_ui_hover():
    tone = Sine(600).to_audio_segment(duration=30).fade_out(20)
    return tone - 15

# 战斗音效
def create_gunshot():
    noise = WhiteNoise().to_audio_segment(duration=50)
    pop = Sine(200).to_audio_segment(duration=30).fade_out(20)
    return (noise.overlay(pop) - 5).fade_out(30)

def create_explosion():
    noise = WhiteNoise().to_audio_segment(duration=300).fade_out(200)
    bass = Sine(60).to_audio_segment(duration=400).fade_out(300)
    return (noise.overlay(bass) - 3).fade_out(100)

def create_hit():
    tone = Sine(150).to_audio_segment(duration=40).fade_out(30)
    return tone - 8

def create_critical_hit():
    tone1 = Sine(200).to_audio_segment(duration=30)
    tone2 = Sine(400).to_audio_segment(duration=30)
    return (tone1.overlay(tone2) - 5).fade_out(20)

def create_unit_down():
    tone = Sine(300).to_audio_segment(duration=200)
    tone = tone.fade_out(150)
    return tone - 10

# 技能音效
def create_skill_cast():
    tone = Sine(500).to_audio_segment(duration=100)
    tone2 = Sine(700).to_audio_segment(duration=100).fade_in(50)
    return (tone.overlay(tone2) - 8).fade_out(50)

def create_heal():
    tones = []
    for freq in [400, 500, 600, 700]:
        t = Sine(freq).to_audio_segment(duration=80)
        tones.append(t)
    result = tones[0]
    for t in tones[1:]:
        result = result.append(t, crossfade=30)
    return result - 10

# 环境音效
def create_cover_destroy():
    noise = WhiteNoise().to_audio_segment(duration=200).fade_out(150)
    crack = Sine(100).to_audio_segment(duration=100).fade_out(80)
    return (noise.overlay(crack) - 8).fade_out(50)

def create_level_up():
    tones = []
    for freq in [400, 500, 600, 800]:
        t = Sine(freq).to_audio_segment(duration=100)
        tones.append(t)
    result = tones[0]
    for t in tones[1:]:
        result = result.append(t, crossfade=50)
    return result - 8

# 回合音效
def create_turn_start():
    tone = Sine(600).to_audio_segment(duration=150).fade_out(100)
    return tone - 10

def create_turn_enemy():
    tone = Sine(300).to_audio_segment(duration=200).fade_out(150)
    return tone - 10

def create_mission_victory():
    tones = []
    for freq in [400, 500, 600, 800, 1000]:
        t = Sine(freq).to_audio_segment(duration=150)
        tones.append(t)
    result = tones[0]
    for t in tones[1:]:
        result = result.append(t, crossfade=80)
    return result - 8

def create_mission_defeat():
    tones = []
    for freq in [400, 300, 200, 150]:
        t = Sine(freq).to_audio_segment(duration=200)
        tones.append(t)
    result = tones[0]
    for t in tones[1:]:
        result = result.append(t, crossfade=100)
    return result - 8

def main():
    ensure_dir(OUTPUT_DIR)
    
    print("生成SFX音效...")
    
    # UI音效
    save_ogg(create_ui_click(), "sfx_ui_click.ogg")
    save_ogg(create_ui_hover(), "sfx_ui_hover.ogg")
    
    # 选择音效
    save_ogg(create_ui_click(), "sfx_select_unit.ogg")
    save_ogg(create_hit(), "sfx_unit_land.ogg")
    
    # 战斗音效
    save_ogg(create_gunshot(), "sfx_combat_pistol.ogg")
    save_ogg(create_gunshot(), "sfx_combat_shotgun.ogg")
    save_ogg(create_gunshot(), "sfx_combat_sniper.ogg")
    save_ogg(create_gunshot(), "sfx_combat_rifle.ogg")
    
    # 命中音效
    save_ogg(create_hit(), "sfx_hit_flesh.ogg")
    save_ogg(create_critical_hit(), "sfx_critical_hit.ogg")
    save_ogg(create_unit_down(), "sfx_unit_down.ogg")
    
    # 爆炸和破坏
    save_ogg(create_explosion(), "sfx_explosion.ogg")
    save_ogg(create_cover_destroy(), "sfx_cover_destroy.ogg")
    
    # 技能音效
    save_ogg(create_skill_cast(), "sfx_skill_cast.ogg")
    save_ogg(create_heal(), "sfx_heal_effect.ogg")
    save_ogg(create_skill_cast(), "sfx_overwatch_trigger.ogg")
    
    # 回合音效
    save_ogg(create_turn_start(), "sfx_turn_player_start.ogg")
    save_ogg(create_turn_enemy(), "sfx_turn_enemy_start.ogg")
    
    # 任务音效
    save_ogg(create_mission_victory(), "sfx_mission_victory.ogg")
    save_ogg(create_mission_defeat(), "sfx_mission_defeat.ogg")
    save_ogg(create_level_up(), "sfx_level_up.ogg")
    save_ogg(create_ui_click(), "sfx_item_pickup.ogg")
    
    print(f"\n完成！共生成 {len(os.listdir(OUTPUT_DIR))} 个SFX文件")

if __name__ == "__main__":
    main()
