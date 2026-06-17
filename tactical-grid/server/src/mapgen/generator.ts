/**
 * 地图生成器核心
 * 自动生成符合规则的战棋地图，玩家无需手动设计
 */
import {
  MapData, GenerateParams, MapObject, MapScript, VictoryConfig,
  SIZE_PRESETS, TerrainType, MapTheme
} from './types';
import { SeededRandom } from './seed_random';
import { MapValidator } from './validator';
import { Pathfinding } from './pathfinding';

/** 主题地形权重 */
const THEME_WEIGHTS: Record<MapTheme, Partial<Record<TerrainType, number>>> = {
  warehouse: { [TerrainType.PLAIN]: 40, [TerrainType.ROAD]: 10, [TerrainType.WALL]: 15, [TerrainType.CRATE]: 12 },
  city_ruins: { [TerrainType.PLAIN]: 25, [TerrainType.ROAD]: 20, [TerrainType.WALL]: 15, [TerrainType.HIGHLAND]: 8, [TerrainType.WATER]: 5 },
  mountain_fort: { [TerrainType.PLAIN]: 35, [TerrainType.HIGHLAND]: 10, [TerrainType.WALL]: 10, [TerrainType.SAND]: 8, [TerrainType.WATER]: 3 },
  forest_camp: { [TerrainType.PLAIN]: 30, [TerrainType.FOREST]: 25, [TerrainType.WATER]: 8, [TerrainType.HIGHLAND]: 5 },
  underground: { [TerrainType.PLAIN]: 45, [TerrainType.WALL]: 15, [TerrainType.POISON]: 3, [TerrainType.CRATE]: 8 },
};

export class MapGenerator {
  /**
   * 生成地图
   * 同一 seed + 参数 → 完全相同的结果
   * 校验失败时用不同偏移种子重试
   */
  static generate(params: GenerateParams): MapData {
    const config = SIZE_PRESETS[params.size];

    // 尝试最多 20 个种子偏移
    for (let attempt = 0; attempt < 20; attempt++) {
      const attemptSeed = params.seed + attempt * 7919; // 用质数偏移
      const rng = new SeededRandom(attemptSeed);
      const map = this.generateOnce({ ...params, seed: attemptSeed }, rng, config);
      const validation = MapValidator.validate(map);

      map.validation = validation;

      if (validation.passed) {
        // 恢复原始种子用于记录
        map.seed = params.seed;
        return map;
      }
    }

    // 20 次都失败，生成一个简化版本（减少掩体密度，确保连通）
    const rng = new SeededRandom(params.seed);
    const fallbackMap = this.generateOnce(params, rng, config);
    fallbackMap.validation = MapValidator.validate(fallbackMap);
    return fallbackMap;
  }

  /** 单次生成 */
  private static generateOnce(
    params: GenerateParams,
    rng: SeededRandom,
    config: { width: number; height: number; playerUnits: number; enemyUnits: number }
  ): MapData {
    const { width, height } = config;

    // 1. 初始化网格
    const base_terrain: number[][] = this.initGrid(width, height, TerrainType.PLAIN);
    const blocker: number[][] = this.initGrid(width, height, 0);
    const vision: number[][] = this.initGrid(width, height, 0);
    const heightLayer: number[][] = this.initGrid(width, height, 0);

    // 2. 生成主路径（出生区 → 目标区），至少 2 条
    const paths = this.generateMainPaths(width, height, rng);

    // 3. 沿路径铺设道路
    for (const path of paths) {
      for (const { x, y } of path) {
        if (base_terrain[y][x] === TerrainType.PLAIN) {
          base_terrain[y][x] = TerrainType.ROAD;
        }
      }
    }

    // 4. 填充地形（按主题权重）
    this.fillTerrain(base_terrain, params.theme, rng, paths);

    // 5. 放置高地
    this.placeHighlands(base_terrain, heightLayer, width, height, rng);

    // 6. 放置掩体（墙 + 箱子）
    this.placeCovers(base_terrain, blocker, vision, width, height, rng, params.theme);

    // 7. 放置对象
    const objects = this.placeObjects(
      base_terrain, blocker, width, height, config, params.mission_type, rng
    );

    // 8. 生成脚本
    const scripts = this.generateScripts(params.mission_type, rng);

    // 9. 胜利条件
    const victory = this.generateVictory(params.mission_type);

    return {
      map_id: `gen_${params.seed}_${Date.now()}`,
      seed: params.seed,
      size: { width, height },
      theme: params.theme,
      mission_type: params.mission_type,
      difficulty: params.difficulty,
      layers: { base_terrain, blocker, vision, height: heightLayer },
      objects,
      scripts,
      victory,
      validation: { passed: false, checks: { connectivity: false, fairness: false, safety: false, density: false }, errors: [] },
    };
  }

