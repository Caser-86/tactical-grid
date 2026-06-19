/**
 * 存档路由
 */
import { Router } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { queryAll, queryOne, execute } from '../models/database';
import { authMiddleware, AuthRequest } from '../middleware/auth';
import { success, error } from '../utils/response';
import { validateBody } from '../middleware/validate';
import { asyncHandler } from '../middleware/asyncHandler';
import { saveUploadSchema } from '../utils/validation';

export const saveRoutes = Router();

// 获取存档列表
saveRoutes.get('/', authMiddleware, asyncHandler(async (req: AuthRequest, res) => {
  const saves = queryAll(
    `SELECT id, save_type, chapter, mission, playtime, created_at, LENGTH(save_data) as size_bytes
     FROM saves WHERE user_id = ? ORDER BY created_at DESC`,
    [req.userId]
  );

  const totalSize = saves.reduce((sum, s) => sum + (s.size_bytes || 0), 0);

  return success(res, {
    saves: saves.map(s => ({
      save_id: s.id,
      save_type: s.save_type,
      chapter: s.chapter,
      mission: s.mission,
      playtime: s.playtime,
      timestamp: s.created_at,
      size_kb: Math.round((s.size_bytes || 0) / 1024),
    })),
    cloud_storage_used_mb: Math.round(totalSize / 1024 / 1024 * 10) / 10,
    cloud_storage_limit_mb: 100,
  });
}));

// 上传存档
saveRoutes.post('/', authMiddleware, validateBody(saveUploadSchema), asyncHandler(async (req: AuthRequest, res) => {
  const { save_type, save_data, save_hash, version, chapter, mission, playtime } = req.body;

  const saveId = uuidv4();

  execute(
    `INSERT INTO saves (id, user_id, save_type, save_data, save_hash, version, chapter, mission, playtime)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [saveId, req.userId!, save_type || 'auto', save_data, save_hash || '', version || '1.0.0', chapter || null, mission || null, playtime || 0]
  );

  return success(res, {
    save_id: saveId,
    timestamp: new Date().toISOString(),
  });
}));

// 下载存档
saveRoutes.get('/:save_id', authMiddleware, asyncHandler(async (req: AuthRequest, res) => {
  const { save_id } = req.params;

  const save = queryOne(
    'SELECT * FROM saves WHERE id = ? AND user_id = ?',
    [save_id, req.userId]
  );

  if (!save) {
    return error(res, 3001, 'Save not found', 404);
  }

  return success(res, {
    save_id: save.id,
    save_data: save.save_data,
    save_hash: save.save_hash,
    version: save.version,
    timestamp: save.created_at,
  });
}));

// 删除存档
saveRoutes.delete('/:save_id', authMiddleware, asyncHandler(async (req: AuthRequest, res) => {
  const { save_id } = req.params;

  const save = queryOne('SELECT id FROM saves WHERE id = ? AND user_id = ?', [save_id, req.userId]);
  if (!save) {
    return error(res, 3001, 'Save not found', 404);
  }

  execute('DELETE FROM saves WHERE id = ? AND user_id = ?', [save_id, req.userId]);

  return success(res, { deleted: true });
}));

// 获取最新存档
saveRoutes.get('/latest', authMiddleware, asyncHandler(async (req: AuthRequest, res) => {
  const save = queryOne(
    'SELECT * FROM saves WHERE user_id = ? ORDER BY created_at DESC LIMIT 1',
    [req.userId]
  );

  if (!save) {
    return error(res, 3001, 'No saves found', 404);
  }

  return success(res, {
    save_id: save.id,
    save_data: save.save_data,
    save_hash: save.save_hash,
    version: save.version,
    timestamp: save.created_at,
  });
}));
