-- Prevent concurrent approval requests from creating the same downstream item.
CREATE UNIQUE INDEX IF NOT EXISTS hub_data_eval_automation_item_unique
ON public.hub_data (
  source,
  (metadata ->> 'user_id'),
  (metadata ->> 'approval_request_id'),
  (metadata ->> 'automation_item_key')
)
WHERE source IN ('team_task', 'calendar_event')
  AND metadata ->> 'source' = 'eval_approval'
  AND COALESCE(metadata ->> 'user_id', '') <> ''
  AND COALESCE(metadata ->> 'approval_request_id', '') <> ''
  AND COALESCE(metadata ->> 'automation_item_key', '') <> '';
