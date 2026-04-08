import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

const IMAGE_CATEGORIES = [
  'modern-apartment',
  'cozy-cabin',
  'beach-house',
  'city-loft',
  'mountain-chalet',
  'villa-pool',
  'treehouse',
  'houseboat',
  'historic-townhouse',
  'minimalist-studio',
];

const IMAGES_PER_CATEGORY = 8;

async function main() {
  console.log('🌱 Seeding database...');

  // 1. Create demo user
  const passwordHash = await bcrypt.hash('demo1234', 10);
  const demoUser = await prisma.user.upsert({
    where: { email: 'demo@stayspot.com' },
    update: {},
    create: {
      email: 'demo@stayspot.com',
      passwordHash,
      firstName: 'Alex',
      lastName: 'Traveler',
      isHost: true,
      isSuperhost: true,
      bio: 'Passionate traveler and host. Love sharing my homes with guests from around the world.',
    },
  });
  console.log(`✅ Demo user created: ${demoUser.email}`);

  // 1b. Create host users for realistic listings
  const hostData = [
    { email: 'marie@stayspot.com', firstName: 'Marie', lastName: 'Dupont', bio: 'Parisian local with a love for art and architecture. Hosting since 2018.', isSuperhost: true },
    { email: 'james@stayspot.com', firstName: 'James', lastName: 'Chen', bio: 'NYC-based architect who turned spare apartments into unique stays.', isSuperhost: false },
    { email: 'yuki@stayspot.com', firstName: 'Yuki', lastName: 'Tanaka', bio: 'Tokyo native passionate about sharing Japanese culture with visitors.', isSuperhost: true },
    { email: 'sofia@stayspot.com', firstName: 'Sofia', lastName: 'Rodriguez', bio: 'Property manager with 15+ years experience in hospitality.', isSuperhost: false },
    { email: 'lucas@stayspot.com', firstName: 'Lucas', lastName: 'Weber', bio: 'World traveler and Superhost. My places are your home away from home.', isSuperhost: true },
  ];
  const hosts = [];
  for (const h of hostData) {
    const host = await prisma.user.upsert({
      where: { email: h.email },
      update: {},
      create: { ...h, passwordHash, isHost: true },
    });
    hosts.push(host);
  }
  console.log(`✅ ${hosts.length} host users created`);

  // 1c. Create reviewer/guest users for realistic reviews
  const reviewerData = [
    { email: 'emma@guest.com', firstName: 'Emma', lastName: 'Wilson' },
    { email: 'carlos@guest.com', firstName: 'Carlos', lastName: 'Mendez' },
    { email: 'anna@guest.com', firstName: 'Anna', lastName: 'Johansson' },
    { email: 'raj@guest.com', firstName: 'Raj', lastName: 'Patel' },
    { email: 'lisa@guest.com', firstName: 'Lisa', lastName: 'Kim' },
    { email: 'omar@guest.com', firstName: 'Omar', lastName: 'Hassan' },
    { email: 'nina@guest.com', firstName: 'Nina', lastName: 'Petrova' },
    { email: 'tom@guest.com', firstName: 'Tom', lastName: 'Murphy' },
  ];
  const reviewers = [];
  for (const r of reviewerData) {
    const reviewer = await prisma.user.upsert({
      where: { email: r.email },
      update: {},
      create: { ...r, passwordHash, isHost: false },
    });
    reviewers.push(reviewer);
  }
  console.log(`✅ ${reviewers.length} reviewer users created`);

  // 2. Create pre-seeded image records
  let imageCount = 0;
  for (const category of IMAGE_CATEGORIES) {
    for (let i = 1; i <= IMAGES_PER_CATEGORY; i++) {
      const num = String(i).padStart(2, '0');
      const filename = `${category}-${num}.jpg`;
      const path = `/images/${category}/${filename}`;

      await prisma.preseededImage.upsert({
        where: { id: `${category}-${num}` },
        update: {},
        create: {
          id: `${category}-${num}`,
          category,
          filename,
          path,
        },
      });
      imageCount++;
    }
  }
  console.log(`✅ ${imageCount} pre-seeded image records created`);

  // 3. Create seed locations — try OpenAI generation, fall back to hardcoded
  const OPENAI_API_KEY = process.env.OPENAI_API_KEY || '';
  const useOpenAI = OPENAI_API_KEY && !OPENAI_API_KEY.startsWith('sk-placeholder');

  const seedLocations = [
    { data: { placeId: 'ChIJD7fiBh9u5kcRYJSMaMOCCwQ', name: 'Paris, France', country: 'France', latitude: 48.8566, longitude: 2.3522 }, fallback: getParisListings, count: 12 },
    { data: { placeId: 'ChIJOwg_06VPwokRYv534QaPC8g', name: 'New York City, USA', country: 'United States', latitude: 40.7128, longitude: -74.006 }, fallback: getNYCListings, count: 10 },
    { data: { placeId: 'ChIJ51cu8IcbXWARiRtXIothAS4', name: 'Tokyo, Japan', country: 'Japan', latitude: 35.6762, longitude: 139.6503 }, fallback: getTokyoListings, count: 10 },
  ];

  for (const loc of seedLocations) {
    let listings: ListingData[];

    if (useOpenAI) {
      console.log(`🤖 Generating listings for ${loc.data.name} via OpenAI...`);
      try {
        listings = await generateListingsViaOpenAI(loc.data.name, loc.data.country, loc.count);
        console.log(`   ✅ Generated ${listings.length} listings via OpenAI`);
      } catch (err) {
        console.log(`   ⚠️  OpenAI failed, using hardcoded fallback: ${err instanceof Error ? err.message : err}`);
        listings = loc.fallback();
      }
    } else {
      console.log(`📝 Using hardcoded listings for ${loc.data.name} (no OpenAI key)`);
      listings = loc.fallback();
    }

    await seedLocation(hosts, reviewers, loc.data, listings);
  }

  console.log('🎉 Seeding complete!');
}

