/**
 * 30 个主线固定种子校验
 * 检查 levels.json 中所有种子是否生成有效地图
 */
import { MapGenerator } from '../src/mapgen/generator';
import { GenerateParams, MapSize, MapTheme, MissionType } from '../src/mapgen/types';
import * as fs from 'fs';
import * as path from 'path';

interface LevelConfig {
  name: string;
  chapter: number;
  mission: number;
  size: MapSize;
  theme: MapTheme;
  mission_type: MissionType;
  difficulty: number;
  seed: number;
}

function loadLevels(): Record<string, LevelConfig> {
  const levelsPath = path.join(__dirname, '..', 'data', 'levels.json');
  const content = fs.readFileSync(levelsPath, 'utf-8');
  const data = JSON.parse(content);
  return data.levels as Record<string, LevelConfig>;
}

function run() {
  const levels = loadLevels();
  const levelIds = Object.keys(levels).sort();

  console.log(`Validating ${levelIds.length} main story seeds...\n`);

  let passed = 0;
  let failed = 0;
  const failures: { levelId: string; errors: string[] }[] = [];

  for (const levelId of levelIds) {
    const level = levels[levelId];
    const params: GenerateParams = {
      size: level.size,
      seed: level.seed,
      theme: level.theme,
      mission_type: level.mission_type,
      difficulty: level.difficulty,
    };

    const map = MapGenerator.generate(params);

    if (map.validation.passed) {
      passed++;
      console.log(`  [PASS] ${levelId} (${level.name}) seed=${level.seed}`);
    } else {
      failed++;
      console.log(`  [FAIL] ${levelId} (${level.name}) seed=${level.seed}`);
      for (const err of map.validation.errors) {
        console.log(`         - ${err}`);
      }
      failures.push({ levelId, errors: map.validation.errors });
    }
  }

  console.log('\n=== Summary ===');
  console.log(`Total: ${levelIds.length}`);
  console.log(`Passed: ${passed}`);
  console.log(`Failed: ${failed}`);

  if (failures.length > 0) {
    console.log('\nFailed levels:');
    for (const f of failures) {
      console.log(`  - ${f.levelId}: ${f.errors.join('; ')}`);
    }
    process.exit(1);
  } else {
    console.log('\n✅ All main story seeds pass validation');
  }
}

run();
