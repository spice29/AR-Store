import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const projectURL = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const signingSecret = Deno.env.get("OTA_SIGNING_SECRET")!;
const encoder = new TextEncoder();
const admin = createClient(projectURL, serviceKey, { auth: { persistSession: false } });
const MAX_AGE = 3600;

function b64(data: Uint8Array): string {
  return btoa(String.fromCharCode(...data)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function unb64(value: string): Uint8Array {
  const base = value.replace(/-/g, "+").replace(/_/g, "/");
  return Uint8Array.from(atob(base + "=".repeat((4 - base.length % 4) % 4)), c => c.charCodeAt(0));
}
async function signature(payload: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", encoder.encode(signingSecret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return b64(new Uint8Array(await crypto.subtle.sign("HMAC", key, encoder.encode(payload))));
}
function xml(value: string): string {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;").replace(/'/g, "&apos;");
}
function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: { "Cache-Control": "no-store" } });
}
Deno.serve(async (req) => {
  try {
    if (!signingSecret || signingSecret.length < 32) return json({ error: "Server not configured" }, 503);
    const endpoint = new URL(req.url);
    if (req.method === "GET" && endpoint.searchParams.has("ticket")) {
      const ticket = endpoint.searchParams.get("ticket")!;
      const [payload, mac] = ticket.split(".");
      if (!payload || !mac || mac !== await signature(payload)) return json({ error: "Invalid ticket" }, 403);
      const data = JSON.parse(new TextDecoder().decode(unb64(payload)));
      if (!Number.isFinite(data.exp) || Date.now() > data.exp || data.exp - Date.now() > MAX_AGE * 1000)
        return json({ error: "Expired ticket" }, 403);
      const { data: app, error } = await admin.from("apps")
        .select("id,name,bundle_id,version,ipa_path,published").eq("id", data.id).eq("published", true).single();
      if (error || !app || app.ipa_path !== data.path) return json({ error: "Not available" }, 404);
      const { data: signed, error: signError } = await admin.storage.from("ipa-files")
        .createSignedUrl(data.path, MAX_AGE);
      if (signError || !signed?.signedUrl) return json({ error: "Storage error" }, 502);
      const plist = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>items</key><array><dict>
<key>assets</key><array><dict><key>kind</key><string>software-package</string>
<key>url</key><string>${xml(signed.signedUrl)}</string></dict></array>
<key>metadata</key><dict>
<key>bundle-identifier</key><string>${xml(app.bundle_id)}</string>
<key>bundle-version</key><string>${xml(app.version)}</string>
<key>kind</key><string>software</string>
<key>title</key><string>${xml(app.name)}</string>
</dict></dict></array></dict></plist>`;
      return new Response(plist, { headers: { "Content-Type": "text/xml; charset=utf-8", "Cache-Control": "no-store" } });
    }
    if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
    const bearer = req.headers.get("Authorization")?.match(/^Bearer (.+)$/i)?.[1];
    if (!bearer) return json({ error: "Authentication required" }, 401);
    const userClient = createClient(projectURL, anonKey, {
      global: { headers: { Authorization: `Bearer ${bearer}` } },
      auth: { persistSession: false },
    });
    const { data: auth, error: authError } = await userClient.auth.getUser(bearer);
    if (authError || !auth.user) return json({ error: "Invalid session" }, 401);
    const body = await req.json();
    if (typeof body.appId !== "string" || !/^[0-9a-f-]{36}$/i.test(body.appId))
      return json({ error: "Invalid app ID" }, 400);
    const { data: app, error } = await userClient.from("apps")
      .select("id,name,bundle_id,version,ipa_path,published")
      .eq("id", body.appId).eq("published", true).single();
    if (error || !app) return json({ error: "App not available" }, 404);
    if (typeof app.ipa_path !== "string" || !/^apps\/[A-Za-z0-9_-]+\.ipa$/.test(app.ipa_path))
      return json({ error: "Upload signed IPA to private storage before installing" }, 422);
    const ticketPayload = b64(encoder.encode(JSON.stringify({
      id: app.id, path: app.ipa_path, exp: Date.now() + MAX_AGE * 1000,
    })));
    const ticket = ticketPayload + "." + await signature(ticketPayload);
    const manifestURL = new URL(req.url);
    manifestURL.search = "";
    manifestURL.searchParams.set("ticket", ticket);
    return json({ installUrl: "itms-services://?action=download-manifest&url=" + encodeURIComponent(manifestURL.toString()) });
  } catch (error) {
    console.error("OTA failure", error);
    return json({ error: "Unable to prepare installation" }, 500);
  }
});
