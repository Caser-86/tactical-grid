/**
 * 种子随机数测试
 */
import { SeededRandom } from '../src/mapgen/seed_random';

describe('SeededRandom', () => {
  test('Same seed produces same sequence', () => {
    const rng1 = new SeededRandom(12345);
    const rng2 = new SeededRandom(12345);

    for (let i = 0; i < 100; i++) {
      expect(rng1.next()).toBe(rng2.next());
    }
  });

  test('Different seeds produce different sequences', () => {
    const rng1 = new SeededRandom(12345);
    const rng2 = new SeededRandom(54321);

    let differences = 0;
    for (let i = 0; i < 100; i++) {
      if (rng1.next() !== rng2.next()) differences++;
    }
    expect(differences).toBeGreaterThan(90);
  });

  test('nextInt returns values within range', () => {
    const rng = new SeededRandom(1);
    for (let i = 0; i < 1000; i++) {
      const val = rng.nextInt(5, 10);
      expect(val).toBeGreaterThanOrEqual(5);
      expect(val).toBeLessThanOrEqual(10);
    }
  });

  test('shuffle preserves elements', () => {
    const rng = new SeededRandom(42);
    const original = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    const shuffled = rng.shuffle(original);

    expect(shuffled.sort((a, b) => a - b)).toEqual(original);
  });

  test('chance returns true for probability 1', () => {
    const rng = new SeededRandom(1);
    for (let i = 0; i < 100; i++) {
      expect(rng.chance(1)).toBe(true);
    }
  });

  test('chance returns false for probability 0', () => {
    const rng = new SeededRandom(1);
    for (let i = 0; i < 100; i++) {
      expect(rng.chance(0)).toBe(false);
    }
  });
});