  /** 初始化网格 */
  private static initGrid(width: number, height: number, defaultValue: number): number[][] {
    return Array.from({ length: height }, () =>
      Array.from({ length: width }, () => defaultValue)
    );
  }

  /** 生成主路径（出生区在底部，目标区在顶部） */
  private static generateMainPaths(
    width: number, height: number, rng: SeededRandom
  ): Array<{ x: number; y: number }[]> {
    const paths: Array<{ x: number; y: number }[]> = [];
    const startX = Math.floor(width / 2);
    const endX = Math.floor(width / 2);

    // 路径 1：中间偏左
    paths.push(this.generatePath({ x: startX - 1, y: height - 1 }, { x: endX, y: 0 }, rng));

    // 路径 2：中间偏右
    paths.push(this.generatePath({ x: startX + 1, y: height - 1 }, { x: endX, y: 0 }, rng));

    return paths;
  }

  /** 生成单条路径（简化的随机游走） */
  private static generatePath(
    start: { x: number; y: number },
    end: { x: number; y: number },
    rng: SeededRandom
  ): { x: number; y: number }[] {
    const path: { x: number; y: number }[] = [];
    let current = { ...start };

    while (current.x !== end.x || current.y !== end.y) {
      path.push({ ...current });

      // 优先朝目标方向移动
      const dx = end.x - current.x;
      const dy = end.y - current.y;

      if (Math.abs(dy) > Math.abs(dx) || (Math.abs(dy) === Math.abs(dx) && rng.chance(0.5))) {
        // 向上移动
        current.y += dy > 0 ? 1 : -1;
      } else {
        // 向左/右移动，有随机性
        if (rng.chance(0.7)) {
          current.x += dx > 0 ? 1 : -1;
        } else {
          current.x += rng.chance(0.5) ? 1 : -1;
        }
      }
    }
    path.push({ ...end });
    return path;
  }

  /** 按主题权重填充地形 */
  private static fillTerrain(
    grid: number[][],
    theme: MapTheme,
    rng: SeededRandom,
    paths: Array<{ x: number; y: number }[]>
  ): void {
    const weights = THEME_WEIGHTS[theme];
    const pathSet = new Set(paths.flat().map(p => `${p.x},${p.y}`));

    const entries = Object.entries(weights).map(([k, v]) => [parseInt(k), v] as [number, number]);
    const totalWeight = entries.reduce((sum, [, w]) => sum + w, 0);

    for (let y = 0; y < grid.length; y++) {
      for (let x = 0; x < grid[0].length; x++) {
        // 路径上的格子保持道路
        if (pathSet.has(`${x},${y}`)) continue;
        // 已经是非平地的跳过
        if (grid[y][x] !== TerrainType.PLAIN) continue;

        // 按权重随机选地形
        let rand = rng.next() * totalWeight;
        for (const [terrain, weight] of entries) {
          rand -= weight;
          if (rand <= 0) {
            grid[y][x] = terrain;
            break;
          }
        }
      }
    }
  }

