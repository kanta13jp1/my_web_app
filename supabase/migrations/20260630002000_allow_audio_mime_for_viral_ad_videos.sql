-- Allow generated narration audio to be stored next to viral ad videos.
-- Hedra presenter videos consume a public uploaded MP3 when ElevenLabs/OpenAI
-- TTS is used instead of Hedra's text_to_speech generation.

UPDATE storage.buckets
SET allowed_mime_types = ARRAY(
  SELECT DISTINCT unnest(
    coalesce(allowed_mime_types, ARRAY[]::text[]) ||
    ARRAY['audio/mpeg', 'audio/mp3']::text[]
  )
)
WHERE id = 'viral-ad-videos';
