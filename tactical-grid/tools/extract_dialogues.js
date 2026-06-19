/**
 * 对话台词提取工具
 * 从 dialogues.json 提取所有台词，输出为 TTS 可用的 CSV
 * 用法: node extract_dialogues.js > dialogues.csv
 */
const fs = require('fs');
const path = require('path');

const data = JSON.parse(fs.readFileSync(path.join(__dirname, '../client/data/dialogues.json'), 'utf8'));

// 角色声线配置
const voiceConfig = {
  alpha:      { voice_id: 'alpha_male',      gender: 'M', age: '25-30' },
  commander:  { voice_id: 'commander_male',  gender: 'M', age: '30-35' },
  lila:       { voice_id: 'lila_female',     gender: 'F', age: '22-25' },
  doctor:     { voice_id: 'doctor_male',     gender: 'M', age: '45-50' },
  sentinel:   { voice_id: 'sentinel_neutral', gender: 'N', age: 'N/A' },
  shadow:     { voice_id: 'shadow_male',     gender: 'M', age: '28-32' },
  architect:  { voice_id: 'architect_neutral', gender: 'N', age: 'N/A' },
  system:     { voice_id: 'system_female',   gender: 'F', age: 'N/A' },
};

// 情感→TTS参数映射
const emotionParams = {
  serious:     { speed: 0.9, pitch: -2, emphasis: 0.8 },
  neutral:     { speed: 1.0, pitch: 0,  emphasis: 0.5 },
  happy:       { speed: 1.1, pitch: 2,  emphasis: 0.7 },
  surprised:   { speed: 1.0, pitch: 4,  emphasis: 0.9 },
  angry:       { speed: 1.0, pitch: -3, emphasis: 1.0 },
  cold:        { speed: 0.85, pitch: -4, emphasis: 0.3 },
  confident:   { speed: 0.95, pitch: 1,  emphasis: 0.8 },
  determined:  { speed: 0.9, pitch: -1, emphasis: 0.9 },
  calm:        { speed: 0.85, pitch: 0,  emphasis: 0.3 },
  intrigued:   { speed: 0.9, pitch: 1,  emphasis: 0.6 },
  urgent:      { speed: 1.2, pitch: 2,  emphasis: 1.0 },
  conflicted:  { speed: 0.9, pitch: 0,  emphasis: 0.4 },
  challenging: { speed: 0.85, pitch: -1, emphasis: 0.7 },
  shocked:     { speed: 1.1, pitch: 4,  emphasis: 0.9 },
  triumphant:  { speed: 1.0, pitch: 3,  emphasis: 0.8 },
  relieved:    { speed: 0.9, pitch: 1,  emphasis: 0.4 },
  hopeful:     { speed: 0.95, pitch: 2,  emphasis: 0.6 },
  tired:       { speed: 0.8, pitch: -1, emphasis: 0.3 },
  caring:      { speed: 0.85, pitch: 1,  emphasis: 0.5 },
  nostalgic:   { speed: 0.85, pitch: 0,  emphasis: 0.4 },
  amused:      { speed: 1.0, pitch: 2,  emphasis: 0.6 },
  warm:        { speed: 0.9, pitch: 1,  emphasis: 0.5 },
  embarrassed: { speed: 1.0, pitch: 1,  emphasis: 0.4 },
};

// 输出CSV头
console.log('id,speaker,voice_id,emotion,text,speed,pitch,emphasis,output_file');

let index = 0;

// 遍历所有对话
for (const [dialogueId, dialogue] of Object.entries(data.dialogues)) {
  // 处理台词
  for (let i = 0; i < dialogue.lines.length; i++) {
    const line = dialogue.lines[i];
    const speaker = line.speaker;
    const voice = voiceConfig[speaker] || voiceConfig.system;
    const emotion = emotionParams[line.emotion] || emotionParams.neutral;

    const outputFile = `voice/dialogue/${dialogueId}_${speaker}_${i}.ogg`;
    const escapedText = `"${line.text.replace(/"/g, '""')}"`;

    console.log(`${index},${speaker},${voice.voice_id},${line.emotion},${escapedText},${emotion.speed},${emotion.pitch},${emotion.emphasis},${outputFile}`);
    index++;
  }

  // 处理选项回复
  if (dialogue.choices) {
    for (const choice of dialogue.choices) {
      if (choice.response) {
        const line = choice.response;
        const speaker = line.speaker;
        const voice = voiceConfig[speaker] || voiceConfig.system;
        const emotion = emotionParams[line.emotion] || emotionParams.neutral;

        const outputFile = `voice/dialogue/${dialogueId}_choice_${speaker}.ogg`;
        const escapedText = `"${line.text.replace(/"/g, '""')}"`;

        console.log(`${index},${speaker},${voice.voice_id},${line.emotion},${escapedText},${emotion.speed},${emotion.pitch},${emotion.emphasis},${outputFile}`);
        index++;
      }
    }
  }
}

// 战斗播报
const systemLines = [
  { event: 'turn_start_player',   text: '玩家回合开始。' },
  { event: 'turn_start_enemy',    text: '敌人回合开始。' },
  { event: 'reinforcement_1',     text: '敌方增援到达！' },
  { event: 'reinforcement_2',     text: '精英增援到达！' },
  { event: 'evac_activate',       text: '撤离点已激活！三回合内撤离！' },
  { event: 'victory',             text: '任务完成。' },
  { event: 'defeat',              text: '任务失败。' },
  { event: 'unit_down',           text: '单位阵亡。' },
  { event: 'critical_hit',        text: '暴击命中！' },
  { event: 'dodge',               text: '闪避成功！' },
  { event: 'mark',                text: '目标已被标记。' },
  { event: 'suppress',            text: '目标被压制。' },
  { event: 'armor_pierce',        text: '护甲穿透！' },
  { event: 'cover_destroy',       text: '掩体被破坏。' },
  { event: 'heal',                text: '治疗完成。' },
  { event: 'revive',              text: '复活成功。' },
  { event: 'overwatch_trigger',   text: '警戒射击触发！' },
  { event: 'level_up',            text: '等级提升！' },
  { event: 'first_clear',         text: '首次通关奖励！' },
  { event: 'timeout',             text: '回合超时。' },
  { event: 'stealth',             text: '进入潜行状态。' },
  { event: 'trap_placed',         text: '陷阱已布置。' },
];

for (const line of systemLines) {
  const outputFile = `voice/system/${line.event}.ogg`;
  const escapedText = `"${line.text.replace(/"/g, '""')}"`;
  console.log(`${index},system,system_female,neutral,${escapedText},1.0,0,0.5,${outputFile}`);
  index++;
}

process.stderr.write(`Total: ${index} voice lines extracted\n`);
