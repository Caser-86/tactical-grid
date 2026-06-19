#!/usr/bin/env python3
"""Generate missing voice files"""
import csv
import os
import asyncio
import edge_tts
import subprocess
import time

try:
    import imageio_ffmpeg
    FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
except:
    FFMPEG = "ffmpeg"

VOICE_MAP = {
    "alpha_male":        "zh-CN-YunxiNeural",
    "commander_male":    "zh-CN-YunjianNeural",
    "lila_female":       "zh-CN-XiaoxiaoNeural",
    "doctor_male":       "zh-CN-YunyangNeural",
    "sentinel_neutral":  "zh-CN-YunxiNeural",
    "shadow_male":       "zh-CN-YunjianNeural",
    "architect_neutral": "zh-CN-XiaohanNeural",
    "system_female":     "zh-CN-XiaoyiNeural",
}

OUTPUT_DIR = "client/assets/audio"
CSV_FILE = "tools/dialogues.csv"

async def generate_audio(text, voice_id, speed, output_path):
    try:
        rate = f"+{int((speed-1)*100)}%" if speed >= 1 else f"{int((speed-1)*100)}%"
        communicate = edge_tts.Communicate(text, voice_id, rate=rate)
        await communicate.save(output_path)
        return True
    except Exception as e:
        print(f"  [ERROR] {e}")
        return False

def post_process(input_path, output_path, voice_id):
    cmd = f'"{FFMPEG}" -y -i "{input_path}" -c:a libvorbis -q:a 6 "{output_path}"'
    subprocess.run(cmd, shell=True, capture_output=True)
    time.sleep(0.2)
    if "sentinel" in voice_id or "architect" in voice_id:
        temp_path = output_path + ".tmp.ogg"
        cmd = f'"{FFMPEG}" -y -i "{output_path}" -af "aecho=0.8:0.88:60:0.4" "{temp_path}"'
        subprocess.run(cmd, shell=True, capture_output=True)
        time.sleep(0.2)
        if os.path.exists(temp_path):
            os.replace(temp_path, output_path)
    time.sleep(0.2)
    try:
        if os.path.exists(input_path):
            os.remove(input_path)
    except:
        pass

async def main():
    with open(CSV_FILE, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        lines = list(reader)
    
    # Find lines that need generation (output_file is valid and file doesn't exist)
    to_generate = []
    for line in lines:
        output_file = line.get("output_file", "")
        if not output_file or output_file == "outputFile":
            continue
        output_path = os.path.join(OUTPUT_DIR, output_file)
        if not os.path.exists(output_path):
            to_generate.append(line)
    
    print(f"Need to generate {len(to_generate)} files")
    
    for line in to_generate:
        voice_key = line["voice_id"]
        voice = VOICE_MAP.get(voice_key, "zh-CN-XiaoxiaoNeural")
        speed = float(line["speed"]) if line["speed"] else 1.0
        text = line["text"]
        output_file = line["output_file"]
        output_path = os.path.join(OUTPUT_DIR, output_file)
        
        print(f"Generating: {output_file}")
        print(f"  Text: {text}")
        print(f"  Voice: {voice}, Speed: {speed}")
        
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        mp3_path = output_path.replace(".ogg", ".mp3")
        ok = await generate_audio(text, voice, speed, mp3_path)
        if ok:
            post_process(mp3_path, output_path, voice_key)
            print(f"  OK!")
        else:
            print(f"  FAILED!")
    
    # Also generate system voices if missing
    system_dir = os.path.join(OUTPUT_DIR, "voice/system")
    os.makedirs(system_dir, exist_ok=True)
    
    system_events = {
        'turn_start_player': '玩家回合开始。',
        'turn_start_enemy': '敌人回合开始。',
        'reinforcement_1': '敌方增援到达！',
        'reinforcement_2': '精英增援到达！',
        'evac_activate': '撤离点已激活！三回合内撤离！',
        'victory': '任务完成。',
        'defeat': '任务失败。',
        'unit_down': '单位阵亡。',
        'critical_hit': '暴击命中！',
        'dodge': '闪避成功！',
        'mark': '目标已被标记。',
        'suppress': '目标被压制。',
        'armor_pierce': '护甲穿透！',
        'cover_destroy': '掩体被破坏。',
        'heal': '治疗完成。',
        'revive': '复活成功。',
        'overwatch_trigger': '警戒射击触发！',
        'level_up': '等级提升！',
        'first_clear': '首次通关奖励！',
        'timeout': '回合超时。',
        'stealth': '进入潜行状态。',
        'trap_placed': '陷阱已布置。',
    }
    
    for event, text in system_events.items():
        output_path = os.path.join(system_dir, f"{event}.ogg")
        if os.path.exists(output_path):
            continue
        print(f"Generating system: {event}.ogg")
        mp3_path = output_path.replace(".ogg", ".mp3")
        ok = await generate_audio(text, "zh-CN-XiaoyiNeural", 1.0, mp3_path)
        if ok:
            post_process(mp3_path, output_path, "system_female")
            print(f"  OK!")

if __name__ == "__main__":
    asyncio.run(main())
