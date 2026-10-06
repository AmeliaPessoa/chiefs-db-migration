select 'role' tipo, rolname nome from pg_roles where rolname in ('app_user','intelligence_user','tl','rubi')
union all select 'membership', m.member::regrole::text||' em '||m.roleid::regrole::text from pg_auth_members m where m.roleid='tl'::regrole
union all select 'search_path', r.rolname||' '||s.setconfig::text from pg_db_role_setting s join pg_roles r on r.oid=s.setrole where r.rolname='rubi'
union all select 'schema', nspname from pg_namespace where nspname='sobrevive_teste'
union all select 'grant schema', 'rubi usage sobrevive_teste = '||has_schema_privilege('rubi','sobrevive_teste','USAGE')::text where exists (select 1 from pg_namespace where nspname='sobrevive_teste')
order by 1,2;
