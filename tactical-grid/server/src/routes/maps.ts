/**
 * 关卡路由
 */
import { Router } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { queryOne, execute, queryAll } from '../models/database';
import { authMiddleware, AuthRequest } from '../middleware/auth';
import { MapGenerator } from '../mapgen/generator';
import { GenerateParams } from '../mapgen/types';
import { success, error } from '../utils/response';

export const mapRoutes = Router();

// 获取战役关卡列表
mapRoutes.get('/campaign', (_req, res) => {
  const chapters = [
    {
      chapter: 1, name: '觉醒',
      missions: [
        { level_id: 'ch1_m1', name: '初次接触', size: 'small', difficulty: 1, completed: false, stars: 0, locked: false },
        { level_id: 'ch1_m2', name: '掩体战术', size: 'small', difficulty: 1, completed: false, stars: 0, locked: false },
        { level_id: 'ch1_m3', name: '高地优势', size: 'small', difficulty: 1, completed: false, stars: 0, locked: true },
        { level_id: 'ch1_m4', name: '交互点', size: 'small', difficulty: 1, completed: false, stars: 0, locked: true },
        { level_id: 'ch1_m5', name: '技能初探', size: 'small', difficulty: 2, completed: false, stars: 0, locked: true },
        { level_id: 'ch1_m6', name: '数据哨兵', size: 'medium', difficulty: 2, completed: false, stars: 0, locked: true, is_boss: true },
      ],
    },
    {
      chapter: 2, name: '深入',
      missions: [
        { level_id: 'ch2_m1', name: '雨夜突袭', size: 'medium', difficulty: 2, completed: false, stars: 0, locked: true },
        { level_id: 'ch2_m2', name: '烟雾迷宫', size: 'medium', difficulty: 2, completed: false, stars: 0, locked: true },
        { level_id: 'ch2_m3', name: '破墙而入', size: 'medium', difficulty: 2, completed: false, stars: 0, locked: true },
        { level_id: 'ch2_m4', name: '视野压制', size: 'medium', difficulty: 3, completed: false, stars: 0, locked: true },
        { level_id: 'ch2_m5', name: '双线作战', size: 'large', difficulty: 3, completed: false, stars: 0, locked: true },
        { level_id: 'ch2_m6', name: '情报获取', size: 'medium', difficulty: 3, completed: false, stars: 0, locked: true },
        { level_id: 'ch2_m7', name: '重装审判者', size: 'large', difficulty: 3, completed: false, stars: 0, locked: true, is_boss: true },
      ],
    },
    {
      chapter: 3, name: '背叛', missions: [
        { level_id: 'ch3_m1', name: '地下入口', size: 'medium', difficulty: 3, completed: false, stars: 0, locked: true },
        { level_id: 'ch3_m2', name: '毒雾管道', size: 'medium', difficulty: 3, completed: false, stars: 0, locked: true },
        { level_id: 'ch3_m3', name: '陷阱迷宫', size: 'medium', difficulty: 4, completed: false, stars: 0, locked: true },
        { level_id: 'ch3_m4', name: '电力设施', size: 'medium', difficulty: 4, completed: false, stars: 0, locked: true },
        { level_id: 'ch3_m5', name: '通讯枢纽', size: 'medium', difficulty: 4, completed: false, stars: 0, locked: true },
        { level_id: 'ch3_m6', name: '影子佣兵', size: 'large', difficulty: 4, completed: false, stars: 0, locked: true, is_boss: true },
      ],
    },
    {
      chapter: 4, name: '围城', missions: [
        { level_id: 'ch4_m1', name: '外围突破', size: 'large', difficulty: 4, completed: false, stars: 0, locked: true },
        { level_id: 'ch4_m2', name: '城墙攀登', size: 'medium', difficulty: 4, completed: false, stars: 0, locked: true },
        { level_id: 'ch4_m3', name: '军械库', size: 'medium', difficulty: 5, completed: false, stars: 0, locked: true },
        { level_id: 'ch4_m4', name: '指挥中心', size: 'large', difficulty: 5, completed: false, stars: 0, locked: true },
        { level_id: 'ch4_m5', name: '围城之夜', size: 'large', difficulty: 5, completed: false, stars: 0, locked: true },
        { level_id: 'ch4_m6', name: '矩阵将军', size: 'large', difficulty: 5, completed: false, stars: 0, locked: true, is_boss: true },
      ],
    },
    {
      chapter: 5, name: '终局', missions: [
        { level_id: 'ch5_m1', name: '核心外围', size: 'large', difficulty: 5, completed: false, stars: 0, locked: true },
        { level_id: 'ch5_m2', name: '数据洪流', size: 'large', difficulty: 5, completed: false, stars: 0, locked: true },
        { level_id: 'ch5_m3', name: '架构师之眼', size: 'large', difficulty: 5, completed: false, stars: 0, locked: true },
        { level_id: 'ch5_m4', name: '最后选择', size: 'large', difficulty: 5, completed: false, stars: 0, locked: true },
        { level_id: 'ch5_m5', name: '架构师', size: 'large', difficulty: 5, completed: false, stars: 0, locked: true, is_boss: true },
      ],
    },
  ];

  return success(res, { chapters });
});

