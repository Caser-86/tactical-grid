#!/usr/bin/env python3
"""Generate failed architect lines with different voice"""
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

OUTPUT_DIR = "client/assets/audio"

# Use zh-CN-YunxiNeural (male) instead for architect since XiaohanNeural fails
VOICE = "zh-CN-YunxiNeural"

LINES = [
    ("voice/dialogue/ch5_m5_intro_architect_1.ogg", "我观察你很久了。你的战术、你的决策、你的牺牲，都很有趣。", 0.9),
    ("voice/dialogue/ch5_m5_intro_architect_3.ogg", "结束？不，这是新的开始。你有两个选择：摧毁我，或者与我融合。", 0.85),
    ("voice/dialogue/ch5_m5_outro_a_architect_0.ogg", "不可能，我的计算没有预测到这个结果。", 1.1),
]

async def generate_audio(text, voice_id, speed, output_path):
    try:
        rate = f"+{int((speed-1)*100)}%" if speed >= 1 else f"{int((speed-1)*100)}%"
        communicate = edge_tts.Communicate(text, voice_id, rate=rate)
        await communicate.save(output_path)
        return True
    except Exception as e:
        print(f"  [ERROR] {e}")
        return False

def post_process(input_path, output_path):
    cmd = f'"{FFMPEG}" -y -i "{input_path}" -c:a libvorbis -q:a 6 "{output_path}"'
    subprocess.run(cmd, shell=True, capture_output=True)
    time.sleep(0.2)
    # Add reverb for architect
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
    for output_file, text, speed in LINES:
        output_path = os.path.join(OUTPUT_DIR, output_file)
        if os.path.exists(output_path):
            print(f"SKIP: {output_file}")
            continue
        print(f"Generating: {output_file}")
        print(f"  Text: {text}")
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        mp3_path = output_path.replace(".ogg", ".mp3")
        ok = await generate_audio(text, VOICE, speed, mp3_path)
        if ok:
            post_process(mp3_path, output_path)
            print(f"  OK!")
        else:
            print(f"  FAILED!")

if __name__ == "__main__":
    asyncio.run(main())
