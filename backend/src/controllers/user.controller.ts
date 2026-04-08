import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { AuthRequest } from '../middleware/auth';
import { z } from 'zod';

const prisma = new PrismaClient();

const updateProfileSchema = z.object({
  firstName: z.string().min(1).optional(),
  lastName: z.string().min(1).optional(),
  bio: z.string().optional(),
  phone: z.string().optional(),
});

export async function updateProfile(req: AuthRequest, res: Response): Promise<void> {
  const parsed = updateProfileSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'Validation error', message: parsed.error.errors[0].message });
    return;
  }

  const user = await prisma.user.update({
    where: { id: req.userId! },
    data: parsed.data,
  });

  const { passwordHash, ...rest } = user;
  res.json({ user: rest });
}

export async function getPublicProfile(req: Request, res: Response): Promise<void> {
  const userId = req.params.id as string;

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      firstName: true,
      lastName: true,
      avatarUrl: true,
      bio: true,
      isSuperhost: true,
      createdAt: true,
      listings: {
        where: { isActive: true },
        include: {
          images: { take: 1, orderBy: { sortOrder: 'asc' } },
          location: { select: { name: true } },
        },
        take: 10,
      },
      reviews: {
        select: { rating: true },
      },
    },
  });

  if (!user) {
    res.status(404).json({ error: 'Not found', message: 'User not found' });
    return;
  }

  const avgRating = user.reviews.length > 0
    ? user.reviews.reduce((sum, r) => sum + r.rating, 0) / user.reviews.length
    : 0;

  res.json({
    user: {
      id: user.id,
      firstName: user.firstName,
      lastName: user.lastName,
      avatarUrl: user.avatarUrl,
      bio: user.bio,
      isSuperhost: user.isSuperhost,
      createdAt: user.createdAt,
      listingCount: user.listings.length,
      averageRating: Math.round(avgRating * 10) / 10,
      reviewCount: user.reviews.length,
      listings: user.listings,
    },
  });
}
