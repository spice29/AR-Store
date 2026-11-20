# ABUREMAS — Operational notes

- The private `ipa-files` bucket is not a public distribution endpoint.
- iOS `fileImporter` now selects Files items and verifies the `.ipa` extension. Selected file name and size are displayed before upload.
- Saving a new app in Files mode without selecting an IPA is rejected. Existing app records can be edited without replacing their IPA.
- Upload limit in this client is 150 MiB; Supabase server limits may be lower. Avoid keeping large IPA data in memory in future releases; implement streaming/resumable uploads.
- iOS cannot install an arbitrary IPA directly from a local file or bare HTTPS link. A signed IPA and supported OTA distribution are required; do not present the HTTPS link as a one-tap install button.
- For authorized private downloads, implement short-lived signed URLs with properly scoped Storage SELECT policy and audited authorization. Never make the bucket public or ship service-role credentials.
