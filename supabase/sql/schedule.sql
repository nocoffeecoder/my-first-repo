-- Local Pulse: scheduled jobs (BUILD.md §14). NOT a migration: run it once by hand in the Supabase SQL editor.
-- Run AFTER: (1) enabling pg_cron and pg_net in Dashboard > Database > Extensions,
--            (2) deploying the Edge Functions,
--            (3) storing two Vault secrets (run once in the SQL editor, with your values):
--   select vault.create_secret('https://<project-ref>.supabase.co', 'project_url');
--   select vault.create_secret('<long random string, same as the CRON_SECRET function secret>', 'cron_secret');
-- Not tested locally (pg_cron/pg_net are Supabase-hosted). Pattern follows Supabase's
-- "Scheduling Edge Functions" guide, with a shared-secret header instead of a JWT.
-- Written with AI assistance (Claude). Log it in docs/AI_USE_LOG.md if you keep it.

create or replace function public.invoke_function(fn text) returns bigint
language sql security definer set search_path = public, extensions as $$
  select net.http_post(
    url     := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/' || fn,
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')),
    body    := jsonb_build_object('at', now())
  );
$$;
revoke all on function public.invoke_function(text) from public, anon, authenticated;

-- Official sources
select cron.schedule('nws',          '*/5 * * * *',  $$ select public.invoke_function('nws') $$);
select cron.schedule('nws-region',   '*/15 * * * *', $$ select public.invoke_function('nws-region') $$);
select cron.schedule('az511',        '*/5 * * * *',  $$ select public.invoke_function('az511') $$);
select cron.schedule('maricopa-rss', '*/30 * * * *', $$ select public.invoke_function('maricopa-rss') $$);
select cron.schedule('phx-legistar', '7 */6 * * *',  $$ select public.invoke_function('phx-legistar') $$);
select cron.schedule('usgs',         '*/15 * * * *', $$ select public.invoke_function('usgs') $$);
select cron.schedule('gdacs',        '*/30 * * * *', $$ select public.invoke_function('gdacs') $$);
select cron.schedule('eonet',        '12 * * * *',   $$ select public.invoke_function('eonet') $$);
select cron.schedule('who',          '17 */6 * * *', $$ select public.invoke_function('who') $$);
select cron.schedule('fema',         '22 */6 * * *', $$ select public.invoke_function('fema') $$);

-- News sources
select cron.schedule('az-news',      '3,33 * * * *', $$ select public.invoke_function('az-news') $$);
select cron.schedule('gdelt',        '9,39 * * * *', $$ select public.invoke_function('gdelt') $$);

-- AI summaries for new notices (processes a small batch each run)
select cron.schedule('summarize',    '*/5 * * * *',  $$ select public.invoke_function('summarize') $$);

-- Housekeeping (pure SQL, no function call)
select cron.schedule('expire',       '*/15 * * * *', $$ select public.expire_old() $$);

-- To see runs:      select * from cron.job_run_details order by start_time desc limit 20;
-- To pause one:     select cron.unschedule('gdelt');
