import test from 'node:test';
import assert from 'node:assert/strict';

import { sanitizeProgress, validateEmail, validatePassword } from './validation.js';

test('email validation', () => {
  assert.equal(validateEmail('a@b.com'), true);
  assert.equal(validateEmail('bad-email'), false);
});

test('password validation', () => {
  assert.equal(validatePassword('abc12345'), true);
  assert.equal(validatePassword('short1'), false);
  assert.equal(validatePassword('onlyletters'), false);
});

test('sanitizeProgress keeps core fields safe', () => {
  const clean = sanitizeProgress({
    playerName: '  kid ',
    cash: 123,
    rewardPoints: 30,
    currentScenario: 2,
    selectedDifficulty: 'hard',
    learnerAgeBand: 'older',
    ownedItemIds: ['char_default', 12],
    equippedCharacterId: 'char_default',
    equippedHomeId: 'home_base_default',
    totalPointsSpent: 11,
    results: [{ scenarioId: 1, timestamp: new Date().toISOString() }],
  });

  assert.equal(clean.playerName, 'kid');
  assert.equal(clean.cash, 123);
  assert.equal(clean.selectedDifficulty, 'hard');
  assert.deepEqual(clean.ownedItemIds, ['char_default']);
  assert.equal(clean.results.length, 1);
});
