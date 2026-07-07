# StaySpot — Server Deployment

The API is deployed as part of the champi docker-compose stack.

| | |
|---|---|
| Compose services | `stayspot-backend` + `stayspot-db` |
| Public base URL | `https://stayspot.champi.lat` |
| Local base URL | `http://127.0.0.1:8093` (API prefix `/api/v1`) |
| Stack | Express + TypeScript (compiled), Prisma |
| Database | dedicated `stayspot-db` container — **PostGIS** (postgis/postgis:16-3.4), volume `stayspot_pgdata` |
| Uploads | `./stayspot/backend/uploads` bind-mounted to `/app/uploads` |

## Deploy / redeploy

```bash
cd ~/Development/champi
docker compose up -d --build stayspot-backend
```

Prisma migrations run automatically on boot (`prisma migrate deploy`).
Seed (already done, idempotent upserts for the demo user):

```bash
docker exec stayspot-backend npx prisma db seed
```

Seeded: 14 users, 32 listings across multiple cities.

## Environment

- `DATABASE_URL` — set in compose to the postgis container
- `JWT_SECRET` / `JWT_REFRESH_SECRET` — dev defaults; set for production
- `GOOGLE_PLACES_API_KEY` — optional, location autocomplete
- `OPENAI_API_KEY` — optional, AI listing generation

## Demo account

`demo@stayspot.com` / `demo1234`

## API surface (prefix `/api/v1`)

Routers: `/auth`, `/locations`, `/listings`, `/bookings`, `/wishlists`,
`/conversations`, `/users`. Health check at `GET /health` (no prefix).
Example: `GET /api/v1/listings?limit=20` returns seeded listings.

## Pointing the Flutter app at this server

`mobile/lib/core/constants.dart` reads compile-time env with localhost
defaults, so no code change needed:

```bash
flutter run --dart-define=API_BASE_URL=http://<HOST>:8093/api/v1 \
            --dart-define=IMAGE_BASE_URL=http://<HOST>:8093
```

- Android emulator on this machine: `10.0.2.2:8093`
- Physical device: LAN IP requires changing the compose mapping from
  `127.0.0.1:8093:3000` to `8093:3000`, or add `stayspot.champi.lat` to
  `~/.cloudflared/config.yml` → `http://localhost:8093` for an HTTPS URL.
