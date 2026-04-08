# StaySpot — Full Technical Specification

**Airbnb Clone · Flutter + Node.js + PostgreSQL**

| Field    | Value                                |
| -------- | ------------------------------------ |
| Version  | 1.0                                  |
| Author   | Daniel — Senior Fullstack Developer  |
| Purpose  | Local demo / portfolio showcase      |
| Consumer | Claude Code (autonomous agent build) |

> This document serves as the single source of truth for building the StaySpot application. It is structured to be consumed directly by Claude Code for autonomous implementation.

---

## 1. Project Overview

StaySpot is a full-featured Airbnb clone built with Flutter (mobile), Node.js (backend API), and PostgreSQL (database). It is designed exclusively for local demonstration purposes and portfolio showcasing — it will never handle real payments or real bookings.

### 1.1 Core Concept

The app allows users to browse property listings across any location worldwide. Listing data (descriptions, amenities, pricing, host info) is generated on-the-fly using an OpenAI model (GPT-4o-mini or equivalent) when a user searches a new location. Property images are pre-seeded via the Leonardo AI API and recycled across listings to keep demo costs minimal. Location search and autocomplete are powered by Google Places API.

### 1.2 Key Constraints & Decisions

| Constraint                         | Decision                                                                                                                                                                                                                          |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Demo-only, no real payments        | Payment flow is fully mocked — UI shows Stripe-like checkout but no actual charge occurs. A fake confirmation is returned after 2 seconds.                                                                                        |
| Images must look professional      | Leonardo AI API generates 50–100 high-quality property images at setup time. These are stored locally and randomly assigned to generated listings.                                                                                |
| Listings for any location on Earth | When a user searches a location not yet in the DB, the backend calls Google Places API to validate the location, then calls OpenAI to generate 8–15 realistic listings for that area, saves them to PostgreSQL, and returns them. |
| Single-user demo                   | Auth is simplified — email/password with JWT. No OAuth, no email verification. A demo account is pre-seeded.                                                                                                                      |
| Must be beautiful and polished     | The UI follows a design system inspired by Airbnb's clean aesthetic with custom touches. Detailed Figma specs are provided in Section 6.                                                                                          |
| Claude Code will build this        | Every section of this doc is structured for machine consumption: explicit file paths, exact dependencies, concrete data schemas, and no ambiguity.                                                                                |

### 1.3 Questions Flagged for Review

These are decisions where I went with a sensible default but want your sign-off:

- Leonardo AI image generation: I'm speccing 80 images (10 categories × 8 variants). Is that enough variety, or do you want more?
- OpenAI model: I'm using gpt-4o-mini for listing generation (cheapest, fast). If quality matters more, we can switch to gpt-4o.
- Map provider: Google Maps Flutter plugin for the map view. If you prefer Mapbox (free tier is generous), let me know.
- State management: I'm speccing Riverpod. If you prefer Bloc or another approach, flag it.
- Notifications: Skipped entirely for demo scope. Want push notification mocks?

---

## 2. Technology Stack

### 2.1 Frontend — Flutter

| Component        | Details                                                     |
| ---------------- | ----------------------------------------------------------- |
| Framework        | Flutter 3.22+ (latest stable)                               |
| Language         | Dart 3.4+                                                   |
| State Management | Riverpod 2.x (with code generation via riverpod_generator)  |
| Navigation       | go_router 14.x (declarative routing with deep links)        |
| HTTP Client      | dio 5.x (interceptors for JWT refresh, logging)             |
| Local Storage    | shared_preferences (tokens, settings), hive (offline cache) |
| Maps             | google_maps_flutter 2.x                                     |
| Image Caching    | cached_network_image 3.x                                    |
| Date Pickers     | syncfusion_flutter_datepicker or table_calendar             |
| Animations       | flutter_animate, lottie                                     |
| Forms            | reactive_forms or flutter_form_builder                      |
| Testing          | flutter_test, mockito, integration_test                     |

### 2.2 Backend — Node.js

| Component     | Details                                                    |
| ------------- | ---------------------------------------------------------- |
| Runtime       | Node.js 20 LTS                                             |
| Framework     | Express.js 4.x (simple, well-understood)                   |
| ORM           | Prisma 5.x (type-safe queries, migrations, seeding)        |
| Auth          | jsonwebtoken (JWT access + refresh tokens), bcryptjs       |
| Validation    | zod (request body validation, shared schemas)              |
| API Docs      | swagger-jsdoc + swagger-ui-express (auto-generated)        |
| Image Storage | Local filesystem (./uploads/images/) with static serving   |
| External APIs | openai (npm), @google/maps, Leonardo AI REST API via axios |
| Rate Limiting | express-rate-limit (prevent abuse of generation endpoints) |
| Testing       | vitest, supertest                                          |

### 2.3 Database — PostgreSQL

| Component  | Details                                                                                                                  |
| ---------- | ------------------------------------------------------------------------------------------------------------------------ |
| Version    | PostgreSQL 16                                                                                                            |
| ORM        | Prisma (see above)                                                                                                       |
| Extensions | postgis (geospatial queries for nearby listings), pg_trgm (fuzzy text search)                                            |
| Seeding    | Prisma seed script that pre-creates demo user, pre-loads image references, seeds 3 popular locations (Paris, NYC, Tokyo) |

### 2.4 External API Integration

#### 2.4.1 Google Places API

Used for location autocomplete and geocoding. When a user types a destination, the Flutter app calls the backend, which proxies to Google Places Autocomplete. On selection, we get lat/lng + formatted address + place_id.

- Endpoints used: Place Autocomplete, Place Details, Geocoding
- API key stored in backend .env, never exposed to client
- Rate limit: 100 requests/minute (more than enough for demo)

#### 2.4.2 OpenAI API (Listing Generation)

When a location is searched for the first time, the backend generates listings using a structured prompt:

- Model: gpt-4o-mini (fast, cheap, good enough for demo)
- Output: JSON array of 8–15 listings with title, description, property_type, price_per_night, amenities[], max_guests, bedrooms, bathrooms, host_name, host_bio, neighborhood_description
- System prompt enforces realistic pricing for the region, diverse property types, and locally-flavored descriptions
- Response is validated with zod before DB insertion

