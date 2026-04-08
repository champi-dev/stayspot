const GOOGLE_API_KEY = process.env.GOOGLE_PLACES_API_KEY || '';
const BASE_URL = 'https://maps.googleapis.com/maps/api';

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

export async function autocomplete(query: string): Promise<AutocompleteSuggestion[]> {
  if (!GOOGLE_API_KEY || GOOGLE_API_KEY === 'AIza-placeholder') {
    // Return mock suggestions for demo
    return getMockSuggestions(query);
  }

  const url = `${BASE_URL}/place/autocomplete/json?input=${encodeURIComponent(query)}&types=(cities)&key=${GOOGLE_API_KEY}`;
  const response = await fetch(url);
  const data: any = await response.json();

  if (data.status !== 'OK') return [];

  return data.predictions.map((p: any) => ({
    placeId: p.place_id,
    description: p.description,
    mainText: p.structured_formatting.main_text,
    secondaryText: p.structured_formatting.secondary_text || '',
  }));
}

export async function getPlaceDetails(placeId: string): Promise<PlaceDetails | null> {
  if (!GOOGLE_API_KEY || GOOGLE_API_KEY === 'AIza-placeholder') {
    return getMockPlaceDetails(placeId);
  }

  const url = `${BASE_URL}/place/details/json?place_id=${placeId}&fields=geometry,address_components,formatted_address,name&key=${GOOGLE_API_KEY}`;
  const response = await fetch(url);
  const data: any = await response.json();

  if (data.status !== 'OK') return null;

  const result = data.result;
  const country = result.address_components?.find((c: any) =>
    c.types.includes('country')
  )?.long_name || 'Unknown';

  return {
    placeId,
    name: result.formatted_address || result.name,
    country,
    latitude: result.geometry.location.lat,
    longitude: result.geometry.location.lng,
  };
}

// Mock data for when Google Places API key is not configured
function getMockSuggestions(query: string): AutocompleteSuggestion[] {
  const cities = [
    { placeId: 'mock-barcelona', description: 'Barcelona, Spain', mainText: 'Barcelona', secondaryText: 'Spain' },
    { placeId: 'mock-london', description: 'London, United Kingdom', mainText: 'London', secondaryText: 'United Kingdom' },
    { placeId: 'mock-rome', description: 'Rome, Italy', mainText: 'Rome', secondaryText: 'Italy' },
    { placeId: 'mock-bali', description: 'Bali, Indonesia', mainText: 'Bali', secondaryText: 'Indonesia' },
    { placeId: 'mock-sydney', description: 'Sydney, Australia', mainText: 'Sydney', secondaryText: 'Australia' },
    { placeId: 'mock-dubai', description: 'Dubai, United Arab Emirates', mainText: 'Dubai', secondaryText: 'United Arab Emirates' },
    { placeId: 'mock-bangkok', description: 'Bangkok, Thailand', mainText: 'Bangkok', secondaryText: 'Thailand' },
    { placeId: 'mock-lisbon', description: 'Lisbon, Portugal', mainText: 'Lisbon', secondaryText: 'Portugal' },
    { placeId: 'ChIJD7fiBh9u5kcRYJSMaMOCCwQ', description: 'Paris, France', mainText: 'Paris', secondaryText: 'France' },
    { placeId: 'ChIJOwg_06VPwokRYv534QaPC8g', description: 'New York City, USA', mainText: 'New York City', secondaryText: 'USA' },
    { placeId: 'ChIJ51cu8IcbXWARiRtXIothAS4', description: 'Tokyo, Japan', mainText: 'Tokyo', secondaryText: 'Japan' },
  ];

  const lower = query.toLowerCase();
  return cities.filter(c => c.description.toLowerCase().includes(lower)).slice(0, 5);
}

function getMockPlaceDetails(placeId: string): PlaceDetails | null {
  const mockDetails: Record<string, PlaceDetails> = {
    'mock-barcelona': { placeId: 'mock-barcelona', name: 'Barcelona, Spain', country: 'Spain', latitude: 41.3874, longitude: 2.1686 },
    'mock-london': { placeId: 'mock-london', name: 'London, United Kingdom', country: 'United Kingdom', latitude: 51.5074, longitude: -0.1278 },
    'mock-rome': { placeId: 'mock-rome', name: 'Rome, Italy', country: 'Italy', latitude: 41.9028, longitude: 12.4964 },
    'mock-bali': { placeId: 'mock-bali', name: 'Bali, Indonesia', country: 'Indonesia', latitude: -8.3405, longitude: 115.092 },
    'mock-sydney': { placeId: 'mock-sydney', name: 'Sydney, Australia', country: 'Australia', latitude: -33.8688, longitude: 151.2093 },
    'mock-dubai': { placeId: 'mock-dubai', name: 'Dubai, United Arab Emirates', country: 'United Arab Emirates', latitude: 25.2048, longitude: 55.2708 },
    'mock-bangkok': { placeId: 'mock-bangkok', name: 'Bangkok, Thailand', country: 'Thailand', latitude: 13.7563, longitude: 100.5018 },
    'mock-lisbon': { placeId: 'mock-lisbon', name: 'Lisbon, Portugal', country: 'Portugal', latitude: 38.7223, longitude: -9.1393 },
  };
  return mockDetails[placeId] || null;
}
