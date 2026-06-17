/**
 * 认证路由
 */
import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';
import { queryOne, execute, queryAll } from '../models/database';
import { generateToken, generateRefreshToken } from '../middleware/auth';
import { success, error } from '../utils/response';

export const authRoutes = Router();

// 注册
authRoutes.post('/register', (req, res) => {
  const { username, password, email } = req.body;

  if (!username || !password) {
    return error(res, 1001, 'Username and password are required');
  }

  const existing = queryOne('SELECT id FROM users WHERE username = ?', [username]);
  if (existing) {
    return error(res, 2003, 'Username already exists', 409);
  }

  const userId = uuidv4();
  const passwordHash = bcrypt.hashSync(password, 10);

  execute(
    'INSERT INTO users (id, username, password_hash, email) VALUES (?, ?, ?, ?)',
    [userId, username, passwordHash, email || null]
  );

  const token = generateToken(userId);
  const refreshToken = generateRefreshToken(userId);

  return success(res, {
    user_id: userId,
    username,
    token,
    refresh_token: refreshToken,
    expires_in: 86400,
  });
});

// 登录
authRoutes.post('/login', (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return error(res, 1001, 'Username and password are required');
  }

  const user = queryOne('SELECT * FROM users WHERE username = ?', [username]);

  if (!user) {
    return error(res, 2001, 'User not found', 404);
  }

  if (!bcrypt.compareSync(password, user.password_hash)) {
    return error(res, 2002, 'Invalid password', 401);
  }

  execute('UPDATE users SET last_login = datetime(\'now\') WHERE id = ?', [user.id]);

  const token = generateToken(user.id);
  const refreshToken = generateRefreshToken(user.id);

  return success(res, {
    user_id: user.id,
    username: user.username,
    token,
    refresh_token: refreshToken,
    expires_in: 86400,
    last_login: new Date().toISOString(),
  });
});

// 刷新 Token
authRoutes.post('/refresh', (req, res) => {
  const { refresh_token } = req.body;

  if (!refresh_token) {
    return error(res, 1001, 'Refresh token is required');
  }

  try {
    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(refresh_token, process.env.JWT_SECRET || 'tactical-grid-dev-secret-change-in-production');
    const token = generateToken(decoded.userId);
    return success(res, { token, expires_in: 86400 });
  } catch {
    return error(res, 1002, 'Invalid refresh token', 401);
  }
});

// 游客登录
authRoutes.post('/guest', (_req, res) => {
  const userId = `guest_${uuidv4().substring(0, 8)}`;
  const username = `Guest_${Math.floor(Math.random() * 10000)}`;

  execute(
    'INSERT INTO users (id, username, password_hash, is_guest) VALUES (?, ?, ?, 1)',
    [userId, username, 'guest']
  );

  const token = generateToken(userId);
  const refreshToken = generateRefreshToken(userId);

  return success(res, {
    user_id: userId,
    username,
    token,
    refresh_token: refreshToken,
    is_guest: true,
    can_upgrade: true,
    expires_in: 86400,
  });
});
