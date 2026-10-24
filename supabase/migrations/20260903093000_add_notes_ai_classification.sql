-- Add an explicit, owner-scoped lifecycle for background Inbox classification.
-- Existing notes are classified-by-default so only new quick captures enter pending.

alter table public.notes
  add column if not exists classification_status text not null default 'classified',
  add column if not exists classification_category text,
  add column if not exists classification_source text,
  add column if not exists classified_at timestamptz;

alter table public.notes
  alter column classification_status set default 'classified',
  alter column classification_status set not null;

alter table public.notes
  drop constraint if exists notes_classification_status_check,
  add constraint notes_classification_status_check
    check (classification_status in ('pending', 'classified', 'failed')),
  drop constraint if exists notes_classification_source_check,
  add constraint notes_classification_source_check
    check (
      classification_source is null
      or classification_source in ('existing', 'gemini', 'heuristic_fallback')
    );

create index if not exists idx_notes_pending_inbox_classification
  on public.notes (user_id, created_at desc)
  where capture_source = 'quick_inbox'
    and classification_status in ('pending', 'failed');

comment on column public.notes.classification_status is
  'Background AI classification lifecycle: pending, classified, or failed.';
comment on column public.notes.classification_category is
  'Short semantic category generated for an Inbox note.';
comment on column public.notes.classification_source is
  'Classification provenance: existing, gemini, or heuristic_fallback.';
comment on column public.notes.classified_at is
  'Timestamp of the latest successful background classification.';
