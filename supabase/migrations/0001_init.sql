-- Local Pulse: initial schema (reference migration from BUILD.md §7)
-- Postgres 15+ with PostGIS 3. Tested against Postgres 16 + PostGIS 3.4 on Sept 26, 2026,
-- with PostGIS in the "extensions" schema and search_path "$user", public, extensions (Supabase's default).
-- Apply with the Supabase CLI (`supabase db push`), not by pasting into the SQL editor.
-- Written with AI assistance (Claude). Log it in docs/AI_USE_LOG.md if you keep it.

create schema if not exists extensions;
create extension if not exists postgis with schema extensions;   -- keeps PostGIS out of the public API

-- ---------------------------------------------------------------------------
-- Sources: one row per feed. Powers the Sources page and the "last checked" dots.
-- ---------------------------------------------------------------------------
create table public.sources (
  id               text primary key,                 -- snake_case: 'nws', 'nws_region', 'maricopa_rss', ... (BUILD.md §14 maps functions to ids)
  name             text not null,                    -- 'National Weather Service'
  kind             text not null check (kind in ('official','news')),
  home_url         text not null,
  terms_note       text not null default '',
  interval_minutes int  not null,                    -- normal polling interval
  enabled          boolean not null default true,
  last_run_at      timestamptz,
  last_ok_at       timestamptz,
  last_error_at    timestamptz,
  last_error       text,
  items_last_run   int not null default 0
);

-- ---------------------------------------------------------------------------
-- Areas: every boundary the app matches against (countries, states, AZ counties,
-- AZ places, AZ school districts, cached NWS zones).
-- id scheme: 'country:USA' 'state:04' 'county:04013' 'place:0455000'
--            'unsd:0406330' 'elsd:0406360' 'scsd:0406340' 'zone:AZZ537'
-- ---------------------------------------------------------------------------
create table public.areas (
  id          text primary key,
  kind        text not null check (kind in ('country','state','county','place','unsd','elsd','scsd','zone')),
  name        text not null,                         -- 'United States', 'Maricopa County' (panel titles)
  short_name  text not null,                         -- 'U.S.', 'Maricopa' (breadcrumb labels)
  code        text not null,                         -- Natural Earth ADM0_A3 for countries (not ISO_A3: it's -99 for France), FIPS/GEOID otherwise, zone id for zones
  parent_id   text references public.areas(id),
  geom        geometry(MultiPolygon, 4326) not null check (st_isvalid(geom))   -- load through upsert_area(), which repairs shapes
);
create index areas_kind_idx on public.areas (kind);
create index areas_geom_gix on public.areas using gist (geom);
create index areas_geog_gix on public.areas using gist ((geom::geography));

-- ---------------------------------------------------------------------------
-- Place names (Census Gazetteer) used to put headlines on the map.
-- ---------------------------------------------------------------------------
create table public.place_names (
  geoid       text primary key,                      -- '0455000'
  name        text not null,                         -- 'Phoenix' (suffix removed)
  full_name   text not null,                         -- 'Phoenix city'
  kind        text not null check (kind in ('city','town','CDP','other')),
  county_fips text,                                  -- '04013' (filled at load time by point-in-county)
  point       geometry(Point, 4326) not null,
  area_id     text references public.areas(id),      -- 'place:0455000' when a polygon is loaded
  needs_cue   boolean not null default false,        -- ordinary word or other famous place (Globe, Surprise, Peoria...)
  blocked     boolean not null default false         -- never match (Congress, York...)
);
create index place_names_point_gix on public.place_names using gist (point);

-- ---------------------------------------------------------------------------
-- Official alerts and notices (the Alerts tab).
-- levels = the levels whose list this notice appears in.
-- ---------------------------------------------------------------------------
create table public.notices (
  id             text primary key,                   -- '<source>:<source_item_id>'
  source         text not null references public.sources(id),
  source_item_id text not null,
  version_key    text not null,                      -- source + id + last-updated; skip if unchanged
  agency         text not null,                      -- 'National Weather Service Phoenix'
  category       text not null check (category in ('weather','roads','air','water','schools','meetings','county','disaster','quake','health')),
  severity       text not null check (severity in ('red','orange','yellow','gray')),
  sev_rank       smallint generated always as (case severity when 'red' then 4 when 'orange' then 3 when 'yellow' then 2 else 1 end) stored,
  headline       text not null,
  summary        text,                               -- AI plain-language version (null until made)
  summary_ok     boolean not null default false,     -- false => show original_text
  original_text  text not null,                      -- agency's exact words
  instruction    text,                               -- agency's "what to do" text, verbatim
  url            text not null,                      -- link to the original. No link, no card.
  issued_at      timestamptz not null,
  starts_at      timestamptz,
  ends_at        timestamptz,                        -- NWS "ends" (danger ends)
  expires_at     timestamptz,                        -- NWS "expires" (message expires)
  levels         text[] not null check (levels <@ array['world','region','state','county','local']),
  country_iso    text,                               -- 'USA'
  state_fips     text,                               -- '04'
  county_fips    text[] not null default '{}',       -- {'04013','04021'}
  area_ids       text[] not null default '{}',       -- filled by trigger from geom
  geom           geometry(Geometry, 4326),
  status         text not null default 'active' check (status in ('active','replaced','cancelled','expired')),
  replaced_by    text,
  ai_model       text,
  ai_made_at     timestamptz,
  first_seen_at  timestamptz not null default now(),
  last_seen_at   timestamptz not null default now()
);
create index notices_status_idx on public.notices (status, issued_at desc);
create index notices_levels_gin on public.notices using gin (levels);
create index notices_county_gin on public.notices using gin (county_fips);
create index notices_geom_gix on public.notices using gist (geom);
create index notices_geog_gix on public.notices using gist ((geom::geography));

-- ---------------------------------------------------------------------------
-- News headlines (the News tab). Headline, outlet, time and link only:
-- never store article text, descriptions or images.
-- ---------------------------------------------------------------------------
create table public.news_items (
  id             text primary key,                   -- sha1 of the canonical URL
  source         text not null references public.sources(id),
  outlet         text not null,                      -- '12News', 'azfamily', 'Cronkite News', GDELT domain
  title          text not null,
  url            text not null unique,
  published_at   timestamptz not null,
  first_seen_at  timestamptz not null default now(),
  levels         text[] not null check (levels <@ array['world','region','state','county','local']),
  country_iso    text,
  state_fips     text,
  county_fips    text[] not null default '{}',
  place_geoids   text[] not null default '{}',       -- Arizona places named in the headline
  topics         text[] not null default '{}',       -- weather, roads, community, schools, health, safety
  hidden_reason  text check (hidden_reason in ('politics','opinion','syndicated','not_local')),
  cluster_id     text                                -- id of the representative item when merged
);
create index news_levels_gin on public.news_items using gin (levels);
create index news_places_gin on public.news_items using gin (place_geoids);
create index news_county_gin on public.news_items using gin (county_fips);
create index news_pub_idx on public.news_items (published_at desc);

-- ---------------------------------------------------------------------------
-- Archive: one row per NEW item version from official sources (demo replay + proof).
-- Not readable by the public.
-- ---------------------------------------------------------------------------
create table public.archive (
  id             bigint generated always as identity primary key,
  source         text not null references public.sources(id),
  source_item_id text not null,
  version_key    text not null,
  fetched_at     timestamptz not null default now(),
  raw            jsonb not null,
  unique (source, version_key)
);

-- ---------------------------------------------------------------------------
-- Area matching: fill area_ids / county_fips / state_fips / country_iso from geom.
-- "Overlaps enough": a shape that only shares a border with an area (a county
-- polygon and its neighbors) doesn't count. Points and lines just need to touch.
-- If a connector pre-fills county_fips (NWS SAME codes), those win over geometry.
-- ---------------------------------------------------------------------------
create or replace function public.overlaps_enough(area geometry, g geometry) returns boolean
language plpgsql immutable set search_path = public, extensions as $$
begin
  if not st_intersects(area, g) then return false; end if;
  if st_dimension(g) < 2 then return true; end if;
  return st_area(st_intersection(area, g)) > 0.01 * least(st_area(area), st_area(g));
exception when others then
  -- GEOS can throw on slightly invalid input; fall back to a plain intersects test
  return st_intersects(area, g) and not st_touches(area, g);
end $$;

create or replace function public.fill_notice_areas() returns trigger
language plpgsql set search_path = public, extensions as $$
begin
  if new.geom is not null then
    select coalesce(array_agg(a.id order by a.id), '{}')
      into new.area_ids
      from public.areas a
     where a.kind in ('state','county','place','unsd','elsd','scsd')
       and a.geom && new.geom
       and public.overlaps_enough(a.geom, new.geom);

    if coalesce(array_length(new.county_fips, 1), 0) = 0 then
      select coalesce(array_agg(a.code order by a.code), '{}')
        into new.county_fips
        from public.areas a
       where a.kind = 'county' and a.geom && new.geom
         and public.overlaps_enough(a.geom, new.geom);
    end if;

    if new.state_fips is null then
      select a.code into new.state_fips
        from public.areas a
       where a.kind = 'state' and a.geom && new.geom and public.overlaps_enough(a.geom, new.geom)
       order by st_area(st_intersection(a.geom, new.geom)) desc
       limit 1;
    end if;

    if new.country_iso is null then
      select a.code into new.country_iso
        from public.areas a
       where a.kind = 'country' and a.geom && new.geom and public.overlaps_enough(a.geom, new.geom)
       order by st_area(st_intersection(a.geom, new.geom)) desc
       limit 1;
    end if;
  end if;
  return new;
end $$;

create trigger notices_fill_areas
  before insert or update of geom on public.notices
  for each row execute function public.fill_notice_areas();

-- ---------------------------------------------------------------------------
-- Where am I: which country, state, county and place contain a point.
-- ---------------------------------------------------------------------------
create or replace function public.where_am_i(lon double precision, lat double precision)
returns table (country_iso text, country_name text, country_short text,
               state_fips text, state_name text,
               county_fips text, county_name text, county_short text,
               place_geoid text, place_name text)
language sql stable set search_path = public, extensions as $$
  with p as (select st_setsrid(st_makepoint(lon, lat), 4326) as g),
  c  as (select a.* from public.areas a, p where a.kind = 'country' and st_contains(a.geom, p.g) limit 1),
  s  as (select a.* from public.areas a, p where a.kind = 'state'   and st_contains(a.geom, p.g) limit 1),
  co as (select a.* from public.areas a, p where a.kind = 'county'  and st_contains(a.geom, p.g) limit 1),
  pl as (select a.* from public.areas a, p where a.kind = 'place'   and st_contains(a.geom, p.g) limit 1)
  select (select code from c), (select name from c), (select short_name from c),
         (select code from s), (select name from s),
         (select code from co), (select name from co), (select short_name from co),
         (select code from pl), (select short_name from pl);
$$;

-- ---------------------------------------------------------------------------
-- Feed for one level. Returns alerts, news and hidden counts as one JSON object.
--   lvl:    'world' | 'region' | 'state' | 'county' | 'local'
--   lon/lat: map center for region/state/county; the saved place for local
--   radius_m: local radius (32187 m = 20 miles)
-- ---------------------------------------------------------------------------
create or replace function public.feed(lvl text, lon double precision, lat double precision,
                                       radius_m integer default 32187,
                                       replay boolean default false)   -- true = ended alerts from the last 7 days
returns jsonb
language plpgsql stable as $$
declare
  w record;
  pt geography := st_setsrid(st_makepoint(lon, lat), 4326)::geography;
  r  integer := least(greatest(coalesce(radius_m, 32187), 1609), 48280);   -- clamp to 1-30 miles
  news_window interval := case when lvl in ('world','region') then interval '24 hours' else interval '48 hours' end;
  max_alerts int := case lvl when 'local' then 15 when 'world' then 10 when 'region' then 10 else 12 end;
  max_news   int := case lvl when 'local' then 15 when 'world' then 10 when 'region' then 10 else 12 end;
  result jsonb;
begin
  if lvl not in ('world','region','state','county','local') then
    raise exception 'unknown level %', lvl;
  end if;
  select * into w from public.where_am_i(lon, lat);

  with a as (
    select n.*,
           case when lvl = 'local' and n.geom is not null
                then round((st_distance(n.geom::geography, pt) / 1609.344)::numeric, 1) end as miles
      from public.notices n
     where (case when replay then n.status <> 'active' and n.last_seen_at > now() - interval '7 days'
                 else n.status = 'active' end)
       and lvl = any(n.levels)
       and case lvl
             when 'world'  then true
             when 'region' then n.country_iso = w.country_iso
             when 'state'  then n.state_fips = w.state_fips
             when 'county' then w.county_fips = any(n.county_fips)
             when 'local'  then n.geom is not null and st_dwithin(n.geom::geography, pt, r)
           end
     order by n.sev_rank desc, n.issued_at desc
     limit max_alerts
  ),
  base_news as (
    select x.*,
           (select round((min(st_distance(coalesce(ar.geom, pn.point)::geography, pt)) / 1609.344)::numeric, 1)
              from public.place_names pn left join public.areas ar on ar.id = pn.area_id
             where pn.geoid = any(x.place_geoids)) as miles,
           (select pn.name
              from public.place_names pn
             where pn.geoid = any(x.place_geoids)
             order by st_distance(pn.point::geography, pt) limit 1) as place_name
      from public.news_items x
     where lvl = any(x.levels)
       and x.published_at > now() - news_window
       and case lvl
             when 'world'  then true
             when 'region' then x.country_iso = w.country_iso
             when 'state'  then x.state_fips = w.state_fips
             when 'county' then w.county_fips = any(x.county_fips)
             when 'local'  then exists (
                 select 1 from public.place_names pn left join public.areas ar on ar.id = pn.area_id
                  where pn.geoid = any(x.place_geoids)
                    and st_dwithin(coalesce(ar.geom, pn.point)::geography, pt, r))
           end
  ),
  shown as (
    select b.*,
           (select count(*) from public.news_items m where m.cluster_id = b.id) + 1 as outlets
      from base_news b
     where b.hidden_reason is null and b.cluster_id is null
     order by b.published_at desc
     limit max_news
  )
  select jsonb_build_object(
    'level', lvl,
    'replay', replay,
    'place', jsonb_build_object('country_iso', w.country_iso, 'country', w.country_name, 'country_short', w.country_short,
                                'state_fips', w.state_fips, 'state', w.state_name,
                                'county_fips', w.county_fips, 'county', w.county_name, 'county_short', w.county_short,
                                'place', w.place_name),
    'alerts', coalesce((select jsonb_agg(jsonb_build_object(
                 'id', a.id, 'source', a.source, 'agency', a.agency, 'category', a.category,
                 'severity', a.severity, 'headline', a.headline,
                 'summary', case when a.summary_ok then a.summary end,
                 'original_text', case when not a.summary_ok then left(a.original_text, 600) end,
                 'url', a.url, 'issued_at', a.issued_at, 'starts_at', a.starts_at,
                 'until', coalesce(a.ends_at, a.expires_at), 'miles', a.miles,
                 'geom', case when a.geom is not null then st_asgeojson(st_simplify(a.geom, 0.001), 5)::jsonb end)
               order by a.sev_rank desc, a.issued_at desc) from a), '[]'::jsonb),
    'news', coalesce((select jsonb_agg(jsonb_build_object(
                 'id', s.id, 'outlet', s.outlet, 'title', s.title, 'url', s.url,
                 'published_at', s.published_at, 'topics', s.topics, 'outlets', s.outlets,
                 'place', s.place_name, 'miles', case when lvl = 'local' then s.miles end)
               order by s.published_at desc) from shown s), '[]'::jsonb),
    -- State level: active alert count and worst severity per county, for the county bubbles
    'county_counts', case when lvl = 'state' then coalesce((
        select jsonb_object_agg(cf, jsonb_build_object('count', cnt, 'max_sev', max_sev))
          from (select cf, count(*) as cnt,
                       (array['gray','yellow','orange','red'])[max(n.sev_rank)] as max_sev
                  from public.notices n, unnest(n.county_fips) cf
                 where n.status = 'active' and 'county' = any(n.levels) and n.state_fips = w.state_fips
                 group by cf) t), '{}'::jsonb) end,
    'hidden', jsonb_build_object(
                 'politics', (select count(*) from base_news b where b.hidden_reason = 'politics'),
                 'opinion',  (select count(*) from base_news b where b.hidden_reason = 'opinion')),
    'generated_at', now()
  ) into result;
  return result;
end $$;

-- ---------------------------------------------------------------------------
-- upsert_area: loaders and the NWS zone cache send GeoJSON through this RPC
-- (supabase-js can't send PostGIS geometry directly). Service role only.
--   select upsert_area('{"id":"zone:AZZ537","kind":"zone","name":"Central Phoenix","short_name":"Central Phoenix",
--                        "code":"AZZ537","parent_id":null,"geometry":{...GeoJSON...}}');
-- ---------------------------------------------------------------------------
create or replace function public.upsert_area(a jsonb) returns void
language sql set search_path = public, extensions as $$
  insert into public.areas (id, kind, name, short_name, code, parent_id, geom)
  values (a->>'id', a->>'kind', a->>'name', a->>'short_name', a->>'code', a->>'parent_id',
          st_multi(st_collectionextract(st_makevalid(st_setsrid(st_geomfromgeojson(a->>'geometry'), 4326)), 3)))
  on conflict (id) do update
    set name = excluded.name, short_name = excluded.short_name, code = excluded.code,
        parent_id = excluded.parent_id, geom = excluded.geom;
$$;

-- ---------------------------------------------------------------------------
-- Housekeeping, called by cron (BUILD.md §14)
-- ---------------------------------------------------------------------------
create or replace function public.expire_old() returns void
language sql set search_path = public, extensions as $$
  -- Notices end at their end time; anything with no end time ends after 7 days.
  -- Sources that list only what is active expire their own rows when an item leaves the feed
  -- (BUILD.md §9 rule 5), so they're skipped here.
  update public.notices set status = 'expired'
   where status = 'active' and source not in ('nws','nws_region','az511','gdacs','eonet')
     and (coalesce(ends_at, expires_at) < now()
          or (ends_at is null and expires_at is null and issued_at < now() - interval '7 days'));
  -- Keep 30 days of notices for the "last 7 days" replay and the archive count.
  delete from public.notices where status <> 'active' and last_seen_at < now() - interval '30 days';
  -- Headlines are only shown for 24-48 hours; keep 7 days.
  delete from public.news_items where published_at < now() - interval '7 days';
$$;

-- ---------------------------------------------------------------------------
-- Row level security: the public (anon) key can only read what the app shows.
-- Connectors write with the service role, which bypasses RLS.
-- ---------------------------------------------------------------------------
alter table public.sources     enable row level security;
alter table public.areas       enable row level security;
alter table public.place_names enable row level security;
alter table public.notices     enable row level security;
alter table public.news_items  enable row level security;
alter table public.archive     enable row level security;   -- no policies: private

-- Table grants (Supabase adds these by default; explicit here so the migration works anywhere).
grant usage on schema public, extensions to anon, authenticated;
grant select on public.sources, public.areas, public.place_names, public.notices, public.news_items to anon, authenticated;
revoke all on public.archive from anon, authenticated;

create policy sources_read     on public.sources     for select to anon, authenticated using (true);
create policy areas_read       on public.areas       for select to anon, authenticated using (true);
create policy place_names_read on public.place_names for select to anon, authenticated using (true);
create policy notices_read     on public.notices     for select to anon, authenticated
  using (status = 'active' or last_seen_at > now() - interval '7 days');
create policy news_read        on public.news_items  for select to anon, authenticated
  using (hidden_reason is null);

-- feed() must count hidden items and read places, so it runs with the owner's rights.
alter function public.feed(text, double precision, double precision, integer, boolean) security definer;
alter function public.feed(text, double precision, double precision, integer, boolean) set search_path = public, extensions;
revoke all on function public.feed(text, double precision, double precision, integer, boolean) from public;
grant execute on function public.feed(text, double precision, double precision, integer, boolean) to anon, authenticated;
grant execute on function public.where_am_i(double precision, double precision) to anon, authenticated;
revoke all on function public.upsert_area(jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Seed the sources table (intervals from BUILD.md §10)
-- ---------------------------------------------------------------------------
insert into public.sources (id, name, kind, home_url, terms_note, interval_minutes) values
  ('nws',          'National Weather Service',          'official', 'https://www.weather.gov/', 'U.S. government, public domain', 5),
  ('nws_region',   'National Weather Service (U.S.)',   'official', 'https://www.weather.gov/', 'U.S. government, public domain', 15),
  ('az511',        'ADOT AZ511',                        'official', 'https://www.az511.com/', 'Free developer key; 10 calls per 60 s', 5),
  ('maricopa_rss', 'Maricopa County',                   'official', 'https://www.maricopa.gov/', 'Government news releases', 30),
  ('phx_legistar', 'City of Phoenix meetings',          'official', 'https://phoenix.legistar.com/', 'Public meeting records', 360),
  ('gdacs',        'GDACS (UN / European Commission)',  'official', 'https://www.gdacs.org/', 'Credit GDACS; check terms before launch', 30),
  ('usgs',         'U.S. Geological Survey',            'official', 'https://earthquake.usgs.gov/', 'Public domain', 15),
  ('eonet',        'NASA EONET',                        'official', 'https://eonet.gsfc.nasa.gov/', 'Public domain', 60),
  ('who',          'World Health Organization',         'official', 'https://www.who.int/emergencies/disease-outbreak-news', 'Credit WHO; check terms', 360),
  ('fema',         'FEMA (OpenFEMA)',                   'official', 'https://www.fema.gov/about/openfema', 'Public', 360),
  ('gdelt',        'The GDELT Project',                 'news',     'https://www.gdeltproject.org/', 'Cite GDELT; 1 call per 5 s; headline and link only', 30),
  ('12news',       '12News',                            'news',     'https://www.12news.com/', 'Headline and link only', 30),
  ('azfamily',     'azfamily',                          'news',     'https://www.azfamily.com/', 'Headline and link only', 30),
  ('cronkite',     'Cronkite News',                     'news',     'https://cronkitenews.azpbs.org/', 'Headline and link only', 30);
