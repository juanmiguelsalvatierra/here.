-- ============================================================
-- 005_push.sql  –  Push notification tokens
-- Run in: Supabase Dashboard → SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS push_tokens (
    user_id    uuid        PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    token      text        NOT NULL,
    platform   text        NOT NULL DEFAULT 'apns',
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "push_tokens: user manages own" ON push_tokens;
CREATE POLICY "push_tokens: user manages own"
    ON push_tokens FOR ALL
    USING    (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP TRIGGER IF EXISTS push_tokens_set_updated_at ON push_tokens;
CREATE TRIGGER push_tokens_set_updated_at
    BEFORE UPDATE ON push_tokens
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- Supabase Storage buckets
-- Run these in the SQL editor OR create buckets manually in
-- Storage → New Bucket in the Supabase Dashboard.
-- ============================================================

-- Avatars: public read, authenticated write
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "avatars: public read"      ON storage.objects;
DROP POLICY IF EXISTS "avatars: auth upload"      ON storage.objects;

CREATE POLICY "avatars: public read"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');

CREATE POLICY "avatars: auth upload"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] IS NOT NULL);

-- Post images: public read, authenticated write
INSERT INTO storage.buckets (id, name, public)
VALUES ('post-images', 'post-images', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "post-images: public read"  ON storage.objects;
DROP POLICY IF EXISTS "post-images: auth upload"  ON storage.objects;

CREATE POLICY "post-images: public read"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'post-images');

CREATE POLICY "post-images: auth upload"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'post-images');