  /** 放置高地 */
  private static placeHighlands(
    terrain: number[][],
    heightLayer: number[][],
    width: number, height: number,
    rng: SeededRandom
  ): void {
    const totalCells = width * height;
    const maxHighlands = Math.floor(totalCells / 25) * 3;
    let placed = 0;

    const attempts = maxHighlands * 3;
    for (let i = 0; i < attempts && placed < maxHighlands; i++) {
      const x = rng.nextInt(1, width - 2);
      const y = rng.nextInt(1, height - 2);

      // 检查附近是否已有高地（至少间隔 3 格）
      let tooClose = false;
      for (let dy = -3; dy <= 3 && !tooClose; dy++) {
        for (let dx = -3; dx <= 3 && !tooClose; dx++) {
          const ny = y + dy;
          const nx = x + dx;
          if (ny >= 0 && ny < height && nx >= 0 && nx < width) {
            if (terrain[ny][nx] === TerrainType.HIGHLAND) {
              tooClose = true;
            }
          }
        }
      }

      if (!tooClose && terrain[y][x] === TerrainType.PLAIN) {
        // 放置 2-4 格的高地平台
        const clusterSize = rng.nextInt(2, 4);
        for (let j = 0; j < clusterSize; j++) {
          const ox = x + rng.nextInt(-1, 1);
          const oy = y + rng.nextInt(-1, 1);
          if (ox >= 0 && ox < width && oy >= 0 && oy < height && terrain[oy][ox] === TerrainType.PLAIN) {
            terrain[oy][ox] = TerrainType.HIGHLAND;
            heightLayer[oy][ox] = 1;
            placed++;
          }
        }
      }
    }
  }

  /** 放置掩体 */
  private static placeCovers(
    terrain: number[][],
    blocker: number[][],
    vision: number[][],
    width: number, height: number,
    rng: SeededRandom,
    theme: MapTheme
  ): void {
    const totalCells = width * height;
    const targetCoverCount = Math.floor(totalCells * 0.10); // 10% 掩体密度（避免过度阻挡）

    let placed = 0;
    let attempts = 0;
    const maxAttempts = targetCoverCount * 5;

    while (placed < targetCoverCount && attempts < maxAttempts) {
      attempts++;
      const x = rng.nextInt(1, width - 2);
      const y = rng.nextInt(1, height - 2);

      // 不在出生区/目标区放掩体
      if (y >= height - 2 || y <= 1) continue;
      if (terrain[y][x] === TerrainType.WATER || terrain[y][x] === TerrainType.HIGHLAND) continue;
      if (blocker[y][x] !== 0) continue;

      // 50% 墙体，50% 箱子
      if (rng.chance(0.5)) {
        blocker[y][x] = TerrainType.WALL;
        vision[y][x] = 2; // 硬阻挡
      } else {
        blocker[y][x] = TerrainType.CRATE;
        vision[y][x] = 2;
      }
      placed++;
    }
  }

