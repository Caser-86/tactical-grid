/**
 * Zod 请求验证 schemas
 */
import { z } from 'zod';

// ===== 认证 =====
export const registerSchema = z.object({
  username: z.string().min(3).max(20).regex(/^[a-zA-Z0-9_]+$/, '用户名只能包含字母、数字和下划线'),
  password: z.string().min(6).max(100),
  email: z.string().email().optional().or(z.literal('')),
});

export const loginSchema = z.object({
  username: z.string().min(1),
  password: z.string().min(1),
});

export const refreshSchema = z.object({
  refresh_token: z.string().min(1),
});

// ===== 地图 =====
export const mapGenerateSchema = z.object({
  size: z.enum(['small', 'medium', 'large']).optional(),
  seed: z.number().int().min(0).max(999999).optional(),
  theme: z.enum(['warehouse', 'city_ruins', 'mountain_fort', 'forest_camp', 'underground']).optional(),
  mission_type: z.enum(['extract', 'destroy', 'escort', 'defend', 'assassinate', 'steal_data']).optional(),
  difficulty: z.number().int().min(1).max(10).optional(),
});

export const missionCompleteSchema = z.object({
  result: z.enum(['victory', 'defeat']),
  turns: z.number().int().min(0).optional(),
  units_survived: z.number().int().min(0).optional(),
  zero_casualty: z.boolean().optional(),
  loot_collected: z.array(z.string()).optional(),
  playtime_seconds: z.number().int().min(0).optional(),
  seed: z.number().int().optional(),
});

// ===== 存档 =====
export const saveUploadSchema = z.object({
  save_type: z.enum(['auto', 'manual', 'checkpoint']).optional(),
  save_data: z.string().min(1),
  save_hash: z.string().optional(),
  version: z.string().optional(),
  chapter: z.number().int().optional(),
  mission: z.string().optional(),
  playtime: z.number().int().min(0).optional(),
});

// ===== 遥测 =====
export const telemetryEventSchema = z.object({
  map_id: z.string().optional(),
  seed: z.number().int().optional(),
  event_type: z.string().min(1).max(50),
  event_data: z.record(z.unknown()).optional(),
});

export const telemetrySchema = z.object({
  events: z.array(telemetryEventSchema).min(1).max(100),
});

// ===== 用户 =====
export const updateProfileSchema = z.object({
  username: z.string().min(3).max(20).optional(),
  email: z.string().email().optional(),
  avatar: z.string().optional(),
});
