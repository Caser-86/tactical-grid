/**
 * A* 寻路算法
 * 用于地图校验和移动范围计算
 */
export class Pathfinding {
  /** 检查从 start 到 end 是否可达（忽略移动成本） */
  static isReachable(
    grid: number[][],
    start: { x: number; y: number },
    end: { x: number; y: number },
    blockedValues: Set<number> = new Set([5, 6]) // water, wall
  ): boolean {
    const height = grid.length;
    const width = grid[0].length;
    const visited = new Set<string>();
    const queue = [start];
    visited.add(`${start.x},${start.y}`);

    while (queue.length > 0) {
      const current = queue.shift()!;
      if (current.x === end.x && current.y === end.y) return true;

      const neighbors = [
        { x: current.x + 1, y: current.y },
        { x: current.x - 1, y: current.y },
        { x: current.x, y: current.y + 1 },
        { x: current.x, y: current.y - 1 },
      ];

      for (const n of neighbors) {
        if (n.x < 0 || n.x >= width || n.y < 0 || n.y >= height) continue;
        const key = `${n.x},${n.y}`;
        if (visited.has(key)) continue;
        if (blockedValues.has(grid[n.y][n.x])) continue;
        visited.add(key);
        queue.push(n);
      }
    }
    return false;
  }

  /** BFS 找最短路径长度（格数） */
  static shortestPath(
    grid: number[][],
    start: { x: number; y: number },
    end: { x: number; y: number },
    blockedValues: Set<number> = new Set([5, 6])
  ): number {
    const height = grid.length;
    const width = grid[0].length;
    const visited = new Map<string, number>();
    const queue = [{ ...start, dist: 0 }];
    visited.set(`${start.x},${start.y}`, 0);

    while (queue.length > 0) {
      const current = queue.shift()!;
      if (current.x === end.x && current.y === end.y) return current.dist;

      const neighbors = [
        { x: current.x + 1, y: current.y },
        { x: current.x - 1, y: current.y },
        { x: current.x, y: current.y + 1 },
        { x: current.x, y: current.y - 1 },
      ];

      for (const n of neighbors) {
        if (n.x < 0 || n.x >= width || n.y < 0 || n.y >= height) continue;
        const key = `${n.x},${n.y}`;
        if (visited.has(key)) continue;
        if (blockedValues.has(grid[n.y][n.x])) continue;
        visited.set(key, current.dist + 1);
        queue.push({ x: n.x, y: n.y, dist: current.dist + 1 });
      }
    }
    return -1; // 不可达
  }

  /** 获取所有可达格子 */
  static getReachableCells(
    grid: number[][],
    start: { x: number; y: number },
    movePoints: number,
    moveCostFn: (terrain: number) => number,
    blockedValues: Set<number> = new Set([5, 6])
  ): Map<string, number> {
    const height = grid.length;
    const width = grid[0].length;
    const distances = new Map<string, number>();
    const pq: { x: number; y: number; cost: number }[] = [{ x: start.x, y: start.y, cost: 0 }];
    distances.set(`${start.x},${start.y}`, 0);

    while (pq.length > 0) {
      pq.sort((a, b) => a.cost - b.cost);
      const current = pq.shift()!;

      if (current.cost > movePoints) continue;

      const neighbors = [
        { x: current.x + 1, y: current.y },
        { x: current.x - 1, y: current.y },
        { x: current.x, y: current.y + 1 },
        { x: current.x, y: current.y - 1 },
      ];

      for (const n of neighbors) {
        if (n.x < 0 || n.x >= width || n.y < 0 || n.y >= height) continue;
        if (blockedValues.has(grid[n.y][n.x])) continue;

        const terrainCost = moveCostFn(grid[n.y][n.x]);
        if (terrainCost < 0) continue; // 不可通行

        const newCost = current.cost + terrainCost;
        const key = `${n.x},${n.y}`;
        const existing = distances.get(key);

        if (existing === undefined || newCost < existing) {
          distances.set(key, newCost);
          if (newCost <= movePoints) {
            pq.push({ x: n.x, y: n.y, cost: newCost });
          }
        }
      }
    }
    return distances;
  }

  /** 曼哈顿距离 */
  static manhattan(a: { x: number; y: number }, b: { x: number; y: number }): number {
    return Math.abs(a.x - b.x) + Math.abs(a.y - b.y);
  }
}
