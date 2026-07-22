// Regenerate descriptions and photos for EXISTING listings so they
// accurately match their real city. For each listing:
//   1. OpenAI rewrites description/neighborhoodDesc (real neighborhoods,
//      landmarks, local architecture) and produces an imagePrompt.
//   2. Old generated image files are deleted and fresh Leonardo images
//      are generated from the accurate imagePrompt.
//
// Run on the server (needs OPENAI_API_KEY + LEONARDO_API_KEY in env):
//   npx ts-node scripts/regenerate-content.ts            # all locations
//   npx ts-node scripts/regenerate-content.ts "Paris"    # one location by name

import fs from 'fs';
import path from 'path';
import { PrismaClient } from '@prisma/client';
import { knowledgeCompletion, openaiEnabled, extractJson } from '../src/config/ai';
import { generateListingImages, imagesEnabled } from '../src/services/listing-images.service';

const prisma = new PrismaClient();
const IMAGES_DIR = path.resolve(process.cwd(), 'uploads', 'images');

interface Rewrite {
  title: string;
  description: string;
  neighborhoodDesc: string;
  imagePrompt: string;
}

async function rewriteListing(
  title: string,
  description: string,
  city: string,
  country: string,
): Promise<Rewrite | null> {
  const prompt = `You are a travel expert with first-hand knowledge of ${city}, ${country}.
Rewrite this vacation-rental listing so it is geographically ACCURATE to ${city}: name a REAL neighborhood, a real nearby landmark/attraction/transit stop, and describe the property using the architecture, era and materials actually typical of that neighborhood. Keep the same general property type and vibe.

Current title: ${title}
Current description: ${description}

Respond ONLY with JSON:
{
  "title": string (catchy, 5-10 words, may reference the real neighborhood),
  "description": string (2-3 sentences, real neighborhood + real landmark + visual detail),
  "neighborhoodDesc": string (1-2 sentences on the actual character of that neighborhood),
  "imagePrompt": string (1-2 sentences for a photo generator: interior/exterior with visually accurate local detail — building style, era, materials, furnishings, what is visible out the window in that part of ${city})
}`;

  try {
    const content = await knowledgeCompletion(
      [{ role: 'user', content: prompt }],
      { temperature: 0.7, maxTokens: 600 },
    );
    return extractJson<Rewrite>(content);
  } catch (err) {
    console.error(`  rewrite failed for "${title}":`, err);
    return null;
  }
}

async function main() {
  if (!openaiEnabled()) {
    console.warn('WARNING: OPENAI_API_KEY not set — rewrites will use the local model (less accurate).');
  }
  if (!imagesEnabled()) {
    console.warn('WARNING: LEONARDO_API_KEY not set — images will NOT be regenerated.');
  }

  const filter = process.argv[2];
  const locations = await prisma.location.findMany({
    where: filter ? { name: { contains: filter, mode: 'insensitive' } } : undefined,
    include: { listings: { where: { isActive: true } } },
  });
  console.log(`${locations.length} location(s), ${locations.reduce((n, l) => n + l.listings.length, 0)} listings`);

  for (const loc of locations) {
    console.log(`\n=== ${loc.name}, ${loc.country} (${loc.listings.length} listings) ===`);
    for (const listing of loc.listings) {
      console.log(`- ${listing.title}`);
      const rw = await rewriteListing(listing.title, listing.description, loc.name, loc.country);
      if (rw) {
        await prisma.listing.update({
          where: { id: listing.id },
          data: {
            title: rw.title,
            description: rw.description,
            neighborhoodDesc: rw.neighborhoodDesc,
          },
        });
        console.log(`  -> "${rw.title}"`);
      }

      if (imagesEnabled()) {
        // Remove old generated files; generateListingImages swaps DB rows
        // only after >=2 new images succeed, so listings never go imageless.
        const dir = path.join(IMAGES_DIR, 'generated', listing.id);
        fs.rmSync(dir, { recursive: true, force: true });
        await generateListingImages(
          listing.id,
          rw?.title ?? listing.title,
          rw?.description ?? listing.description,
          `${loc.name}, ${loc.country}`,
          rw?.imagePrompt,
        );
      }
    }
  }

  console.log('\nDone.');
  await prisma.$disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
