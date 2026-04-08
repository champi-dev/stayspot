import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { PrismaClient } from '@prisma/client';
import { registerSchema, loginSchema, refreshSchema } from '../validators/auth';
import { generateAccessToken, generateRefreshToken, verifyRefreshToken } from '../utils/jwt';
import { AuthRequest } from '../middleware/auth';

const prisma = new PrismaClient();

function sanitizeUser(user: any) {
  const { passwordHash, ...rest } = user;
  return rest;
}

export async function register(req: Request, res: Response): Promise<void> {
  const parsed = registerSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'Validation error', message: parsed.error.errors[0].message });
    return;
  }

  const { email, password, firstName, lastName } = parsed.data;

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    res.status(409).json({ error: 'Conflict', message: 'This email is already registered' });
    return;
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await prisma.user.create({
    data: { email, passwordHash, firstName, lastName },
  });

  const accessToken = generateAccessToken(user.id);
  const refreshToken = generateRefreshToken(user.id);

  res.status(201).json({
    user: sanitizeUser(user),
    accessToken,
    refreshToken,
  });
}

export async function login(req: Request, res: Response): Promise<void> {
  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'Validation error', message: parsed.error.errors[0].message });
    return;
  }

  const { email, password } = parsed.data;

  const user = await prisma.user.findUnique({ where: { email } });
  if (!user) {
    res.status(401).json({ error: 'Unauthorized', message: 'Incorrect email or password' });
    return;
  }

  const valid = await bcrypt.compare(password, user.passwordHash);
  if (!valid) {
    res.status(401).json({ error: 'Unauthorized', message: 'Incorrect email or password' });
    return;
  }

  const accessToken = generateAccessToken(user.id);
  const refreshToken = generateRefreshToken(user.id);

  res.json({
    user: sanitizeUser(user),
    accessToken,
    refreshToken,
  });
}

export async function refresh(req: Request, res: Response): Promise<void> {
  const parsed = refreshSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'Validation error', message: parsed.error.errors[0].message });
    return;
  }

  try {
    const payload = verifyRefreshToken(parsed.data.refreshToken);
    const accessToken = generateAccessToken(payload.userId);
    res.json({ accessToken });
  } catch {
    res.status(401).json({ error: 'Unauthorized', message: 'Invalid or expired refresh token' });
  }
}

export async function me(req: AuthRequest, res: Response): Promise<void> {
  const user = await prisma.user.findUnique({ where: { id: req.userId } });
  if (!user) {
    res.status(404).json({ error: 'Not found', message: 'User not found' });
    return;
  }

  res.json({ user: sanitizeUser(user) });
}
