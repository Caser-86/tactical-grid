/**
 * 寻路测试
 */
import { Pathfinding } from '../src/mapgen/pathfinding';
import { TerrainType } from '../src/mapgen/types';

describe('Pathfinding', () => {
  test('isReachable: direct path', () => {
    const grid = [
      [0, 0, 0],
      [0, 0, 0],
      [0, 0, 0],
    ];
    expect(Pathfinding.isReachable(grid, { x: 0, y: 0 }, { x: 2, y: 2 })).toBe(true);
  });

  test('isReachable: blocked by walls', () => {
    const grid = [
      [0, 6, 0],
      [0, 6, 0],
      [0, 6, 0],
    ];
    expect(Pathfinding.isReachable(grid, { x: 0, y: 0 }, { x: 2, y: 0 })).toBe(false);
  });

  test('isReachable: same cell', () => {
    const grid = [[0, 0], [0, 0]];
    expect(Pathfinding.isReachable(grid, { x: 0, y: 0 }, { x: 0, y: 0 })).toBe(true);
  });

  test('shortestPath: straight line', () => {
    const grid = [
      [0, 0, 0, 0, 0],
    ];
    const dist = Pathfinding.shortestPath(grid, { x: 0, y: 0 }, { x: 4, y: 0 });
    expect(dist).toBe(4);
  });

  test('shortestPath: around obstacle', () => {
    const grid = [
      [0, 6, 0],
      [0, 6, 0],
      [0, 0, 0],
    ];
    const dist = Pathfinding.shortestPath(grid, { x: 0, y: 0 }, { x: 2, y: 0 });
    // Path: (0,0)->(0,1)->(0,2)->(1,2)->(2,2)->(2,1)->(2,0) = 6
    expect(dist).toBe(6);
  });

  test('shortestPath: unreachable returns -1', () => {
    const grid = [
      [0, 6, 0],
      [0, 6, 0],
      [0, 6, 0],
    ];
    const dist = Pathfinding.shortestPath(grid, { x: 0, y: 0 }, { x: 2, y: 0 });
    expect(dist).toBe(-1);
  });

  test('manhattan distance', () => {
    expect(Pathfinding.manhattan({ x: 0, y: 0 }, { x: 3, y: 4 })).toBe(7);
    expect(Pathfinding.manhattan({ x: 5, y: 5 }, { x: 5, y: 5 })).toBe(0);
  });

  test('getReachableCells: limited by move points', () => {
    const grid = [
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
    ];
    const reachable = Pathfinding.getReachableCells(
      grid,
      { x: 2, y: 1 },
      2,
      () => 1
    );
    // Should reach cells within 2 moves
    expect(reachable.size).toBeGreaterThan(5);
    expect(reachable.size).toBeLessThan(20);
  });

  test('getReachableCells: respects terrain cost', () => {
    const grid = [
      [0, 0, 0],
      [0, 0, 0],
      [0, 0, 0],
    ];
    // Forest costs 2
    const reachable = Pathfinding.getReachableCells(
      grid,
      { x: 0, y: 0 },
      3,
      (terrain) => terrain === 2 ? 2 : 1
    );
    // With 3 move points and cost 1, can reach up to 3 cells away
    expect(reachable.has('0,0')).toBe(true);
    expect(reachable.has('3,0')).toBe(false); // Too far
  });
});
