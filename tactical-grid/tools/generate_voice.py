#!/usr/bin/env python3
"""
Edge-TTS 批量语音生成脚本（使用微软免费TTS）
使用方法：
  1. 安装依赖: pip install edge-tts
  2. 运行: python generate_voice.py
"""
import csv
import os
import asyncio
import edge_tts

# 获取ffmpeg路径
try:
    import imageio_ffmpeg
    FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
except:
    FFMPEG = "ffmpeg"

# ===== 配置 =====
OUTPUT_DIR = "client/assets/audio"
CSV_FILE = "tools/dialogues.csv"

# 角色→音色映射（Edge-TTS可用音色）
# 男声: zh-CN-YunxiNeural(年轻), zh-CN-YunjianNeural(成熟), zh-CN-YunyangNeural(新闻)
# 女声: zh-CN-XiaoxiaoNeural(温柔), zh-CN-XiaoyiNeural(活泼), zh-CN-XiaohanNeural(情感)
VOICE_MAP = {
    "alpha_male":        "zh-CN-YunxiNeural",      # 年轻男声
    "commander_male":    "zh-CN-YunjianNeural",     # 成熟男声
    "lila_female":       "zh-CN-XiaoxiaoNeural",    # 温柔女声
    "doctor_male":       "zh-CN-YunyangNeural",     # 新闻男声
    "sentinel_neutral":  "zh-CN-YunxiNeural",       # 机械感（用年轻男声）
    "shadow_male":       "zh-CN-YunjianNeural",     # 冷酷男声
    "architect_neutral": "zh-CN-XiaohanNeural",     # 情感女声
    "system_female":     "zh-CN-XiaoyiNeural",      # 活泼女声
}


async def generate_audio(text: str, voice_id: str, speed: float, output_path: str) -> bool:
    """调用Edge-TTS生成单条音频"""
    try:
        # 语速调整: +20% 表示加快20%, -20% 表示减慢20%
        rate = f"+{int((speed-1)*100)}%" if speed >= 1 else f"{int((speed-1)*100)}%"
        
        communicate = edge_tts.Communicate(text, voice_id, rate=rate)
        await communicate.save(output_path)
        return True

    except Exception as e:
        print(f"  [ERROR] {e}")
        return False


def post_process(input_path: str, output_path: str, voice_id: str):
    """后处理：转OGG、调整响度、添加效果"""
    import time
    import subprocess
    
    # Edge-TTS直接输出mp3，转为ogg
    cmd = f'"{FFMPEG}" -y -i "{input_path}" -c:a libvorbis -q:a 6 "{output_path}"'
    subprocess.run(cmd, shell=True, capture_output=True)
    time.sleep(0.2)

    # 哨兵/架构师添加混响效果
    if "sentinel" in voice_id or "architect" in voice_id:
        temp_path = output_path + ".tmp.ogg"
        cmd = f'"{FFMPEG}" -y -i "{output_path}" -af "aecho=0.8:0.88:60:0.4" "{temp_path}"'
        subprocess.run(cmd, shell=True, capture_output=True)
        time.sleep(0.2)
        if os.path.exists(temp_path):
            os.replace(temp_path, output_path)

    # 删除临时mp3
    time.sleep(0.2)
    try:
        if os.path.exists(input_path):
            os.remove(input_path)
    except:
        pass


async def main():
    if not os.path.exists(CSV_FILE):
        print(f"CSV文件不存在: {CSV_FILE}")
        print("请先运行: node tools/extract_dialogues.js > tools/dialogues.csv")
        return

    # 读取CSV
    with open(CSV_FILE, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        lines = list(reader)

    print(f"共 {len(lines)} 条语音待生成")

    success = 0
    failed = 0

    for i, line in enumerate(lines):
        voice_key = line["voice_id"]
        voice = VOICE_MAP.get(voice_key, "zh-CN-XiaoxiaoNeural")
        speed = float(line["speed"]) if line["speed"] else 1.0
        
        # 获取输出文件路径
        output_file = line.get("output_file", "")
        if not output_file or output_file == "outputFile":
            # 跳过无效行
            print(f"[{i+1}/{len(lines)}] SKIP (no output_file)")
            continue
            
        output_path = os.path.join(OUTPUT_DIR, output_file)

        # 跳过已存在的文件
        if os.path.exists(output_path):
            print(f"[{i+1}/{len(lines)}] SKIP (exists): {output_file}")
            success += 1
            continue

        print(f"[{i+1}/{len(lines)}] Generating: {output_file}")

        # 确保目录存在
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        mp3_path = output_path.replace(".ogg", ".mp3")
        ok = await generate_audio(line["text"], voice, speed, mp3_path)

        if ok:
            post_process(mp3_path, output_path, voice_key)
            success += 1
        else:
            failed += 1

    print(f"\n完成: {success} 成功, {failed} 失败")


if __name__ == "__main__":
    asyncio.run(main())
