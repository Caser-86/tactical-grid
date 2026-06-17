/**
 * 地图校验器
 * 检查生成的地图是否符合平衡性和可玩性标准
 */
import { MapData, ValidationResult, MapObject } from './types';
import { Pathfinding } from './pathfinding';
import { TerrainType } from './types';

export class MapValidator {
  /** 完整校验 */
  static validate(map: MapData): ValidationResult {
    const errors: string[] = [];
    const checks = {
      connectivity: true,
      fairness: true,
      safety: true,
      density: true,
    };

    // 1. 连通性校验
    const connectivityResult = this.checkConnectivity(map);
    if (!connectivityResult.passed) {
      checks.connectivity = false;
      errors.push(...connectivityResult.errors);
    }

    // 2. 公平性校验
    const fairnessResult = this.checkFairness(map);
    if (!fairnessResult.passed) {
      checks.fairness = false;
      errors.push(...fairnessResult.errors);
    }

    // 3. 安全性校验（首回合不可贴脸）
    const safetyResult = this.checkSafety(map);
    if (!safetyResult.passed) {
      checks.safety = false;
      errors.push(...safetyResult.errors);
    }

    // 4. 密度校验
    const densityResult = this.checkDensity(map);
    if (!densityResult.passed) {
      checks.density = false;
      errors.push(...densityResult.errors);
    }

    return {
      passed: checks.connectivity && checks.fairness && checks.safety && checks.density,
      checks,
      errors,
    };
  }

  /** 连通性：所有格子可达 + 主目标可达 */
  private static checkConnectivity(map: MapData): { passed: boolean; errors: string[] } {
    const errors: string[] = [];
    const { base_terrain, blocker } = map.layers;
    const { width, height } = map.size;

    // 合并阻挡层到地形层用于通行性判断
    const passableGrid: number[][] = [];
    for (let y = 0; y < height; y++) {
      passableGrid[y] = [];
      for (let x = 0; x < width; x++) {
        // 墙体和箱子不可通行
        if (blocker[y][x] === TerrainType.WALL || blocker[y][x] === TerrainType.CRATE) {
          passableGrid[y][x] = TerrainType.WALL;
        } else {
          passableGrid[y][x] = base_terrain[y][x];
        }
      }
    }

    // 找玩家出生点
    const playerSpawns = map.objects.filter(o => o.type === 'spawn_player');
    if (playerSpawns.length === 0) {
      errors.push('No player spawn point found');
      return { passed: false, errors };
    }

    const start = { x: playerSpawns[0].x, y: playerSpawns[0].y };
    const blocked = new Set([TerrainType.WATER, TerrainType.WALL]);

    // 检查主目标可达
    const mainObjectives = map.objects.filter(o =>
      o.type === 'terminal' || o.type === 'destructible_target'
    );

    for (const obj of mainObjectives) {
      const reachable = Pathfinding.isReachable(
        passableGrid,
        start,
        { x: obj.x, y: obj.y },
        blocked
      );
      if (!reachable) {
        errors.push(`Main objective at (${obj.x},${obj.y}) is not reachable from player spawn`);
      }
    }

    // 检查撤离点可达
    const evacPoints = map.objects.filter(o => o.type === 'evac');
    for (const evac of evacPoints) {
      const reachable = Pathfinding.isReachable(
        passableGrid,
        start,
        { x: evac.x, y: evac.y },
        blocked
      );
      if (!reachable) {
        errors.push(`Evac point at (${evac.x},${evac.y}) is not reachable`);
      }
    }

    return { passed: errors.length === 0, errors };
  }

