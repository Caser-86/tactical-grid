/**
 * API 路由集成测试
 */
import request from 'supertest';
import { app } from '../src/index';
import { initDatabase } from '../src/models/database';

beforeAll(async () => {
  process.env.JWT_SECRET = 'test-secret';
  await initDatabase();
});

describe('Health Check', () => {
  test('GET /health returns ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});

describe('Auth Routes', () => {
  let authToken: string;
  let userId: string;

  test('POST /api/auth/guest creates guest account', async () => {
    const res = await request(app)
      .post('/api/auth/guest')
      .send({});

    expect(res.status).toBe(200);
    expect(res.body.code).toBe(0);
    expect(res.body.data.user_id).toBeDefined();
    expect(res.body.data.token).toBeDefined();
    expect(res.body.data.is_guest).toBe(true);

    authToken = res.body.data.token;
    userId = res.body.data.user_id;
  });

  test('POST /api/auth/register creates user', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({
        username: 'testuser' + Date.now().toString().slice(-6),
        password: 'test123456',
      });

    expect(res.status).toBe(200);
    expect(res.body.code).toBe(0);
    expect(res.body.data.token).toBeDefined();
  });

  test('POST /api/auth/register rejects duplicate username', async () => {
    const username = 'dupuser' + Date.now().toString().slice(-6);
    await request(app)
      .post('/api/auth/register')
      .send({ username, password: 'test123456' });

    const res = await request(app)
      .post('/api/auth/register')
      .send({ username, password: 'test123456' });

    expect(res.status).toBe(409);
    expect(res.body.code).toBe(2003);
  });

  test('POST /api/auth/register validates input', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ username: 'ab', password: '123' });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe(1001);
  });

  test('POST /api/auth/login succeeds with correct credentials', async () => {
    const username = 'loginuser' + Date.now().toString().slice(-6);
    await request(app)
      .post('/api/auth/register')
      .send({ username, password: 'test123456' });

    const res = await request(app)
      .post('/api/auth/login')
      .send({ username, password: 'test123456' });

    expect(res.status).toBe(200);
    expect(res.body.code).toBe(0);
    expect(res.body.data.token).toBeDefined();
  });

  test('POST /api/auth/login fails with wrong password', async () => {
    const username = 'wrongpw' + Date.now().toString().slice(-6);
    await request(app)
      .post('/api/auth/register')
      .send({ username, password: 'test123456' });

    const res = await request(app)
      .post('/api/auth/login')
      .send({ username, password: 'wrongpassword' });

    expect(res.status).toBe(401);
    expect(res.body.code).toBe(2002);
  });
});

describe('User Routes', () => {
  let authToken: string;

  beforeAll(async () => {
    const res = await request(app)
      .post('/api/auth/guest')
      .send({});
    authToken = res.body.data.token;
  });

  test('GET /api/user/profile returns user info', async () => {
    const res = await request(app)
      .get('/api/user/profile')
      .set('Authorization', `Bearer ${authToken}`);

    expect(res.status).toBe(200);
    expect(res.body.code).toBe(0);
    expect(res.body.data.user_id).toBeDefined();
    expect(res.body.data.username).toBeDefined();
  });

  test('GET /api/user/profile requires auth', async () => {
    const res = await request(app)
      .get('/api/user/profile');

    expect(res.status).toBe(401);
  });
});

describe('Map Routes', () => {
  let authToken: string;

  beforeAll(async () => {
    const res = await request(app)
      .post('/api/auth/guest')
      .send({});
    authToken = res.body.data.token;
  });

  test('GET /api/maps/campaign returns chapters', async () => {
    const res = await request(app)
      .get('/api/maps/campaign');

    expect(res.status).toBe(200);
    expect(res.body.code).toBe(0);
    expect(res.body.data.chapters).toBeDefined();
    expect(res.body.data.chapters.length).toBe(5);
  });

  test('GET /api/maps/:level_id generates map', async () => {
    const res = await request(app)
      .get('/api/maps/ch1_m1')
      .set('Authorization', `Bearer ${authToken}`);

    expect(res.status).toBe(200);
    expect(res.body.code).toBe(0);
    expect(res.body.data.map_data).toBeDefined();
    expect(res.body.data.map_data.layers).toBeDefined();
  });

  test('POST /api/maps/generate creates random map', async () => {
    const res = await request(app)
      .post('/api/maps/generate')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ size: 'small', seed: 12345 });

    expect(res.status).toBe(200);
    expect(res.body.code).toBe(0);
    expect(res.body.data.map_id).toBeDefined();
  });

  test('POST /api/maps/generate validates params', async () => {
    const res = await request(app)
      .post('/api/maps/generate')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ size: 'invalid_size' });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe(1001);
  });
});

describe('Save Routes', () => {
  let authToken: string;

  beforeAll(async () => {
    const res = await request(app)
      .post('/api/auth/guest')
      .send({});
    authToken = res.body.data.token;
  });

  test('POST /api/saves uploads save', async () => {
    const res = await request(app)
      .post('/api/saves')
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        save_type: 'auto',
        save_data: '{"test": true}',
      });

    expect(res.status).toBe(200);
    expect(res.body.code).toBe(0);
    expect(res.body.data.save_id).toBeDefined();
  });

  test('GET /api/saves returns save list', async () => {
    const res = await request(app)
      .get('/api/saves')
      .set('Authorization', `Bearer ${authToken}`);

    expect(res.status).toBe(200);
    expect(res.body.code).toBe(0);
    expect(res.body.data.saves).toBeDefined();
  });

  test('POST /api/saves validates required fields', async () => {
    const res = await request(app)
      .post('/api/saves')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ save_type: 'auto' });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe(1001);
  });
});

describe('Telemetry Routes', () => {
  let authToken: string;

  beforeAll(async () => {
    const res = await request(app)
      .post('/api/auth/guest')
      .send({});
    authToken = res.body.data.token;
  });

  test('POST /api/telemetry accepts events', async () => {
    const res = await request(app)
      .post('/api/telemetry')
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        events: [
          { event_type: 'test_event', event_data: { key: 'value' } },
        ],
      });

    expect(res.status).toBe(200);
    expect(res.body.code).toBe(0);
    expect(res.body.data.received).toBe(1);
  });

  test('POST /api/telemetry validates events array', async () => {
    const res = await request(app)
      .post('/api/telemetry')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ events: 'not_an_array' });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe(1001);
  });
});
