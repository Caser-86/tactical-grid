/**
 * 生成 30 个版本锁定的主线地图 JSON
 * 输出到 server/data/generated_maps/
 * 同时生成 _index.json（含生成器版本）和 _validation_report.json（独立校验报告）
 */
import { MapGenerator, GENERATOR_VERSION } from '../src/mapgen/generator';
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

  const outputDir = path.join(__dirname, '..', 'data', 'generated_maps');
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  console.log(`Generating ${levelIds.length} locked maps to ${outputDir}...`);
  console.log(`Generator version: ${GENERATOR_VERSION}\n`);

  let generated = 0;
  let failed = 0;
  const validationReports: Array<{
    level_id: string;
    name: string;
    seed: number;
    generator_version: string;
    passed: boolean;
    checks: Record<string, boolean>;
    errors: string[];
    generated_at: string;
  }> = [];

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

    if (!map.validation.passed) {
      console.log(`  [WARN] ${levelId} validation failed: ${map.validation.errors.join('; ')}`);
      failed++;
      // 仍然写入，但记录警告
    }

    // 写入文件，使用 levelId 作为文件名
    const outputPath = path.join(outputDir, `${levelId}.json`);
    fs.writeFileSync(outputPath, JSON.stringify(map, null, 2));
    generated++;
    console.log(`  [OK] ${levelId} (${level.name}) -> ${levelId}.json`);

    // 收集校验报告
    validationReports.push({
      level_id: levelId,
      name: level.name,
      seed: level.seed,
      generator_version: GENERATOR_VERSION,
      passed: map.validation.passed,
      checks: { ...map.validation.checks },
      errors: [...map.validation.errors],
      generated_at: new Date().toISOString(),
    });
  }

  console.log(`\n=== Summary ===`);
  console.log(`Generated: ${generated}`);
  console.log(`Failed validation: ${failed}`);

  // 生成索引文件（含生成器版本）
  const index = levelIds.map(id => ({
    level_id: id,
    name: levels[id].name,
    map_file: `data/generated_maps/${id}.json`,
    seed: levels[id].seed,
    generator_version: GENERATOR_VERSION,
    size: levels[id].size,
    theme: levels[id].theme,
    mission_type: levels[id].mission_type,
    validation_passed: validationReports.find(r => r.level_id === id)?.passed ?? false,
  }));

  const indexPath = path.join(outputDir, '_index.json');
  fs.writeFileSync(indexPath, JSON.stringify({
    generator_version: GENERATOR_VERSION,
    generated_at: new Date().toISOString(),
    total_maps: index.length,
    maps: index,
  }, null, 2));
  console.log(`Index written to _index.json (with generator_version=${GENERATOR_VERSION})`);

  // 生成独立校验报告
  const reportPath = path.join(outputDir, '_validation_report.json');
  fs.writeFileSync(reportPath, JSON.stringify({
    generator_version: GENERATOR_VERSION,
    generated_at: new Date().toISOString(),
    total_maps: validationReports.length,
    passed: validationReports.filter(r => r.passed).length,
    failed: validationReports.filter(r => !r.passed).length,
    reports: validationReports,
  }, null, 2));
  console.log(`Validation report written to _validation_report.json`);

  if (failed > 0) {
    process.exit(1);
  } else {
    console.log('\n✅ All maps generated and validated');
  }
}

run();
