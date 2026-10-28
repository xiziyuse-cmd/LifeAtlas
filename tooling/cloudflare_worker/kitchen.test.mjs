import assert from 'node:assert/strict';
import test from 'node:test';
import worker, { __test } from './worker.js';
import { normalizeKitchenInput, normalizeKitchenResult } from './kitchen.js';

const recipe = {name: '鸡蛋汤', categories: ['汤类'], difficulty: '简单', cookTime: 10, materials: [{name: '鸡蛋', amount: 1, unit: '个'}], seasonings: [{name: '盐', amount: 1, unit: 'g', stage: '出锅前', sort: 1}], steps: [{name: '炖煮阶段', content: '蛋液倒入沸水煮熟', duration: 10, materials: ['鸡蛋'], seasonings: ['盐']}]};
test('kitchen input validates quantities and drops unrelated fields', () => {
  assert.throws(() => normalizeKitchenInput({inventory: []}), e => e.status === 400);
  assert.throws(() => normalizeKitchenInput({inventory: [{name: '盐', amount: -1, unit: 'g'}]}), e => e.status === 400);
  const input = normalizeKitchenInput({inventory: [{name: '鸡蛋', amount: 3, unit: '个', remaining_days: 2, secret: 'drop'}], instruction: '少油'});
  assert.equal(input.inventory[0].secret, undefined);
  assert.equal(input.inventory[0].remaining_days, 2);
  assert.throws(() => normalizeKitchenInput({inventory: [{name: '鸡蛋', amount: 3, unit: '个', remaining_days: 1.5}]}), e => e.status === 400);
  assert.equal(input.instruction, '少油');
});
test('kitchen response validates step references and removes model media paths', () => {
  const result = normalizeKitchenResult({recipes: [{...recipe, image: '/private/file'}]});
  assert.equal(result.recipes[0].image, undefined);
  assert.throws(() => normalizeKitchenResult({recipes: [{...recipe, steps: [{...recipe.steps[0], materials: ['不存在']}]}]}), e => e.status === 502);
  assert.throws(() => normalizeKitchenResult({recipes: [{...recipe, materials: []}]}), e => e.status === 502);
});
test('kitchen route authenticates then returns validated model recipes', async (t) => {
  const env = {ARK_API_KEY: 'test-key', LIFEATLAS_LOGIN_USERNAME: 'test-user', LIFEATLAS_LOGIN_PASSWORD: 'test-password-12345', LIFEATLAS_AUTH_SIGNING_KEY: 'test-signing-key-with-at-least-32-characters'};
  const denied = await worker.fetch(new Request('https://example.test/v1/kitchen/recommend', {method: 'POST', body: '{}'}), env);
  assert.equal(denied.status, 401);
  const tokens = await __test.issueTokenPair({username: env.LIFEATLAS_LOGIN_USERNAME, password: env.LIFEATLAS_LOGIN_PASSWORD, signingKey: env.LIFEATLAS_AUTH_SIGNING_KEY});
  t.mock.method(globalThis, 'fetch', async (_url, options) => {
    const body = JSON.parse(options.body);
    assert.equal(body.model, 'doubao-seed-2-1-turbo-260628');
    assert.equal(JSON.parse(body.messages[1].content).inventory[0].name, '鸡蛋');
    return Response.json({choices: [{message: {content: JSON.stringify({recipes: [recipe]})}}]});
  });
  const response = await worker.fetch(new Request('https://example.test/v1/kitchen/recommend', {method: 'POST', headers: {Authorization: `Bearer ${tokens.accessToken}`}, body: JSON.stringify({inventory: [{name: '鸡蛋', amount: 3, unit: '个'}]})}), env);
  assert.equal(response.status, 200);
  assert.equal((await response.json()).recipes[0].name, '鸡蛋汤');
});