#### 2.4.3 Leonardo AI API (Image Pre-seeding)

At project setup time (not runtime), a seed script generates property images across 10 categories:

- Categories: Modern apartment, Cozy cabin, Beach house, City loft, Mountain chalet, Villa with pool, Treehouse, Houseboat, Historic townhouse, Minimalist studio
- 8 images per category = 80 images total
- Images downloaded and stored locally in ./uploads/images/[category]/
- Each generated listing is randomly assigned 5–8 images from matching category
- Prompt template: "Photorealistic interior/exterior of a [category], professional real estate photography, natural lighting, 4K, no people, no text"

### 2.5 Project Structure

```
stayspot/
├── mobile/                  # Flutter app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app/              # App config, theme, router
│   │   ├── features/         # Feature-first architecture
│   │   │   ├── auth/
│   │   │   ├── explore/
│   │   │   ├── listing_detail/
│   │   │   ├── booking/
│   │   │   ├── wishlists/
│   │   │   ├── inbox/
│   │   │   └── profile/
│   │   ├── shared/           # Shared widgets, utils, models
│   │   └── core/             # API client, interceptors, constants
│   └── pubspec.yaml
├── backend/                  # Node.js API
│   ├── src/
│   │   ├── index.ts
│   │   ├── routes/
│   │   ├── controllers/
│   │   ├── services/         # Business logic, AI generation
│   │   ├── middleware/
│   │   ├── validators/       # Zod schemas
│   │   └── utils/
│   ├── prisma/
│   │   ├── schema.prisma
│   │   ├── seed.ts
│   │   └── migrations/
│   ├── uploads/images/       # Pre-seeded Leonardo AI images
│   ├── scripts/              # Image seeding script
│   └── package.json
└── docker-compose.yml        # PostgreSQL + backend
```

---

## 3. Database Schema (Prisma)

Below is the complete Prisma schema. Claude Code should use this verbatim in `prisma/schema.prisma`.

### 3.1 Entity Relationship Summary

- User → has many Listings (as host)
- User → has many Bookings (as guest)
- User → has many Reviews (as author)
- User → has many Wishlists
- Listing → has many ListingImages
- Listing → has many Bookings
- Listing → has many Reviews
- Listing → belongs to a Location
- Wishlist → many-to-many with Listings
- Message → belongs to Conversation, sent by User

### 3.2 Full Schema

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

// ─── ENUMS ───

enum PropertyType {
  ENTIRE_PLACE
  PRIVATE_ROOM
  SHARED_ROOM
  HOTEL_ROOM
}

enum BookingStatus {
  PENDING
  CONFIRMED
  CANCELLED
  COMPLETED
}

// ─── MODELS ───

model User {
  id            String    @id @default(uuid())
  email         String    @unique
  passwordHash  String
  firstName     String
  lastName      String
  avatarUrl     String?
  bio           String?
  phone         String?
  isHost        Boolean   @default(false)
  isSuperhost   Boolean   @default(false)
  createdAt     DateTime  @default(now())
  listings      Listing[]
  bookings      Booking[]
  reviews       Review[]
  wishlists     Wishlist[]
  sentMessages  Message[] @relation("sender")
  conversations ConversationParticipant[]
}

model Location {
  id            String    @id @default(uuid())
  placeId       String    @unique  // Google Places ID
  name          String               // "Paris, France"
  country       String
  latitude      Float
  longitude     Float
  generatedAt   DateTime  @default(now())
  listings      Listing[]
}

model Listing {
  id                  String    @id @default(uuid())
  title               String
  description         String
  propertyType        PropertyType
  pricePerNight       Float
  cleaningFee         Float     @default(25)
  serviceFee          Float     @default(15)
  maxGuests           Int
  bedrooms            Int
  beds                Int
  bathrooms           Float
  amenities           String[]  // ["wifi","kitchen","pool"]
  houseRules          String[]
  checkInTime         String    @default("15:00")
  checkOutTime        String    @default("11:00")
  neighborhoodDesc    String?
  latitude            Float
  longitude           Float
  averageRating       Float     @default(0)
  reviewCount         Int       @default(0)
  isActive            Boolean   @default(true)
  createdAt           DateTime  @default(now())
  hostId              String
  host                User      @relation(fields: [hostId], references: [id])
  locationId          String
  location            Location  @relation(fields: [locationId], references: [id])
  images              ListingImage[]
  bookings            Booking[]
  reviews             Review[]
  wishlists           WishlistListing[]
}

model ListingImage {
  id         String  @id @default(uuid())
  url        String  // relative path: /images/modern-apartment/01.jpg
  caption    String?
  sortOrder  Int     @default(0)
  listingId  String
  listing    Listing @relation(fields: [listingId], references: [id])
}

model Booking {
  id            String        @id @default(uuid())
  checkIn       DateTime
  checkOut      DateTime
  guests        Int
  totalPrice    Float
  status        BookingStatus @default(PENDING)
  createdAt     DateTime      @default(now())
  guestId       String
  guest         User          @relation(fields: [guestId], references: [id])
  listingId     String
  listing       Listing       @relation(fields: [listingId], references: [id])
}

model Review {
  id            String   @id @default(uuid())
  rating        Float    // 1.0 - 5.0
  comment       String
  cleanliness   Float
  accuracy      Float
  checkIn       Float
  communication Float
  location      Float
  value         Float
  createdAt     DateTime @default(now())
  authorId      String
  author        User     @relation(fields: [authorId], references: [id])
  listingId     String
  listing       Listing  @relation(fields: [listingId], references: [id])
}

model Wishlist {
  id        String            @id @default(uuid())
  name      String
  userId    String
  user      User              @relation(fields: [userId], references: [id])
  listings  WishlistListing[]
}

model WishlistListing {
  wishlistId String
  wishlist   Wishlist @relation(fields: [wishlistId], references: [id])
  listingId  String
  listing    Listing  @relation(fields: [listingId], references: [id])
  @@id([wishlistId, listingId])
}

model Conversation {
  id           String   @id @default(uuid())
  createdAt    DateTime @default(now())
  participants ConversationParticipant[]
  messages     Message[]
}

model ConversationParticipant {
  conversationId String
  conversation   Conversation @relation(fields: [conversationId], references: [id])
  userId         String
  user           User         @relation(fields: [userId], references: [id])
  @@id([conversationId, userId])
}

