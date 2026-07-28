/**
 * 地图生成器类型定义
 */

/** 地形类型 */
export enum TerrainType {
  PLAIN = 0,
  ROAD = 1,
  FOREST = 2,
  SAND = 3,
  HIGHLAND = 4,
  WATER = 5,
  WALL = 6,
  CRATE = 7,
  POISON = 8,
  BRIDGE = 9,
}

/** 地图尺寸档位 */
export type MapSize = 'small' | 'medium' | 'large';

export const SIZE_PRESETS: Record<MapSize, { width: number; height: number; playerUnits: number; enemyUnits: number }> = {
  small: { width: 10, height: 8, playerUnits: 4, enemyUnits: 5 },
  medium: { width: 14, height: 10, playerUnits: 5, enemyUnits: 7 },
  large: { width: 18, height: 12, playerUnits: 6, enemyUnits: 10 },
};

/** 地图主题 */
export type MapTheme = 'warehouse' | 'city_ruins' | 'mountain_fort' | 'forest_camp' | 'underground';

/** 任务类型 */
export type MissionType = 'extract' | 'destroy' | 'escort' | 'defend' | 'assassinate' | 'steal_data';

/** 地图对象 */
export interface MapObject {
  id: string;
  type: 'spawn_player' | 'spawn_enemy' | 'terminal' | 'evac' | 'resource' | 'destructible_target' | 'alarm_panel' | 'npc';
  x: number;
  y: number;
  team?: 'player' | 'enemy' | 'neutral';
  job?: string;
  ai?: string;
  state?: string;
  reward?: string;
  hp?: number;
  turnsToActivate?: number;
  guardTarget?: string;
  requires?: string;
  canDisable?: boolean;
}

/** 地图脚本 */
export interface MapScript {
  trigger_id: string;
  trigger: { type: string; condition?: string };
  action: string;
  data: Record<string, unknown>;
  repeat: boolean;
}

/** 胜利条件 */
export interface VictoryConfig {
  primary: string;
  secondary: string[];
  bonus: number;
}

/** 校验结果 */
export interface ValidationResult {
  passed: boolean;
  checks: {
    connectivity: boolean;
    fairness: boolean;
    safety: boolean;
    density: boolean;
  };
  errors: string[];
}

/** 完整地图数据 */
export interface MapData {
  map_id: string;
  seed: number;
  generator_version?: string;
  size: { width: number; height: number };
  theme: MapTheme;
  mission_type: MissionType;
  difficulty: number;
  layers: {
    base_terrain: number[][];
    blocker: number[][];
    vision: number[][];
    height: number[][];
  };
  objects: MapObject[];
  scripts: MapScript[];
  victory: VictoryConfig;
  validation: ValidationResult;
}

/** 生成参数 */
export interface GenerateParams {
  size: MapSize;
  seed: number;
  theme: MapTheme;
  mission_type: MissionType;
  difficulty: number;
}
