const OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast";
const NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse";

export async function fetchWeatherBundle(latitude, longitude) {
  const search = new URLSearchParams({
    latitude: String(latitude),
    longitude: String(longitude),
    current: "temperature_2m,apparent_temperature,weather_code,is_day,wind_speed_10m",
    daily: "weather_code,temperature_2m_max,temperature_2m_min",
    timezone: "auto",
    forecast_days: "7"
  });

  const response = await fetch(`${OPEN_METEO_URL}?${search.toString()}`);
  if (!response.ok) {
    throw new Error("Hava durumu bilgisi alinamadi.");
  }

  return response.json();
}

export async function reverseGeocode(latitude, longitude) {
  const search = new URLSearchParams({
    lat: String(latitude),
    lon: String(longitude),
    format: "jsonv2"
  });

  const response = await fetch(`${NOMINATIM_URL}?${search.toString()}`, {
    headers: {
      Accept: "application/json"
    }
  });

  if (!response.ok) {
    throw new Error("Konum bilgisi alinamadi.");
  }

  return response.json();
}

export function buildMapEmbedUrl(latitude, longitude, delta = 0.02) {
  const left = longitude - delta;
  const right = longitude + delta;
  const top = latitude + delta;
  const bottom = latitude - delta;
  const search = new URLSearchParams({
    bbox: `${left},${bottom},${right},${top}`,
    layer: "mapnik",
    marker: `${latitude},${longitude}`
  });

  return `https://www.openstreetmap.org/export/embed.html?${search.toString()}`;
}
