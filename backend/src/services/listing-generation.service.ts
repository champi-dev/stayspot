import { PrismaClient, PropertyType } from '@prisma/client';
import { z } from 'zod';
import { chatCompletion, extractJson, NO_THINK } from '../config/ai';
import { generateListingImages, imagesEnabled } from './listing-images.service';

const prisma = new PrismaClient();

const generatedListingSchema = z.object({
  title: z.string(),
  description: z.string(),
  propertyType: z.enum(['ENTIRE_PLACE', 'PRIVATE_ROOM', 'SHARED_ROOM']),
  pricePerNight: z.number(),
  maxGuests: z.number(),
  bedrooms: z.number(),
  beds: z.number(),
  bathrooms: z.number(),
  amenities: z.array(z.string()),
  houseRules: z.array(z.string()),
  neighborhoodDesc: z.string(),
  hostName: z.string(),
  hostBio: z.string(),
});

const generatedReviewSchema = z.object({
  authorName: z.string(),
  rating: z.number(),
  comment: z.string(),
  cleanliness: z.number(),
  accuracy: z.number(),
  checkIn: z.number(),
  communication: z.number(),
  location: z.number(),
  value: z.number(),
});

// Map property description keywords to image categories
function getImageCategory(title: string, description: string): string {
  const text = `${title} ${description}`.toLowerCase();
  if (text.match(/cabin|cottage|farmhouse/)) return 'cozy-cabin';
  if (text.match(/beach|coastal|ocean|seaside/)) return 'beach-house';
  if (text.match(/loft|penthouse/)) return 'city-loft';
  if (text.match(/chalet|lodge|mountain/)) return 'mountain-chalet';
  if (text.match(/villa|pool|estate/)) return 'villa-pool';
  if (text.match(/treehouse|tree house|unique/)) return 'treehouse';
  if (text.match(/boat|houseboat|floating/)) return 'houseboat';
  if (text.match(/historic|townhouse|brownstone/)) return 'historic-townhouse';
  if (text.match(/studio|minimalist|compact/)) return 'minimalist-studio';
  return 'modern-apartment';
}

// Helper: pre-fetch images map once
async function getImageMap() {
  const allImages = await prisma.preseededImage.findMany();
  const imagesByCategory = new Map<string, typeof allImages>();
  for (const img of allImages) {
    const list = imagesByCategory.get(img.category) || [];
    list.push(img);
    imagesByCategory.set(img.category, list);
  }
  return imagesByCategory;
}

// Helper: save a single listing to DB
async function saveListing(
  listing: z.infer<typeof generatedListingSchema>,
  locationId: string,
  locationName: string,
  lat: number,
  lng: number,
  hostIds: string[],
  imagesByCategory: Map<string, any[]>,
  usedImagePaths: Set<string>,
) {
  const category = getImageCategory(listing.title, listing.description);
  const catImages = imagesByCategory.get(category) || imagesByCategory.get('modern-apartment') || [];
  // Shuffle and avoid images already used by this batch so listings
  // don't all share the same photos
  const fresh = catImages.filter((img) => !usedImagePaths.has(img.path));
  const pool = fresh.length >= 4 ? fresh : catImages;
  const shuffled = [...pool].sort(() => Math.random() - 0.5);
  const selectedImages = shuffled.slice(0, 5);
  selectedImages.forEach((img) => usedImagePaths.add(img.path));

  const rating = Math.round((Math.random() * 1.0 + 4.0) * 10) / 10;
  const latOffset = (Math.random() - 0.5) * 0.06;
  const lngOffset = (Math.random() - 0.5) * 0.06;
  const hostId = hostIds[Math.floor(Math.random() * hostIds.length)];

  const created = await prisma.listing.create({
    data: {
      title: listing.title,
      description: listing.description,
      propertyType: listing.propertyType as PropertyType,
      pricePerNight: listing.pricePerNight,
      maxGuests: listing.maxGuests,
      bedrooms: listing.bedrooms,
      beds: listing.beds,
      bathrooms: listing.bathrooms,
      amenities: listing.amenities,
      houseRules: listing.houseRules,
      neighborhoodDesc: listing.neighborhoodDesc,
      latitude: lat + latOffset,
      longitude: lng + lngOffset,
      averageRating: rating,
      reviewCount: Math.floor(Math.random() * 80) + 5,
      hostId,
      locationId,
      images: {
        create: selectedImages.map((img, idx) => ({
          url: img.path,
          sortOrder: idx,
        })),
      },
    },
  });

  // Unique photos via Leonardo Nano Banana, replacing preseeded ones (background)
  if (imagesEnabled()) {
    generateListingImages(created.id, listing.title, listing.description, locationName)
      .catch(err => console.error('Image gen failed:', err));
  }

  // Reviews in background
  const reviewCount = Math.floor(Math.random() * 3) + 2;
  const reviewerUsers = await prisma.user.findMany({ where: { isHost: false }, select: { id: true }, take: 8 });
  const reviewerIds = reviewerUsers.length > 0 ? reviewerUsers.map(u => u.id) : [hostId];
  generateReviewsViaAI(created.id, reviewerIds, listing.title, locationName, listing.propertyType, rating, reviewCount)
    .catch(err => console.error('Review gen failed:', err));
}

