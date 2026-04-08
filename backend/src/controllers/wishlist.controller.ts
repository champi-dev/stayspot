import { Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { AuthRequest } from '../middleware/auth';
import { z } from 'zod';

const prisma = new PrismaClient();

const createWishlistSchema = z.object({ name: z.string().min(1) });
const addListingSchema = z.object({ listingId: z.string().uuid() });

export async function getUserWishlists(req: AuthRequest, res: Response): Promise<void> {
  const wishlists = await prisma.wishlist.findMany({
    where: { userId: req.userId! },
    include: {
      listings: {
        include: {
          listing: {
            include: { images: { take: 1, orderBy: { sortOrder: 'asc' } } },
          },
        },
      },
    },
    orderBy: { id: 'desc' },
  });

  const result = wishlists.map(w => ({
    id: w.id,
    name: w.name,
    listingCount: w.listings.length,
    coverImage: w.listings[0]?.listing.images[0]?.url || null,
    listings: w.listings.map(wl => ({
      id: wl.listing.id,
      title: (wl.listing as any).title,
      imageUrl: wl.listing.images[0]?.url || null,
    })),
  }));

  res.json({ wishlists: result });
}

export async function createWishlist(req: AuthRequest, res: Response): Promise<void> {
  const parsed = createWishlistSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'Validation error', message: 'Name is required' });
    return;
  }

  const wishlist = await prisma.wishlist.create({
    data: { name: parsed.data.name, userId: req.userId! },
  });

  res.status(201).json({ wishlist });
}

export async function addListingToWishlist(req: AuthRequest, res: Response): Promise<void> {
  const wishlistId = req.params.id as string;
  const parsed = addListingSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'Validation error', message: 'listingId is required' });
    return;
  }

  const wishlist = await prisma.wishlist.findUnique({ where: { id: wishlistId } });
  if (!wishlist || wishlist.userId !== req.userId!) {
    res.status(404).json({ error: 'Not found', message: 'Wishlist not found' });
    return;
  }

  await prisma.wishlistListing.upsert({
    where: { wishlistId_listingId: { wishlistId, listingId: parsed.data.listingId } },
    update: {},
    create: { wishlistId, listingId: parsed.data.listingId },
  });

  res.json({ success: true });
}

export async function removeListingFromWishlist(req: AuthRequest, res: Response): Promise<void> {
  const wishlistId = req.params.id as string;
  const listingId = req.params.listingId as string;

  try {
    await prisma.wishlistListing.delete({
      where: { wishlistId_listingId: { wishlistId, listingId } },
    });
    res.json({ success: true });
  } catch {
    res.status(404).json({ error: 'Not found', message: 'Listing not in wishlist' });
  }
}