model Message {
  id             String       @id @default(uuid())
  content        String
  createdAt      DateTime     @default(now())
  isRead         Boolean      @default(false)
  senderId       String
  sender         User         @relation("sender", fields: [senderId], references: [id])
  conversationId String
  conversation   Conversation @relation(fields: [conversationId], references: [id])
}

model PreseededImage {
  id        String @id @default(uuid())
  category  String // "modern-apartment", "beach-house", etc.
  filename  String // "modern-apartment-01.jpg"
  path      String // "/images/modern-apartment/modern-apartment-01.jpg"
}
```

---

## 4. API Endpoints

All endpoints are prefixed with `/api/v1`. Authentication is via Bearer token (JWT) in the Authorization header.

### 4.1 Auth

| Method | Endpoint       | Description                                                                                                     |
| ------ | -------------- | --------------------------------------------------------------------------------------------------------------- |
| POST   | /auth/register | Create account. Body: `{ email, password, firstName, lastName }`. Returns `{ user, accessToken, refreshToken }` |
| POST   | /auth/login    | Login. Body: `{ email, password }`. Returns `{ user, accessToken, refreshToken }`                               |
| POST   | /auth/refresh  | Refresh access token. Body: `{ refreshToken }`. Returns `{ accessToken }`                                       |
| GET    | /auth/me       | Get current user profile. Requires auth.                                                                        |

### 4.2 Locations & Search

| Method | Endpoint                      | Description                                                                                                                     |
| ------ | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| GET    | /locations/autocomplete?q=par | Proxy to Google Places Autocomplete. Returns `[{ placeId, description, mainText, secondaryText }]`                              |
| GET    | /locations/:placeId           | Get or generate listings for a location. If location not in DB, triggers AI generation flow. Returns `{ location, listings[] }` |

### 4.3 Listings

| Method | Endpoint                                                                     | Description                                         |
| ------ | ---------------------------------------------------------------------------- | --------------------------------------------------- |
| GET    | /listings?locationId=&minPrice=&maxPrice=&propertyType=&guests=&page=&limit= | Search/filter listings. Supports pagination.        |
| GET    | /listings/:id                                                                | Get listing detail with images, host info, reviews. |
| GET    | /listings/:id/availability?month=&year=                                      | Get booked dates for calendar display.              |
| GET    | /listings/:id/reviews?page=&limit=                                           | Paginated reviews for a listing.                    |

### 4.4 Bookings

| Method | Endpoint              | Description                                                                                                                                      |
| ------ | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| POST   | /bookings             | Create booking. Body: `{ listingId, checkIn, checkOut, guests }`. Validates availability, calculates total. Returns booking with PENDING status. |
| POST   | /bookings/:id/confirm | Mock payment confirmation. Changes status to CONFIRMED after 2s fake delay.                                                                      |
| GET    | /bookings             | Get user's bookings (upcoming + past). Requires auth.                                                                                            |
| DELETE | /bookings/:id         | Cancel a booking. Changes status to CANCELLED.                                                                                                   |

### 4.5 Wishlists

| Method | Endpoint                           | Description                                 |
| ------ | ---------------------------------- | ------------------------------------------- |
| GET    | /wishlists                         | Get user's wishlists with listing previews. |
| POST   | /wishlists                         | Create wishlist. Body: `{ name }`.          |
| POST   | /wishlists/:id/listings            | Add listing. Body: `{ listingId }`.         |
| DELETE | /wishlists/:id/listings/:listingId | Remove listing from wishlist.               |

### 4.6 Messaging

| Method | Endpoint                                 | Description                                           |
| ------ | ---------------------------------------- | ----------------------------------------------------- |
| GET    | /conversations                           | Get user's conversations with last message preview.   |
| GET    | /conversations/:id/messages?page=&limit= | Get messages in a conversation.                       |
| POST   | /conversations/:id/messages              | Send message. Body: `{ content }`.                    |
| POST   | /conversations                           | Start conversation. Body: `{ recipientId, content }`. |

### 4.7 User Profile

| Method | Endpoint          | Description                                                  |
| ------ | ----------------- | ------------------------------------------------------------ |
| PUT    | /users/me         | Update profile. Body: `{ firstName, lastName, bio, phone }`. |
| GET    | /users/:id/public | Get public host profile (listings, reviews, member since).   |

---

## 5. User Stories

Each story follows the format: **As a [role], I want to [action], so that [benefit]**. Acceptance criteria are listed below each story.

### 5.1 Authentication

**US-001: Registration**
_As a new user, I want to create an account with my email and password, so that I can book places and save favorites._

- Form validates email format, password minimum 8 chars, first/last name required
- Duplicate email shows inline error: "This email is already registered"
- On success, user is logged in and redirected to Explore tab
- JWT access token (15min) and refresh token (7d) are stored securely

**US-002: Login**
_As a returning user, I want to log in with my credentials, so that I can access my bookings and wishlists._

- Invalid credentials show: "Incorrect email or password"
- Loading state shows spinner on button, prevents double-tap
- Successful login restores full app state (wishlists, bookings)

**US-003: Persistent Session**
_As a user, I want to stay logged in between app restarts, so I don't have to log in every time._

- Refresh token is used to obtain new access token on app launch
- If refresh token is expired, user is redirected to login screen

### 5.2 Explore & Search

**US-010: Browse Explore Screen**
_As a guest, I want to see a curated explore screen when I open the app, so I can get inspired about where to travel._

- Shows pre-seeded locations (Paris, NYC, Tokyo) with hero images
- Category chips at top: Beach, Mountain, City, Countryside, Lake, Design, Tropical
- Scrollable grid of listing cards below with image carousel dots

**US-011: Search Destination**
_As a user, I want to search for any destination worldwide, so I can find stays wherever I want to go._

- Tapping search bar opens full-screen search modal
- Typing shows Google Places autocomplete suggestions within 300ms debounce
- Selecting a destination shows date picker step
- After dates, shows guest count picker
- Tapping "Search" navigates to results screen for that location

**US-012: View Search Results**
_As a user, I want to see all available listings for my destination, so I can compare options._

- Results show as vertical scrolling list of listing cards
- Each card shows: hero image (swipeable), title, property type, price/night, rating, distance text
- Toggle button switches between list view and map view
- Map view shows pins with prices; tapping pin shows listing card preview

**US-013: Filter Results**
_As a user, I want to filter listings by price, property type, and amenities, so I can find exactly what I need._

- Filter modal opens from button in results header
- Price range slider (min/max) with histogram showing price distribution
- Property type toggles: Entire place, Private room, Shared room
- Guest count stepper
- Amenity checkboxes: Wifi, Kitchen, Pool, Parking, AC, Washer, Dryer, Gym
- Shows "Show X places" button with live count

**US-014: On-the-fly Generation**
_As a user, I want listings to appear for any location I search, even if nobody has listed there before, so the app always has content._

- If location is not in DB, a loading skeleton screen shows while backend generates listings (3–8 seconds)
- Progress indicator: "Discovering places in [Location]..."
- Backend generates 8–15 listings via OpenAI, assigns random pre-seeded images, saves to DB
- Subsequent searches for the same location return cached results instantly

### 5.3 Listing Detail

**US-020: View Listing Detail**
_As a user, I want to see complete details about a listing, so I can decide if I want to book it._

- Hero image gallery (horizontal scroll) with photo count indicator
- Title, property type label, location text
- Key stats row: X guests · X bedrooms · X beds · X baths
- Host card with avatar, name, Superhost badge, "Contact host" button
- Description text (expandable "Read more" after 4 lines)
- Amenities grid (icons + labels), "Show all X amenities" button
- Calendar section showing availability, check-in/check-out date selection
- Reviews section: average rating breakdown (6 categories), 2 review previews, "Show all X reviews"
- Map section with pin and neighborhood description
- House rules section
- Bottom sticky bar: price/night on left, "Reserve" button on right

**US-021: View All Photos**
_As a user, I want to see all photos for a listing in a full-screen gallery, so I can examine the space closely._

- Tapping any photo or "Show all photos" opens full-screen gallery
- Supports pinch-to-zoom and swipe navigation
- Dark background, close button top-left, photo counter top-right

**US-022: View All Reviews**
_As a user, I want to read all reviews for a listing, so I can make an informed decision._

- Full-screen modal with scrollable review list
- Each review shows: author avatar, name, date, star rating, comment text
- Rating breakdown chart at top (6 categories with horizontal bars)

### 5.4 Booking

**US-030: Reserve a Listing**
_As a user, I want to book a listing for specific dates, so I can secure my stay._

- Tapping "Reserve" from listing detail opens booking confirmation screen
- Shows: listing preview card, date range, guest count, price breakdown (nightly × nights, cleaning fee, service fee, total)
- If dates not selected, prompts user to select dates first
- Requires authentication (redirects to login if not logged in)

**US-031: Mock Payment**
_As a user, I want to go through a payment flow, so the demo feels realistic._

- Booking confirmation screen shows "Confirm and Pay" button
- Tapping shows a mock credit card form (pre-filled with fake data)
- On "Pay", shows 2-second loading animation, then success screen with confetti
- No actual payment processing occurs

**US-032: View My Trips**
_As a user, I want to see my upcoming and past trips, so I can manage my travel._

- Trips tab shows two sections: "Upcoming" and "Past"
- Each trip card shows: listing image, title, location, dates, status badge
- Tapping opens trip detail with full booking info, cancellation option

**US-033: Cancel Booking**
_As a user, I want to cancel a booking, so I can change my plans._

- Trip detail shows "Cancel reservation" button for CONFIRMED bookings
- Confirmation dialog: "Are you sure? This cannot be undone."
- On cancel, status changes to CANCELLED, listing dates become available again

### 5.5 Wishlists

**US-040: Save to Wishlist**
_As a user, I want to save listings I like, so I can come back to them later._

- Heart icon on every listing card and on listing detail screen
- First tap opens "Save to wishlist" bottom sheet with existing wishlists + "Create new"
- Subsequent taps toggle save/unsave with haptic feedback
- Heart fills red when saved

**US-041: View Wishlists**
_As a user, I want to browse my saved wishlists, so I can revisit places I liked._

- Wishlists tab shows grid of wishlist covers (first listing image + count)
- Tapping opens wishlist with full listing cards

### 5.6 Messaging

**US-050: Contact Host**
_As a user, I want to message a host, so I can ask questions before booking._

- Tapping "Contact host" on listing detail opens/creates conversation
- If conversation exists, opens it; otherwise creates new one

**US-051: View Conversations**
_As a user, I want to see all my conversations, so I can continue chatting._

- Inbox tab shows conversation list sorted by most recent message
- Each row: other user's avatar, name, last message preview, timestamp, unread badge
- Tapping opens full conversation thread

**US-052: Send/Receive Messages**
_As a user, I want to send and receive messages in real-time, so communication feels instant._

- Chat bubble UI: user messages on right (blue), other on left (gray)
- Text input at bottom with send button
- Messages load paginated (newest first), scroll up to load more
- Note: For demo, polling every 5 seconds is acceptable instead of WebSockets

### 5.7 Profile

**US-060: View/Edit Profile**
_As a user, I want to view and edit my profile, so I can keep my info current._

- Profile tab shows avatar, name, member since date, edit button
- Edit screen allows changing: first name, last name, bio, phone
- Settings section: currency preference (display only), logout button

**US-061: View Host Profile**
_As a user, I want to view a host's public profile, so I can gauge their trustworthiness._

- Shows: avatar, name, Superhost badge, member since, bio
- Lists their properties and aggregate review score

---

## 6. UI Design Specifications

These specs define the visual language of StaySpot. The design draws from Airbnb's clean, photo-centric aesthetic while establishing its own identity. All measurements are in logical pixels (dp).

### 6.1 Design Tokens

#### 6.1.1 Color Palette

| Token           | Value             | Usage                                                     |
| --------------- | ----------------- | --------------------------------------------------------- |
| Primary (Brand) | `#FF5A5F`         | CTA buttons, heart icons, active states, price highlights |
| Primary Dark    | `#E04850`         | Pressed state of primary buttons                          |
| Secondary       | `#00A699`         | Success states, confirmed badges, check icons             |
| Background      | `#FFFFFF`         | Main background                                           |
| Surface         | `#F7F7F7`         | Cards, input backgrounds, secondary surfaces              |
| Divider         | `#EBEBEB`         | Lines, separators, card borders                           |
| Text Primary    | `#222222`         | Headlines, body text, primary labels                      |
| Text Secondary  | `#717171`         | Subtitles, meta info, placeholder text                    |
| Text Tertiary   | `#B0B0B0`         | Disabled text, hints                                      |
| Overlay         | `rgba(0,0,0,0.5)` | Modal backdrops, image overlays                           |
| Star            | `#FFB400`         | Review stars                                              |
| Error           | `#C13515`         | Form errors, destructive actions                          |

