const request = require('supertest');
const createApp = require('../src/app');

const app = createApp();

describe('GET /', () => {
  it('returns the welcome payload', async () => {
    const res = await request(app).get('/');
    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Hello from DevOps Task!');
    expect(res.body.status).toBe('running');
    expect(res.body.version).toBeDefined();
  });
});

describe('GET /health', () => {
  it('reports ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});

describe('GET /metrics', () => {
  it('exposes Prometheus-format metrics', async () => {
    await request(app).get('/');
    const res = await request(app).get('/metrics');
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/text\/plain/);
    expect(res.text).toContain('http_requests_total');
    expect(res.text).toContain('http_errors_total');
    expect(res.text).toContain('http_request_duration_seconds');
  });
});

describe('GET /unknown', () => {
  it('returns 404 for unmatched routes', async () => {
    const res = await request(app).get('/does-not-exist');
    expect(res.status).toBe(404);
  });
});