export async function generateListingsForLocation(
  locationId: string,
  locationName: string,
  country: string,
  lat: number,
  lng: number,
  hostIds: string[],
): Promise<void> {
  const imagesByCategory = await getImageMap();
  const usedImagePaths = new Set<string>();

  // FAST PATH: 5 listings for a quick first response (qwen3 local, with
  // hand-written fallback if the model output is unusable)
  console.log(`[Gen] Fast batch: 5 listings for ${locationName}...`);
  let fastListings: z.infer<typeof generatedListingSchema>[];
  try {
    fastListings = await generateViaAI(locationName, country, 5);
  } catch (err) {
    console.error('[Gen] AI generation failed, using fallback:', err);
    fastListings = [];
  }
  if (fastListings.length < 5) {
    fastListings = fastListings.concat(
      generateFallbackListings(locationName, country, 5 - fastListings.length),
    );
  }
  await Promise.all(fastListings.map(l =>
    saveListing(l, locationId, locationName, lat, lng, hostIds, imagesByCategory, usedImagePaths)
  ));
  console.log(`[Gen] Fast batch done. Queuing background batch...`);

  // BACKGROUND: 3 more listings without blocking the response
  generateViaAI(locationName, country, 3).then(async (moreListings) => {
    console.log(`[Gen] Background batch: ${moreListings.length} more for ${locationName}`);
    await Promise.all(moreListings.map(l =>
      saveListing(l, locationId, locationName, lat, lng, hostIds, imagesByCategory, usedImagePaths)
    ));
    console.log(`[Gen] Background batch complete for ${locationName}`);
  }).catch(err => {
    console.error(`[Gen] Background batch failed for ${locationName}:`, err);
  });
}

