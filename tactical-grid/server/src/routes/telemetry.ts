/**
 * 遥测路由
 */
import { Router } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { execute, queryAll } from '../models/database';
import { authMiddleware, AuthRequest } from '../middleware/auth';
import { success } from '../utils/response';
import { validateBody } from '../middleware/validate';
import { asyncHandler } from '../middleware/asyncHandler';
import { telemetrySchema } from '../utils/validation';

export const telemetryRoutes = Router();

// 上报遥测事件
telemetryRoutes.post('/', authMiddleware, validateBody(telemetrySchema), asyncHandler(async (req: AuthRequest, res) => {
  const { events } = req.body;

  let received = 0;
  for (const event of events) {
    try {
      execute(
        `INSERT INTO telemetry (id, user_id, map_id, seed, event_type, event_data)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [uuidv4(), req.userId, event.map_id || null, event.seed || null, event.event_type, JSON.stringify(event.event_data || {})]
      );
      received++;
    } catch (e) {
      console.error('Telemetry insert error:', e);
    }
  }

  return success(res, { received });
}));

// 获取平衡报告
telemetryRoutes.get('/balance-report', authMiddleware, asyncHandler(async (_req: AuthRequest, res) => {
  const winRateData = queryAll(
    `SELECT level_id,
     COUNT(CASE WHEN result = 'victory' THEN 1 END) as wins,
     COUNT(*) as total
     FROM mission_results
     GROUP BY level_id`
  );

  const avgTurnsData = queryAll(
    `SELECT level_id, AVG(turns) as avg_turns
     FROM mission_results WHERE result = 'victory'
     GROUP BY level_id`
  );

  return success(res, {
    win_rates: winRateData.map(r => ({
      level_id: r.level_id,
      win_rate: r.total > 0 ? r.wins / r.total : 0,
      total_games: r.total,
    })),
    avg_turns: avgTurnsData,
  });
}));
