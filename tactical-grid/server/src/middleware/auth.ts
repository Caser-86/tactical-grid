/**
 * 认证中间件
 */
import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'tactical-grid-dev-secret-change-in-production';

export interface AuthRequest extends Request {
  userId?: string;
}

export function authMiddleware(req: AuthRequest, res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({ code: 1002, message: 'Unauthorized', data: null, timestamp: Date.now(), request_id: '' });
    return;
  }

  const token = authHeader.substring(7);
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as { userId: string };
    req.userId = decoded.userId;
    next();
  } catch {
    res.status(401).json({ code: 1002, message: 'Invalid token', data: null, timestamp: Date.now(), request_id: '' });
  }
}

export function generateToken(userId: string): string {
  return jwt.sign({ userId }, JWT_SECRET, { expiresIn: '24h' });
}

export function generateRefreshToken(userId: string): string {
  return jwt.sign({ userId, type: 'refresh' }, JWT_SECRET, { expiresIn: '7d' });
}

export { JWT_SECRET };
