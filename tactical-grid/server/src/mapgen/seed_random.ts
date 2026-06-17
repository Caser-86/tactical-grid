/**
 * 种子随机数生成器
 * 确保同一种子生成相同结果（可复现）
 */
export class SeededRandom {
  private state: number;

  constructor(seed: number) {
    this.state = seed >>> 0;
  }

  /** 生成 0-1 之间的随机数 */
  next(): number {
    // xorshift32
    this.state ^= this.state << 13;
    this.state ^= this.state >>> 17;
    this.state ^= this.state << 5;
    this.state >>>= 0;
    return this.state / 0xFFFFFFFF;
  }

  /** 生成 min-max 之间的整数（含两端） */
  nextInt(min: number, max: number): number {
    return Math.floor(this.next() * (max - min + 1)) + min;
  }

  /** 从数组中随机选一个 */
  pick<T>(arr: T[]): T {
    return arr[Math.floor(this.next() * arr.length)];
  }

  /** 洗牌 */
  shuffle<T>(arr: T[]): T[] {
    const result = [...arr];
    for (let i = result.length - 1; i > 0; i--) {
      const j = Math.floor(this.next() * (i + 1));
      [result[i], result[j]] = [result[j], result[i]];
    }
    return result;
  }

  /** 概率判断 */
  chance(probability: number): boolean {
    return this.next() < probability;
  }
}
