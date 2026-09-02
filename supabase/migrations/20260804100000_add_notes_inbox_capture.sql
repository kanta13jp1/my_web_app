-- nocheck: time-relative -- This backfill only updates Inbox metadata on public.notes.
alter table public.notes
  add column if not exists capture_status text,
  add column if not exists capture_source text,
  add column if not exists inbox_saved_at timestamptz;

update public.notes
set
  capture_status = coalesce(capture_status, 'organized'),
  capture_source = coalesce(capture_source, 'editor')
where capture_status is null or capture_source is null;

alter table public.notes
  alter column capture_status set default 'organized',
  alter column capture_status set not null,
  alter column capture_source set default 'editor',
  alter column capture_source set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'notes_capture_status_check'
      and conrelid = 'public.notes'::regclass
  ) then
    alter table public.notes
      add constraint notes_capture_status_check
      check (capture_status in ('inbox', 'organized', 'archived'));
  end if;
end;
$$;

create index if not exists notes_user_inbox_saved_at_idx
  on public.notes (user_id, inbox_saved_at desc)
  where capture_status = 'inbox' and is_archived = false;

comment on column public.notes.capture_status is
  'Inbox capture lifecycle: inbox until the owner marks the note organized.';
comment on column public.notes.capture_source is
  'Origin of the note capture, such as editor or quick_inbox.';
comment on column public.notes.inbox_saved_at is
  'UTC timestamp recorded when a note is saved through quick Inbox capture.';
