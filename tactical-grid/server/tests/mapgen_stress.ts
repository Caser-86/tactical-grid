/**
 * 地图生成器压力测试
 * 生成 10000 张地图，检查通过率和失败原因
 */
import { MapGenerator } from '../src/mapgen/generator';
import { GenerateParams, MapSize, MapTheme, MissionType } from '../src/mapgen/types';

const SIZES: MapSize[] = ['small', 'medium', 'large'];
const THEMES: MapTheme[] = ['warehouse', 'city_ruins', 'mountain_fort', 'forest_camp', 'underground'];
const MISSIONS: MissionType[] = ['extract', 'destroy', 'escort', 'defend'];

const TOTAL = 10000;

function run() {
  console.log(`Running stress test: ${TOTAL} maps...\n`);

  let passed = 0;
  let failed = 0;
  const failures: { seed: number; size: string; theme: string; errors: string[] }[] = [];

  const startTime = Date.now();

  for (let i = 0; i < TOTAL; i++) {
    const params: GenerateParams = {
      size: SIZES[i % SIZES.length],
      seed: i + 1,
      theme: THEMES[i % THEMES.length],
      mission_type: MISSIONS[i % MISSIONS.length],
      difficulty: 1 + (i % 5),
    };

    const map = MapGenerator.generate(params);

    if (map.validation.passed) {
      passed++;
    } else {
      failed++;
      if (failures.length < 20) {
        failures.push({
          seed: params.seed,
          size: params.size,
          theme: params.theme,
          errors: map.validation.errors,
        });
      }
    }

    if ((i + 1) % 1000 === 0) {
      const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
      console.log(`  ${i + 1}/${TOTAL} (${elapsed}s) - Pass: ${passed} Fail: ${failed}`);
    }
  }

  const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
  const passRate = ((passed / TOTAL) * 100).toFixed(1);

  console.log('\n=== Results ===');
  console.log(`Total: ${TOTAL}`);
  console.log(`Passed: ${passed} (${passRate}%)`);
  console.log(`Failed: ${failed} (${(100 - parseFloat(passRate)).toFixed(1)}%)`);
  console.log(`Time: ${elapsed}s`);
  console.log(`Avg per map: ${(parseFloat(elapsed) / TOTAL * 1000).toFixed(1)}ms`);

  if (failures.length > 0) {
    console.log('\n=== Sample Failures ===');
    for (const f of failures.slice(0, 10)) {
      console.log(`  Seed ${f.seed} (${f.size}/${f.theme}): ${f.errors.join('; ')}`);
    }
  }

  // Assert pass rate > 99%
  const rate = passed / TOTAL;
  if (rate < 0.99) {
    console.error(`\n❌ FAIL: Pass rate ${passRate}% is below 99% threshold`);
    process.exit(1);
  } else {
    console.log(`\n✅ PASS: Pass rate ${passRate}% meets 99% threshold`);
  }
}

run();
