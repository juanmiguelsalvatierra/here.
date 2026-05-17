-- ============================================================
-- 004_realtime.sql  –  Enable Supabase Realtime
-- Run in: Supabase Dashboard → SQL Editor
-- ============================================================

-- Add tables to the realtime publication so the WebSocket
-- delivers INSERT/UPDATE/DELETE events to connected clients.
ALTER PUBLICATION supabase_realtime ADD TABLE posts;
ALTER PUBLICATION supabase_realtime ADD TABLE reactions;
ALTER PUBLICATION supabase_realtime ADD TABLE post_joins;
ALTER PUBLICATION supabase_realtime ADD TABLE comments;

-- REPLICA IDENTITY FULL means DELETE events carry the entire
-- old row, not just the primary key. Without this, a deleted
-- reaction arrives with only { id } — we wouldn't know which
-- post to update in the feed.
ALTER TABLE reactions  REPLICA IDENTITY FULL;
ALTER TABLE post_joins REPLICA IDENTITY FULL;