#### 6.1.2 Typography

| Style          | Size | Weight | Line Height | Usage                           |
| -------------- | ---- | ------ | ----------- | ------------------------------- |
| Display Large  | 32dp | 800    | 40dp        | Explore screen hero text        |
| Display Medium | 26dp | 700    | 34dp        | Section titles                  |
| Headline       | 22dp | 600    | 28dp        | Listing titles, screen titles   |
| Title          | 18dp | 600    | 24dp        | Card titles, section headers    |
| Body Large     | 16dp | 400    | 24dp        | Descriptions, primary body text |
| Body           | 14dp | 400    | 20dp        | Secondary info, reviews, meta   |
| Caption        | 12dp | 400    | 16dp        | Timestamps, labels, badges      |
| Button         | 16dp | 600    | 20dp        | All buttons                     |
| Price          | 20dp | 700    | 26dp        | Price displays                  |

Font family: System default (San Francisco on iOS, Roboto on Android). The app uses the platform's native font for best readability.

#### 6.1.3 Spacing Scale

Base unit: 4dp. All spacing uses multiples of 4.

| Token | Value | Usage                                            |
| ----- | ----- | ------------------------------------------------ |
| xs    | 4dp   | Tight internal padding, icon gaps                |
| sm    | 8dp   | Between related elements                         |
| md    | 12dp  | Card internal padding                            |
| lg    | 16dp  | Section padding, screen horizontal padding       |
| xl    | 24dp  | Between sections                                 |
| 2xl   | 32dp  | Major section gaps, top/bottom safe area padding |
| 3xl   | 48dp  | Hero spacing, screen vertical margins            |

