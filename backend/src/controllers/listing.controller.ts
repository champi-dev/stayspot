import { Request, Response } from 'express';
import { PrismaClient, PropertyType, Prisma } from '@prisma/client';

const prisma = new PrismaClient();

export async function searchListings(req: Request, res: Response): Promise<void> {
  const {
    locationId,
    minPrice,
    maxPrice,
    propertyType,
    guests,
    page = '1',
    limit = '20',
  } = req.query;

  const pageNum = parseInt(page as string, 10);
  const limitNum = parseInt(limit as string, 10);

  const where: Prisma.ListingWhereInput = { isActive: true };

  if (locationId) where.locationId = String(locationId);
  if (minPrice) where.pricePerNight = { ...where.pricePerNight as any, gte: parseFloat(String(minPrice)) };
  if (maxPrice) where.pricePerNight = { ...where.pricePerNight as any, lte: parseFloat(String(maxPrice)) };
  if (propertyType) where.propertyType = String(propertyType) as PropertyType;
  if (guests) where.maxGuests = { gte: parseInt(String(guests), 10) };

  const [listings, total] = await Promise.all([
    prisma.listing.findMany({
      where,
      include: {
        images: { orderBy: { sortOrder: 'asc' }, take: 5 },
        host: { select: { id: true, firstName: true, lastName: true, avatarUrl: true, isSuperhost: true } },
        location: { select: { name: true, country: true } },
      },
      orderBy: { averageRating: 'desc' },
      skip: (pageNum - 1) * limitNum,
      take: limitNum,
    }),
    prisma.listing.count({ where }),
  ]);

  res.json({
    listings,
    pagination: {
      page: pageNum,
      limit: limitNum,
      total,
      totalPages: Math.ceil(total / limitNum),
    },
  });
}

export async function getListingById(req: Request, res: Response): Promise<void> {
  const id = req.params.id as string;

  const listing = await prisma.listing.findUnique({
    where: { id },
    include: {
      images: { orderBy: { sortOrder: 'asc' } },
      host: {
        select: {
          id: true,
          firstName: true,
          lastName: true,
          avatarUrl: true,
          bio: true,
          isSuperhost: true,
          createdAt: true,
        },
      },
      location: { select: { name: true, country: true } },
      reviews: {
        take: 6,
        orderBy: { createdAt: 'desc' },
        include: {
          author: { select: { firstName: true, lastName: true, avatarUrl: true } },
        },
      },
    },
  });

  if (!listing) {
    res.status(404).json({ error: 'Not found', message: 'Listing not found' });
    return;
  }

  res.json({ listing });
}

export async function getListingAvailability(req: Request, res: Response): Promise<void> {
  const id = req.params.id as string;

  const m = parseInt(String(req.query.month || ''), 10) || new Date().getMonth() + 1;
  const y = parseInt(String(req.query.year || ''), 10) || new Date().getFullYear();

  const startDate = new Date(y, m - 1, 1);
  const endDate = new Date(y, m, 0);

  const bookings = await prisma.booking.findMany({
    where: {
      listingId: id,
      status: { in: ['CONFIRMED', 'PENDING'] },
      OR: [
        { checkIn: { lte: endDate }, checkOut: { gte: startDate } },
      ],
    },
    select: { checkIn: true, checkOut: true },
  });

  const bookedDates: string[] = [];
  for (const booking of bookings) {
    const current = new Date(booking.checkIn);
    while (current <= booking.checkOut) {
      bookedDates.push(current.toISOString().split('T')[0]);
      current.setDate(current.getDate() + 1);
    }
  }

  res.json({ bookedDates: [...new Set(bookedDates)] });
}

export async function getListingReviews(req: Request, res: Response): Promise<void> {
  const id = req.params.id as string;
  const page = parseInt(String(req.query.page || '1'), 10);
  const limit = parseInt(String(req.query.limit || '10'), 10);

  const [reviews, total] = await Promise.all([
    prisma.review.findMany({
      where: { listingId: id },
      include: {
        author: { select: { firstName: true, lastName: true, avatarUrl: true } },
      },
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * limit,
      take: limit,
    }),
    prisma.review.count({ where: { listingId: id } }),
  ]);

  // Calculate aggregate ratings
  const aggregation = await prisma.review.aggregate({
    where: { listingId: id },
    _avg: {
      rating: true,
      cleanliness: true,
      accuracy: true,
      checkIn: true,
      communication: true,
      location: true,
      value: true,
    },
  });

  res.json({
    reviews,
    averages: aggregation._avg,
    pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
  });
}
