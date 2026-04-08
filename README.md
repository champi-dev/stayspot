# StaySpot

A full-featured Airbnb clone built for portfolio demonstration. Browse AI-generated property listings for any location worldwide, complete with real property images, booking flow, wishlists, and messaging.

## Demo

**Login:** `demo@stayspot.com` / `demo1234`

Search any city → AI generates realistic listings on the fly → browse, book, message hosts.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Flutter App                        │
│                                                      │
│  Explore ─── Wishlists ─── Trips ─── Inbox ─── Profile│
│     │                        │          │              │
│  Search ── Listing Detail ── Booking ── Chat          │
│     │            │              │          │           │
└─────┼────────────┼──────────────┼──────────┼───────────┘
      │            │              │          │
      ▼            ▼              ▼          ▼
┌─────────────────────────────────────────────────────┐
│              Express.js REST API                     │
│                                                      │
│  /locations  /listings  /bookings  /wishlists         │
│  /auth       /users     /conversations                │
└──────┬──────────┬───────────────────────┬────────────┘
       │          │                       │
       ▼          ▼                       ▼
  ┌─────────┐ ┌──────────┐        ┌─────────────┐
  │ Google  │ │ OpenAI   │        │ PostgreSQL  │
  │ Places  │ │ GPT-4o   │        │   + Prisma  │
  │   API   │ │  mini    │        │             │
  └─────────┘ └──────────┘        └─────────────┘
```

## How It Works

1. **User searches a city** → Google Places autocomplete provides suggestions
2. **First visit to a city** → OpenAI generates 3 listings instantly, 5 more in the background
3. **Listings get images** → 80 pre-generated Leonardo AI property photos assigned by category
4. **Subsequent visits** → cached in PostgreSQL, loads instantly
5. **Messaging** → OpenAI powers contextual host auto-replies

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.38, Dart 3.10 |
| State | Riverpod |
| Navigation | go_router |
| Backend | Node.js 22, Express.js, TypeScript |
| Database | PostgreSQL 16 (Docker) |
| ORM | Prisma 5 |
| AI | OpenAI GPT-4o-mini (listings, reviews, chat) |
| Images | Leonardo AI (80 pre-seeded property photos) |
| Maps | Google Maps Flutter + Google Places API |
| Auth | JWT (access + refresh tokens) |

## Features

- **Explore** — search any city, filter by price/type/guests/amenities
- **Listing Detail** — image gallery, amenities, reviews with ratings breakdown, Google Map, host profile
- **Booking** — date/guest selection, price breakdown, mock payment with confirmation animation
- **Wishlists** — save/unsave listings, create collections
- **Messaging** — AI-powered host conversations with auto-replies
- **Trips** — upcoming/past bookings with status badges
- **Profile** — edit info, view host profiles, logout
- **Auth** — register/login with JWT, persistent sessions with token refresh

## Quick Start

```bash
# 1. Database
docker compose up -d

# 2. Backend
cd backend
npm install
cp .env.example .env          # Add your API keys
npx prisma migrate dev --name init
npx ts-node scripts/seed-images.ts   # Leonardo AI images (~15 min)
npx prisma db seed                    # OpenAI-generated listings
npm run dev

# 3. Mobile
cd mobile
flutter pub get
flutter run
```

## Project Structure

```
├── backend/
│   ├── src/
│   │   ├── controllers/    # Route handlers (7 controllers)
│   │   ├── services/       # OpenAI generation, Google Places
│   │   ├── middleware/      # JWT auth
│   │   ├── routes/          # API route definitions
│   │   └── validators/      # Zod request validation
│   ├── prisma/              # Schema + seed script
│   └── uploads/images/      # 80 Leonardo AI property photos
│
├── mobile/
│   └── lib/
│       ├── app/             # Theme, router, splash
│       ├── core/            # API client, constants
│       ├── features/        # Feature-first architecture
│       │   ├── auth/
│       │   ├── explore/
│       │   ├── listing_detail/
│       │   ├── booking/
│       │   ├── wishlists/
│       │   ├── inbox/
│       │   └── profile/
│       └── shared/          # Models, widgets
│
└── docker-compose.yml
```

## API Keys Required

| Key | Used For |
|-----|----------|
| `OPENAI_API_KEY` | Listing/review generation, chat auto-replies |
| `GOOGLE_PLACES_API_KEY` | Location autocomplete + geocoding + maps |
| `LEONARDO_API_KEY` | One-time image generation (seed script) |

---

Built with Flutter + Node.js + PostgreSQL + OpenAI + Leonardo AI
