/**
 * 地图可视化工具
 * 以 ASCII 方式打印地图，方便调试
 */
import { MapData, TerrainType } from './types';

const TERRAIN_SYMBOLS: Record<number, string> = {
  [TerrainType.PLAIN]: '.',
  [TerrainType.ROAD]: ' ',
  [TerrainType.FOREST]: 'T',
  [TerrainType.SAND]: '~',
  [TerrainType.HIGHLAND]: 'H',
  [TerrainType.WATER]: 'W',
  [TerrainType.WALL]: '#',
  [TerrainType.CRATE]: 'c',
  [TerrainType.POISON]: 'x',
  [TerrainType.BRIDGE]: '=',
};

const OBJECT_SYMBOLS: Record<string, string> = {
  spawn_player: 'P',
  spawn_enemy: 'E',
  terminal: 'T',
  evac: 'X',
  resource: '$',
  destructible_target: 'D',
  alarm_panel: 'A',
  npc: 'N',
};

export function visualizeMap(map: MapData): string {
  const { base_terrain, blocker } = map.layers;
  const { width, height } = map.size;
  const lines: string[] = [];

  // 对象位置映射
  const objectMap = new Map<string, string>();
  for (const obj of map.objects) {
    objectMap.set(`${obj.x},${obj.y}`, OBJECT_SYMBOLS[obj.type] || '?');
  }

  // 顶部坐标
  let header = '   ';
  for (let x = 0; x < width; x++) {
    header += (x % 10).toString();
  }
  lines.push(header);
  lines.push('  +' + '-'.repeat(width) + '+');

  for (let y = 0; y < height; y++) {
    let line = `${y.toString().padStart(2)}|`;
    for (let x = 0; x < width; x++) {
      const objSymbol = objectMap.get(`${x},${y}`);
      if (objSymbol) {
        line += objSymbol;
      } else if (blocker[y][x] !== 0) {
        line += TERRAIN_SYMBOLS[blocker[y][x]] || '?';
      } else {
        line += TERRAIN_SYMBOLS[base_terrain[y][x]] || '?';
      }
    }
    line += '|';
    lines.push(line);
  }

  lines.push('  +' + '-'.repeat(width) + '+');

  // 图例
  lines.push('');
  lines.push('Legend:');
  lines.push('  P=Player  E=Enemy  T=Terminal  X=Evac  $=Resource  D=Target');
  lines.push('  .=Plain  =Road  T=Forest  H=Highland  W=Water  #=Wall  c=Crate');

  // 校验结果
  lines.push('');
  lines.push(`Validation: ${map.validation.passed ? '✅ PASSED' : '❌ FAILED'}`);
  if (!map.validation.passed && map.validation.errors.length > 0) {
    lines.push('Errors:');
    for (const err of map.validation.errors) {
      lines.push(`  - ${err}`);
    }
  }

  // 对象统计
  const playerCount = map.objects.filter(o => o.type === 'spawn_player').length;
  const enemyCount = map.objects.filter(o => o.type === 'spawn_enemy').length;
  lines.push('');
  lines.push(`Players: ${playerCount}, Enemies: ${enemyCount}`);
  lines.push(`Objects: ${map.objects.length}, Scripts: ${map.scripts.length}`);

  return lines.join('\n');
}
