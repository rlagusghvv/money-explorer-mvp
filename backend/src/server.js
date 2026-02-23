import express from 'express';
import cors from 'cors';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import crypto from 'node:crypto';

import { loadDb, saveDb } from './storage.js';
import { sanitizeProgress, validateEmail, validatePassword } from './validation.js';

const app = express();
const PORT = process.env.PORT || 8787;
const JWT_SECRET = process.env.JWT_SECRET || 'dev-only-change-me';

app.use(cors());
app.use(express.json({ limit: '1mb' }));

function issueToken(user) {
  return jwt.sign({ userId: user.id, email: user.email }, JWT_SECRET, {
    expiresIn: '30d',
  });
}

function authMiddleware(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'UNAUTHORIZED' });
  }
  const token = auth.slice(7);
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    return next();
  } catch {
    return res.status(401).json({ error: 'INVALID_TOKEN' });
  }
}

app.get('/health', (req, res) => {
  res.json({ ok: true, now: new Date().toISOString() });
});

app.post('/auth/signup', async (req, res) => {
  const email = String(req.body?.email ?? '').trim().toLowerCase();
  const password = String(req.body?.password ?? '');

  if (!validateEmail(email)) {
    return res.status(400).json({ error: 'INVALID_EMAIL' });
  }
  if (!validatePassword(password)) {
    return res.status(400).json({ error: 'INVALID_PASSWORD' });
  }

  const db = loadDb();
  if (db.users.some((u) => u.email === email)) {
    return res.status(409).json({ error: 'EMAIL_ALREADY_EXISTS' });
  }

  const passwordHash = await bcrypt.hash(password, 12);
  const user = {
    id: crypto.randomUUID(),
    email,
    passwordHash,
    createdAt: new Date().toISOString(),
  };
  db.users.push(user);
  db.progressByUserId[user.id] = db.progressByUserId[user.id] ?? null;
  saveDb(db);

  const token = issueToken(user);
  return res.status(201).json({
    token,
    user: { id: user.id, email: user.email },
  });
});

app.post('/auth/login', async (req, res) => {
  const email = String(req.body?.email ?? '').trim().toLowerCase();
  const password = String(req.body?.password ?? '');

  const db = loadDb();
  const user = db.users.find((u) => u.email === email);
  if (!user) return res.status(401).json({ error: 'INVALID_CREDENTIALS' });

  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) return res.status(401).json({ error: 'INVALID_CREDENTIALS' });

  const token = issueToken(user);
  return res.json({ token, user: { id: user.id, email: user.email } });
});

app.get('/progress', authMiddleware, (req, res) => {
  const db = loadDb();
  const progress = db.progressByUserId[req.user.userId] ?? null;
  return res.json({ progress });
});

app.put('/progress', authMiddleware, (req, res) => {
  const clean = sanitizeProgress(req.body?.progress);
  if (!clean) return res.status(400).json({ error: 'INVALID_PROGRESS' });

  const db = loadDb();
  db.progressByUserId[req.user.userId] = clean;
  saveDb(db);
  return res.json({ ok: true, progress: clean });
});

app.listen(PORT, () => {
  console.log(`kid-econ backend listening on :${PORT}`);
});