async function generateViaAI(
  locationName: string,
  country: string,
  count: number,
): Promise<z.infer<typeof generatedListingSchema>[]> {
  const systemPrompt = `You are a creative real estate copywriter generating property listings for a travel platform. Generate realistic, diverse listings for the specified location. Each listing must feel authentic to the local culture and pricing norms.\n\nRespond ONLY with a valid JSON array. No markdown, no explanation.`;

  const userPrompt = `Generate ${count} property listings for ${locationName}, ${country}.

Requirements:
- Mix of property types: apartments, houses, unique stays
- Prices realistic for ${locationName} in USD per night
- Each listing has 4-8 amenities from: wifi, kitchen, pool, parking, ac, washer, dryer, gym, hot_tub, fireplace, workspace, tv, balcony, garden, bbq, elevator, doorman
- Titles should be catchy, 5-10 words
- Descriptions 2-3 sentences, mention neighborhood
- Rating between 4.0-5.0 (weighted toward 4.3-4.8)

JSON schema for each listing:
{
  "title": string,
  "description": string,
  "propertyType": "ENTIRE_PLACE"|"PRIVATE_ROOM"|"SHARED_ROOM",
  "pricePerNight": number,
  "maxGuests": number (1-12),
  "bedrooms": number (1-6),
  "beds": number (1-8),
  "bathrooms": number (1-4, can be .5),
  "amenities": string[],
  "houseRules": string[] (2-4 rules),
  "neighborhoodDesc": string (1-2 sentences),
  "hostName": string (local-sounding name),
  "hostBio": string (1-2 sentences)
}`;

  const content = await chatCompletion(
    [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userPrompt + NO_THINK },
    ],
    { temperature: 0.8, maxTokens: 3000 },
  );

  const parsed = extractJson<unknown[]>(content);
  // Tolerate partially-valid output from the small model: keep what parses
  const valid: z.infer<typeof generatedListingSchema>[] = [];
  for (const item of Array.isArray(parsed) ? parsed : []) {
    const r = generatedListingSchema.safeParse(item);
    if (r.success) valid.push(r.data);
  }
  if (valid.length === 0) throw new Error('No valid listings from AI');
  return valid;
}

async function generateReviewsViaAI(
  listingId: string,
  reviewerIds: string[],
  title: string,
  location: string,
  propertyType: string,
  rating: number,
  count: number,
): Promise<void> {
  const prompt = `Generate ${count} guest reviews for a ${propertyType} called "${title}" in ${location}. Rated ${rating}/5 overall.

Each review JSON:
{
  "authorName": string,
  "rating": number (within 0.5 of ${rating}),
  "comment": string (2-4 sentences),
  "cleanliness": number,
  "accuracy": number,
  "checkIn": number,
  "communication": number,
  "location": number,
  "value": number
}

Respond ONLY with a valid JSON array.`;

  try {
    const content = await chatCompletion(
      [{ role: 'user', content: prompt + NO_THINK }],
      { temperature: 0.8, maxTokens: 1500 },
    );

    const parsed = extractJson<unknown[]>(content);
    const reviews: z.infer<typeof generatedReviewSchema>[] = [];
    for (const item of Array.isArray(parsed) ? parsed : []) {
      const r = generatedReviewSchema.safeParse(item);
      if (r.success) reviews.push(r.data);
    }
    if (reviews.length === 0) throw new Error('No valid reviews from AI');
    for (const review of reviews) {
      await prisma.review.create({
        data: {
          rating: review.rating,
          comment: review.comment,
          cleanliness: review.cleanliness,
          accuracy: review.accuracy,
          checkIn: review.checkIn,
          communication: review.communication,
          location: review.location,
          value: review.value,
          authorId: reviewerIds[Math.floor(Math.random() * reviewerIds.length)],
          listingId,
        },
      });
    }
  } catch {
    // Fallback to generated reviews
    await generateFallbackReviews(listingId, reviewerIds, rating, count);
  }
}

async function generateFallbackReviews(
  listingId: string,
  reviewerIds: string[],
  baseRating: number,
  count: number,
): Promise<void> {
  const comments = [
    'Amazing place! Exactly as described. Would definitely stay again.',
    'Great location and very clean. The host was super responsive.',
    'Lovely apartment with beautiful views. Highly recommend!',
    'Perfect for a weekend getaway. Had everything we needed.',
    'Wonderful stay! The neighborhood was charming and quiet.',
    'Exceeded our expectations. Very comfortable and well-equipped.',
    'Fantastic host and beautiful space. Will be back!',
    'Cozy and well-maintained. Great value for the price.',
  ];

  for (let i = 0; i < count; i++) {
    const variance = (Math.random() - 0.5) * 0.8;
    const rating = Math.min(5, Math.max(1, Math.round((baseRating + variance) * 10) / 10));
    const subRating = () => Math.min(5, Math.max(1, Math.round((baseRating + (Math.random() - 0.5)) * 10) / 10));

    await prisma.review.create({
      data: {
        rating,
        comment: comments[Math.floor(Math.random() * comments.length)],
        cleanliness: subRating(),
        accuracy: subRating(),
        checkIn: subRating(),
        communication: subRating(),
        location: subRating(),
        value: subRating(),
        authorId: reviewerIds[Math.floor(Math.random() * reviewerIds.length)],
        listingId,
      },
    });
  }
}

