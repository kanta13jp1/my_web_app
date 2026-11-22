-- Move update_site_statistics() maintenance from browser clients to pg_cron (#4081).
-- cleanup_old_presence() was already migrated to pg_cron and revoked from anon/authenticated
-- in 20260610090000_session_hygiene_cleanup.sql. This migration completes #4081 by
-- scheduling update_site_statistics() every 15 minutes server-side and revoking client EXECUTE.

revoke all on function public.update_site_statistics() from public, anon, authenticated;
grant execute on function public.update_site_statistics() to service_role;

do $$
declare
  v_job_id bigint;
begin
  begin
    create extension if not exists pg_cron;
  exception
    when others then
      raise notice 'pg_cron extension is not available in this environment.';
      return;
  end;

  select jobid into v_job_id
  from cron.job
  where jobname = 'site_statistics_15m';

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  perform cron.schedule(
    'site_statistics_15m',
    '*/15 * * * *',
    $cmd$select public.update_site_statistics();$cmd$
  );
end $$;