interface LocationData {
  placeId: string;
  name: string;
  country: string;
  latitude: number;
  longitude: number;
}

interface ListingData {
  title: string;
  description: string;
  propertyType: 'ENTIRE_PLACE' | 'PRIVATE_ROOM' | 'SHARED_ROOM' | 'HOTEL_ROOM';
  pricePerNight: number;
  maxGuests: number;
  bedrooms: number;
  beds: number;
  bathrooms: number;
  amenities: string[];
  houseRules: string[];
  neighborhoodDesc: string;
  imageCategory: string;
  rating: number;
}

async function seedLocation(hosts: { id: string }[], reviewers: { id: string }[], locationData: LocationData, listings: ListingData[]) {
  const location = await prisma.location.upsert({
    where: { placeId: locationData.placeId },
    update: {},
    create: locationData,
  });

  for (const listing of listings) {
    const lat = locationData.latitude + (Math.random() - 0.5) * 0.05;
    const lng = locationData.longitude + (Math.random() - 0.5) * 0.05;
    const hostId = hosts[Math.floor(Math.random() * hosts.length)].id;

    // Get images from matching category
    const images = await prisma.preseededImage.findMany({
      where: { category: listing.imageCategory },
      take: 6,
    });

    const created = await prisma.listing.create({
      data: {
        title: listing.title,
        description: listing.description,
        propertyType: listing.propertyType,
        pricePerNight: listing.pricePerNight,
        maxGuests: listing.maxGuests,
        bedrooms: listing.bedrooms,
        beds: listing.beds,
        bathrooms: listing.bathrooms,
        amenities: listing.amenities,
        houseRules: listing.houseRules,
        neighborhoodDesc: listing.neighborhoodDesc,
        latitude: lat,
        longitude: lng,
        averageRating: listing.rating,
        reviewCount: Math.floor(Math.random() * 80) + 10,
        hostId,
        locationId: location.id,
        images: {
          create: images.map((img, idx) => ({
            url: img.path,
            sortOrder: idx,
            caption: idx === 0 ? 'Main photo' : null,
          })),
        },
      },
    });

    // Create reviews — try OpenAI, fall back to hardcoded
    const reviewCount = Math.floor(Math.random() * 3) + 2;
    const OPENAI_KEY = process.env.OPENAI_API_KEY || '';
    const canUseAI = OPENAI_KEY && !OPENAI_KEY.startsWith('sk-placeholder');

    let aiReviews: any[] | null = null;
    if (canUseAI) {
      try {
        aiReviews = await generateReviewsViaOpenAI(
          listing.title, locationData.name, listing.propertyType, listing.rating, reviewCount
        );
      } catch { /* fall through to hardcoded */ }
    }

    if (aiReviews && aiReviews.length > 0) {
      for (const review of aiReviews) {
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
            authorId: reviewers[Math.floor(Math.random() * reviewers.length)].id,
            listingId: created.id,
          },
        });
      }
    } else {
      for (let i = 0; i < reviewCount; i++) {
        const ratingVariance = (Math.random() - 0.5) * 0.8;
        const reviewRating = Math.min(5, Math.max(1, listing.rating + ratingVariance));
        await prisma.review.create({
          data: {
            rating: Math.round(reviewRating * 10) / 10,
            comment: getRandomReviewComment(),
            cleanliness: randomSubRating(reviewRating),
            accuracy: randomSubRating(reviewRating),
            checkIn: randomSubRating(reviewRating),
            communication: randomSubRating(reviewRating),
            location: randomSubRating(reviewRating),
            value: randomSubRating(reviewRating),
            authorId: reviewers[Math.floor(Math.random() * reviewers.length)].id,
            listingId: created.id,
          },
        });
      }
    }
  }

  console.log(`✅ ${locationData.name}: ${listings.length} listings seeded`);
}

