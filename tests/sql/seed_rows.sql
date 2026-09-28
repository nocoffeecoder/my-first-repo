-- Sample rows for checking feed() (BUILD.md §26). Run after 0001_init.sql and seed_areas.sql.
-- Headlines are made up. Expected results are in tests/sql/README.md.
insert into place_names(geoid,name,full_name,kind,county_fips,point,area_id,needs_cue) values
 ('0455000','Phoenix','Phoenix city','city','04013',st_setsrid(st_makepoint(-112.090,33.572),4326),'place:0455000',false),
 ('0446000','Mesa','Mesa city','city','04013',st_setsrid(st_makepoint(-111.716487,33.400626),4326),null,false),
 ('0477000','Tucson','Tucson city','city','04019',st_setsrid(st_makepoint(-110.87,32.15),4326),null,false);

insert into notices(id,source,source_item_id,version_key,agency,category,severity,headline,original_text,url,issued_at,ends_at,levels,geom)
values ('nws:1','nws','1','nws:1:a','National Weather Service Phoenix','weather','red','Dust Storm Warning','orig','https://forecast.weather.gov/MapClick.php?lat=33.4&lon=-112.2',now(),now()+interval '2 hours',
  array['state','county','local'], st_setsrid(st_geomfromtext('POLYGON((-112.42 33.29,-112.08 33.27,-112.02 33.40,-112.20 33.47,-112.40 33.42,-112.42 33.29))'),4326));
insert into notices(id,source,source_item_id,version_key,agency,category,severity,headline,original_text,url,issued_at,levels,geom)
values ('usgs:q1','usgs','q1','usgs:q1:a','U.S. Geological Survey','quake','gray','M 5.6 - 74 km ESE of Kokopo, Papua New Guinea','orig','https://earthquake.usgs.gov/',now(),array['world'], st_setsrid(st_makepoint(152.84,-4.70),4326));
insert into notices(id,source,source_item_id,version_key,agency,category,severity,headline,original_text,url,issued_at,levels,county_fips,state_fips,geom)
values ('nws:2','nws','2','nws:2:a','National Weather Service Tucson','weather','orange','Flood Watch','orig','https://forecast.weather.gov/',now(),array['state','county','local'],array['04019'],'04',null);

insert into news_items(id,source,outlet,title,url,published_at,levels,state_fips,county_fips,place_geoids,topics) values
 ('n1','12news','12News','Sample: Mesa story','https://example.com/1',now()-interval '1 hour',array['state','county','local'],'04',array['04013'],array['0446000'],array['community']),
 ('n2','azfamily','azfamily','Sample: same Mesa story','https://example.com/2',now()-interval '2 hour',array['state','county','local'],'04',array['04013'],array['0446000'],array['community']),
 ('n3','12news','12News','Sample: Tucson story','https://example.com/3',now()-interval '3 hour',array['state','county','local'],'04',array['04019'],array['0477000'],array['safety']),
 ('n4','gdelt','example.com','Sample: world story','https://example.com/4',now()-interval '3 hour',array['world'],null,'{}','{}','{}'),
 ('n5','12news','12News','Sample: election story','https://example.com/5',now()-interval '3 hour',array['state','county','local'],'04',array['04013'],'{}','{}');
update news_items set cluster_id='n1' where id='n2';
update news_items set hidden_reason='politics' where id='n5';

-- A county press release uses the whole Maricopa County shape. It must match only Maricopa (04013),
-- not the neighboring counties it shares borders with (Pinal 04021, Pima 04019 are in seed_areas.sql).
insert into notices(id,source,source_item_id,version_key,agency,category,severity,headline,original_text,url,issued_at,levels,geom)
select 'maricopa_rss:t1','maricopa_rss','t1','maricopa_rss:t1:a','Maricopa County','county','gray','Sample: county release','orig','https://www.maricopa.gov/',now(),array['county','local'],geom
  from areas where id='county:04013';