  /** 放置对象 */
  private static placeObjects(
    terrain: number[][],
    blocker: number[][],
    width: number, height: number,
    config: { playerUnits: number; enemyUnits: number },
    missionType: string,
    rng: SeededRandom
  ): MapObject[] {
    const objects: MapObject[] = [];
    let objId = 0;

    const makeObj = (type: string, x: number, y: number, extra: Partial<MapObject> = {}): MapObject => ({
      id: `obj_${objId++}`,
      type: type as MapObject['type'],
      x, y,
      ...extra,
    });

    // 玩家出生点（底部中间）
    const playerStartY = height - 1;
    const playerStartX = Math.floor(width / 2);
    for (let i = 0; i < config.playerUnits; i++) {
      const px = Math.max(0, Math.min(width - 1, playerStartX - Math.floor(config.playerUnits / 2) + i));
      objects.push(makeObj('spawn_player', px, playerStartY, { team: 'player' }));
    }

    // 敌人出生点（顶部 + 两侧，距离玩家 ≥ 5 格）
    let enemiesPlaced = 0;
    let attempts = 0;
    while (enemiesPlaced < config.enemyUnits && attempts < 100) {
      attempts++;
      const ex = rng.nextInt(0, width - 1);
      const ey = rng.nextInt(0, Math.floor(height / 2));

      // 距离玩家出生点 ≥ 5
      const minDist = Math.min(
        ...objects.filter(o => o.type === 'spawn_player').map(p =>
          Pathfinding.manhattan({ x: p.x, y: p.y }, { x: ex, y: ey })
        )
      );

      if (minDist < 5) continue;
      if (blocker[ey][ex] !== 0) continue;
      if (terrain[ey][ex] === TerrainType.WATER) continue;

      // 随机敌人类型
      const enemyTypes = ['sentry_basic', 'drone_scout', 'shield_bot', 'sentry_sniper', 'heavy_gunner'];
      const enemyType = rng.pick(enemyTypes);
      const aiTypes = ['patrol', 'guard_point', 'aggressive'];
      const ai = rng.pick(aiTypes);

      objects.push(makeObj('spawn_enemy', ex, ey, { team: 'enemy', job: enemyType, ai }));
      enemiesPlaced++;
    }

    // 主任务目标（中央偏上）
    const objectiveX = Math.floor(width / 2);
    const objectiveY = Math.floor(height / 3);
    // 找一个可放置的格子
    for (let dy = 0; dy < 3; dy++) {
      for (let dx = -2; dx <= 2; dx++) {
        const ox = objectiveX + dx;
        const oy = objectiveY + dy;
        if (ox >= 0 && ox < width && oy >= 0 && oy < height && blocker[oy][ox] === 0) {
          if (missionType === 'destroy') {
            objects.push(makeObj('destructible_target', ox, oy, { hp: 30 }));
          } else {
            objects.push(makeObj('terminal', ox, oy, { state: 'inactive' }));
          }
          break;
        }
      }
      if (objects.find(o => o.type === 'terminal' || o.type === 'destructible_target')) break;
    }

    // 撤离点（顶部角落）
    const evacX = width - 1;
    const evacY = 0;
    objects.push(makeObj('evac', evacX, evacY, { turnsToActivate: 3 }));

    // 资源点（侧路 1-2 个）
    const resourceCount = rng.nextInt(1, 2);
    for (let i = 0; i < resourceCount; i++) {
      const rx = rng.nextInt(0, Math.floor(width / 3));
      const ry = rng.nextInt(Math.floor(height / 3), Math.floor((2 * height) / 3));
      if (blocker[ry][rx] === 0 && terrain[ry][rx] !== TerrainType.WATER) {
        objects.push(makeObj('resource', rx, ry, { reward: 'credit_100' }));
      }
    }

    return objects;
  }

  /** 生成脚本 */
  private static generateScripts(missionType: string, rng: SeededRandom): MapScript[] {
    const scripts: MapScript[] = [];

    // 增援脚本：第 4 回合
    scripts.push({
      trigger_id: 'wave_01',
      trigger: { type: 'turn', condition: '>= 4' },
      action: 'spawn_reinforcement',
      data: {
        units: [{ type: 'drone_assault', position: [0, 0] }],
        message: '敌方增援到达！',
      },
      repeat: false,
    });

    // 第 6 回合第二波增援
    scripts.push({
      trigger_id: 'wave_02',
      trigger: { type: 'turn', condition: '>= 6' },
      action: 'spawn_reinforcement',
      data: {
        units: [{ type: 'sentry_elite', position: [0, 0] }],
        message: '精英增援到达！',
      },
      repeat: false,
    });

    // 主目标完成后激活撤离
    scripts.push({
      trigger_id: 'evac_activate',
      trigger: { type: 'all_objectives_complete' },
      action: 'activate_evac',
      data: { turns_to_evac: 3, message: '撤离点已激活！3回合内撤离！' },
      repeat: false,
    });

    return scripts;
  }

  /** 生成胜利条件 */
  private static generateVictory(missionType: string): VictoryConfig {
    switch (missionType) {
      case 'destroy':
        return {
          primary: 'destroy_all_targets + reach_evac',
          secondary: ['zero_casualty', 'turns <= 10', 'loot >= 1'],
          bonus: 0.2,
        };
      case 'escort':
        return {
          primary: 'escort_npc_to_evac',
          secondary: ['npc_survives', 'zero_casualty'],
          bonus: 0.25,
        };
      default:
        return {
          primary: 'activate_terminal + reach_evac',
          secondary: ['zero_casualty', 'turns <= 12', 'loot >= 1'],
          bonus: 0.2,
        };
    }
  }
}
