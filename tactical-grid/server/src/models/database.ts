/**
 * 数据库初始化与连接（使用 sql.js，纯 WASM 无需编译）
 */
import initSqlJs, { Database } from 'sql.js';
import path from 'path';
import fs from 'fs';

let db: Database;
let dbPath: string;

export async function initDatabase(): Promise<void> {
  const SQL = await initSqlJs();
  dbPath = path.join(process.cwd(), 'data', 'tactical_grid.db');

  // 如果已有数据库文件，加载它
  if (fs.existsSync(dbPath)) {
    const buffer = fs.readFileSync(dbPath);
    db = new SQL.Database(buffer);
  } else {
    db = new SQL.Database();
  }

  // 创建表
  db.run(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      username TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      email TEXT,
      is_guest INTEGER DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now')),
      last_login TEXT
    );

    CREATE TABLE IF NOT EXISTS saves (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      save_type TEXT NOT NULL,
      save_data TEXT NOT NULL,
      save_hash TEXT,
      version TEXT,
      chapter INTEGER,
      mission TEXT,
      playtime INTEGER,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id)
    );

    CREATE TABLE IF NOT EXISTS maps (
      id TEXT PRIMARY KEY,
      seed INTEGER NOT NULL,
      size TEXT NOT NULL,
      theme TEXT NOT NULL,
      mission_type TEXT NOT NULL,
      map_data TEXT NOT NULL,
      validation TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS telemetry (
      id TEXT PRIMARY KEY,
      user_id TEXT,
      map_id TEXT,
      seed INTEGER,
      event_type TEXT NOT NULL,
      event_data TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS mission_results (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      level_id TEXT NOT NULL,
      result TEXT NOT NULL,
      turns INTEGER,
      playtime INTEGER,
      units_survived INTEGER,
      zero_casualty INTEGER,
      stars INTEGER,
      first_clear INTEGER,
      seed INTEGER,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id)
    );
  `);

  saveDatabase();
  console.log('Database initialized at', dbPath);
}

/** 保存数据库到文件 */
export function saveDatabase(): void {
  if (!db || !dbPath) return;
  const data = db.export();
  const buffer = Buffer.from(data);
  // 确保目录存在
  const dir = path.dirname(dbPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  fs.writeFileSync(dbPath, buffer);
}

export function getDb(): Database {
  if (!db) {
    throw new Error('Database not initialized. Call initDatabase() first.');
  }
  return db;
}

/** 执行查询并返回所有结果 */
export function queryAll(sql: string, params: any[] = []): any[] {
  const stmt = db.prepare(sql);
  stmt.bind(params);
  const results: any[] = [];
  while (stmt.step()) {
    results.push(stmt.getAsObject());
  }
  stmt.free();
  return results;
}

/** 执行查询返回第一行 */
export function queryOne(sql: string, params: any[] = []): any | null {
  const results = queryAll(sql, params);
  return results.length > 0 ? results[0] : null;
}

/** 执行写操作并保存 */
export function execute(sql: string, params: any[] = []): void {
  db.run(sql, params);
  saveDatabase();
}
