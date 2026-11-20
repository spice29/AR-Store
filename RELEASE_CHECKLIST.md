# ABUREMAS — Release checklist

## Included
- SwiftUI store with compact home, application cards, published list, categories list, account status, admin dashboard.
- Admin app create/edit, draft/publish, file picker and private Supabase Storage upload.
- Auth and password recovery preserved.
- Automated GitHub Actions unsigned IPA builds.

## Verified vs not verified
- Source changes committed to GitHub.
- Build must pass on the PR before merging. Actual iPhone behavior still requires device testing.
- Private bucket uploads depend on Storage policy, project file-size limits and network; SQL policy was successfully run according to Supabase screenshot.
- The app opens external HTTPS IPA links but **does not provide one-tap iOS installation**. iOS installation requires signing and a supported distribution mechanism (e.g. itms-services manifest), not merely a .ipa URL.
- Supabase private IPA paths are intentionally not exposed as public URLs. Future secure downloads require short-lived signed URLs or a server-side authorization flow.

## Device acceptance test
1. Log in as admin and confirm management tab appears.
2. Open existing Test draft and choose IPA from Files.
3. Confirm filename displays; save and check Supabase Storage `ipa-files/apps/`.
4. Publish the record; return to Home and confirm it appears.
5. Confirm the bottom tab bar does not cover cards, including with large Dynamic Type.

## Deployment
Use the successful GitHub Actions `ABUREMAS-unsigned` artifact. Sign with the user's own certificate/provisioning profile and install on a provisioned device. Do not commit signing keys or credentials.
