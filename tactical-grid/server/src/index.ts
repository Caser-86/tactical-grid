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
app.use(morgan('combined'));

// 限流
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 分钟
  max: 100, // 每个 IP 最多 100 次请求
});
app.use('/api/', limiter);

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

// 错误处理
app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err.stack);
  res.status(500).json({
    code: 5001,
    message: 'Internal Server Error',
    data: null,
    timestamp: Date.now(),
    request_id: '',
  });
});

// 初始化数据库并启动
initDatabase().then(() => {
  app.listen(PORT, () => {
    console.log(`Tactical Grid server running on http://localhost:${PORT}`);
  });
});

export { app };
