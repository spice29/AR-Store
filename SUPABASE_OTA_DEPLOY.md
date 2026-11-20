# ABUREMAS: Supabase OTA install deployment

The SwiftUI **تثبيت** button invokes `ota-install` using the signed-in user's JWT. The Edge Function checks the user, published app, and private storage path, then issues a short-lived HMAC-signed manifest ticket. iOS fetches the manifest without custom Authorization headers and then fetches the signed IPA from private Supabase Storage.

## Deploy (project ikzhzfqhgnhnsdyvbzqt)

1. In Supabase Dashboard, open **Edge Functions** and deploy `supabase/functions/ota-install/index.ts` as function **ota-install**. Configure **JWT verification disabled** for this function because iOS requests the manifest without a bearer header; the function itself authenticates every POST and validates HMAC on GET.
2. Set a **new random 32+ character** `OTA_SIGNING_SECRET` in Edge Function secrets. Do not paste this secret into GitHub or Swift code. Supabase's server-provided `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` must be available to the function. The service role is server-side only.
3. Ensure the `ipa-files` bucket stays **private**, and apply the `supabase/storage-authorized-read.sql` policy if needed for the legacy download feature.
4. Sign each IPA **Ad Hoc** with a provisioning profile containing the recipient device's UDID, and verify the signed IPA bundle identifier and version match the app record. Upload that signed IPA using the admin file picker, then publish the app.
5. Build and sign ABUREMAS itself, log in as an authorized user, tap **تثبيت**, and test installation on a registered device.

## Security and limitations

- Ticket and IPA signed URLs expire after one hour. They are bearer URLs: anyone holding a valid unexpired URL can use it. Do not share them publicly. Removing an app from publication prevents new manifest requests; already-issued signed IPA URLs may remain usable until expiration/caching.
- Only paths matching `apps/<generated-id>.ipa` are accepted. External HTTPS IPA links cannot be installed through this endpoint; re-upload the signed IPA to private Storage.
- This is **not** server-side IPA signing. The signing certificate/profile must be valid and each target device must be registered in Ad Hoc provisioning.
- The feature is not production-verified until the Edge Function is deployed and a real device completes installation. Never put service role or signing secrets in the iOS app.
