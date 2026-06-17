/**
 * 用户路由
 */
import { queryOne } from '../models/database';
import { authMiddleware, AuthRequest } from '../middleware/auth';
import { success, error } from '../utils/response';
import { Router } from 'express';

export const userRoutes = Router();

// 获取用户信息
userRoutes.get('/profile', authMiddleware, (req: AuthRequest, res) => {
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
});

// 更新用户信息
userRoutes.put('/profile', authMiddleware, (_req: AuthRequest, res) => {
  return success(res, { updated: true });
});
