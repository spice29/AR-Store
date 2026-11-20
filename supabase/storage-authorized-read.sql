-- ABUREMAS private IPA read policy.
-- Run in Supabase SQL Editor as project owner. Bucket stays PRIVATE.
-- Permits authenticated users to create short-lived signed URLs only for
-- published app objects; admins may also access their draft IPA objects.
-- Ensure public.is_admin() exists and is protected against RLS recursion.
DROP POLICY IF EXISTS "ABUREMAS authorized read published IPA" ON storage.objects;
CREATE POLICY "ABUREMAS authorized read published IPA"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'ipa-files'
  AND (storage.foldername(name))[1] = 'apps'
  AND (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.apps a
      WHERE a.published = true
        AND a.ipa_path = storage.objects.name
    )
  )
);
-- Do not add a public SELECT policy to storage.objects.
