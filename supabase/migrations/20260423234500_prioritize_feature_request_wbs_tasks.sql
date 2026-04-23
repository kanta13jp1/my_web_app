-- Prioritize registered feature-request tasks in WBS.
-- Existing request tasks keep their own high/medium/low urgency, but the
-- category ordering is moved to the front so they surface first in WBS views.

UPDATE wbs_tasks
SET category_order = 0
WHERE category = 'ユーザー要望'
   OR title LIKE '[追加要望]%';
