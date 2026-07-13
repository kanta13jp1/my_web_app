-- オーナーアカウントへ X operator 権限 (user_profiles.is_admin) を付与する。
--
-- 背景 (2026-07-13 本番実測): growth-hub の x.post / x.metrics_collect 等の
-- 共有X資格情報を使う操作は、R系ハードニング(2026-07-12)で
-- user_profiles.is_admin = true の「X operator」限定になった。一方オーナー
-- アカウントには is_admin が未付与のままだったため、AIシェアの投稿が
-- 403 {error: Forbidden: X operator role required} で失敗した
-- (動画生成まで成功し、最後の x.post だけ拒否される)。
--
-- is_admin は 20260712144000_lock_user_profile_admin_flag.sql のトリガーで
-- service_role / postgres からしか変更できない(自己昇格防止)。migration は
-- postgres 権限で適用されるため、ここが正規の付与経路になる。
-- email が auth.users に存在しない環境(ローカル/プレビュー)では no-op。
--
-- nocheck: time-relative
-- (S78 ガードは user_profiles の updated_at=NOW() 系トリガーで機械的に警告
--  するが、この UPDATE は boolean の is_admin のみで日付制約と無関係。
--  CURRENT_DATE 比較の CHECK/トリガーに触れないためリプレイ安全。)

-- 既存プロフィール行があるオーナーへ付与
UPDATE public.user_profiles
SET is_admin = true
WHERE user_id IN (
  SELECT id FROM auth.users WHERE email = 'kanta13jp@gmail.com'
);

-- プロフィール行が未作成の場合に備える(存在すれば no-op)
INSERT INTO public.user_profiles (user_id, is_admin)
SELECT u.id, true
FROM auth.users u
WHERE u.email = 'kanta13jp@gmail.com'
  AND NOT EXISTS (
    SELECT 1 FROM public.user_profiles p WHERE p.user_id = u.id
  );
