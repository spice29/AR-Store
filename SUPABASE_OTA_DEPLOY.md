# ABUREMAS OTA install

The deployed Supabase Edge Function `ota-install` accepts authenticated POST `{"appId":"<uuid>"}` and responds with `installUrl`. It validates the user's JWT, checks access to a published app through RLS, signs the private IPA for one hour, writes a per-install plist to the private `ipa-files` bucket, and signs that plist for one hour. iOS can retrieve both without authentication headers.

Function deployment: `supabase functions deploy ota-install --no-verify-jwt` (the function authenticates POST internally; GET is not implemented). Supabase automatically supplies `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`. No additional signing secret required.

Upload a valid pre-signed Ad Hoc IPA to `ipa-files/apps/<uuid>.ipa` through admin, publish it, and test on an iPhone whose UDID is in the provisioning profile. The iOS app must also be signed and installed. Existing draft app `Test` has no IPA and is unpublished. Manifest objects accumulate and should be periodically cleaned up. Private signed URLs remain usable until expiry.