function randomSubRating(base: number): number {
  const variance = (Math.random() - 0.5) * 1.0;
  return Math.round(Math.min(5, Math.max(1, base + variance)) * 10) / 10;
}

function getRandomReviewComment(): string {
  const comments = [
    'Amazing place! Exactly as described. Would definitely stay again.',
    'Great location and very clean. The host was super responsive.',
    'Lovely apartment with beautiful views. Highly recommend!',
    'Perfect for a weekend getaway. Had everything we needed.',
    'Wonderful stay! The neighborhood was charming and quiet.',
    'Exceeded our expectations. Very comfortable and well-equipped.',
    'Fantastic host and beautiful space. Will be back!',
    'Cozy and well-maintained. Great value for the price.',
    'The photos don\'t do it justice - even better in person!',
    'Ideal location for exploring the city. Very convenient.',
    'Spotlessly clean and thoughtfully decorated. A real gem!',
    'We had a wonderful time. The check-in was seamless.',
  ];
  return comments[Math.floor(Math.random() * comments.length)];
}

async function generateListingsViaOpenAI(locationName: string, country: string, count: number): Promise<ListingData[]> {
  const OPENAI_API_KEY = process.env.OPENAI_API_KEY!;

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
  "hostBio": string (1-2 sentences),
  "imageCategory": string (one of: modern-apartment, cozy-cabin, beach-house, city-loft, mountain-chalet, villa-pool, treehouse, houseboat, historic-townhouse, minimalist-studio),
  "rating": number (4.0-5.0)
}`;

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      temperature: 0.8,
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`OpenAI API error ${response.status}: ${text}`);
  }

  const data: any = await response.json();
  const content = data.choices?.[0]?.message?.content;
  if (!content) throw new Error('No content from OpenAI');

  const parsed = JSON.parse(content);
  if (!Array.isArray(parsed)) throw new Error('Response is not an array');

  return parsed.map((item: any) => ({
    title: item.title,
    description: item.description,
    propertyType: item.propertyType,
    pricePerNight: item.pricePerNight,
    maxGuests: item.maxGuests,
    bedrooms: item.bedrooms,
    beds: item.beds,
    bathrooms: item.bathrooms,
    amenities: item.amenities,
    houseRules: item.houseRules,
    neighborhoodDesc: item.neighborhoodDesc,
    imageCategory: item.imageCategory || 'modern-apartment',
    rating: item.rating || (4.0 + Math.random() * 0.8),
  }));
}

// Generate reviews via OpenAI too
async function generateReviewsViaOpenAI(listingTitle: string, location: string, propertyType: string, rating: number, count: number): Promise<{ comment: string; rating: number; cleanliness: number; accuracy: number; checkIn: number; communication: number; location: number; value: number }[]> {
  const OPENAI_API_KEY = process.env.OPENAI_API_KEY!;

  const prompt = `Generate ${count} guest reviews for a ${propertyType} called "${listingTitle}" in ${location}. Rated ${rating}/5 overall.

Each review JSON:
{
  "authorName": string,
  "rating": number (within 0.5 of ${rating}),
  "comment": string (2-4 sentences, realistic traveler voice),
  "cleanliness": number (1-5),
  "accuracy": number (1-5),
  "checkIn": number (1-5),
  "communication": number (1-5),
  "location": number (1-5),
  "value": number (1-5)
}

