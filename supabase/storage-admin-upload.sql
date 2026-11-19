-- Review before running in Supabase SQL Editor.
-- This policy restricts uploads to admins, to the private ipa-files bucket and apps/ folder.
create policy "ABUREMAS admin upload IPA"
on storage.objects for insert to authenticated
with check (
 bucket_id = 'ipa-files'
 and (storage.foldername(name))[1] = 'apps'
 and public.is_admin()
);
-- No public read policy is added.
