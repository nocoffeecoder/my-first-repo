# Checking feed() locally

With a local Postgres 15+ and PostGIS 3 (or `supabase start`, which sets up the roles, schema and search path for you):

    createdb lp
    psql -d lp -c 'alter database lp set search_path to "$user", public, extensions;'
    psql -d lp -c "create role anon nologin; create role authenticated nologin;"   # skip on Supabase
    psql -d lp -f supabase/migrations/0001_init.sql
    psql -d lp -f tests/sql/seed_areas.sql      # U.S. + France (Natural Earth 110m), Arizona, Maricopa, Pinal, Pima, Phoenix
    psql -d lp -f tests/sql/seed_rows.sql
    psql -d lp -c "set role anon; select feed('local', -112.074, 33.4484)"

Expected (checked on Postgres 16 + PostGIS 3.4 with PostGIS in the extensions schema, Sept 26, 2026):

| Call | alerts | news | other |
|---|---|---|---|
| feed('world', -150, 15) | usgs:q1 | n4 | |
| feed('region', -98.5, 38.5) | none | none | place.country = "United States", country_short = "U.S." |
| feed('state', -111.9, 34.2) | nws:1 (red), nws:2 (orange) | n1 (outlets 2, place Mesa), n3 (Tucson) | hidden.politics 1; county_counts {04013: 2 red, 04019: 1 orange} |
| feed('county', -112.25, 33.4) | nws:1, maricopa_rss:t1 | n1 (outlets 2) | hidden.politics 1 |
| feed('local', -112.074, 33.4484) | nws:1 at 1.7 mi, maricopa_rss:t1 at 0 mi | none: Mesa's center point is 20.9 mi away and no Mesa outline is loaded | |
| feed('local', -110.97, 32.22) | none | n3 at 7.6 mi | place.county = "Pima County" |
| feed('region', 2.3, 46.8) | none | none | place.country = "France" |
| feed('local', -112.074, 33.4484, 999999) | same as the 20-mile call | | radius is clamped to 30 miles |

Border check: `select id, county_fips from notices where id = 'maricopa_rss:t1';` must return `{04013}` only.
Replay check: `update notices set status='expired', last_seen_at=now() where id='nws:1';` then `feed('county', -112.25, 33.4, 32187, true)` returns nws:1.
Permissions: as anon, `select count(*) from archive` and `select upsert_area('{}')` must both fail with "permission denied".