#### 6.1.4 Border Radius

| Element                     | Radius       | Notes                             |
| --------------------------- | ------------ | --------------------------------- |
| Listing card images         | 12dp         | Top corners only for card layout  |
| Buttons (primary)           | 8dp          | Slightly rounded, not pill-shaped |
| Buttons (secondary/outline) | 8dp          | Matches primary                   |
| Chips / Tags                | 20dp         | Pill-shaped                       |
| Avatars                     | 50% (circle) | Always circular                   |
| Bottom sheets               | 16dp         | Top corners only                  |
| Search bar                  | 32dp         | Fully rounded pill                |
| Input fields                | 8dp          | Subtle rounding                   |

#### 6.1.5 Shadows & Elevation

| Element              | Shadow                                                    |
| -------------------- | --------------------------------------------------------- |
| Cards (resting)      | `0 1dp 2dp rgba(0,0,0,0.08), 0 4dp 12dp rgba(0,0,0,0.05)` |
| Cards (pressed)      | `0 0dp 0dp rgba(0,0,0,0.08)` — flatten on press           |
| Bottom navigation    | `0 -1dp 4dp rgba(0,0,0,0.08)`                             |
| Sticky bottom bar    | `0 -2dp 8dp rgba(0,0,0,0.10)`                             |
| Bottom sheet         | `0 -4dp 16dp rgba(0,0,0,0.15)`                            |
| Search bar (explore) | `0 2dp 8dp rgba(0,0,0,0.12)`                              |
| Floating map button  | `0 2dp 8dp rgba(0,0,0,0.20)`                              |

### 6.2 Component Specifications

#### 6.2.1 Listing Card

The listing card is the most important UI component in the app. It appears in search results, explore, and wishlists.

- Width: Full screen width minus 32dp horizontal padding (16dp each side)
- Image carousel: Aspect ratio 1:1, with 5 pagination dots at bottom center (8dp from bottom, 6dp diameter, active dot is white, inactive 50% opacity white)
- Swipe to navigate images, no auto-play
- Heart icon: Top-right of image, 24dp from top, 16dp from right, 28dp icon, white fill with subtle drop shadow
- Below image, 12dp padding all sides:
  - Row 1: Title (Title style, single line ellipsis) + Star icon + Rating (Body, bold) on right
  - Row 2: Property type + distance text (Body, Text Secondary)
  - Row 3: Date range text (Body, Text Secondary)
  - Row 4: Price (Price style) + "/ night" (Body)
- Total card height: approximately 380dp
- Bottom margin between cards: 24dp

#### 6.2.2 Search Bar (Explore)

The explore screen search bar is a floating pill that acts as a tap target opening the search modal.

- Height: 56dp, full width minus 32dp padding
- Background: white, border-radius 32dp, shadow as specified
- Internal layout: Magnifying glass icon (20dp, Text Secondary) | 12dp gap | Column of two lines:
  - Line 1: "Where to?" (Title style, Text Primary)
  - Line 2: "Anywhere · Any week · Add guests" (Caption, Text Secondary)
