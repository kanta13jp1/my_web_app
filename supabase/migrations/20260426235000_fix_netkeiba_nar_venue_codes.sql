-- Horse racing: correct netkeiba NAR venue codes and backfill existing rows.
-- netkeiba's NAR race_id venue codes are not the same as some NAR official codes.

WITH netkeiba_nar_code_map(code, venue) AS (
  VALUES
    ('30', '門別'),
    ('35', '盛岡'),
    ('36', '水沢'),
    ('42', '浦和'),
    ('43', '船橋'),
    ('44', '大井'),
    ('45', '川崎'),
    ('46', '金沢'),
    ('47', '笠松'),
    ('48', '名古屋'),
    ('50', '園田'),
    ('51', '姫路'),
    ('54', '高知'),
    ('55', '佐賀'),
    ('65', '帯広')
)
UPDATE public.horse_races AS hr
SET venue = m.venue
FROM netkeiba_nar_code_map AS m
WHERE hr.source = 'nar'
  AND substring(hr.race_id_ext from 5 for 2) = m.code
  AND hr.venue IS DISTINCT FROM m.venue;
