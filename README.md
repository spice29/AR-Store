# ABUREMAS Store — متجر أبو ريماس

Private SwiftUI iOS IPA catalog with Supabase authentication, admin dashboard, IPA uploads, and GitHub Actions unsigned builds.

## Current capabilities
- Supabase email/password authentication and password reset via `aburemas://auth/callback`.
- Admin role from `public.profiles` and private admin tab.
- Create/edit app records, draft/publish state, HTTPS IPA links, iOS Files IPA selection and private bucket uploads.
- Published apps catalog with pull-to-refresh and refresh on returning to Home.
- Unsigned iOS IPA produced by GitHub Actions for manual signing.

## Build
1. GitHub Actions builds on push to `main`, pull requests and manual dispatch.
2. Download artifact `ABUREMAS-unsigned` from a successful workflow run (retained 7 days).
3. Sign the unsigned IPA using a valid certificate and provisioning profile containing the device UDID, then install using a compatible signing/distribution tool.

## Supabase prerequisites
- Project URL and **publishable/anon** key in `ABUREMAS/SupabaseConfig.swift` (never embed service-role key).
- Auth users with `public.profiles` role `admin` for administration.
- `public.apps` table and suitable RLS policies for authorized readers and admin writers.
- Private Storage bucket `ipa-files`; run and review `supabase/storage-admin-upload.sql` in Supabase SQL Editor (policy already applied in the user's project).
- Check the project's Storage per-file upload size limit. The iOS picker currently has a 150 MiB memory guard, **not** a guarantee Supabase accepts that size.

## Limitations / next phase
- The catalog currently **does not install IPA files directly**. Installation needs signed IPA distribution and an appropriate manifest/HTTPS hosting workflow, plus secure time-limited access to private IPA files.
- File uploads use an in-memory Data buffer; very large IPA files require resumable/streaming uploads for reliability.
- No automated end-to-end tests of live Supabase permissions, device signing, or installation.
- A successful build does not prove live upload and installation work.

## Security
Keep `ipa-files` private; never add unrestricted public Storage SELECT. Do not distribute private signing certificates or service-role keys in the repo.
