import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const catalogBucket = "offset-catalogs";
const incentiveObject = "offset_seed.json";
const locationObject = "location_catalog.json";

const jsonHeaders = {
  "Content-Type": "application/json",
  "Cache-Control": "private, no-store",
};

function response(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function base64(data: ArrayBuffer): string {
  const bytes = new Uint8Array(data);
  let binary = "";
  const chunkSize = 0x8000;
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + chunkSize));
  }
  return btoa(binary);
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return response(405, { error: "method_not_allowed" });
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseURL || !serviceRoleKey) {
    return response(500, { error: "server_not_configured" });
  }

  const authorization = request.headers.get("Authorization");
  const accessToken = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!accessToken) {
    return response(401, { error: "missing_authorization" });
  }

  const admin = createClient(supabaseURL, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await admin.auth.getUser(accessToken);
  if (userError || !userData.user || userData.user.is_anonymous !== true) {
    return response(401, { error: "invalid_anonymous_session" });
  }

  const [incentiveResult, locationResult] = await Promise.all([
    admin.storage.from(catalogBucket).download(incentiveObject),
    admin.storage.from(catalogBucket).download(locationObject),
  ]);
  if (incentiveResult.error || locationResult.error ||
      !incentiveResult.data || !locationResult.data) {
    return response(503, { error: "catalog_unavailable" });
  }

  const [incentiveData, locationData] = await Promise.all([
    incentiveResult.data.arrayBuffer(),
    locationResult.data.arrayBuffer(),
  ]);

  return response(200, {
    incentive_catalog_base64: base64(incentiveData),
    location_catalog_base64: base64(locationData),
  });
});
