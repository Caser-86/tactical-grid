/**
 * 地图生成器测试
 */
import { MapGenerator } from '../src/mapgen/generator';
import { GenerateParams, TerrainType } from '../src/mapgen/types';

describe('MapGenerator', () => {
  const baseParams: GenerateParams = {
    size: 'small',
    seed: 12345,
    theme: 'warehouse',
    mission_type: 'extract',
    difficulty: 1,
  };

  test('generates a map with correct dimensions', () => {
    const map = MapGenerator.generate(baseParams);
    expect(map.size.width).toBe(10);
    expect(map.size.height).toBe(8);
    expect(map.layers.base_terrain.length).toBe(8);
    expect(map.layers.base_terrain[0].length).toBe(10);
  });

  test('seed reproducibility', () => {
    const map1 = MapGenerator.generate(baseParams);
    const map2 = MapGenerator.generate(baseParams);
    expect(map1.layers.base_terrain).toEqual(map2.layers.base_terrain);
    expect(map1.layers.blocker).toEqual(map2.layers.blocker);
    expect(map1.objects).toEqual(map2.objects);
  });

  test('has player spawn points', () => {
    const map = MapGenerator.generate(baseParams);
    const playerSpawns = map.objects.filter(o => o.type === 'spawn_player');
    expect(playerSpawns.length).toBeGreaterThan(0);
    expect(playerSpawns.length).toBe(4); // small map = 4 players
  });

  test('has enemy spawn points', () => {
    const map = MapGenerator.generate(baseParams);
    const enemySpawns = map.objects.filter(o => o.type === 'spawn_enemy');
    expect(enemySpawns.length).toBeGreaterThan(0);
    expect(enemySpawns.length).toBeLessThanOrEqual(5); // small map = max 5 enemies
  });

  test('has main objective', () => {
    const map = MapGenerator.generate(baseParams);
    const objectives = map.objects.filter(o =>
      o.type === 'terminal' || o.type === 'destructible_target'
    );
    expect(objectives.length).toBeGreaterThan(0);
  });

  test('has evac point', () => {
    const map = MapGenerator.generate(baseParams);
    const evac = map.objects.filter(o => o.type === 'evac');
    expect(evac.length).toBeGreaterThan(0);
  });

  test('enemies are not too close to players', () => {
    const map = MapGenerator.generate(baseParams);
    const players = map.objects.filter(o => o.type === 'spawn_player');
    const enemies = map.objects.filter(o => o.type === 'spawn_enemy');

    for (const p of players) {
      for (const e of enemies) {
        const dist = Math.abs(p.x - e.x) + Math.abs(p.y - e.y);
        expect(dist).toBeGreaterThanOrEqual(5);
      }
    }
  });

  test('medium size generates correct dimensions', () => {
    const map = MapGenerator.generate({ ...baseParams, size: 'medium' });
    expect(map.size.width).toBe(14);
    expect(map.size.height).toBe(10);
  });

  test('large size generates correct dimensions', () => {
    const map = MapGenerator.generate({ ...baseParams, size: 'large' });
    expect(map.size.width).toBe(18);
    expect(map.size.height).toBe(12);
  });

  test('has scripts (reinforcement triggers)', () => {
    const map = MapGenerator.generate(baseParams);
    expect(map.scripts.length).toBeGreaterThan(0);
    const hasReinforcement = map.scripts.some(s => s.action === 'spawn_reinforcement');
    expect(hasReinforcement).toBe(true);
  });

  test('has victory conditions', () => {
    const map = MapGenerator.generate(baseParams);
    expect(map.victory.primary).toBeTruthy();
    expect(map.victory.secondary).toBeInstanceOf(Array);
  });

  test('different themes produce different terrain', () => {
    const warehouse = MapGenerator.generate({ ...baseParams, theme: 'warehouse' });
    const forest = MapGenerator.generate({ ...baseParams, theme: 'forest_camp' });
    // They should be different (very unlikely to be identical)
    expect(warehouse.layers.base_terrain).not.toEqual(forest.layers.base_terrain);
  });

  test('destroy mission creates destructible targets', () => {
    const map = MapGenerator.generate({ ...baseParams, mission_type: 'destroy' });
    const targets = map.objects.filter(o => o.type === 'destructible_target');
    expect(targets.length).toBeGreaterThan(0);
  });

  test('validation runs on generated map', () => {
    const map = MapGenerator.generate(baseParams);
    expect(map.validation).toBeDefined();
    expect(typeof map.validation.passed).toBe('boolean');
  });
});
