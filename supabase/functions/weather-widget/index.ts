// Weather Widget Edge Function
// 天気ウィジェット (ダッシュボード用)
// - 現在の天気情報
// - 予報 (日本の主要都市)
// - ユーザー設定都市
//
// GET → 天気情報 / 都市一覧

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const CITIES = [
  { key: "tokyo", name: "東京", lat: 35.6762, lon: 139.6503 },
  { key: "osaka", name: "大阪", lat: 34.6937, lon: 135.5023 },
  { key: "nagoya", name: "名古屋", lat: 35.1815, lon: 136.9066 },
  { key: "sapporo", name: "札幌", lat: 43.0618, lon: 141.3545 },
  { key: "fukuoka", name: "福岡", lat: 33.5904, lon: 130.4017 },
  { key: "sendai", name: "仙台", lat: 38.2682, lon: 140.8694 },
  { key: "hiroshima", name: "広島", lat: 34.3853, lon: 132.4553 },
  { key: "kyoto", name: "京都", lat: 35.0116, lon: 135.7681 },
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method === "GET") {
      const url = new URL(req.url);
      const city = url.searchParams.get("city") ?? "tokyo";
      const view = url.searchParams.get("view"); // 'cities' | 'forecast'

      if (view === "cities") {
        return new Response(
          JSON.stringify({ success: true, cities: CITIES }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const cityData = CITIES.find((c) => c.key === city) ?? CITIES[0];

      // Use Open-Meteo free API (no key required)
      const apiUrl = `https://api.open-meteo.com/v1/forecast?latitude=${cityData.lat}&longitude=${cityData.lon}&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=Asia%2FTokyo&forecast_days=7`;

      const res = await fetch(apiUrl);
      if (!res.ok) {
        throw new Error(`Weather API error: ${res.status}`);
      }

      const data = await res.json();

      const weatherDescriptions: Record<number, string> = {
        0: "快晴", 1: "晴れ", 2: "一部曇り", 3: "曇り",
        45: "霧", 48: "霧氷", 51: "小雨", 53: "雨",
        55: "強い雨", 61: "小雨", 63: "雨", 65: "大雨",
        71: "小雪", 73: "雪", 75: "大雪", 80: "にわか雨",
        81: "にわか雨", 82: "激しいにわか雨", 95: "雷雨",
      };

      const current = data.current ?? {};
      const daily = data.daily ?? {};

      return new Response(
        JSON.stringify({
          success: true,
          city: cityData.name,
          current: {
            temperature: current.temperature_2m,
            humidity: current.relative_humidity_2m,
            weatherCode: current.weather_code,
            weatherDescription: weatherDescriptions[current.weather_code] ?? "不明",
            windSpeed: current.wind_speed_10m,
          },
          forecast: (daily.time ?? []).map((date: string, i: number) => ({
            date,
            maxTemp: daily.temperature_2m_max?.[i],
            minTemp: daily.temperature_2m_min?.[i],
            weatherCode: daily.weather_code?.[i],
            weatherDescription: weatherDescriptions[daily.weather_code?.[i]] ?? "不明",
            precipitationProbability: daily.precipitation_probability_max?.[i],
          })),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("weather-widget error:", err);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
