export function validateEmail(email) {
  if (typeof email !== 'string') return false;
  const value = email.trim().toLowerCase();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

export function validatePassword(password) {
  if (typeof password !== 'string') return false;
  if (password.length < 8 || password.length > 72) return false;
  return /[A-Za-z]/.test(password) && /\d/.test(password);
}

export function sanitizeProgress(progress) {
  if (!progress || typeof progress !== 'object') return null;

  const numberOr = (value, fallback) =>
    typeof value === 'number' && Number.isFinite(value) ? value : fallback;

  const arrayOfStrings = (value) =>
    Array.isArray(value)
      ? value.filter((v) => typeof v === 'string').slice(0, 300)
      : [];

  const safeResults = Array.isArray(progress.results)
    ? progress.results
        .map((entry) => {
          if (!entry || typeof entry !== 'object') return null;
          return {
            scenarioId: numberOr(entry.scenarioId, 0),
            invested: numberOr(entry.invested, 0),
            profit: numberOr(entry.profit, 0),
            returnPercent: numberOr(entry.returnPercent, 0),
            judgementScore: numberOr(entry.judgementScore, 0),
            riskManagementScore: numberOr(entry.riskManagementScore, 0),
            emotionControlScore: numberOr(entry.emotionControlScore, 0),
            hintUsed: Boolean(entry.hintUsed),
            difficulty:
              entry.difficulty === 'easy' ||
              entry.difficulty === 'normal' ||
              entry.difficulty === 'hard'
                ? entry.difficulty
                : 'easy',
            timestamp:
              typeof entry.timestamp === 'string'
                ? entry.timestamp
                : new Date().toISOString(),
            allocationPercent: numberOr(entry.allocationPercent, 50),
          };
        })
        .filter(Boolean)
        .slice(0, 600)
    : [];

  return {
    playerName:
      typeof progress.playerName === 'string' && progress.playerName.trim()
        ? progress.playerName.trim().slice(0, 24)
        : '탐험대원',
    cash: numberOr(progress.cash, 1000),
    rewardPoints: numberOr(progress.rewardPoints, 0),
    currentScenario: numberOr(progress.currentScenario, 0),
    results: safeResults,
    bestStreak: numberOr(progress.bestStreak, 0),
    onboarded: Boolean(progress.onboarded),
    selectedDifficulty:
      progress.selectedDifficulty === 'easy' ||
      progress.selectedDifficulty === 'normal' ||
      progress.selectedDifficulty === 'hard'
        ? progress.selectedDifficulty
        : 'easy',
    learnerAgeBand:
      progress.learnerAgeBand === 'younger' ||
      progress.learnerAgeBand === 'middle' ||
      progress.learnerAgeBand === 'older'
        ? progress.learnerAgeBand
        : 'middle',
    ownedItemIds: arrayOfStrings(progress.ownedItemIds),
    equippedCharacterId:
      typeof progress.equippedCharacterId === 'string'
        ? progress.equippedCharacterId
        : 'char_default',
    equippedHomeId:
      typeof progress.equippedHomeId === 'string'
        ? progress.equippedHomeId
        : 'home_base_default',
    totalPointsSpent: numberOr(progress.totalPointsSpent, 0),
    updatedAt: new Date().toISOString(),
  };
}
