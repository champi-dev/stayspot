import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';

dotenv.config();

const LEONARDO_API_KEY = process.env.LEONARDO_API_KEY || '';
const BASE_URL = 'https://cloud.leonardo.ai/api/rest/v1';
const BASE_URL_V2 = 'https://cloud.leonardo.ai/api/rest/v2';
// Nano Banana = Gemini 2.5 Flash Image
const MODEL = 'gemini-2.5-flash-image';
const IMAGES_DIR = path.join(__dirname, '..', 'uploads', 'images');

const CATEGORIES = [
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

const VIEWS = [
  'interior living room',
  'interior bedroom',
  'interior kitchen',
  'interior bathroom',
  'exterior facade',
  'terrace with view',
  'dining area',
  'close-up of design details',
];

const CATEGORY_LABELS: Record<string, string> = {
  'modern-apartment': 'modern apartment',
  'cozy-cabin': 'cozy cabin in the woods',
  'beach-house': 'beach house by the ocean',
  'city-loft': 'urban city loft',
  'mountain-chalet': 'mountain chalet',
  'villa-pool': 'luxury villa with pool',
  'treehouse': 'treehouse retreat',
  'houseboat': 'houseboat on calm water',
  'historic-townhouse': 'historic European townhouse',
  'minimalist-studio': 'minimalist studio apartment',
};

async function sleep(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function createGeneration(prompt: string, numImages: number = 1): Promise<string> {
  const response = await fetch(`${BASE_URL_V2}/generations`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${LEONARDO_API_KEY}`,
      'Content-Type': 'application/json',
      accept: 'application/json',
    },
    body: JSON.stringify({
      model: MODEL,
      parameters: {
        width: 1024,
        height: 768,
        prompt,
        quantity: numImages,
        prompt_enhance: 'OFF',
      },
      public: false,
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Leonardo API error ${response.status}: ${text}`);
  }

  const data: any = await response.json();
  if (Array.isArray(data)) {
    throw new Error(`Leonardo error: ${data[0]?.message ?? 'unknown'}`);
  }
  return data.generate.generationId;
}

async function waitForGeneration(generationId: string, maxWait: number = 120000): Promise<string[]> {
  const startTime = Date.now();

  while (Date.now() - startTime < maxWait) {
    await sleep(5000); // Poll every 5 seconds

    const response = await fetch(`${BASE_URL}/generations/${generationId}`, {
      headers: { 'Authorization': `Bearer ${LEONARDO_API_KEY}` },
    });

    if (!response.ok) {
      console.warn(`  Poll failed: ${response.status}`);
      continue;
    }

    const data: any = await response.json();
    const gen = data.generations_by_pk;

    if (gen.status === 'COMPLETE') {
      return gen.generated_images.map((img: any) => img.url);
    } else if (gen.status === 'FAILED') {
      throw new Error(`Generation failed: ${generationId}`);
    }

    process.stdout.write('.');
  }

  throw new Error(`Generation timed out: ${generationId}`);
}

async function downloadImage(url: string, filepath: string): Promise<void> {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Download failed: ${response.status}`);

  const buffer = Buffer.from(await response.arrayBuffer());
  fs.writeFileSync(filepath, buffer);
}

async function main() {
  if (!LEONARDO_API_KEY || LEONARDO_API_KEY === 'placeholder') {
    console.error('❌ LEONARDO_API_KEY not set in .env');
    process.exit(1);
  }

  console.log('🎨 Starting Leonardo AI image generation...');
  console.log(`   ${CATEGORIES.length} categories × ${VIEWS.length} views = ${CATEGORIES.length * VIEWS.length} images`);
  console.log('   This will take approximately 15-30 minutes.\n');

  // Create all category directories
  for (const category of CATEGORIES) {
    const dir = path.join(IMAGES_DIR, category);
    fs.mkdirSync(dir, { recursive: true });
  }

  let totalGenerated = 0;
  let totalSkipped = 0;

  for (const category of CATEGORIES) {
    console.log(`\n📁 Category: ${category}`);
    const categoryLabel = CATEGORY_LABELS[category] || category;
    const categoryDir = path.join(IMAGES_DIR, category);

    for (let i = 0; i < VIEWS.length; i++) {
      const view = VIEWS[i];
      const num = String(i + 1).padStart(2, '0');
      const filename = `${category}-${num}.jpg`;
      const filepath = path.join(categoryDir, filename);

      // Skip if already exists
      if (fs.existsSync(filepath)) {
        console.log(`  ⏭️  ${filename} (already exists)`);
        totalSkipped++;
        continue;
      }

      const prompt = `Photorealistic ${view} of a ${categoryLabel}, professional real estate photography, natural lighting, 4K resolution, interior design magazine style, no people, no text, no watermarks`;

      try {
        process.stdout.write(`  🖼️  ${filename} - generating`);
        const generationId = await createGeneration(prompt, 1);
        const imageUrls = await waitForGeneration(generationId);

        if (imageUrls.length > 0) {
          await downloadImage(imageUrls[0], filepath);
          console.log(` ✅`);
          totalGenerated++;
        } else {
          console.log(` ❌ (no images returned)`);
        }

        // Rate limit: wait 3 seconds between generations
        await sleep(3000);
      } catch (error) {
        console.log(` ❌ (${error instanceof Error ? error.message : 'unknown error'})`);

        // Retry once after longer wait
        console.log(`  ⏳ Retrying in 10 seconds...`);
        await sleep(10000);

        try {
          const generationId = await createGeneration(prompt, 1);
          const imageUrls = await waitForGeneration(generationId);
          if (imageUrls.length > 0) {
            await downloadImage(imageUrls[0], filepath);
            console.log(`  ✅ Retry succeeded`);
            totalGenerated++;
          }
        } catch (retryError) {
          console.log(`  ❌ Retry also failed, skipping`);
        }

        await sleep(5000);
      }
    }
  }

  console.log(`\n🎉 Image seeding complete!`);
  console.log(`   Generated: ${totalGenerated}`);
  console.log(`   Skipped: ${totalSkipped}`);
  console.log(`   Total on disk: ${totalGenerated + totalSkipped}`);
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
