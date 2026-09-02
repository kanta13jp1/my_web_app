-- 返済報告カードの画像を X に添付するための公開バケット。
--
-- x.post は既に mediaUrl を受け付けるが、X の media upload は「公開 URL から
-- 取得できる画像」を要求するため、クライアントで描画した PNG を一度公開 URL に
-- 置く必要がある。
--
-- 用途を分離する理由: `ai-generated-images` (OpenAI 生成画像) と混ぜると、
-- 後から「返済カードだけ消したい」ときに選別できない。個人の金額が載る画像
-- なので、消せる単位を分けておく。
--
-- 🔴 public = true = **URL を知っていれば誰でも読める**。X に添付する時点で
-- 公開されるので投稿分には問題ないが、「投稿をやめた画像も URL 上に残る」点は
-- 設計上の受容事項 (パスは uuid なので推測は現実的でない)。

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'debt-progress-cards',
  'debt-progress-cards',
  true,
  5242880,
  array['image/png']::text[]
)
on conflict (id) do update
set
  public = true,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- 書き込みは所有者のみ。読み取りは public バケットなので anon にも開くが、
-- **他人のフォルダへ書けない** ことがここでの肝
-- (`attachments` の direct-upload 強化と同じ形)。
drop policy if exists "Users can upload their own debt progress cards"
  on storage.objects;
drop policy if exists "Users can update their own debt progress cards"
  on storage.objects;
drop policy if exists "Users can delete their own debt progress cards"
  on storage.objects;

create policy "Users can upload their own debt progress cards"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'debt-progress-cards'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can update their own debt progress cards"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'debt-progress-cards'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'debt-progress-cards'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- 投稿をやめた画像を本人が消せるようにする (公開 URL を残さない手段)。
create policy "Users can delete their own debt progress cards"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'debt-progress-cards'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