  /** 公平性：最短路径差 ≤ 2 */
  private static checkFairness(map: MapData): { passed: boolean; errors: string[] } {
    const errors: string[] = [];
    const { base_terrain, blocker } = map.layers;
    const { width, height } = map.size;

    const passableGrid: number[][] = [];
    for (let y = 0; y < height; y++) {
      passableGrid[y] = [];
      for (let x = 0; x < width; x++) {
        if (blocker[y][x] === TerrainType.WALL || blocker[y][x] === TerrainType.CRATE) {
          passableGrid[y][x] = TerrainType.WALL;
        } else {
          passableGrid[y][x] = base_terrain[y][x];
        }
      }
    }

    const playerSpawns = map.objects.filter(o => o.type === 'spawn_player');
    const enemySpawns = map.objects.filter(o => o.type === 'spawn_enemy');

    if (playerSpawns.length === 0 || enemySpawns.length === 0) {
      errors.push('Missing spawn points for fairness check');
      return { passed: false, errors };
    }

    // 找主目标
    const mainObjective = map.objects.find(o => o.type === 'terminal' || o.type === 'destructible_target');
    if (!mainObjective) return { passed: true, errors };

    const blocked = new Set([TerrainType.WATER, TerrainType.WALL]);

    // 计算玩家和敌人到主目标的最短路径
    const playerDist = Pathfinding.shortestPath(
      passableGrid,
      { x: playerSpawns[0].x, y: playerSpawns[0].y },
      { x: mainObjective.x, y: mainObjective.y },
      blocked
    );

    const enemyDist = Pathfinding.shortestPath(
      passableGrid,
      { x: enemySpawns[0].x, y: enemySpawns[0].y },
      { x: mainObjective.x, y: mainObjective.y },
      blocked
    );

    if (playerDist < 0 || enemyDist < 0) {
      errors.push('Cannot calculate path to main objective');
      return { passed: false, errors };
    }

    const diff = Math.abs(playerDist - enemyDist);
    if (diff > 2) {
      errors.push(`Path difference too large: ${diff} (player=${playerDist}, enemy=${enemyDist})`);
    }

    return { passed: errors.length === 0, errors };
  }

  /** 安全性：敌人不能贴脸出生 */
  private static checkSafety(map: MapData): { passed: boolean; errors: string[] } {
    const errors: string[] = [];
    const playerSpawns = map.objects.filter(o => o.type === 'spawn_player');
    const enemySpawns = map.objects.filter(o => o.type === 'spawn_enemy');
    const MIN_DISTANCE = 5;

    for (const player of playerSpawns) {
      for (const enemy of enemySpawns) {
        const dist = Pathfinding.manhattan(
          { x: player.x, y: player.y },
          { x: enemy.x, y: enemy.y }
        );
        if (dist < MIN_DISTANCE) {
          errors.push(
            `Enemy at (${enemy.x},${enemy.y}) is too close to player at (${player.x},${player.y}): distance=${dist} < ${MIN_DISTANCE}`
          );
        }
      }
    }

    return { passed: errors.length === 0, errors };
  }

  /** 密度：掩体/高地比例 */
  private static checkDensity(map: MapData): { passed: boolean; errors: string[] } {
    const errors: string[] = [];
    const { base_terrain, blocker, height } = map.layers;
    const totalCells = map.size.width * map.size.height;
    const standableCells = this.countStandableCells(base_terrain, blocker);

    // 全掩体密度 12%-18%
    let fullCoverCount = 0;
    for (let y = 0; y < map.size.height; y++) {
      for (let x = 0; x < map.size.width; x++) {
        if (blocker[y][x] === TerrainType.WALL) fullCoverCount++;
      }
    }
    const fullCoverRatio = fullCoverCount / standableCells;
    if (fullCoverRatio > 0.25) {
      errors.push(`Full cover density too high: ${(fullCoverRatio * 100).toFixed(1)}% > 25%`);
    }
    if (fullCoverRatio < 0.05) {
      errors.push(`Full cover density too low: ${(fullCoverRatio * 100).toFixed(1)}% < 5%`);
    }

    // 高地密度 ≤ 3/25格
    let highlandCount = 0;
    for (let y = 0; y < map.size.height; y++) {
      for (let x = 0; x < map.size.width; x++) {
        if (base_terrain[y][x] === TerrainType.HIGHLAND) highlandCount++;
      }
    }
    const maxHighland = Math.ceil(totalCells / 25) * 3;
    if (highlandCount > maxHighland) {
      errors.push(`Highland density too high: ${highlandCount} > ${maxHighland}`);
    }

    return { passed: errors.length === 0, errors };
  }

  /** 统计可站立格数 */
  private static countStandableCells(terrain: number[][], blocker: number[][]): number {
    let count = 0;
    for (let y = 0; y < terrain.length; y++) {
      for (let x = 0; x < terrain[0].length; x++) {
        if (blocker[y][x] !== TerrainType.WALL &&
            blocker[y][x] !== TerrainType.CRATE &&
            terrain[y][x] !== TerrainType.WATER) {
          count++;
        }
      }
    }
    return count;
  }
}