Respond ONLY with a valid JSON array.`;

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.8,
    }),
  });

  if (!response.ok) throw new Error(`OpenAI review error: ${response.status}`);

  const data: any = await response.json();
  const content = data.choices?.[0]?.message?.content;
  if (!content) throw new Error('No review content');

  return JSON.parse(content);
}

function getParisListings(): ListingData[] {
  return [
    {
      title: 'Charming Marais Apartment with Balcony',
      description: 'Elegant apartment in the heart of Le Marais. Steps from Place des Vosges, this beautifully renovated space blends Parisian charm with modern comfort.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 185,
      maxGuests: 4,
      bedrooms: 2,
      beds: 2,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'washer', 'elevator', 'tv', 'workspace'],
      houseRules: ['No smoking', 'No parties', 'Quiet hours after 10pm'],
      neighborhoodDesc: 'Le Marais is one of Paris\'s most vibrant neighborhoods, known for its historic architecture, trendy boutiques, and lively café scene.',
      imageCategory: 'modern-apartment',
      rating: 4.8,
    },
    {
      title: 'Montmartre Artist Loft with City Views',
      description: 'Spacious artist loft near Sacré-Cœur with panoramic views of Paris. Bright, open-plan living with original exposed beams and artistic touches throughout.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 210,
      maxGuests: 3,
      bedrooms: 1,
      beds: 2,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'balcony', 'tv', 'workspace', 'washer'],
      houseRules: ['No smoking', 'No pets', 'Quiet hours after 11pm'],
      neighborhoodDesc: 'Montmartre is famous for its artistic heritage, cobblestone streets, and the stunning Sacré-Cœur basilica.',
      imageCategory: 'city-loft',
      rating: 4.7,
    },
    {
      title: 'Cozy Saint-Germain Studio',
      description: 'Perfectly located studio on a quiet street in Saint-Germain-des-Prés. Ideal for couples seeking authentic Parisian living near world-class cafés and galleries.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 130,
      maxGuests: 2,
      bedrooms: 1,
      beds: 1,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'washer', 'tv', 'ac'],
      houseRules: ['No smoking', 'No parties'],
      neighborhoodDesc: 'Saint-Germain-des-Prés is the intellectual heart of Paris, filled with legendary cafés, bookshops, and art galleries.',
      imageCategory: 'minimalist-studio',
      rating: 4.6,
    },
    {
      title: 'Elegant Haussmann Flat near Champs-Élysées',
      description: 'Stunning Haussmannian apartment with high ceilings, ornate moldings, and period fireplaces. Walking distance to the Arc de Triomphe and luxury shopping.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 320,
      maxGuests: 6,
      bedrooms: 3,
      beds: 4,
      bathrooms: 2,
      amenities: ['wifi', 'kitchen', 'washer', 'dryer', 'elevator', 'doorman', 'tv', 'workspace'],
      houseRules: ['No smoking', 'No parties', 'No shoes indoors'],
      neighborhoodDesc: 'The 8th arrondissement is Paris\'s most prestigious district, home to the Champs-Élysées and world-renowned luxury boutiques.',
      imageCategory: 'historic-townhouse',
      rating: 4.9,
    },
    {
      title: 'Bright Room in Latin Quarter Home',
      description: 'Private room in a friendly local\'s home in the Latin Quarter. Shared kitchen and living room. Perfect for budget-conscious travelers.',
      propertyType: 'PRIVATE_ROOM',
      pricePerNight: 65,
      maxGuests: 2,
      bedrooms: 1,
      beds: 1,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'washer', 'tv'],
      houseRules: ['No smoking', 'Quiet hours after 10pm', 'Clean shared spaces'],
      neighborhoodDesc: 'The Latin Quarter buzzes with student energy, featuring the Panthéon, Luxembourg Gardens, and countless bistros.',
      imageCategory: 'modern-apartment',
      rating: 4.4,
    },
    {
      title: 'Seine-View Penthouse with Terrace',
      description: 'Luxurious penthouse with a private terrace overlooking the Seine. Enjoy morning coffee with views of Notre-Dame and the Eiffel Tower.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 450,
      maxGuests: 4,
      bedrooms: 2,
      beds: 2,
      bathrooms: 2,
      amenities: ['wifi', 'kitchen', 'balcony', 'washer', 'dryer', 'ac', 'tv', 'workspace', 'elevator', 'doorman'],
      houseRules: ['No smoking', 'No parties', 'No pets'],
      neighborhoodDesc: 'Île Saint-Louis offers one of the most romantic settings in Paris, surrounded by the Seine with views of Notre-Dame.',
      imageCategory: 'city-loft',
      rating: 4.95,
    },
    {
      title: 'Bohemian Belleville Creative Space',
      description: 'Colorful, eclectic apartment in multicultural Belleville. Street art at your doorstep, authentic food from around the world, and the best sunset views in Paris.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 110,
      maxGuests: 3,
      bedrooms: 1,
      beds: 2,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'washer', 'balcony', 'workspace'],
      houseRules: ['No smoking indoors', 'Recycling required'],
      neighborhoodDesc: 'Belleville is Paris\'s most diverse and creative neighborhood, a melting pot of cultures with amazing street food and art.',
      imageCategory: 'modern-apartment',
      rating: 4.5,
    },
    {
      title: 'Classic Parisian Pied-à-Terre in Opéra',
      description: 'Charming one-bedroom near Palais Garnier. Classic French décor with modern amenities. Ideal base for exploring central Paris.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 165,
      maxGuests: 2,
      bedrooms: 1,
      beds: 1,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'ac', 'tv', 'elevator'],
      houseRules: ['No smoking', 'No parties', 'Check-out by 11am'],
      neighborhoodDesc: 'The Opéra district combines grand Haussmannian architecture with world-class department stores and the magnificent Palais Garnier.',
      imageCategory: 'historic-townhouse',
      rating: 4.6,
    },
    {
      title: 'Modern Bastille Loft with Mezzanine',
      description: 'Industrial-chic loft in the trendy Bastille area. High ceilings, mezzanine bedroom, and a vibrant nightlife scene right outside.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 155,
      maxGuests: 2,
      bedrooms: 1,
      beds: 1,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'washer', 'tv', 'workspace', 'ac'],
      houseRules: ['No smoking', 'No parties'],
      neighborhoodDesc: 'Bastille is a lively hub for nightlife, dining, and culture, anchored by the famous Place de la Bastille and its many bars and restaurants.',
      imageCategory: 'city-loft',
      rating: 4.7,
    },
    {
      title: 'Quiet Room near Canal Saint-Martin',
      description: 'Peaceful private room in a modern flat near the picturesque Canal Saint-Martin. Great neighborhood for morning walks and local brunch spots.',
      propertyType: 'PRIVATE_ROOM',
      pricePerNight: 55,
      maxGuests: 1,
      bedrooms: 1,
      beds: 1,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'washer'],
      houseRules: ['No smoking', 'Quiet hours after 10pm', 'Clean up after yourself'],
      neighborhoodDesc: 'Canal Saint-Martin is a trendy area loved for its tree-lined waterways, hip boutiques, and charming iron footbridges.',
      imageCategory: 'minimalist-studio',
      rating: 4.3,
    },
    {
      title: 'Luxury Villa near Bois de Boulogne',
      description: 'Stunning private villa with garden and pool access near the Bois de Boulogne. Five bedrooms, perfect for family gatherings or group stays.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 550,
      maxGuests: 10,
      bedrooms: 5,
      beds: 7,
      bathrooms: 3,
      amenities: ['wifi', 'kitchen', 'pool', 'parking', 'washer', 'dryer', 'garden', 'bbq', 'tv', 'ac'],
      houseRules: ['No parties over 10 people', 'Pool hours 8am-9pm', 'No smoking indoors'],
      neighborhoodDesc: 'The 16th arrondissement offers a tranquil, residential atmosphere with the sprawling Bois de Boulogne park at your doorstep.',
      imageCategory: 'villa-pool',
      rating: 4.85,
    },
    {
      title: 'Stylish Duplex in Le Marais',
      description: 'Two-story duplex apartment in a 17th-century building. Original stone walls meet designer furniture. Rooftop access for unforgettable Paris sunsets.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 275,
      maxGuests: 4,
      bedrooms: 2,
      beds: 3,
      bathrooms: 1.5,
      amenities: ['wifi', 'kitchen', 'washer', 'tv', 'workspace', 'ac', 'balcony'],
      houseRules: ['No smoking', 'No parties', 'Respect the historic building'],
      neighborhoodDesc: 'Le Marais blends medieval Paris with contemporary culture — cobblestone lanes, concept stores, and the Place des Vosges.',
      imageCategory: 'historic-townhouse',
      rating: 4.75,
    },
  ];
}

function getNYCListings(): ListingData[] {
  return [
    {
      title: 'SoHo Designer Loft with Skylight',
      description: 'Sun-drenched industrial loft in the heart of SoHo. Cast-iron architecture, massive skylight, and surrounded by the best galleries and shopping in NYC.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 280,
      maxGuests: 4,
      bedrooms: 1,
      beds: 2,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'ac', 'washer', 'dryer', 'elevator', 'workspace', 'tv'],
      houseRules: ['No smoking', 'No parties', 'Quiet hours after 10pm'],
      neighborhoodDesc: 'SoHo is a vibrant neighborhood known for its cast-iron architecture, upscale boutiques, and thriving art scene.',
      imageCategory: 'city-loft',
      rating: 4.8,
    },
    {
      title: 'Brooklyn Brownstone Garden Apartment',
      description: 'Charming garden-level apartment in a classic Brooklyn brownstone. Private patio, exposed brick, and a short subway ride to Manhattan.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 175,
      maxGuests: 3,
      bedrooms: 1,
      beds: 1,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'washer', 'garden', 'tv', 'workspace'],
      houseRules: ['No smoking', 'No loud music after 9pm'],
      neighborhoodDesc: 'Park Slope is one of Brooklyn\'s most beloved neighborhoods, with tree-lined streets, Prospect Park, and excellent restaurants.',
      imageCategory: 'historic-townhouse',
      rating: 4.7,
    },
    {
      title: 'Midtown Skyline View Studio',
      description: 'Modern high-rise studio with floor-to-ceiling windows and spectacular Manhattan skyline views. Perfect location for Times Square and Broadway.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 220,
      maxGuests: 2,
      bedrooms: 1,
      beds: 1,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'ac', 'gym', 'elevator', 'doorman', 'tv'],
      houseRules: ['No smoking', 'No parties', 'Building quiet hours 11pm-7am'],
      neighborhoodDesc: 'Midtown Manhattan is the iconic heart of NYC — Broadway theaters, Rockefeller Center, and the energy of Times Square.',
      imageCategory: 'minimalist-studio',
      rating: 4.5,
    },
    {
      title: 'West Village Townhouse Suite',
      description: 'Beautifully appointed suite in a historic West Village townhouse. Fireplaces, original hardwood floors, and the charm of old New York.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 350,
      maxGuests: 4,
      bedrooms: 2,
      beds: 2,
      bathrooms: 1.5,
      amenities: ['wifi', 'kitchen', 'fireplace', 'washer', 'dryer', 'tv', 'ac', 'workspace'],
      houseRules: ['No smoking', 'No parties', 'No shoes on hardwood floors'],
      neighborhoodDesc: 'The West Village is quintessential New York, with winding streets, jazz clubs, cozy cafés, and a thriving food scene.',
      imageCategory: 'historic-townhouse',
      rating: 4.9,
    },
    {
      title: 'Cozy Room in Harlem Apartment',
      description: 'Private room in a welcoming Harlem home. Experience authentic NYC culture with incredible soul food, live jazz, and friendly neighbors.',
      propertyType: 'PRIVATE_ROOM',
      pricePerNight: 75,
      maxGuests: 2,
      bedrooms: 1,
      beds: 1,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'washer', 'tv'],
      houseRules: ['No smoking', 'Quiet hours after 10pm', 'Respect shared spaces'],
      neighborhoodDesc: 'Harlem is a cultural powerhouse, famous for the Apollo Theater, soul food restaurants, and a rich African American heritage.',
      imageCategory: 'modern-apartment',
      rating: 4.4,
    },
    {
      title: 'Williamsburg Penthouse with Rooftop',
      description: 'Sleek penthouse in Williamsburg with private rooftop access. Stunning views of the Manhattan skyline, surrounded by Brooklyn\'s coolest bars and restaurants.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 310,
      maxGuests: 5,
      bedrooms: 2,
      beds: 3,
      bathrooms: 2,
      amenities: ['wifi', 'kitchen', 'ac', 'washer', 'dryer', 'balcony', 'bbq', 'tv', 'workspace'],
      houseRules: ['No smoking', 'Rooftop quiet hours after 10pm', 'No parties over 6 people'],
      neighborhoodDesc: 'Williamsburg is Brooklyn\'s trendiest neighborhood, packed with craft breweries, vintage shops, and waterfront parks.',
      imageCategory: 'city-loft',
      rating: 4.75,
    },
    {
      title: 'Chelsea Art District Modern Flat',
      description: 'Contemporary apartment in the heart of Chelsea\'s gallery district. Walk to the High Line, Chelsea Market, and Hudson Yards.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 240,
      maxGuests: 3,
      bedrooms: 1,
      beds: 1,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'ac', 'gym', 'elevator', 'doorman', 'tv', 'workspace'],
      houseRules: ['No smoking', 'No parties'],
      neighborhoodDesc: 'Chelsea is NYC\'s premier art district, home to hundreds of galleries, the High Line park, and Chelsea Market.',
      imageCategory: 'modern-apartment',
      rating: 4.6,
    },
    {
      title: 'East Village Eclectic Studio',
      description: 'Quirky, character-filled studio in the East Village. Surrounded by the best ramen shops, dive bars, and vintage stores in the city.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 145,
      maxGuests: 2,
      bedrooms: 1,
      beds: 1,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'ac', 'tv'],
      houseRules: ['No smoking', 'No parties'],
      neighborhoodDesc: 'The East Village is a hub of counterculture, with eclectic restaurants, live music venues, and a gritty, authentic NYC vibe.',
      imageCategory: 'minimalist-studio',
      rating: 4.5,
    },
    {
      title: 'Upper West Side Family Apartment',
      description: 'Spacious family-friendly apartment steps from Central Park and the American Museum of Natural History. Three bedrooms with plenty of space for everyone.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 395,
      maxGuests: 8,
      bedrooms: 3,
      beds: 5,
      bathrooms: 2,
      amenities: ['wifi', 'kitchen', 'washer', 'dryer', 'ac', 'elevator', 'doorman', 'tv'],
      houseRules: ['No smoking', 'No parties', 'Quiet hours after 10pm'],
      neighborhoodDesc: 'The Upper West Side is a family-friendly neighborhood with Central Park, Lincoln Center, and some of the best museums in the world.',
      imageCategory: 'modern-apartment',
      rating: 4.8,
    },
    {
      title: 'Financial District High-Rise Studio',
      description: 'Modern studio in a luxury high-rise near Wall Street. Gym, pool, and concierge included. Walk to the Statue of Liberty ferry.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 195,
      maxGuests: 2,
      bedrooms: 1,
      beds: 1,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'ac', 'gym', 'pool', 'elevator', 'doorman', 'tv', 'workspace'],
      houseRules: ['No smoking', 'No parties', 'Building rules apply'],
      neighborhoodDesc: 'The Financial District has evolved into a vibrant residential area with waterfront parks, historic landmarks, and easy access to all of Manhattan.',
      imageCategory: 'minimalist-studio',
      rating: 4.55,
    },
  ];
}

function getTokyoListings(): ListingData[] {
  return [
    {
      title: 'Shibuya Modern Apartment with City Views',
      description: 'Sleek, modern apartment in the heart of Shibuya. Watch the famous scramble crossing from your window and explore Tokyo\'s trendiest district.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 150,
      maxGuests: 3,
      bedrooms: 1,
      beds: 2,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'ac', 'washer', 'tv'],
      houseRules: ['No smoking', 'No parties', 'Remove shoes at entrance'],
      neighborhoodDesc: 'Shibuya is Tokyo\'s youth culture hub, famous for the scramble crossing, department stores, and vibrant nightlife.',
      imageCategory: 'minimalist-studio',
      rating: 4.7,
    },
    {
      title: 'Traditional Asakusa Townhouse',
      description: 'Experience authentic Japanese living in this beautifully restored machiya near Senso-ji temple. Tatami rooms, futon beds, and a private garden.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 180,
      maxGuests: 4,
      bedrooms: 2,
      beds: 3,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'ac', 'washer', 'garden', 'tv'],
      houseRules: ['No smoking', 'Remove shoes at entrance', 'Respect neighbors quiet hours'],
      neighborhoodDesc: 'Asakusa is Tokyo\'s most traditional neighborhood, home to Senso-ji temple, Nakamise shopping street, and old-world charm.',
      imageCategory: 'historic-townhouse',
      rating: 4.85,
    },
    {
      title: 'Shinjuku Compact Studio near Station',
      description: 'Efficient and clean studio just 3 minutes from Shinjuku Station. Perfect base for exploring all of Tokyo with easy train access everywhere.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 95,
      maxGuests: 2,
      bedrooms: 1,
      beds: 1,
      bathrooms: 1,
      amenities: ['wifi', 'ac', 'washer', 'tv'],
      houseRules: ['No smoking', 'No parties', 'Quiet hours after 10pm'],
      neighborhoodDesc: 'Shinjuku is one of Tokyo\'s busiest districts, with the world\'s busiest train station, endless restaurants, and neon-lit entertainment.',
      imageCategory: 'minimalist-studio',
      rating: 4.5,
    },
    {
      title: 'Roppongi Hills Designer Apartment',
      description: 'High-end designer apartment in the Roppongi Hills complex. Stunning Tokyo Tower views, walking distance to Mori Art Museum and top restaurants.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 290,
      maxGuests: 4,
      bedrooms: 2,
      beds: 2,
      bathrooms: 1.5,
      amenities: ['wifi', 'kitchen', 'ac', 'washer', 'dryer', 'gym', 'elevator', 'doorman', 'tv', 'workspace'],
      houseRules: ['No smoking', 'No parties', 'Building rules apply'],
      neighborhoodDesc: 'Roppongi is Tokyo\'s cosmopolitan district, mixing international dining, contemporary art, and vibrant nightlife.',
      imageCategory: 'modern-apartment',
      rating: 4.8,
    },
    {
      title: 'Cozy Room in Shimokitazawa Home',
      description: 'Private room in a local family\'s home in bohemian Shimokitazawa. Experience real Japanese daily life in Tokyo\'s most artistic neighborhood.',
      propertyType: 'PRIVATE_ROOM',
      pricePerNight: 55,
      maxGuests: 1,
      bedrooms: 1,
      beds: 1,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'ac', 'washer'],
      houseRules: ['No smoking', 'Remove shoes at entrance', 'Quiet hours after 9pm'],
      neighborhoodDesc: 'Shimokitazawa is Tokyo\'s bohemian heart, filled with vintage shops, indie theaters, and cozy coffee shops.',
      imageCategory: 'modern-apartment',
      rating: 4.4,
    },
    {
      title: 'Ginza Luxury Suite with Butler Service',
      description: 'Ultra-premium suite in the Ginza district with dedicated concierge. Marble bathrooms, premium linens, and panoramic views of the Imperial Palace gardens.',
      propertyType: 'HOTEL_ROOM',
      pricePerNight: 480,
      maxGuests: 2,
      bedrooms: 1,
      beds: 1,
      bathrooms: 1,
      amenities: ['wifi', 'ac', 'gym', 'elevator', 'doorman', 'tv', 'workspace', 'hot_tub'],
      houseRules: ['No smoking', 'Formal dress in common areas'],
      neighborhoodDesc: 'Ginza is Tokyo\'s most upscale shopping district, with flagship luxury stores, Michelin-starred restaurants, and kabuki theater.',
      imageCategory: 'modern-apartment',
      rating: 4.95,
    },
    {
      title: 'Harajuku Colorful Flat near Takeshita',
      description: 'Fun and vibrant flat decorated with Japanese pop culture touches, steps from Takeshita Street and Meiji Shrine. Perfect for culture lovers.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 120,
      maxGuests: 2,
      bedrooms: 1,
      beds: 1,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'ac', 'washer', 'tv'],
      houseRules: ['No smoking', 'No parties', 'Remove shoes at entrance'],
      neighborhoodDesc: 'Harajuku is Tokyo\'s fashion capital, famous for Takeshita Street, cosplay culture, and the serene Meiji Shrine.',
      imageCategory: 'minimalist-studio',
      rating: 4.6,
    },
    {
      title: 'Meguro River Apartment with Cherry Views',
      description: 'Beautiful apartment overlooking the Meguro River, one of Tokyo\'s best cherry blossom viewing spots. Calm residential area with great local dining.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 165,
      maxGuests: 3,
      bedrooms: 1,
      beds: 2,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'ac', 'washer', 'balcony', 'tv'],
      houseRules: ['No smoking', 'No parties', 'Quiet hours after 10pm'],
      neighborhoodDesc: 'Nakameguro is a fashionable neighborhood known for the cherry blossom-lined Meguro River, stylish cafés, and curated boutiques.',
      imageCategory: 'modern-apartment',
      rating: 4.7,
    },
    {
      title: 'Akihabara Tech Hub Studio',
      description: 'Modern studio in the heart of Electric Town. Surrounded by anime shops, gaming centers, and maid cafés. A tech lover\'s dream location.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 85,
      maxGuests: 2,
      bedrooms: 1,
      beds: 1,
      bathrooms: 1,
      amenities: ['wifi', 'ac', 'tv'],
      houseRules: ['No smoking', 'No parties'],
      neighborhoodDesc: 'Akihabara is the global center of otaku culture, packed with electronics shops, anime stores, and arcade gaming centers.',
      imageCategory: 'minimalist-studio',
      rating: 4.3,
    },
    {
      title: 'Yanaka Heritage Home with Garden',
      description: 'Charming traditional house in Yanaka, one of Tokyo\'s few neighborhoods that survived WWII. Peaceful garden, wooden architecture, and timeless atmosphere.',
      propertyType: 'ENTIRE_PLACE',
      pricePerNight: 200,
      maxGuests: 5,
      bedrooms: 2,
      beds: 4,
      bathrooms: 1,
      amenities: ['wifi', 'kitchen', 'garden', 'washer', 'tv'],
      houseRules: ['No smoking', 'Remove shoes at entrance', 'Respect the historic property', 'Quiet hours after 9pm'],
      neighborhoodDesc: 'Yanaka is old Tokyo preserved, with narrow lanes, traditional shops, temples, and a nostalgic atmosphere unlike anywhere else in the city.',
      imageCategory: 'historic-townhouse',
      rating: 4.8,
    },
  ];
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
