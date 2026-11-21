import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const projectURL = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin = createClient(projectURL, serviceKey, { auth: { persistSession: false } });
const MAX_AGE = 3600;

function xml(value: string): string {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;").replace(/'/g, "&apos;");
}
function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: { "Cache-Control": "no-store" } });
}
Deno.serve(async (req) => {
  try {
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
    const { data: signed, error: ipaError } = await admin.storage.from("ipa-files")
      .createSignedUrl(app.ipa_path, MAX_AGE);
    if (ipaError || !signed?.signedUrl) return json({ error: "Signed IPA unavailable" }, 502);
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
    const manifestPath = `manifests/${app.id}/${crypto.randomUUID()}.plist`;
    const { error: uploadError } = await admin.storage.from("ipa-files")
      .upload(manifestPath, new Blob([plist], { type: "application/xml" }), {
        contentType: "application/xml", upsert: false,
      });
    if (uploadError) return json({ error: "Manifest storage unavailable" }, 502);
    const { data: manifest, error: manifestError } = await admin.storage.from("ipa-files")
      .createSignedUrl(manifestPath, MAX_AGE);
    if (manifestError || !manifest?.signedUrl) return json({ error: "Manifest link unavailable" }, 502);
    return json({ installUrl: "itms-services://?action=download-manifest&url=" +
      encodeURIComponent(manifest.signedUrl) });
  } catch (error) {
    console.error("OTA failure", error);
    return json({ error: "Unable to prepare installation" }, 500);
  }
});
