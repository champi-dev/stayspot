import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { autocomplete, getPlaceDetails } from '../services/google-places.service';
import { generateListingsForLocation } from '../services/listing-generation.service';

const prisma = new PrismaClient();

export async function searchAutocomplete(req: Request, res: Response): Promise<void> {
  const query = String(req.query.q || '');
  if (!query || query.length < 2) {
    res.json([]);
    return;
  }

  try {
    const suggestions = await autocomplete(query);
    res.json(suggestions);
  } catch (error) {
    console.error('Autocomplete error:', error);
    res.json([]);
  }
}

export async function getOrGenerateLocation(req: Request, res: Response): Promise<void> {
  const placeId = req.params.placeId as string;

  // Check if location already exists in DB
  const existing = await prisma.location.findUnique({
    where: { placeId },
    include: {
      listings: {
        where: { isActive: true },
        include: {
          images: { orderBy: { sortOrder: 'asc' } },
          host: { select: { id: true, firstName: true, lastName: true, avatarUrl: true, isSuperhost: true } },
        },
        orderBy: { averageRating: 'desc' },
      },
    },
  });

  if (existing) {
    res.json({ location: existing, listings: existing.listings });
    return;
  }

  // Get place details from Google
  const details = await getPlaceDetails(placeId as string);
  if (!details) {
    res.status(404).json({ error: 'Not found', message: 'Location not found' });
    return;
  }

  // Create location
  const location = await prisma.location.create({
    data: {
      placeId: details.placeId,
      name: details.name,
      country: details.country,
      latitude: details.latitude,
      longitude: details.longitude,
    },
  });

  // Get host users for generated listings (random assignment)
  const hostUsers = await prisma.user.findMany({ where: { isHost: true }, select: { id: true } });
  if (hostUsers.length === 0) {
    res.status(500).json({ error: 'Server error', message: 'No host user available' });
    return;
  }

  // Generate listings
  try {
    await generateListingsForLocation(
      location.id,
      details.name,
      details.country,
      details.latitude,
      details.longitude,
      hostUsers.map(h => h.id),
    );
  } catch (error) {
    console.error('Generation error:', error);
    res.status(503).json({
      error: 'Service unavailable',
      message: "We're having trouble loading listings for this area. Try again in a moment.",
    });
    return;
  }

  // Fetch the complete data
  const result = await prisma.location.findUnique({
    where: { id: location.id },
    include: {
      listings: {
        where: { isActive: true },
        include: {
          images: { orderBy: { sortOrder: 'asc' } },
          host: { select: { id: true, firstName: true, lastName: true, avatarUrl: true, isSuperhost: true } },
        },
        orderBy: { averageRating: 'desc' },
      },
    },
  });

  res.json({ location: result, listings: result?.listings || [] });
}