function generateFallbackListings(
  locationName: string,
  country: string,
  count: number,
): z.infer<typeof generatedListingSchema>[] {
  const templates = [
    { title: `Charming Apartment in ${locationName}`, type: 'ENTIRE_PLACE' as const, price: 120, guests: 4, beds: 2, rooms: 1, bath: 1 },
    { title: `Cozy Studio near City Center`, type: 'ENTIRE_PLACE' as const, price: 85, guests: 2, beds: 1, rooms: 1, bath: 1 },
    { title: `Luxury Penthouse with Panoramic Views`, type: 'ENTIRE_PLACE' as const, price: 280, guests: 4, beds: 2, rooms: 2, bath: 2 },
    { title: `Budget-Friendly Private Room`, type: 'PRIVATE_ROOM' as const, price: 45, guests: 1, beds: 1, rooms: 1, bath: 1 },
    { title: `Modern Loft in Arts District`, type: 'ENTIRE_PLACE' as const, price: 165, guests: 3, beds: 2, rooms: 1, bath: 1 },
    { title: `Spacious Family Home with Garden`, type: 'ENTIRE_PLACE' as const, price: 195, guests: 6, beds: 4, rooms: 3, bath: 2 },
    { title: `Stylish Downtown Flat`, type: 'ENTIRE_PLACE' as const, price: 140, guests: 3, beds: 2, rooms: 1, bath: 1 },
    { title: `Historic Quarter Hideaway`, type: 'ENTIRE_PLACE' as const, price: 155, guests: 2, beds: 1, rooms: 1, bath: 1 },
    { title: `Bright Room in Local Home`, type: 'PRIVATE_ROOM' as const, price: 55, guests: 2, beds: 1, rooms: 1, bath: 1 },
    { title: `Designer Villa with Pool Access`, type: 'ENTIRE_PLACE' as const, price: 350, guests: 8, beds: 5, rooms: 4, bath: 3 },
    { title: `Minimalist Studio near Transport`, type: 'ENTIRE_PLACE' as const, price: 75, guests: 2, beds: 1, rooms: 1, bath: 1 },
    { title: `Elegant Suite with Balcony View`, type: 'ENTIRE_PLACE' as const, price: 200, guests: 2, beds: 1, rooms: 1, bath: 1 },
  ];

  const amenityPool = ['wifi', 'kitchen', 'ac', 'tv', 'washer', 'workspace', 'balcony', 'parking', 'elevator', 'pool', 'gym'];

  return templates.slice(0, count).map((t, i) => {
    const numAmenities = Math.floor(Math.random() * 4) + 4;
    const shuffled = [...amenityPool].sort(() => Math.random() - 0.5);

    return {
      title: t.title,
      description: `Beautiful ${t.type === 'PRIVATE_ROOM' ? 'room' : 'space'} in the heart of ${locationName}. Enjoy local culture, great restaurants, and easy access to top attractions in ${country}.`,
      propertyType: t.type,
      pricePerNight: t.price + Math.floor(Math.random() * 30) - 15,
      maxGuests: t.guests,
      bedrooms: t.rooms,
      beds: t.beds,
      bathrooms: t.bath,
      amenities: shuffled.slice(0, numAmenities),
      houseRules: ['No smoking', 'No parties', 'Quiet hours after 10pm'],
      neighborhoodDesc: `A vibrant area in ${locationName} known for its charm, local dining, and walkability to major sights.`,
      hostName: `Host ${i + 1}`,
      hostBio: `Local resident of ${locationName} who loves sharing their home with travelers from around the world.`,
    };
  });
}
