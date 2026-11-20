# ABUREMAS — Production readiness

## Confirmed
- GitHub Actions builds unsigned IPA on main and pull requests.
- Admin interface supports creating/editing apps and uploading IPA to private bucket.
- Login and role checks are implemented.

## Required before declaring fully operational
1. Apply `supabase/storage-authorized-read.sql` in Supabase SQL Editor. Verify the policy and the private `ipa-files` bucket.
2. Confirm Supabase Storage upload limits are sufficient for real IPA sizes; app's 150 MiB guard does not override the server limit.
3. Verify selecting an IPA, uploading it, publishing it, and downloading it from a non-admin account on a real iPhone.
4. **Install is not implemented.** A signed IPA must be distributed through an Apple-supported method; for wireless installation, host a valid manifest plist and IPA via trusted HTTPS and open an `itms-services` link. Do not confuse temporary file download with installation.
5. Determine actual P12/mobileprovision distribution type (Ad Hoc / Enterprise / Development). Do not upload signing credentials into the repository or chat. Validate intended devices are authorized.
6. Verify app signing and installation on the device and test expiration/revocation handling.
7. Add end-to-end tests and a secure distribution endpoint before declaring production-ready.

## Safety
Never ship the Supabase service-role key in the client. Do not make the IPA bucket public. Keep private IPA download URLs short-lived and scope SELECT to published apps and authorized administrators.
