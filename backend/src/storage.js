import fs from 'node:fs';
import path from 'node:path';

const DATA_PATH = path.resolve(process.cwd(), 'data', 'db.json');

const defaultDb = {
  users: [],
  progressByUserId: {},
};

function ensureDbFile() {
  if (!fs.existsSync(path.dirname(DATA_PATH))) {
    fs.mkdirSync(path.dirname(DATA_PATH), { recursive: true });
  }
  if (!fs.existsSync(DATA_PATH)) {
    fs.writeFileSync(DATA_PATH, JSON.stringify(defaultDb, null, 2));
  }
}

export function loadDb() {
  ensureDbFile();
  const raw = fs.readFileSync(DATA_PATH, 'utf8');
  const parsed = JSON.parse(raw);
  return {
    users: Array.isArray(parsed.users) ? parsed.users : [],
    progressByUserId:
      parsed.progressByUserId && typeof parsed.progressByUserId === 'object'
        ? parsed.progressByUserId
        : {},
  };
}

export function saveDb(db) {
  fs.writeFileSync(DATA_PATH, JSON.stringify(db, null, 2));
}
