// City search + details via OpenStreetMap Nominatim — free, no API key.
// Usage policy: descriptive User-Agent, ≤1 req/s (autocomplete is
// debounced client-side).

const NOMINATIM = 'https://nominatim.openstreetmap.org';
const HEADERS = { 'User-Agent': 'StaySpot/1.0 (stayspot.champi.lat)' };

export interface AutocompleteSuggestion {
  placeId: string;
  description: string;
  mainText: string;
  secondaryText: string;
}

export interface PlaceDetails {
  placeId: string;
  name: string;
  country: string;
  latitude: number;
  longitude: number;
}

interface NominatimPlace {
  osm_type: string; // node | way | relation
  osm_id: number;
  lat: string;
  lon: string;
  name?: string;
  display_name: string;
  address?: Record<string, string>;
  addresstype?: string;
}

// placeId format: "osm:<N|W|R>:<osm_id>" — stable across search & lookup
function toPlaceId(p: NominatimPlace): string {
  return `osm:${p.osm_type[0].toUpperCase()}:${p.osm_id}`;
}

function cityName(p: NominatimPlace): string {
  const a = p.address ?? {};
  return p.name || a.city || a.town || a.village || p.display_name.split(',')[0];
}

export async function autocomplete(query: string): Promise<AutocompleteSuggestion[]> {
  const params = new URLSearchParams({
    q: query,
    format: 'jsonv2',
    limit: '6',
    addressdetails: '1',
    featureType: 'settlement', // cities, towns, villages
    'accept-language': 'en',
  });

  const res = await fetch(`${NOMINATIM}/search?${params}`, { headers: HEADERS });
  if (!res.ok) return [];
  const data = (await res.json()) as NominatimPlace[];

  return data.map((p) => {
    const main = cityName(p);
    const country = p.address?.country || '';
    const region = p.address?.state || p.address?.county || '';
    const secondary = [region, country].filter(Boolean).join(', ');
    return {
      placeId: toPlaceId(p),
      description: [main, secondary].filter(Boolean).join(', '),
      mainText: main,
      secondaryText: secondary,
    };
  });
}

export async function getPlaceDetails(placeId: string): Promise<PlaceDetails | null> {
  const m = placeId.match(/^osm:([NWR]):(\d+)$/);
  if (!m) return null;

  const params = new URLSearchParams({
    osm_ids: `${m[1]}${m[2]}`,
    format: 'jsonv2',
    addressdetails: '1',
    'accept-language': 'en',
  });

  const res = await fetch(`${NOMINATIM}/lookup?${params}`, { headers: HEADERS });
  if (!res.ok) return null;
  const data = (await res.json()) as NominatimPlace[];
  const p = data[0];
  if (!p) return null;

  const name = cityName(p);
  const country = p.address?.country || 'Unknown';

  return {
    placeId,
    name: [name, country].filter(Boolean).join(', '),
    country,
    latitude: parseFloat(p.lat),
    longitude: parseFloat(p.lon),
  };
}
