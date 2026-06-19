/**
 * 用户路由
 */
import { queryOne, execute } from '../models/database';
import { authMiddleware, AuthRequest } from '../middleware/auth';
import { success, error } from '../utils/response';
import { Router } from 'express';
import { validateBody } from '../middleware/validate';
import { asyncHandler } from '../middleware/asyncHandler';
import { updateProfileSchema } from '../utils/validation';

export const userRoutes = Router();

// 获取用户信息
userRoutes.get('/profile', authMiddleware, asyncHandler(async (req: AuthRequest, res) => {
  const user = queryOne(
    'SELECT id, username, email, is_guest, created_at, last_login FROM users WHERE id = ?',
    [req.userId]
  );

  if (!user) {
    return error(res, 2001, 'User not found', 404);
  }

  const stats = queryOne(
    `SELECT
      COUNT(CASE WHEN result = 'victory' THEN 1 END) as wins,
      COUNT(*) as total_games,
      COALESCE(SUM(playtime), 0) as total_playtime,
      COUNT(CASE WHEN first_clear = 1 THEN 1 END) as first_clears
     FROM mission_results WHERE user_id = ?`,
    [req.userId]
  );

  return success(res, {
    user_id: user.id,
    username: user.username,
    email: user.email,
    is_guest: !!user.is_guest,
    avatar: 'avatar_01',
    level: Math.floor((stats?.total_playtime || 0) / 3600) + 1,
    exp: 0,
    title: '新兵',
    created_at: user.created_at,
    last_login: user.last_login,
    stats: {
      total_playtime: stats?.total_playtime || 0,
      total_missions: stats?.total_games || 0,
      pvp_wins: 0,
      pvp_losses: 0,
      achievement_count: 0,
    },
  });
}));

// 更新用户信息
userRoutes.put('/profile', authMiddleware, validateBody(updateProfileSchema), asyncHandler(async (req: AuthRequest, res) => {
  const { username, email } = req.body;

  if (username) {
    const existing = queryOne('SELECT id FROM users WHERE username = ? AND id != ?', [username, req.userId]);
    if (existing) {
      return error(res, 2003, 'Username already exists', 409);
    }
    execute('UPDATE users SET username = ? WHERE id = ?', [username, req.userId]);
  }

  if (email !== undefined) {
    execute('UPDATE users SET email = ? WHERE id = ?', [email || null, req.userId]);
  }

  return success(res, { updated: true });
}));
