-- ABUREMAS: allow authenticated administrators to delete app catalog records.
-- Run in Supabase SQL Editor after confirming public.is_admin() exists.
-- This file does not delete existing data or IPA objects.
-- public.apps must already have RLS enabled and appropriate SELECT policies.
DROP POLICY IF EXISTS "ABUREMAS admin delete apps" ON public.apps;
CREATE POLICY "ABUREMAS admin delete apps"
ON public.apps
FOR DELETE
TO authenticated
USING (public.is_admin());

-- PostgreSQL RLS DELETE requires the row to be visible under SELECT policies.
-- If deletion still affects zero rows, verify the admin's SELECT policy,
-- the current JWT, and that public.is_admin() returns true for that account.