- Filter icon button on right edge: 40dp circular outline, thin border (#DDDDDD), filter icon 20dp

#### 6.2.3 Bottom Navigation

5-tab bottom navigation bar, standard Material/Cupertino height.

| Tab       | Icon                                     | Label     |
| --------- | ---------------------------------------- | --------- |
| Explore   | search (outline/filled)                  | Explore   |
| Wishlists | heart (outline/filled)                   | Wishlists |
| Trips     | suitcase (outline/filled)                | Trips     |
| Inbox     | chat-bubble (outline/filled) + red badge | Inbox     |
| Profile   | person-circle (outline/filled)           | Profile   |

- Active tab: icon filled + Text Primary color
- Inactive tab: icon outline + Text Tertiary color
- Bar height: 64dp + safe area bottom inset
- Background: white, top border 1dp #EBEBEB or top shadow

#### 6.2.4 Primary Button

- Height: 52dp, full-width (minus screen padding) or auto-width
- Background: Gradient from #FF5A5F to #E04850 (left to right)
- Text: Button style, white, centered
- Border radius: 8dp
- Pressed state: darken 10%, scale 0.98
- Disabled: 50% opacity, no gradient
- Loading: white CircularProgressIndicator centered, button width maintained

#### 6.2.5 Host Card (Listing Detail)

- Height: 80dp, full-width
- Left: Avatar (48dp circle), 12dp gap
- Middle column: Host name (Title), "Superhost" badge or "X years hosting" (Caption)
- Right: Chevron icon (navigate to host profile)
- Divider above and below

#### 6.2.6 Review Summary

- Star icon (20dp, Star color) + Rating number (Display Medium) + " · X reviews" (Body, Text Secondary)
- 6 rating bars below: label on left (Body), horizontal bar (120dp width, 4dp height, Surface background with Primary fill proportional to score), score on right (Body)
- Categories: Cleanliness, Accuracy, Check-in, Communication, Location, Value

### 6.3 Screen-by-Screen Layout

#### 6.3.1 Explore Screen

- Status bar: transparent, content underlaps
- Search bar: 16dp from top of safe area, floating
- Category chips: Horizontal scroll, 8dp below search bar. Each chip: 64dp height total (40dp icon circle + 12dp label). Active chip has bottom border 2dp Primary
- Listing cards: Vertical scroll, 16dp horizontal padding, 24dp vertical gaps
- Pull-to-refresh supported

#### 6.3.2 Search Modal (Full-screen)

Three-step flow in a single full-screen modal:

- **Step 1 — Where:** Large title "Where to?", search text field with autocomplete dropdown. Recent searches below as chips.
- **Step 2 — When:** Horizontal scrolling calendar months. Date range selection with Primary color highlight. Skip button available.
- **Step 3 — Who:** Guest counter with +/– steppers for Adults, Children, Infants. Each has a description subtitle.
- Bottom bar: "Clear all" text button left, red "Search" button right with search icon

#### 6.3.3 Listing Detail Screen

- Full-bleed image gallery at top (300dp height on phones)
- Back button: 32dp circle, white, subtle shadow, 16dp from left, 12dp from top of safe area
- Share + Save buttons: same style, top-right
- Below images, 16dp horizontal padding:
  - Title (Headline)
  - Stats row with dot separators
  - Divider
  - Host card
  - Divider
  - Description (expandable)
  - Divider
  - Amenities section
  - Divider
  - Calendar section
  - Divider
  - Reviews section
  - Divider
  - Map section (200dp height)
  - Divider
  - House rules section
- Sticky bottom bar: 80dp height, white bg, shadow. Left: price/night. Right: "Reserve" primary button (auto-width, min 120dp)

#### 6.3.4 Booking Confirmation Screen

- App bar with back button and title "Confirm and Pay"
- Listing mini-card: 80dp image + title + rating (horizontal layout)
- Divider
- Trip details section: Check-in/check-out dates, guest count, edit link
- Divider
- Price breakdown: line items with amounts aligned right, total row bold with top border
- Divider
- Mock payment section: fake credit card visual (dark card with last 4 digits "4242")
- Bottom: "Confirm and Pay" primary button, full width

#### 6.3.5 Trips Screen

- Segmented control or tabs: "Upcoming" / "Past"
- Each trip card: 120dp image left, right side has title, location, dates, status chip
- Status chips: CONFIRMED (green bg), CANCELLED (red bg), COMPLETED (gray bg)
- Empty state: illustration + "No trips yet — start exploring!" with CTA button

#### 6.3.6 Inbox Screen

- Simple list of conversation rows
- Each row: 48dp avatar, name (Title), last message (Body, single line ellipsis, Text Secondary), timestamp (Caption) aligned right
- Unread indicator: 8dp red circle on avatar
- Empty state: "No messages yet"

#### 6.3.7 Profile Screen

- Large avatar (80dp) centered, name below (Display Medium), "Member since [year]" (Body, Text Secondary)
- Settings list: "Personal info", "Payments" (mock), "Notifications" (mock), "Help" (mock)
- Bottom: "Log out" text button (Error color)
- Version number at very bottom (Caption, Text Tertiary)

---

## 7. UX Flows

These flows describe the step-by-step user journeys through the app. Each step indicates screen, action, and transition.

### 7.1 First-Time User Flow

1. App opens → Splash screen (1.5s, brand logo animation)
2. Splash fades into Explore screen (no auth required to browse)
3. User taps search bar → Search modal slides up
4. User types "Barcelona" → autocomplete suggestions appear
5. User selects "Barcelona, Spain" → date picker step appears
6. User selects dates (or skips) → guest picker step appears
7. User sets guests (or skips) → taps "Search"
8. Results screen loads. If first search for Barcelona, skeleton loading 3–8s while AI generates listings
9. User scrolls through listings, taps one → listing detail screen slides in
10. User taps "Reserve" → prompted to log in / register (bottom sheet)
11. User registers → returns to booking confirmation screen automatically
12. User confirms booking → mock payment → success screen with confetti
13. User taps "Done" → navigates to Trips tab showing the new booking

### 7.2 Search-to-Book Flow (Authenticated)

1. User taps search bar on Explore
2. Search modal: select location → dates → guests → Search
3. Results screen shows listings
4. User applies filters (optional) → results update
5. User taps listing card → listing detail
6. User selects dates on embedded calendar (if not already selected)
7. User taps "Reserve" → booking confirmation screen
8. User reviews price breakdown
9. User taps "Confirm and Pay" → 2s loading → success screen
10. User taps "View Trip" → trip detail screen

### 7.3 Wishlist Flow

1. User taps heart on listing card or listing detail
2. If no wishlists exist: "Create wishlist" bottom sheet (name input + create button)
3. If wishlists exist: bottom sheet shows list of wishlists to save to, plus "Create new"
4. User selects wishlist → toast confirmation "Saved to [name]"
5. Heart icon fills red with scale animation
6. User navigates to Wishlists tab → sees wishlist grid
7. User taps wishlist → sees saved listings
8. User taps heart again to unsave → heart unfills, listing removed from wishlist

### 7.4 Messaging Flow

1. User is on listing detail → taps "Contact host"
2. If conversation exists: opens existing conversation
3. If new: conversation created, chat screen opens with empty thread
4. User types message and taps send
5. Message appears in sent bubble with timestamp
6. For demo: a fake auto-reply from "host" appears after 3–5 seconds (using a canned response from a small set)
7. User navigates to Inbox tab → conversation appears in list with last message preview

### 7.5 Location Generation Flow (Backend)

This describes the server-side flow when a new location is searched:

1. Frontend sends `GET /api/v1/locations/:placeId`
2. Backend checks if Location exists in DB by placeId
3. If exists: return location + associated listings immediately
4. If not: call Google Places API (Place Details) to get lat/lng, country, formatted name
5. Create Location record in DB
6. Call OpenAI API with structured prompt including location name, country, and request for 10 listings
7. Parse OpenAI JSON response, validate with zod
8. For each listing: randomly select 5–8 images from PreseededImage table (matching relevant category based on property type)
9. Create Listing + ListingImage records in DB
10. Generate 2–4 fake reviews per listing using a second OpenAI call (batch)
11. Return complete location + listings response to frontend

---

## 8. AI Generation Prompts

These are the exact prompts the backend uses when generating content. Claude Code should implement them as template literals in the listing generation service.

### 8.1 Listing Generation System Prompt

```
You are a creative real estate copywriter generating property listings
for a travel platform. Generate realistic, diverse listings for the
specified location. Each listing must feel authentic to the local
culture and pricing norms.

Respond ONLY with a valid JSON array. No markdown, no explanation.
```

### 8.2 Listing Generation User Prompt Template

```
Generate {count} property listings for {locationName}, {country}.

Requirements:
- Mix of property types: apartments, houses, unique stays
- Prices realistic for {locationName} in USD per night
- Each listing has 4-8 amenities from: wifi, kitchen, pool,
  parking, ac, washer, dryer, gym, hot_tub, fireplace,
  workspace, tv, balcony, garden, bbq, elevator, doorman
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
}
```

### 8.3 Review Generation Prompt

```
Generate {count} guest reviews for a {propertyType} called
"{title}" in {location}. Rated {rating}/5 overall.

Each review JSON:
{
  "authorName": string,
  "rating": number (within 0.5 of {rating}),
  "comment": string (2-4 sentences),
  "cleanliness": number,
  "accuracy": number,
  "checkIn": number,
  "communication": number,
  "location": number,
  "value": number
}

Respond ONLY with a valid JSON array.
```

### 8.4 Leonardo AI Image Prompt Template

```
Photorealistic {view} of a {category},
professional real estate photography, natural lighting,
4K resolution, interior design magazine style,
no people, no text, no watermarks
```

Where `{view}` cycles through: "interior living room", "interior bedroom", "interior kitchen", "interior bathroom", "exterior facade", "terrace with view", "dining area", "close-up of design details"

---

## 9. Seed Data & Setup Instructions

### 9.1 Pre-seeded Demo Account

| Field       | Value                                                                                  |
| ----------- | -------------------------------------------------------------------------------------- |
| Email       | demo@stayspot.com                                                                      |
| Password    | demo1234                                                                               |
| First Name  | Alex                                                                                   |
| Last Name   | Traveler                                                                               |
| isHost      | true                                                                                   |
| isSuperhost | true                                                                                   |
| Bio         | Passionate traveler and host. Love sharing my homes with guests from around the world. |

### 9.2 Pre-seeded Locations

Three locations are seeded at setup with fully generated listings:

- **Paris, France** — 12 listings (apartments, lofts, historic townhouses)
- **New York City, USA** — 10 listings (city lofts, apartments, studios)
- **Tokyo, Japan** — 10 listings (minimalist studios, apartments, traditional stays)

### 9.3 Image Categories & Mapping

| Image Category     | Property Types Matched     | Views Generated                                                       |
| ------------------ | -------------------------- | --------------------------------------------------------------------- |
| modern-apartment   | ENTIRE_PLACE, PRIVATE_ROOM | Living, bedroom, kitchen, bathroom, exterior, balcony, dining, detail |
| cozy-cabin         | ENTIRE_PLACE               | Same 8 views                                                          |
| beach-house        | ENTIRE_PLACE               | Same 8 views                                                          |
| city-loft          | ENTIRE_PLACE, PRIVATE_ROOM | Same 8 views                                                          |
| mountain-chalet    | ENTIRE_PLACE               | Same 8 views                                                          |
| villa-pool         | ENTIRE_PLACE               | Same 8 views + pool                                                   |
| treehouse          | ENTIRE_PLACE               | Same 8 views                                                          |
| houseboat          | ENTIRE_PLACE, SHARED_ROOM  | Same 8 views                                                          |
| historic-townhouse | ENTIRE_PLACE               | Same 8 views                                                          |
| minimalist-studio  | ENTIRE_PLACE, PRIVATE_ROOM | Same 8 views                                                          |

### 9.4 Setup Script (run order)

1. `docker-compose up -d` (starts PostgreSQL)
2. `cd backend && npm install`
3. `cp .env.example .env` (fill in API keys)
4. `npx prisma migrate dev` (creates tables)
5. `npx ts-node scripts/seed-images.ts` (runs Leonardo AI generation — takes ~10 min)
6. `npx prisma db seed` (creates demo user, seeded locations, assigns images)
7. `npm run dev` (starts backend on port 3000)
8. `cd ../mobile && flutter pub get`
9. `flutter run` (starts Flutter app)

### 9.5 Environment Variables (.env)

```env
DATABASE_URL=postgresql://stayspot:stayspot@localhost:5432/stayspot
JWT_SECRET=your-secret-key-here
JWT_REFRESH_SECRET=your-refresh-secret-here
OPENAI_API_KEY=sk-...
GOOGLE_PLACES_API_KEY=AIza...
LEONARDO_API_KEY=...
PORT=3000
NODE_ENV=development
```

---

## 10. Animations & Micro-interactions

Polish matters for a portfolio piece. These specs define the key animations.

| Interaction          | Duration                     | Details                                                                                          |
| -------------------- | ---------------------------- | ------------------------------------------------------------------------------------------------ |
| Splash → Explore     | 1500ms                       | Logo scales up 0.8→1.0, fades in. Then crossfade to explore screen.                              |
| Heart save toggle    | 300ms                        | Scale 1.0→1.3→1.0 with spring curve. Fill color fades in simultaneously. Haptic impact (medium). |
| Listing card press   | 150ms                        | Scale 1.0→0.98, shadow flattens. On release: spring back.                                        |
| Search modal open    | 400ms                        | Slide up from bottom with Material decelerate curve. Background dims to overlay.                 |
| Skeleton loading     | 1200ms loop                  | Shimmer gradient sweep left-to-right at 30° angle. Base: #E0E0E0, highlight: #F0F0F0.            |
| Image carousel swipe | 300ms                        | Standard scroll physics with pagination snap. Dot indicator crossfades.                          |
| Tab switch           | 200ms                        | Icon morphs outline→filled. Label color transitions.                                             |
| Toast notification   | 300ms in, 2s hold, 300ms out | Slides down from top, auto-dismisses. Success: green left border. Error: red left border.        |
| Booking success      | 800ms                        | Checkmark draws on (Lottie), confetti particles burst, card fades in below.                      |
| Pull to refresh      | Standard                     | Use RefreshIndicator with Primary color.                                                         |
| Page transitions     | 300ms                        | Standard Material forward/backward (slide + fade). Modal routes: slide up.                       |

---

## 11. Error Handling & Edge Cases

| Scenario                                | Handling                                                                                                                                       |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| No internet connection                  | Show offline banner at top (amber). Cached listings still browsable. Actions that require network show inline error.                           |
| AI generation fails (OpenAI down)       | Return 503 with message. Frontend shows: "We're having trouble loading listings for this area. Try again in a moment." with retry button.      |
| Google Places API error                 | Autocomplete falls back to showing "No results found". Search can still be performed with typed text (basic text match on existing locations). |
| Leonardo AI generation fails            | Seed script retries 3x per image. Missing images fallback to a set of 5 generic placeholder images bundled with the app.                       |
| Booking date conflict                   | Backend validates date availability before confirming. Returns 409 Conflict. Frontend shows: "These dates are no longer available."            |
| JWT expired during session              | Dio interceptor catches 401, uses refresh token to get new access token, retries original request. If refresh also fails, redirect to login.   |
| Empty search results (after generation) | Show: "No places found matching your filters. Try adjusting your search." with option to clear filters.                                        |
| Slow network / long generation          | Skeleton screens show immediately. After 10s, show "Still loading..." message. After 30s, show timeout error with retry.                       |

---

## 12. Testing Strategy

### 12.1 Backend (vitest + supertest)

- Unit tests for: listing generation service (mock OpenAI), booking validation logic, auth middleware, price calculation
- Integration tests for: full auth flow, listing CRUD, booking lifecycle, search with filters
- Mock external APIs (OpenAI, Google Places) in all tests

### 12.2 Frontend (flutter_test)

- Widget tests for: listing card rendering, search bar interaction, booking form validation, price breakdown calculation
- Golden tests for: key screens (explore, listing detail, booking confirmation) to catch visual regressions
- Integration tests for: search-to-book flow, wishlist flow, auth flow

### 12.3 Test Data

- Backend seed includes a "test" location with predictable data for integration tests
- Flutter tests use mock API responses matching the backend's zod schemas

---

## 13. Appendix

### 13.1 Amenity Icon Mapping

Claude Code should use Material Icons or Lucide icons for amenity display:

| Amenity Key | Icon Name             | Display Label       |
| ----------- | --------------------- | ------------------- |
| wifi        | wifi                  | Wifi                |
| kitchen     | kitchen / restaurant  | Kitchen             |
| pool        | pool                  | Pool                |
| parking     | local_parking         | Free parking        |
| ac          | ac_unit               | Air conditioning    |
| washer      | local_laundry_service | Washer              |
| dryer       | dry_cleaning          | Dryer               |
| gym         | fitness_center        | Gym                 |
| hot_tub     | hot_tub               | Hot tub             |
| fireplace   | fireplace             | Fireplace           |
| workspace   | desktop_windows       | Dedicated workspace |
| tv          | tv                    | TV                  |
| balcony     | balcony               | Balcony             |
| garden      | yard                  | Garden              |
| bbq         | outdoor_grill         | BBQ grill           |
| elevator    | elevator              | Elevator            |
| doorman     | security              | Doorman             |

### 13.2 Category Chip Mapping (Explore)

| Category    | Icon          | Filter Applied                         |
| ----------- | ------------- | -------------------------------------- |
| Beach       | beach_access  | Filter by beach-house images           |
| Mountain    | terrain       | Filter by mountain-chalet images       |
| City        | location_city | Filter by city-loft, modern-apartment  |
| Countryside | grass         | Filter by cozy-cabin                   |
| Lake        | water         | Filter by beach-house, houseboat       |
| Design      | architecture  | Filter by minimalist-studio, city-loft |
| Tropical    | spa           | Filter by villa-pool, beach-house      |

### 13.3 Property Type to Image Category Mapping

When generating listings, the backend maps the OpenAI-generated property type to image categories for random image assignment:

| Generated Property Flavor       | Image Categories Pool               |
| ------------------------------- | ----------------------------------- |
| apartment, flat, condo          | modern-apartment, minimalist-studio |
| house, villa, estate            | villa-pool, beach-house             |
| cabin, cottage, farmhouse       | cozy-cabin                          |
| loft, penthouse, studio         | city-loft, minimalist-studio        |
| chalet, lodge, mountain         | mountain-chalet                     |
| boat, houseboat, floating       | houseboat                           |
| treehouse, unique               | treehouse                           |
| historic, townhouse, brownstone | historic-townhouse                  |
| fallback / unmatched            | modern-apartment (safest default)   |

### 13.4 Docker Compose

```yaml
version: "3.8"
services:
  db:
    image: postgis/postgis:16-3.4
    environment:
      POSTGRES_USER: stayspot
      POSTGRES_PASSWORD: stayspot
      POSTGRES_DB: stayspot
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
  backend:
    build: ./backend
    ports:
      - "3000:3000"
    depends_on:
      - db
    env_file:
      - ./backend/.env
volumes:
  pgdata:
```
