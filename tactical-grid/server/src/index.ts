/**
 * Express 服务器入口
 */
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';
import { authRoutes } from './routes/auth';
import { mapRoutes } from './routes/maps';
import { saveRoutes } from './routes/saves';
import { telemetryRoutes } from './routes/telemetry';
import { userRoutes } from './routes/user';
import { initDatabase } from './models/database';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// 安全中间件
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));

// 限流 - 通用
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { code: 4290, message: 'Too many requests, please try again later', data: null },
});

// 限流 - 认证接口（更严格）
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { code: 4290, message: 'Too many auth attempts, please try again later', data: null },
});

app.use('/api/', generalLimiter);
app.use('/api/auth/', authLimiter);

// 路由
app.use('/api/auth', authRoutes);
app.use('/api/user', userRoutes);
app.use('/api/maps', mapRoutes);
app.use('/api/saves', saveRoutes);
app.use('/api/telemetry', telemetryRoutes);

// 健康检查
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: Date.now() });
});

// 404 处理
app.use((_req, res) => {
  res.status(404).json({
    code: 4040,
    message: 'Not Found',
    data: null,
    timestamp: Date.now(),
  });
});

// 全局错误处理
app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('[ERROR]', err.message, err.stack);
  res.status(500).json({
    code: 5001,
    message: process.env.NODE_ENV === 'production' ? 'Internal Server Error' : err.message,
    data: null,
    timestamp: Date.now(),
  });
});

// 初始化数据库并启动
initDatabase().then(() => {
  app.listen(PORT, () => {
    console.log(`[INFO] Tactical Grid server running on http://localhost:${PORT}`);
    console.log(`[INFO] Environment: ${process.env.NODE_ENV || 'development'}`);
  });
}).catch((err) => {
  console.error('[FATAL] Failed to initialize database:', err);
  process.exit(1);
});

export { app };
