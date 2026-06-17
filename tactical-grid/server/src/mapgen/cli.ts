/**
 * 地图生成器 CLI
 * 用法:
 *   npx tsx src/mapgen/cli.ts --size small --seed 12345
 *   npx tsx src/mapgen/cli.ts --size medium --seed 1 --visualize
 */
import { MapGenerator } from './generator';
import { GenerateParams, MapSize, MapTheme, MissionType } from './types';
import { visualizeMap } from './visualizer';

function parseArgs(): GenerateParams & { visualize: boolean } {
  const args = process.argv.slice(2);
  const params = {
    size: 'small' as MapSize,
    seed: Math.floor(Math.random() * 999999),
    theme: 'warehouse' as MapTheme,
    mission_type: 'extract' as MissionType,
    difficulty: 1,
    visualize: false,
  };

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--size':
        params.size = (args[++i] as MapSize) || 'small';
        break;
      case '--seed':
        params.seed = parseInt(args[++i]) || params.seed;
        break;
      case '--theme':
        params.theme = (args[++i] as MapTheme) || 'warehouse';
        break;
      case '--mission':
        params.mission_type = (args[++i] as MissionType) || 'extract';
        break;
      case '--difficulty':
        params.difficulty = parseInt(args[++i]) || 1;
        break;
      case '--visualize':
      case '-v':
        params.visualize = true;
        break;
    }
  }

  return params;
}

function main() {
  const params = parseArgs();
  console.error(`Generating: size=${params.size}, seed=${params.seed}, theme=${params.theme}, mission=${params.mission_type}`);

  const map = MapGenerator.generate(params);

  console.error(`Validation: ${map.validation.passed ? 'PASSED' : 'FAILED'}`);
  console.error(`Objects: ${map.objects.length}`);

  if (params.visualize) {
    console.log(visualizeMap(map));
  } else {
    console.log(JSON.stringify(map, null, 2));
  }
}

main();
