/**
 * 请求验证中间件
 */
import { Request, Response, NextFunction } from 'express';
import { ZodSchema, ZodError } from 'zod';
import { error } from '../utils/response';

/**
 * 验证请求体
 */
export function validateBody(schema: ZodSchema) {
  return (req: Request, res: Response, next: NextFunction): void => {
    try {
      req.body = schema.parse(req.body);
      next();
    } catch (err) {
      if (err instanceof ZodError) {
        const messages = err.errors.map(e => `${e.path.join('.')}: ${e.message}`).join('; ');
        error(res, 1001, `Validation error: ${messages}`, 400);
      } else {
        error(res, 1001, 'Invalid request body', 400);
      }
    }
  };
}

/**
 * 验证查询参数
 */
export function validateQuery(schema: ZodSchema) {
  return (req: Request, res: Response, next: NextFunction): void => {
    try {
      req.query = schema.parse(req.query) as any;
      next();
    } catch (err) {
      if (err instanceof ZodError) {
        const messages = err.errors.map(e => `${e.path.join('.')}: ${e.message}`).join('; ');
        error(res, 1001, `Validation error: ${messages}`, 400);
      } else {
        error(res, 1001, 'Invalid query parameters', 400);
      }
    }
  };
}
