/**
 * 统一响应工具
 */
import { Response } from 'express';

export function success(res: Response, data: unknown, message: string = 'success'): void {
  res.json({
    code: 0,
    message,
    data,
    timestamp: Date.now(),
    request_id: res.locals.requestId || '',
  });
}

export function error(res: Response, code: number, message: string, httpStatus: number = 400): void {
  res.status(httpStatus).json({
    code,
    message,
    data: null,
    timestamp: Date.now(),
    request_id: res.locals.requestId || '',
  });
}