// 获取关卡详情（生成地图）
mapRoutes.get('/:level_id', authMiddleware, (req: AuthRequest, res) => {
  const { level_id } = req.params;

  const match = level_id.match(/ch(\d+)_m(\d+)/);
  if (!match) {
    return error(res, 1004, 'Level not found', 404);
  }

  const chapter = parseInt(match[1]);
  const mission = parseInt(match[2]);

  const themeMap = ['warehouse', 'city_ruins', 'underground', 'mountain_fort', 'city_ruins'] as const;
  const missionTypes = ['extract', 'destroy', 'escort', 'defend', 'assassinate'] as const;

  const seed = chapter * 1000 + mission;
  const params: GenerateParams = {
    size: chapter <= 1 ? 'small' : chapter <= 3 ? 'medium' : 'large',
    seed,
    theme: themeMap[chapter - 1] || 'warehouse',
    mission_type: missionTypes[chapter - 1] || 'extract',
    difficulty: chapter,
  };

  const mapData = MapGenerator.generate(params);

  return success(res, {
    level_id,
    name: `第${chapter}章 第${mission}关`,
    size: params.size,
    theme: params.theme,
    mission_type: params.mission_type,
    difficulty: params.difficulty,
    map_data: mapData,
  });
});

// 随机生成关卡
mapRoutes.post('/generate', authMiddleware, (req: AuthRequest, res) => {
  const { size, seed, theme, mission_type, difficulty } = req.body;

  const params: GenerateParams = {
    size: size || 'small',
    seed: seed || Math.floor(Math.random() * 999999),
    theme: theme || 'warehouse',
    mission_type: mission_type || 'extract',
    difficulty: difficulty || 1,
  };

  const mapData = MapGenerator.generate(params);

  execute(
    'INSERT INTO maps (id, seed, size, theme, mission_type, map_data, validation) VALUES (?, ?, ?, ?, ?, ?, ?)',
    [mapData.map_id, params.seed, params.size, params.theme, params.mission_type, JSON.stringify(mapData), JSON.stringify(mapData.validation)]
  );

  return success(res, mapData);
});

// 上报关卡结果
mapRoutes.post('/:level_id/complete', authMiddleware, (req: AuthRequest, res) => {
  const { level_id } = req.params;
  const { result, turns, units_survived, zero_casualty, loot_collected, playtime_seconds, seed } = req.body;

  const resultId = uuidv4();

  let stars = 0;
  if (result === 'victory') stars = 1;
  if (result === 'victory' && zero_casualty) stars = 2;
  if (result === 'victory' && zero_casualty && turns <= 10) stars = 3;

  const existing = queryOne(
    'SELECT id FROM mission_results WHERE user_id = ? AND level_id = ? AND result = ?',
    [req.userId, level_id, 'victory']
  );
  const firstClear = existing ? 0 : 1;

  execute(
    `INSERT INTO mission_results (id, user_id, level_id, result, turns, playtime, units_survived, zero_casualty, stars, first_clear, seed)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [resultId, req.userId!, level_id, result, turns || 0, playtime_seconds || 0, units_survived || 0, zero_casualty ? 1 : 0, stars, firstClear, seed || 0]
  );

  const chapterMatch = level_id.match(/ch(\d+)/);
  const chapter = chapterMatch ? parseInt(chapterMatch[1]) : 1;
  const baseCredit = 200 + (chapter - 1) * 100;
  const baseExp = 150 + (chapter - 1) * 50;
  const bonusMultiplier = (zero_casualty ? 0.5 : 0) + (turns <= 10 ? 0.3 : 0) + (loot_collected?.length > 0 ? 0.2 : 0);

  const rewards = {
    credit: Math.floor(baseCredit * (1 + bonusMultiplier)),
    exp: Math.floor(baseExp * (1 + bonusMultiplier)),
    intel: firstClear ? 20 : 0,
    first_clear_bonus: firstClear ? { credit: 500, intel: 20 } : null,
  };

  return success(res, {
    result,
    stars,
    first_clear: !!firstClear,
    rewards,
  });
});

// 获取支线关卡
mapRoutes.get('/sidequests/list', authMiddleware, (_req: AuthRequest, res) => {
  const sidequests = [
    { id: 's1', name: '生存挑战 I', type: 'survival', difficulty: 3, locked: false },
    { id: 's2', name: '护送任务', type: 'escort', difficulty: 3, locked: true },
    { id: 's3', name: '限时撤离', type: 'timed', difficulty: 4, locked: true },
    { id: 's4', name: '狙击挑战', type: 'sniper', difficulty: 4, locked: true },
    { id: 's5', name: '潜行关', type: 'stealth', difficulty: 4, locked: true },
    { id: 's6', name: 'Boss挑战', type: 'boss', difficulty: 5, locked: true },
    { id: 's7', name: '无伤挑战', type: 'flawless', difficulty: 5, locked: true },
    { id: 's8', name: '生存挑战 II', type: 'survival', difficulty: 5, locked: true },
    { id: 's9', name: '速通挑战', type: 'speedrun', difficulty: 5, locked: true },
    { id: 's10', name: '终极挑战', type: 'ultimate', difficulty: 6, locked: true },
  ];
  return success(res, { sidequests });
});
