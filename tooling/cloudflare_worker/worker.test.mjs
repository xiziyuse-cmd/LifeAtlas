import assert from 'node:assert/strict';
import test from 'node:test';

import worker, { __test } from './worker.js';

const authEnvironment = {
  LIFEATLAS_LOGIN_USERNAME: 'lifeatlas-user',
  LIFEATLAS_LOGIN_PASSWORD: 'test-password-12345',
  LIFEATLAS_AUTH_SIGNING_KEY: 'test-signing-key-with-at-least-32-characters',
};

test('health check reports configured model names without secrets', async () => {
  const response = await worker.fetch(
    new Request('https://example.test/health'),
    {},
  );
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.status, 'ok');
  assert.equal(body.models.image, 'doubao-seed-2-1-pro-260628');
  assert.equal(body.models.text, 'doubao-seed-2-1-turbo-260628');
});

test('login issues signed access and refresh tokens', async () => {
  const response = await worker.fetch(
    new Request('https://example.test/v1/auth/login', {
      method: 'POST',
      body: JSON.stringify({
        username: 'lifeatlas-user',
        password: 'test-password-12345',
      }),
    }),
    authEnvironment,
  );
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.username, 'lifeatlas-user');
  assert.equal(body.tokenType, 'Bearer');
  assert.equal(
    (await __test.verifyToken(body.accessToken, 'access', {
      username: authEnvironment.LIFEATLAS_LOGIN_USERNAME,
      password: authEnvironment.LIFEATLAS_LOGIN_PASSWORD,
      signingKey: authEnvironment.LIFEATLAS_AUTH_SIGNING_KEY,
    })).typ,
    'access',
  );
  assert.equal(
    (await __test.verifyToken(body.refreshToken, 'refresh', {
      username: authEnvironment.LIFEATLAS_LOGIN_USERNAME,
      password: authEnvironment.LIFEATLAS_LOGIN_PASSWORD,
      signingKey: authEnvironment.LIFEATLAS_AUTH_SIGNING_KEY,
    })).typ,
    'refresh',
  );
});

test('login uses one generic error for invalid credentials', async () => {
  const response = await worker.fetch(
    new Request('https://example.test/v1/auth/login', {
      method: 'POST',
      body: JSON.stringify({ username: 'unknown', password: 'wrong-password' }),
    }),
    authEnvironment,
  );
  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), { message: '账号或密码错误' });
});

test('login reports the invalid runtime variable without exposing its value', async () => {
  const response = await worker.fetch(
    new Request('https://example.test/v1/auth/login', {
      method: 'POST',
      body: JSON.stringify({ username: 'user', password: 'password' }),
    }),
    {
      LIFEATLAS_LOGIN_USERNAME: 'user',
      LIFEATLAS_LOGIN_PASSWORD: '123456789012',
      LIFEATLAS_AUTH_SIGNING_KEY: 'too-short',
    },
  );
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), {
    message: 'AI 账号安全配置无效：LIFEATLAS_AUTH_SIGNING_KEY 需至少 32 位',
  });
});

test('refresh token returns a new token pair', async () => {
  const config = {
    username: authEnvironment.LIFEATLAS_LOGIN_USERNAME,
    password: authEnvironment.LIFEATLAS_LOGIN_PASSWORD,
    signingKey: authEnvironment.LIFEATLAS_AUTH_SIGNING_KEY,
  };
  const tokens = await __test.issueTokenPair(config);
  const response = await worker.fetch(
    new Request('https://example.test/v1/auth/refresh', {
      method: 'POST',
      body: JSON.stringify({ refreshToken: tokens.refreshToken }),
    }),
    authEnvironment,
  );
  assert.equal(response.status, 200);
  const refreshed = await response.json();
  assert.notEqual(refreshed.accessToken, tokens.accessToken);
  assert.notEqual(refreshed.refreshToken, tokens.refreshToken);
});

test('model endpoints require encrypted runtime configuration', async () => {
  const response = await worker.fetch(
    new Request('https://example.test/v1/wardrobe/analyze', {
      method: 'POST',
      body: '{}',
    }),
    {},
  );
  assert.equal(response.status, 503);
});

test('model endpoints reject an invalid bearer token before parsing input', async () => {
  const response = await worker.fetch(
    new Request('https://example.test/v1/wardrobe/analyze', {
      method: 'POST',
      headers: { Authorization: 'Bearer wrong-token' },
      body: '{}',
    }),
    { ARK_API_KEY: 'test-key', ...authEnvironment },
  );
  assert.equal(response.status, 401);
});

test('image validation rejects unsupported and oversized payloads', () => {
  assert.throws(
    () => __test.validateImage('image/svg+xml', 'AAAA'),
    (error) => error.status === 400,
  );
  const oversized = 'A'.repeat(Math.ceil((10 * 1024 * 1024 + 1) * 4 / 3));
  assert.throws(
    () => __test.validateImage('image/jpeg', oversized),
    (error) => error.status === 413,
  );
});

test('preorder input is constrained to allowed fields and limits', () => {
  const input = __test.normalizePreorderInput({
    item: { name: '测试衣服', injected: 'discarded' },
    wardrobe: [{ name: '已有衣服', secret: 'discarded' }],
    userInstruction: '请分析',
  });
  assert.deepEqual(input.item, { name: '测试衣服' });
  assert.deepEqual(input.wardrobe[0], { name: '已有衣服', parameters: {} });
  assert.equal(input.userInstruction, '请分析');
});

test('skincare health exposes independent Turbo configuration and disabled routes stop before model calls', async () => {
  const config = {
    image: {model:'legacy-image',enabled:true},
    preorder: {model:'legacy-text',enabled:true},
    kitchen: {model:'legacy-kitchen',enabled:false},
    skincare: {model:'doubao-seed-2-1-turbo-260628',enabled:false},
  };
  const env = {LIFEATLAS_FEATURE_CONFIG:JSON.stringify(config)};
  const health = await (await worker.fetch(new Request('https://example.test/health'), env)).json();
  assert.deepEqual(health.features, config);
  for (const action of ['identify','plan']) {
    const response = await worker.fetch(new Request(`https://example.test/v1/skincare/${action}`,{method:'POST',body:'{}'}),env);
    assert.equal(response.status,503);
    assert.equal((await response.json()).code,'FEATURE_DISABLED');
  }
});
