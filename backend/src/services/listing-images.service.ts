// On-the-fly listing image generation via Leonardo AI using
// Nano Banana (gemini-2.5-flash-image). Runs in the background after a
// listing is created: generated images replace the preseeded placeholders.

import fs from 'fs';
import path from 'path';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const LEONARDO_API_KEY = process.env.LEONARDO_API_KEY || '';
const V2 = 'https://cloud.leonardo.ai/api/rest/v2';
const V1 = 'https://cloud.leonardo.ai/api/rest/v1';
const MODEL = 'gemini-2.5-flash-image'; // Nano Banana

const IMAGES_DIR = path.join(__dirname, '..', '..', 'uploads', 'images');

const VIEWS = [
  'wide shot of the living area',
  'bedroom interior',
  'kitchen and dining area',
  'exterior or balcony view',
];

export function imagesEnabled(): boolean {
  return Boolean(LEONARDO_API_KEY && LEONARDO_API_KEY !== 'placeholder');
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function createGeneration(prompt: string): Promise<string> {
  const res = await fetch(`${V2}/generations`, {
    method: 'POST',
    headers: {
      accept: 'application/json',
      authorization: `Bearer ${LEONARDO_API_KEY}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: MODEL,
      parameters: {
        width: 1024,
        height: 768,
        prompt,
        quantity: 1,
        prompt_enhance: 'OFF',
      },
      public: false,
    }),
  });
  if (!res.ok) throw new Error(`Leonardo ${res.status}: ${await res.text()}`);
  const data: any = await res.json();
  if (Array.isArray(data)) {
    throw new Error(`Leonardo error: ${data[0]?.message ?? 'unknown'}`);
  }
  return data.generate.generationId;
}

async function waitForImage(generationId: string, maxWaitMs = 120000): Promise<string> {
  const start = Date.now();
  while (Date.now() - start < maxWaitMs) {
    await sleep(5000);
    const res = await fetch(`${V1}/generations/${generationId}`, {
      headers: { authorization: `Bearer ${LEONARDO_API_KEY}` },
    });
    if (!res.ok) continue;
    const data: any = await res.json();
    const gen = data.generations_by_pk;
    if (gen?.status === 'COMPLETE') {
      const url = gen.generated_images?.[0]?.url;
      if (url) return url;
      throw new Error('Generation complete but no image');
    }
    if (gen?.status === 'FAILED') throw new Error('Generation failed');
  }
  throw new Error('Generation timed out');
}

async function download(url: string, filepath: string): Promise<void> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Download failed: ${res.status}`);
  fs.mkdirSync(path.dirname(filepath), { recursive: true });
  fs.writeFileSync(filepath, Buffer.from(await res.arrayBuffer()));
}

/**
 * Generate unique photos for a listing and swap them in, replacing the
 * preseeded placeholders. Fire-and-forget: callers should .catch().
 */
export async function generateListingImages(
  listingId: string,
  title: string,
  description: string,
  locationName: string,
): Promise<void> {
  if (!imagesEnabled()) return;

  const basePrompt =
    `Professional real estate photography of "${title}" in ${locationName}. ` +
    `${description} Photorealistic, natural light, editorial quality, no people, no text.`;

  const created: { url: string; sortOrder: number }[] = [];

  for (let i = 0; i < VIEWS.length; i++) {
    try {
      const genId = await createGeneration(`${basePrompt} View: ${VIEWS[i]}.`);
      const cdnUrl = await waitForImage(genId);
      const relPath = `/images/generated/${listingId}/${i + 1}.jpg`;
      await download(cdnUrl, path.join(IMAGES_DIR, 'generated', listingId, `${i + 1}.jpg`));
      created.push({ url: relPath, sortOrder: i });
    } catch (err) {
      console.error(`[Images] ${listingId} view ${i + 1} failed:`, err);
    }
  }

  // Swap in generated images only if we got at least 2 usable ones
  if (created.length >= 2) {
    await prisma.$transaction([
      prisma.listingImage.deleteMany({ where: { listingId } }),
      prisma.listingImage.createMany({
        data: created.map((c) => ({ ...c, listingId })),
      }),
    ]);
    console.log(`[Images] ${listingId}: ${created.length} generated images swapped in`);
  }
}
