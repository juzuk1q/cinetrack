import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

const BASE_URL = "https://kinopoiskapiunofficial.tech";

// Whitelist patterns for allowed Kinopoisk endpoints
const ALLOWED_PATH_PATTERNS = [
  /^\/api\/v2\.2\/films\/collections$/,
  /^\/api\/v2\.1\/films\/search-by-keyword$/,
  /^\/api\/v2\.2\/films$/,
  /^\/api\/v2\.2\/films\/\d+$/,
  /^\/api\/v2\.2\/films\/\d+\/images$/,
  /^\/api\/v2\.2\/films\/\d+\/videos$/,
  /^\/api\/v2\.2\/films\/\d+\/seasons$/,
];

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    let path = "";
    let params: Record<string, string> = {};

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      path = body.path || "";
      params = body.params || {};
    } else {
      const url = new URL(req.url);
      path = url.searchParams.get("path") || "";
      url.searchParams.forEach((val, key) => {
        if (key !== "path") params[key] = val;
      });
    }

    if (!path) {
      return new Response(JSON.stringify({ error: "Missing 'path' parameter" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Verify path against whitelist
    const isAllowed = ALLOWED_PATH_PATTERNS.some((pattern) => pattern.test(path));
    if (!isAllowed) {
      return new Response(
        JSON.stringify({ error: `Path '${path}' is not permitted by proxy whitelist` }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Load API keys from environment
    const rawKeys = Deno.env.get("KINOPOISK_API_KEYS") || Deno.env.get("KINOPOISK_API_KEY") || "";
    const apiKeys = rawKeys
      .split(",")
      .map((k) => k.trim())
      .filter((k) => k.length > 0);

    if (apiKeys.length === 0) {
      return new Response(
        JSON.stringify({ error: "Kinopoisk API key(s) not configured on server" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Build target URL
    const targetUrl = new URL(`${BASE_URL}${path}`);
    Object.entries(params).forEach(([key, val]) => {
      targetUrl.searchParams.set(key, val);
    });

    let lastResponse: Response | null = null;
    let lastError: Error | null = null;

    // Rotate keys on 402 (Payment Required) or 429 (Rate Limit Exceeded)
    for (const key of apiKeys) {
      try {
        const response = await fetch(targetUrl.toString(), {
          method: "GET",
          headers: {
            "X-API-KEY": key,
            "Content-Type": "application/json",
          },
        });

        if (response.status === 402 || response.status === 429) {
          console.warn(`Key exhausted or rate limited (status ${response.status}), trying next key...`);
          lastResponse = response;
          continue;
        }

        const data = await response.text();
        return new Response(data, {
          status: response.status,
          headers: {
            ...corsHeaders,
            "Content-Type": response.headers.get("Content-Type") || "application/json",
          },
        });
      } catch (err: any) {
        lastError = err;
        console.error("Fetch attempt error:", err);
      }
    }

    // If all keys were exhausted
    if (lastResponse) {
      const data = await lastResponse.text();
      return new Response(data, {
        status: lastResponse.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({ error: lastError ? lastError.message : "All Kinopoisk API keys failed" }),
      {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message || "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
