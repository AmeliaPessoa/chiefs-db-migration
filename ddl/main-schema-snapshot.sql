--
-- PostgreSQL database dump
--

-- Dumped from database version 17.9
-- Dumped by pg_dump version 17.0

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: _heroku; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA _heroku;


--
-- Name: analytics; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA analytics;


--
-- Name: SCHEMA analytics; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA analytics IS 'Schema for analytics data';


--
-- Name: heroku_ext; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA heroku_ext;


--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA heroku_ext;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


--
-- Name: create_ext(); Type: FUNCTION; Schema: _heroku; Owner: -
--

CREATE FUNCTION _heroku.create_ext() RETURNS event_trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $$

DECLARE

  schemaname pg_catalog.TEXT;
  databaseowner pg_catalog.TEXT;

  r pg_catalog.RECORD;

BEGIN
  IF tg_tag OPERATOR(pg_catalog.=) 'CREATE EXTENSION'
       OR tg_tag OPERATOR(pg_catalog.=) 'ALTER EXTENSION' THEN
    PERFORM _heroku.validate_search_path();

    FOR r IN SELECT * FROM pg_catalog.pg_event_trigger_ddl_commands()
    LOOP
        CONTINUE WHEN (r.command_tag OPERATOR(pg_catalog.!=) 'CREATE EXTENSION'
                         AND r.command_tag OPERATOR(pg_catalog.!=) 'ALTER EXTENSION')
                      OR r.object_type OPERATOR(pg_catalog.!=) 'extension';

        schemaname := (
            SELECT n.nspname
            FROM pg_catalog.pg_extension AS e
            INNER JOIN pg_catalog.pg_namespace AS n
            ON e.extnamespace OPERATOR(pg_catalog.=) n.oid
            WHERE e.oid OPERATOR(pg_catalog.=) r.objid
        );

        databaseowner := (
            SELECT pg_catalog.pg_get_userbyid(d.datdba)
            FROM pg_catalog.pg_database d
            WHERE d.datname OPERATOR(pg_catalog.=) pg_catalog.current_database()
        );
        --RAISE NOTICE 'Record for event trigger %, objid: %,tag: %, current_user: %, schema: %, database_owenr: %', r.object_identity, r.objid, tg_tag, current_user, schemaname, databaseowner;
        -- Though not ideal, we do not fully quality operators; we should be protected by validate_search_path
        IF r.object_identity OPERATOR(pg_catalog.=) 'address_standardizer_data_us' THEN
            PERFORM _heroku.grant_table_if_exists(schemaname, 'SELECT, UPDATE, INSERT, DELETE', databaseowner, 'us_gaz');
            PERFORM _heroku.grant_table_if_exists(schemaname, 'SELECT, UPDATE, INSERT, DELETE', databaseowner, 'us_lex');
            PERFORM _heroku.grant_table_if_exists(schemaname, 'SELECT, UPDATE, INSERT, DELETE', databaseowner, 'us_rules');
        ELSIF r.object_identity OPERATOR(pg_catalog.=) 'amcheck' THEN
            -- Grant execute permissions on amcheck functions (bt_*, gin_*, and verify_*)
            PERFORM _heroku.grant_function_execute_for_extension(r.objid, schemaname, databaseowner, ARRAY['bt_%', 'gin_%', 'verify_%'], NULL);
        ELSIF r.object_identity OPERATOR(pg_catalog.=) 'dblink' THEN
            -- Grant execute permissions on dblink functions, excluding dblink_connect_u()
            -- which allows unauthenticated connections and should remain superuser-only
            PERFORM _heroku.grant_function_execute_for_extension(r.objid, schemaname, databaseowner, ARRAY['dblink%'], 'dblink_connect_u%');
            -- Explicitly revoke permissions on dblink_connect_u functions as a safety measure
            -- in case they were granted by default or in a previous version
            BEGIN
                EXECUTE pg_catalog.format('REVOKE EXECUTE ON FUNCTION %I.dblink_connect_u(text) FROM %I;', schemaname, databaseowner);
            EXCEPTION WHEN OTHERS THEN
                -- Function might not exist, continue
                NULL;
            END;
            BEGIN
                EXECUTE pg_catalog.format('REVOKE EXECUTE ON FUNCTION %I.dblink_connect_u(text, text) FROM %I;', schemaname, databaseowner);
            EXCEPTION WHEN OTHERS THEN
                -- Function might not exist, continue
                NULL;
            END;
        ELSIF r.object_identity OPERATOR(pg_catalog.=) 'dict_int' THEN
            EXECUTE pg_catalog.format('ALTER TEXT SEARCH DICTIONARY %I.intdict OWNER TO %I;', schemaname, databaseowner);
        ELSIF r.object_identity OPERATOR(pg_catalog.=) 'pg_prewarm' THEN
            -- Grant execute permissions on pg_prewarm and autoprewarm functions
            PERFORM _heroku.grant_function_execute_for_extension(
                r.objid, schemaname, databaseowner, ARRAY['pg_prewarm%', 'autoprewarm%'], NULL
            );
        ELSIF r.object_identity OPERATOR(pg_catalog.=) 'pg_partman' THEN
            PERFORM _heroku.grant_table_if_exists(schemaname, 'SELECT, UPDATE, INSERT, DELETE', databaseowner, 'part_config');
            PERFORM _heroku.grant_table_if_exists(schemaname, 'SELECT, UPDATE, INSERT, DELETE', databaseowner, 'part_config_sub');
            PERFORM _heroku.grant_table_if_exists(schemaname, 'SELECT, UPDATE, INSERT, DELETE', databaseowner, 'custom_time_partitions');
        ELSIF r.object_identity OPERATOR(pg_catalog.=) 'pg_stat_statements' THEN
            PERFORM _heroku.grant_function_execute_for_extension(
                r.objid, schemaname, databaseowner, ARRAY['pg_stat_statements%'], 'pg_stat_statements_reset%'
            );
            EXECUTE pg_catalog.format(
                'GRANT EXECUTE ON FUNCTION %I.pg_stat_statements_reset TO %I',
                schemaname, pg_catalog.current_user()
            );
        ELSIF r.object_identity OPERATOR(pg_catalog.=) 'postgres_fdw' THEN
            -- Grant USAGE on the foreign data wrapper (required for creating foreign servers and user mappings)
            EXECUTE pg_catalog.format('GRANT USAGE ON FOREIGN DATA WRAPPER postgres_fdw TO %I;', databaseowner);
            -- Grant execute permissions on all postgres_fdw functions
            PERFORM _heroku.grant_function_execute_for_extension(r.objid, schemaname, databaseowner, ARRAY['postgres_fdw%'], NULL);
        ELSIF r.object_identity OPERATOR(pg_catalog.=) 'postgis' THEN
            PERFORM _heroku.postgis_after_create();
        ELSIF r.object_identity OPERATOR(pg_catalog.=) 'postgis_raster' THEN
            PERFORM _heroku.postgis_after_create();
            PERFORM _heroku.grant_table_if_exists(schemaname, 'SELECT', databaseowner, 'raster_columns');
            PERFORM _heroku.grant_table_if_exists(schemaname, 'SELECT', databaseowner, 'raster_overviews');
        ELSIF r.object_identity OPERATOR(pg_catalog.=) 'postgis_topology' THEN
            PERFORM _heroku.postgis_after_create();
            EXECUTE pg_catalog.format('ALTER SCHEMA topology OWNER TO %I;', databaseowner);
            EXECUTE pg_catalog.format('GRANT USAGE ON SCHEMA topology TO %I;', databaseowner);
            EXECUTE pg_catalog.format('GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA topology TO %I;', databaseowner);
            PERFORM _heroku.grant_table_if_exists('topology', 'SELECT, UPDATE, INSERT, DELETE', databaseowner);
            EXECUTE pg_catalog.format('GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA topology TO %I;', databaseowner);
        ELSIF r.object_identity OPERATOR(pg_catalog.=) 'postgis_tiger_geocoder' THEN
            PERFORM _heroku.postgis_after_create();
            EXECUTE pg_catalog.format('ALTER SCHEMA tiger OWNER TO %I;', databaseowner);
            EXECUTE pg_catalog.format('GRANT USAGE ON SCHEMA tiger TO %I;', databaseowner);
            EXECUTE pg_catalog.format('GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA tiger TO %I;', databaseowner);
            PERFORM _heroku.grant_table_if_exists('tiger', 'SELECT, UPDATE, INSERT, DELETE', databaseowner);
            EXECUTE pg_catalog.format('ALTER SCHEMA tiger_data OWNER TO %I;', databaseowner);
            EXECUTE pg_catalog.format('GRANT USAGE ON SCHEMA tiger_data TO %I;', databaseowner);
            EXECUTE pg_catalog.format('GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA tiger_data TO %I;', databaseowner);
            PERFORM _heroku.grant_table_if_exists('tiger_data', 'SELECT, UPDATE, INSERT, DELETE', databaseowner);
        END IF;
    END LOOP;
  END IF;
END;
$$;


--
-- Name: drop_ext(); Type: FUNCTION; Schema: _heroku; Owner: -
--

CREATE FUNCTION _heroku.drop_ext() RETURNS event_trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $$

DECLARE

  schemaname pg_catalog.TEXT;
  databaseowner pg_catalog.TEXT;

  r pg_catalog.RECORD;

BEGIN
  IF tg_tag OPERATOR(pg_catalog.=) 'DROP EXTENSION' THEN
    PERFORM _heroku.validate_search_path();

    FOR r IN SELECT * FROM pg_catalog.pg_event_trigger_dropped_objects()
    LOOP
      CONTINUE WHEN r.object_type OPERATOR(pg_catalog.!=) 'extension';

      databaseowner := (
            SELECT pg_catalog.pg_get_userbyid(d.datdba)
            FROM pg_catalog.pg_database d
            WHERE d.datname OPERATOR(pg_catalog.=) pg_catalog.current_database()
      );

      --RAISE NOTICE 'Record for event trigger %, objid: %,tag: %, current_user: %, database_owner: %, schemaname: %', r.object_identity, r.objid, tg_tag, current_user, databaseowner, r.schema_name;

      IF r.object_identity OPERATOR(pg_catalog.=) 'postgis_topology' THEN
          EXECUTE pg_catalog.format('DROP SCHEMA IF EXISTS topology');
      END IF;
    END LOOP;

  END IF;
END;
$$;


--
-- Name: extension_before_drop(); Type: FUNCTION; Schema: _heroku; Owner: -
--

CREATE FUNCTION _heroku.extension_before_drop() RETURNS event_trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $$

DECLARE

  query pg_catalog.TEXT;

BEGIN
  -- skip this validation if executed by an rds_superuser
  IF tg_tag OPERATOR(pg_catalog.=) 'DROP EXTENSION' AND NOT pg_catalog.pg_has_role(session_user, 'rds_superuser', 'MEMBER') THEN
    PERFORM _heroku.validate_search_path();

    query := pg_catalog.unistr(pg_catalog.lower(pg_catalog.current_query()));
    IF query OPERATOR(pg_catalog.~) '\mplpgsql\M' THEN
      RAISE EXCEPTION 'The plpgsql extension is required for database management and cannot be dropped.';
    END IF;
  END IF;
END;
$$;


--
-- Name: extension_before_run(); Type: FUNCTION; Schema: _heroku; Owner: -
--

CREATE FUNCTION _heroku.extension_before_run() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF tg_tag OPERATOR(pg_catalog.=) 'CREATE EXTENSION'
       OR tg_tag OPERATOR(pg_catalog.=) 'ALTER EXTENSION'
       OR tg_tag OPERATOR(pg_catalog.=) 'DROP EXTENSION' THEN
    PERFORM _heroku.validate_search_path();
    PERFORM _heroku.validate_pg_temp_clean();
    PERFORM _heroku.validate_extension_query();
  END IF;
END;
$$;


--
-- Name: grant_function_execute_for_extension(oid, text, text, text[], text); Type: FUNCTION; Schema: _heroku; Owner: -
--

CREATE FUNCTION _heroku.grant_function_execute_for_extension(extension_oid oid, schemaname text, databaseowner text, name_patterns text[] DEFAULT NULL::text[], exclude_pattern text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $$

DECLARE
    func_rec pg_catalog.RECORD;

BEGIN
    PERFORM _heroku.validate_search_path();

    -- Dynamically grant execute permissions on extension functions.
    -- Finds functions belonging to the extension via pg_depend and grants execute permissions.
    FOR func_rec IN
        SELECT p.oid::regprocedure::text as func_sig
        FROM pg_catalog.pg_depend d
        JOIN pg_catalog.pg_proc p ON d.objid OPERATOR(pg_catalog.=) p.oid
        JOIN pg_catalog.pg_namespace n ON p.pronamespace OPERATOR(pg_catalog.=) n.oid
        WHERE d.refclassid OPERATOR(pg_catalog.=) 'pg_catalog.pg_extension'::regclass::oid
          AND d.refobjid OPERATOR(pg_catalog.=) extension_oid
          AND d.deptype OPERATOR(pg_catalog.=) 'e'
          AND n.nspname OPERATOR(pg_catalog.=) schemaname::name
          AND (name_patterns IS NULL OR p.proname OPERATOR(pg_catalog.~~) ANY(name_patterns))
          AND (exclude_pattern IS NULL OR p.proname OPERATOR(pg_catalog.!~~) exclude_pattern)
    LOOP
        BEGIN
            EXECUTE pg_catalog.format('GRANT EXECUTE ON FUNCTION %s TO %I;', func_rec.func_sig, databaseowner);
        EXCEPTION WHEN OTHERS THEN
            -- Function might not exist or already granted, continue
            NULL;
        END;
    END LOOP;
END;
$$;


--
-- Name: grant_table_if_exists(text, text, text, text); Type: FUNCTION; Schema: _heroku; Owner: -
--

CREATE FUNCTION _heroku.grant_table_if_exists(alias_schemaname text, grants text, databaseowner text, alias_tablename text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $$

BEGIN
  PERFORM _heroku.validate_search_path();

  IF alias_tablename IS NULL THEN
    EXECUTE pg_catalog.format('GRANT %s ON ALL TABLES IN SCHEMA %I TO %I;', grants, alias_schemaname, databaseowner);
  ELSE
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_tables WHERE pg_tables.schemaname OPERATOR(pg_catalog.=) alias_schemaname::name AND pg_tables.tablename OPERATOR(pg_catalog.=) alias_tablename::name) THEN
      EXECUTE pg_catalog.format('GRANT %s ON TABLE %I.%I TO %I;', grants, alias_schemaname, alias_tablename, databaseowner);
    END IF;
  END IF;
END;
$$;


--
-- Name: pg_stat_statements_reset(); Type: FUNCTION; Schema: _heroku; Owner: -
--

CREATE FUNCTION _heroku.pg_stat_statements_reset() RETURNS timestamp with time zone
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$
DECLARE
  v_schema pg_catalog.text;
  v_result pg_catalog.timestamptz;
BEGIN
  SELECT n.nspname INTO v_schema
  FROM pg_catalog.pg_extension e
  JOIN pg_catalog.pg_namespace n ON n.oid OPERATOR(pg_catalog.=) e.extnamespace
  WHERE e.extname OPERATOR(pg_catalog.=) 'pg_stat_statements';

  IF v_schema IS NULL THEN
    RAISE EXCEPTION 'pg_stat_statements is not installed';
  END IF;

  EXECUTE pg_catalog.format(
    'SELECT %I.pg_stat_statements_reset($1, $2, $3)',
    v_schema
  )
  USING 0::pg_catalog.oid,
        (SELECT oid FROM pg_catalog.pg_database WHERE datname OPERATOR(pg_catalog.=) pg_catalog.current_database()),
        0::pg_catalog.int8
  INTO v_result;

  RETURN v_result;
END;
$_$;


--
-- Name: postgis_after_create(); Type: FUNCTION; Schema: _heroku; Owner: -
--

CREATE FUNCTION _heroku.postgis_after_create() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $$
DECLARE
    schemaname pg_catalog.TEXT;
    databaseowner pg_catalog.TEXT;
BEGIN
    PERFORM _heroku.validate_search_path();

    schemaname := (
        SELECT n.nspname
        FROM pg_catalog.pg_extension AS e
        INNER JOIN pg_catalog.pg_namespace AS n ON e.extnamespace OPERATOR(pg_catalog.=) n.oid
        WHERE e.extname OPERATOR(pg_catalog.=) 'postgis'
    );
    databaseowner := (
        SELECT pg_catalog.pg_get_userbyid(d.datdba)
        FROM pg_catalog.pg_database d
        WHERE d.datname OPERATOR(pg_catalog.=) pg_catalog.current_database()
    );

    EXECUTE pg_catalog.format('GRANT EXECUTE ON FUNCTION %I.st_tileenvelope TO %I;', schemaname, databaseowner);
    EXECUTE pg_catalog.format('GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE %I.spatial_ref_sys TO %I;', schemaname, databaseowner);
END;
$$;


--
-- Name: sanitize_search_path(text); Type: FUNCTION; Schema: _heroku; Owner: -
--

CREATE FUNCTION _heroku.sanitize_search_path(unsafe_search_path text DEFAULT NULL::text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  search_path_parts pg_catalog.TEXT[];
  safe_search_path pg_catalog.TEXT;
BEGIN
  IF unsafe_search_path IS NULL THEN
    unsafe_search_path := pg_catalog.current_setting('search_path');
  END IF;

  search_path_parts := pg_catalog.string_to_array(unsafe_search_path, ',');
  search_path_parts := (
    SELECT pg_catalog.array_agg(TRIM(schema_name::text))
    FROM pg_catalog.unnest(search_path_parts) AS schema_name
    WHERE TRIM(schema_name::text) OPERATOR(pg_catalog.!~~) 'pg_temp%'
  );
  search_path_parts := (SELECT pg_catalog.array_remove(search_path_parts, 'pg_catalog'));
  search_path_parts := (SELECT pg_catalog.array_append(search_path_parts, 'pg_temp'));
  SELECT pg_catalog.array_to_string(search_path_parts, ',') INTO safe_search_path;
  RETURN safe_search_path;
END;
$$;


--
-- Name: validate_extension(); Type: FUNCTION; Schema: _heroku; Owner: -
--

CREATE FUNCTION _heroku.validate_extension() RETURNS event_trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $$

DECLARE

  schemaname pg_catalog.text;
  extversion pg_catalog.text;
  r pg_catalog.RECORD;

BEGIN
  IF tg_tag OPERATOR(pg_catalog.=) 'CREATE EXTENSION'
       OR tg_tag OPERATOR(pg_catalog.=) 'ALTER EXTENSION' THEN
    PERFORM _heroku.validate_search_path();

    FOR r IN SELECT * FROM pg_catalog.pg_event_trigger_ddl_commands()
    LOOP
      CONTINUE WHEN (r.command_tag OPERATOR(pg_catalog.!=) 'CREATE EXTENSION'
                       AND r.command_tag OPERATOR(pg_catalog.!=) 'ALTER EXTENSION')
                    OR r.object_type OPERATOR(pg_catalog.!=) 'extension';

      SELECT n.nspname, e.extversion
        INTO schemaname, extversion
        FROM pg_catalog.pg_extension AS e
        INNER JOIN pg_catalog.pg_namespace AS n
        ON e.extnamespace OPERATOR(pg_catalog.=) n.oid
        WHERE e.oid OPERATOR(pg_catalog.=) r.objid;

      IF schemaname OPERATOR(pg_catalog.=) '_heroku' THEN
        RAISE EXCEPTION 'Extensions are not allowed in the _heroku schema';
      END IF;

      IF extversion OPERATOR(pg_catalog.=) 'unpackaged' THEN
        RAISE EXCEPTION 'Unable to perform this operation: extension version "unpackaged" is not allowed';
      END IF;
    END LOOP;
  END IF;
END;
$$;


--
-- Name: validate_extension_query(); Type: FUNCTION; Schema: _heroku; Owner: -
--

CREATE FUNCTION _heroku.validate_extension_query() RETURNS void
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $$
DECLARE
  query pg_catalog.text;
BEGIN
    query := pg_catalog.unistr(pg_catalog.lower(pg_catalog.current_query()));
    IF query OPERATOR(pg_catalog.~) '\munpackaged\M' THEN
      RAISE EXCEPTION 'Unable to perform this operation: extension version "unpackaged" is not allowed';
    END IF;
END;
$$;


--
-- Name: validate_pg_temp_clean(); Type: FUNCTION; Schema: _heroku; Owner: -
--

CREATE FUNCTION _heroku.validate_pg_temp_clean() RETURNS void
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $$
BEGIN
  IF pg_catalog.pg_my_temp_schema() OPERATOR(pg_catalog.!=) 0 AND EXISTS (
    SELECT 1 FROM pg_catalog.pg_class
      WHERE relnamespace OPERATOR(pg_catalog.=) pg_catalog.pg_my_temp_schema()
        AND relkind OPERATOR(pg_catalog.=) ANY(ARRAY['r', 'v', 'm', 'f', 'p', 'S']::"char"[])
    UNION ALL
    SELECT 1 FROM pg_catalog.pg_proc
      WHERE pronamespace OPERATOR(pg_catalog.=) pg_catalog.pg_my_temp_schema()
    UNION ALL
    SELECT 1 FROM pg_catalog.pg_type
      WHERE typnamespace OPERATOR(pg_catalog.=) pg_catalog.pg_my_temp_schema()
    UNION ALL
    SELECT 1 FROM pg_catalog.pg_operator
      WHERE oprnamespace OPERATOR(pg_catalog.=) pg_catalog.pg_my_temp_schema()
  ) THEN
    RAISE EXCEPTION 'Unable to perform this operation with current session state. Reset your session and try again.';
  END IF;
END;
$$;


--
-- Name: validate_search_path(); Type: FUNCTION; Schema: _heroku; Owner: -
--

CREATE FUNCTION _heroku.validate_search_path() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE

  current_search_path pg_catalog.TEXT;
  safe_search_path pg_catalog.TEXT;
  current_schemas pg_catalog.TEXT[];
  pg_catalog_index pg_catalog.INT4;

BEGIN

  current_search_path := pg_catalog.current_setting('search_path');
  current_schemas := (SELECT pg_catalog.current_schemas(true));
  safe_search_path := _heroku.sanitize_search_path(current_search_path);

  IF current_schemas[1] OPERATOR(pg_catalog.~~) 'pg_temp%' THEN
    RAISE EXCEPTION 'Unable to perform this operation with current schema configuration. Try: SET search_path TO %.', safe_search_path;
  END IF;

  IF ('pg_catalog' OPERATOR(pg_catalog.=) ANY(current_schemas)) THEN
    SELECT pg_catalog.array_position(current_schemas, 'pg_catalog') INTO pg_catalog_index;
    IF pg_catalog_index OPERATOR(pg_catalog.!=) 1 THEN
      RAISE EXCEPTION 'Unable to perform this operation with current schema configuration. Try: SET search_path TO %.', safe_search_path;
    END IF;
  END IF;
END;
$$;


--
-- Name: update_analytics_chiefs_actives_monthly_avg(); Type: PROCEDURE; Schema: analytics; Owner: -
--

CREATE PROCEDURE analytics.update_analytics_chiefs_actives_monthly_avg()
    LANGUAGE sql
    AS $$
truncate analytics.chiefs_actives_monthly_avg;
insert into analytics.chiefs_actives_monthly_avg
SELECT
    extract(YEAR from period_to) || '-' || extract(MONTH from period_to) as month,
    avg(active_users) as avg_active_users
FROM (
    SELECT
        --period_from,
        period_to,
        (
            select count(*) from (
                -- considera visitas em dias distintos
                select distinct chief_id
                from (
                    -- consider 1 day = 1 visit mesmo que tenham várias visitas no mesmo dia
                    select chief_id, created_at::date
                    from public.page_views
                    where
                        chief_id is not null
                        --and created_at::date between CURRENT_DATE::date - '30 days'::interval AND CURRENT_DATE::date
                        and created_at::date between period_from AND period_to
                    group by chief_id, created_at::date
                ) as temp
                group by chief_id
                having count(*) > 2
            ) as temp
        ) as active_users
    FROM (
        SELECT
            CURRENT_DATE::date - (interval_num + 30 || ' days')::interval as period_from,
            CURRENT_DATE::date - (interval_num || ' days')::interval as period_to
        FROM
            generate_series(0, 240) as interval_num
    ) as temp
) as temp
group by month;
$$;


--
-- Name: update_analytics_companies_actives_monthly_avg(); Type: PROCEDURE; Schema: analytics; Owner: -
--

CREATE PROCEDURE analytics.update_analytics_companies_actives_monthly_avg()
    LANGUAGE sql
    AS $$
truncate analytics.companies_actives_monthly_avg ;
insert into analytics.companies_actives_monthly_avg
SELECT users.month, round(active_users.avg_active_users,7), users.total_startups, round((active_users.avg_active_users / users.total_startups),7) as percent_active
    FROM (
        SELECT
            extract(YEAR from period_to) || '-' || extract(MONTH from period_to) as month,
        avg(active_users) as avg_active_users
    FROM (
        SELECT
            --period_from,
            period_to,
            (
                select count(*) from (
                    -- considera visitas em dias distintos
                    select distinct startup_id
                    from (
                        -- consider 1 day = 1 visit mesmo que tenham várias visitas no mesmo dia
                        select startup_id, created_at::date
                        from public.page_views
                        where
                            startup_id is not null
                            --and created_at::date between CURRENT_DATE::date - '30 days'::interval AND CURRENT_DATE::date
                            and created_at::date between period_from AND period_to
                        group by startup_id, created_at::date
                    ) as temp
                    group by startup_id
                    having count(*) > 2
                ) as temp
            ) as active_users
        FROM (
            SELECT
                CURRENT_DATE::date - (interval_num + 30 || ' days')::interval as period_from,
                CURRENT_DATE::date - (interval_num || ' days')::interval as period_to
            FROM
                generate_series(0, 240) as interval_num
        ) as temp
    ) as temp
    group by month
) as active_users
LEFT JOIN (
    SELECT
        to_char(date_trunc('month', created_at), 'YYYY-FMMM') AS month,
        SUM(COUNT(*)) OVER (ORDER BY date_trunc('year', created_at), date_trunc('month', created_at)) AS total_startups
    FROM startups
    WHERE status = 'active'
    GROUP BY date_trunc('year', created_at), date_trunc('month', created_at)
    ORDER BY month
) as users on active_users.month = users.month;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: chiefs_actives_monthly_avg; Type: TABLE; Schema: analytics; Owner: -
--

CREATE TABLE analytics.chiefs_actives_monthly_avg (
    month text NOT NULL,
    avg_active_users numeric(7,2) NOT NULL
);


--
-- Name: TABLE chiefs_actives_monthly_avg; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON TABLE analytics.chiefs_actives_monthly_avg IS 'Chiefs - Ativos 30 dias (2 acessos dias distintos) (Média Mensal)';


--
-- Name: COLUMN chiefs_actives_monthly_avg.month; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics.chiefs_actives_monthly_avg.month IS 'Month in text';


--
-- Name: COLUMN chiefs_actives_monthly_avg.avg_active_users; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics.chiefs_actives_monthly_avg.avg_active_users IS 'Average of chiefs active';


--
-- Name: companies_actives_monthly_avg; Type: TABLE; Schema: analytics; Owner: -
--

CREATE TABLE analytics.companies_actives_monthly_avg (
    month character varying(255),
    avg_active_users numeric,
    total_startups integer,
    percent_active numeric
);


--
-- Name: active_campaign_campaigns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_campaign_campaigns (
    id bigint NOT NULL,
    ac_id character varying NOT NULL,
    name character varying,
    campaign_type character varying,
    status character varying,
    subject character varying,
    sent_at timestamp without time zone,
    total_sent integer DEFAULT 0,
    total_opens integer DEFAULT 0,
    total_clicks integer DEFAULT 0,
    unique_opens integer DEFAULT 0,
    unique_clicks integer DEFAULT 0,
    unsubscribes integer DEFAULT 0,
    bounces integer DEFAULT 0,
    synced_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    message_ac_id character varying,
    message_subject character varying,
    message_from_name character varying,
    message_from_email character varying,
    message_preheader character varying,
    message_html text,
    message_text text,
    message_synced_at timestamp without time zone
);


--
-- Name: active_campaign_campaigns_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_campaign_campaigns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_campaign_campaigns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_campaign_campaigns_id_seq OWNED BY public.active_campaign_campaigns.id;


--
-- Name: active_campaign_contact_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_campaign_contact_messages (
    id bigint NOT NULL,
    active_campaign_contact_id bigint NOT NULL,
    chief_id bigint,
    active_campaign_campaign_id bigint,
    ac_campaign_id character varying,
    campaign_name character varying,
    subject character varying,
    status character varying,
    sent_at timestamp without time zone,
    first_open_at timestamp without time zone,
    last_open_at timestamp without time zone,
    last_click_at timestamp without time zone,
    opens_count integer,
    clicks_count integer,
    synced_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_campaign_contact_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_campaign_contact_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_campaign_contact_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_campaign_contact_messages_id_seq OWNED BY public.active_campaign_contact_messages.id;


--
-- Name: active_campaign_contact_monthly_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_campaign_contact_monthly_snapshots (
    id bigint NOT NULL,
    active_campaign_contact_id bigint NOT NULL,
    chief_id bigint,
    year_month date NOT NULL,
    score integer,
    status character varying,
    tags_count integer DEFAULT 0 NOT NULL,
    lists_count integer DEFAULT 0 NOT NULL,
    last_activity_at timestamp without time zone,
    snapshotted_at timestamp without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_campaign_contact_monthly_snapshots_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_campaign_contact_monthly_snapshots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_campaign_contact_monthly_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_campaign_contact_monthly_snapshots_id_seq OWNED BY public.active_campaign_contact_monthly_snapshots.id;


--
-- Name: active_campaign_contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_campaign_contacts (
    id bigint NOT NULL,
    ac_id bigint NOT NULL,
    chief_id bigint,
    startup_id bigint,
    email character varying,
    first_name character varying,
    last_name character varying,
    phone character varying,
    status character varying,
    score integer,
    owner_id character varying,
    tags jsonb DEFAULT '[]'::jsonb NOT NULL,
    lists jsonb DEFAULT '[]'::jsonb NOT NULL,
    field_values jsonb DEFAULT '{}'::jsonb NOT NULL,
    raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    ac_created_at timestamp without time zone,
    ac_updated_at timestamp without time zone,
    last_activity_at timestamp without time zone,
    synced_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    sent_count integer DEFAULT 0 NOT NULL,
    last_open_at timestamp without time zone,
    last_click_at timestamp without time zone,
    bounced_hard_count integer DEFAULT 0 NOT NULL,
    bounced_soft_count integer DEFAULT 0 NOT NULL,
    bounced_at timestamp without time zone,
    best_send_hour integer,
    mpp_tracking boolean DEFAULT false NOT NULL,
    last_message_sync_at timestamp without time zone,
    aggregates_refreshed_at timestamp without time zone,
    derived_score integer DEFAULT 0 NOT NULL
);


--
-- Name: active_campaign_contacts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_campaign_contacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_campaign_contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_campaign_contacts_id_seq OWNED BY public.active_campaign_contacts.id;


--
-- Name: active_campaign_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_campaign_tags (
    id bigint NOT NULL,
    ac_id character varying NOT NULL,
    name character varying NOT NULL,
    tag_type character varying,
    description text,
    subscriber_count integer DEFAULT 0 NOT NULL,
    ac_created_at timestamp without time zone,
    ac_updated_at timestamp without time zone,
    synced_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_campaign_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_campaign_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_campaign_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_campaign_tags_id_seq OWNED BY public.active_campaign_tags.id;


--
-- Name: active_campaign_webhook_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_campaign_webhook_events (
    id bigint NOT NULL,
    event_type character varying NOT NULL,
    ac_contact_id bigint,
    ac_list_id bigint,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    processed_at timestamp without time zone,
    error character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_campaign_webhook_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_campaign_webhook_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_campaign_webhook_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_campaign_webhook_events_id_seq OWNED BY public.active_campaign_webhook_events.id;


--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    byte_size bigint NOT NULL,
    checksum character varying NOT NULL,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: agent_conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_conversations (
    id bigint NOT NULL,
    chief_id bigint NOT NULL,
    title character varying,
    status character varying DEFAULT 'active'::character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    openai_conversation_id character varying
);


--
-- Name: agent_conversations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_conversations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_conversations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_conversations_id_seq OWNED BY public.agent_conversations.id;


--
-- Name: agent_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_messages (
    id bigint NOT NULL,
    agent_conversation_id bigint NOT NULL,
    role character varying NOT NULL,
    content text NOT NULL,
    raw jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    "position" integer
);


--
-- Name: agent_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_messages_id_seq OWNED BY public.agent_messages.id;


--
-- Name: analytics_chief_view_rankings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_chief_view_rankings (
    id bigint NOT NULL,
    chief_id bigint NOT NULL,
    view_count integer DEFAULT 0 NOT NULL,
    rank integer NOT NULL,
    computed_at timestamp without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    ranking_type character varying DEFAULT 'demand'::character varying NOT NULL
);


--
-- Name: analytics_chief_view_rankings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.analytics_chief_view_rankings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: analytics_chief_view_rankings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.analytics_chief_view_rankings_id_seq OWNED BY public.analytics_chief_view_rankings.id;


--
-- Name: analytics_page_view_summaries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_page_view_summaries (
    id bigint NOT NULL,
    period date NOT NULL,
    total_views integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    chief_profile_views integer DEFAULT 0 NOT NULL,
    unique_startup_visitors integer DEFAULT 0 NOT NULL,
    views_desktop integer DEFAULT 0 NOT NULL,
    views_mobile integer DEFAULT 0 NOT NULL,
    views_tablet integer DEFAULT 0 NOT NULL,
    browser_chrome integer DEFAULT 0 NOT NULL,
    browser_safari integer DEFAULT 0 NOT NULL,
    browser_firefox integer DEFAULT 0 NOT NULL,
    browser_edge integer DEFAULT 0 NOT NULL,
    browser_other integer DEFAULT 0 NOT NULL
);


--
-- Name: analytics_page_view_summaries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.analytics_page_view_summaries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: analytics_page_view_summaries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.analytics_page_view_summaries_id_seq OWNED BY public.analytics_page_view_summaries.id;


--
-- Name: api_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_tokens (
    id bigint NOT NULL,
    name character varying NOT NULL,
    token_digest character varying NOT NULL,
    expires_at timestamp without time zone,
    revoked_at timestamp without time zone,
    last_used_at timestamp without time zone,
    slug character varying NOT NULL,
    requests_count integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    company_id bigint,
    scope character varying
);


--
-- Name: api_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.api_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: api_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.api_tokens_id_seq OWNED BY public.api_tokens.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ca_acquittances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_acquittances (
    id bigint NOT NULL,
    conta_azul_id character varying NOT NULL,
    parcela_uuid character varying NOT NULL,
    valor numeric(15,2),
    data_baixa date,
    conta_financeira_uuid character varying,
    raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ca_acquittances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ca_acquittances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ca_acquittances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ca_acquittances_id_seq OWNED BY public.ca_acquittances.id;


--
-- Name: ca_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_categories (
    id bigint NOT NULL,
    conta_azul_id character varying NOT NULL,
    versao integer,
    nome character varying NOT NULL,
    categoria_pai character varying,
    tipo character varying,
    entrada_dre character varying,
    considera_custo_dre boolean DEFAULT false NOT NULL,
    raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ca_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ca_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ca_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ca_categories_id_seq OWNED BY public.ca_categories.id;


--
-- Name: ca_contracts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_contracts (
    id bigint NOT NULL,
    conta_azul_id character varying NOT NULL,
    numero character varying,
    status character varying,
    periodicidade character varying,
    data_inicio date,
    data_fim date,
    valor_total numeric(12,2),
    valor_recorrente numeric(12,2),
    cliente_uuid character varying,
    cliente_nome character varying,
    vendedor_uuid character varying,
    vendedor_nome character varying,
    tipo_negociacao character varying,
    data_criacao timestamp without time zone,
    data_alteracao timestamp without time zone,
    raw_payload jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ca_contracts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ca_contracts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ca_contracts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ca_contracts_id_seq OWNED BY public.ca_contracts.id;


--
-- Name: ca_cost_centers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_cost_centers (
    id bigint NOT NULL,
    conta_azul_id character varying NOT NULL,
    nome character varying,
    status character varying,
    raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ca_cost_centers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ca_cost_centers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ca_cost_centers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ca_cost_centers_id_seq OWNED BY public.ca_cost_centers.id;


--
-- Name: ca_dre_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_dre_categories (
    id bigint NOT NULL,
    conta_azul_id character varying NOT NULL,
    parent_uuid character varying,
    descricao character varying,
    codigo character varying,
    posicao integer,
    indica_totalizador boolean DEFAULT false NOT NULL,
    representa_soma_custo_medio boolean DEFAULT false NOT NULL,
    raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ca_dre_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ca_dre_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ca_dre_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ca_dre_categories_id_seq OWNED BY public.ca_dre_categories.id;


--
-- Name: ca_dre_category_categorias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_dre_category_categorias (
    id bigint NOT NULL,
    dre_node_uuid character varying NOT NULL,
    categoria_uuid character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ca_dre_category_categorias_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ca_dre_category_categorias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ca_dre_category_categorias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ca_dre_category_categorias_id_seq OWNED BY public.ca_dre_category_categorias.id;


--
-- Name: ca_event_apportionments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_event_apportionments (
    id bigint NOT NULL,
    evento_uuid character varying NOT NULL,
    tipo character varying NOT NULL,
    target_uuid character varying NOT NULL,
    nome character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ca_event_apportionments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ca_event_apportionments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ca_event_apportionments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ca_event_apportionments_id_seq OWNED BY public.ca_event_apportionments.id;


--
-- Name: ca_financial_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_financial_accounts (
    id bigint NOT NULL,
    conta_azul_id character varying NOT NULL,
    nome character varying,
    tipo character varying,
    banco character varying,
    status character varying,
    saldo_atual numeric(15,2),
    raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    saldo_atualizado_em timestamp without time zone
);


--
-- Name: ca_financial_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ca_financial_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ca_financial_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ca_financial_accounts_id_seq OWNED BY public.ca_financial_accounts.id;


--
-- Name: ca_financial_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_financial_events (
    id bigint NOT NULL,
    conta_azul_id character varying NOT NULL,
    tipo character varying NOT NULL,
    pessoa_uuid character varying,
    categoria_uuid character varying,
    centro_custo_uuid character varying,
    conta_financeira_uuid character varying,
    valor numeric(15,2),
    data_competencia date,
    data_vencimento date,
    descricao text,
    status character varying,
    raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ca_financial_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ca_financial_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ca_financial_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ca_financial_events_id_seq OWNED BY public.ca_financial_events.id;


--
-- Name: ca_financial_installments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_financial_installments (
    id bigint NOT NULL,
    conta_azul_id character varying NOT NULL,
    evento_uuid character varying,
    numero_parcela integer,
    valor numeric(15,2),
    valor_pago numeric(15,2),
    data_vencimento date,
    data_pagamento date,
    status character varying,
    raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    venda_uuid character varying,
    descricao character varying,
    origem character varying DEFAULT 'event'::character varying NOT NULL
);


--
-- Name: ca_financial_installments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ca_financial_installments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ca_financial_installments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ca_financial_installments_id_seq OWNED BY public.ca_financial_installments.id;


--
-- Name: ca_people; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_people (
    id bigint NOT NULL,
    conta_azul_id character varying NOT NULL,
    email character varying,
    nome character varying,
    documento character varying,
    telefone character varying,
    tipo_pessoa character varying,
    ativo boolean DEFAULT true NOT NULL,
    perfis character varying[] DEFAULT '{}'::character varying[],
    endereco_cep character varying,
    endereco_logradouro character varying,
    endereco_numero character varying,
    endereco_bairro character varying,
    endereco_cidade character varying,
    endereco_estado character varying,
    endereco_pais character varying,
    raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ca_people_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ca_people_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ca_people_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ca_people_id_seq OWNED BY public.ca_people.id;


--
-- Name: ca_sale_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_sale_items (
    id bigint NOT NULL,
    conta_azul_id character varying NOT NULL,
    venda_uuid character varying NOT NULL,
    id_item character varying,
    nome character varying,
    descricao character varying,
    tipo character varying,
    quantidade numeric(15,4),
    valor numeric(15,2),
    custo numeric(15,2),
    total numeric(15,2),
    centro_custo_uuid character varying,
    raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ca_sale_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ca_sale_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ca_sale_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ca_sale_items_id_seq OWNED BY public.ca_sale_items.id;


--
-- Name: ca_sales; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_sales (
    id bigint NOT NULL,
    conta_azul_id character varying NOT NULL,
    id_legado bigint,
    numero integer,
    data date,
    tipo_negociacao character varying,
    status character varying,
    situacao_nome character varying,
    situacao_descricao character varying,
    total numeric(15,2),
    valor_bruto numeric(15,2),
    desconto numeric(15,2),
    valor_liquido numeric(15,2),
    cliente_uuid character varying,
    cliente_nome character varying,
    vendedor_uuid character varying,
    vendedor_nome character varying,
    evento_financeiro_uuid character varying,
    contrato_uuid character varying,
    natureza_operacao_uuid character varying,
    natureza_operacao_label character varying,
    tipo_operacao character varying,
    template_operacao character varying,
    centro_custo_uuid character varying,
    categoria_uuid character varying,
    origem character varying,
    versao integer,
    data_criacao timestamp without time zone,
    data_alteracao timestamp without time zone,
    raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ca_sales_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ca_sales_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ca_sales_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ca_sales_id_seq OWNED BY public.ca_sales.id;


--
-- Name: ca_sellers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_sellers (
    id bigint NOT NULL,
    conta_azul_id character varying NOT NULL,
    nome character varying,
    email character varying,
    documento character varying,
    status character varying,
    raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ca_sellers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ca_sellers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ca_sellers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ca_sellers_id_seq OWNED BY public.ca_sellers.id;


--
-- Name: ca_service_invoices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_service_invoices (
    id bigint NOT NULL,
    conta_azul_id character varying NOT NULL,
    numero character varying,
    numero_rps character varying,
    chave_acesso character varying,
    status character varying,
    data_emissao date,
    data_competencia date,
    valor_total numeric(15,2),
    cliente_uuid character varying,
    cliente_nome character varying,
    venda_uuid character varying,
    contrato_uuid character varying,
    tipo_negociacao character varying,
    raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ca_service_invoices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ca_service_invoices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ca_service_invoices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ca_service_invoices_id_seq OWNED BY public.ca_service_invoices.id;


--
-- Name: careers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.careers (
    id bigint NOT NULL,
    chief_id integer,
    notes text,
    first_meeting timestamp without time zone,
    video character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: careers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.careers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: careers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.careers_id_seq OWNED BY public.careers.id;


--
-- Name: chief_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chief_accounts (
    id bigint NOT NULL,
    chief_id integer,
    holder_name character varying,
    bank character varying,
    branch_number character varying,
    branch_check_digit character varying,
    account_number character varying,
    account_check_digit character varying,
    holder_type character varying,
    holder_document character varying,
    account_type character varying,
    transfer_interval character varying DEFAULT 'Monthly'::character varying,
    transfer_day character varying DEFAULT '10'::character varying,
    external_id character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    transfer_enabled boolean DEFAULT false
);


--
-- Name: chief_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chief_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chief_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chief_accounts_id_seq OWNED BY public.chief_accounts.id;


--
-- Name: chief_ads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chief_ads (
    id bigint NOT NULL,
    title character varying,
    description text,
    price_desc character varying,
    chief_id integer,
    status character varying DEFAULT 'active'::character varying,
    views integer DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    anonymous boolean DEFAULT false,
    youtube character varying,
    location character varying,
    duration character varying,
    availability character varying,
    deliverables text,
    requirements text
);


--
-- Name: chief_ads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chief_ads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chief_ads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chief_ads_id_seq OWNED BY public.chief_ads.id;


--
-- Name: chief_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chief_comments (
    id bigint NOT NULL,
    chief_id bigint NOT NULL,
    author_id bigint NOT NULL,
    content text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: chief_comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chief_comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chief_comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chief_comments_id_seq OWNED BY public.chief_comments.id;


--
-- Name: chiefs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chiefs (
    id bigint NOT NULL,
    name character varying,
    status character varying DEFAULT 'pending'::character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    slug character varying,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp without time zone,
    remember_created_at timestamp without time zone,
    role integer DEFAULT 0,
    job_title character varying,
    gender character varying,
    company character varying,
    phone character varying,
    city character varying,
    linkedin character varying,
    resume_experience text,
    resume_project text,
    c_level_experience character varying,
    company_profiles character varying,
    industries_experience character varying,
    sectors_experience character varying,
    main_companies character varying,
    wallet character varying,
    tags jsonb DEFAULT '"{}"'::jsonb,
    views integer DEFAULT 0,
    provider character varying,
    uid character varying,
    picture_url character varying,
    linkedin_token character varying,
    linkedin_expires integer,
    "tokenId" integer,
    firebase_id character varying,
    firebase_id_token character varying,
    onepercent_chief_id character varying,
    onepercent_asset_id character varying,
    firebase_password character varying,
    onepercent_transaction_id character varying,
    "position" integer DEFAULT 999,
    approved_operator boolean DEFAULT false,
    crop_settings jsonb,
    blacklist jsonb DEFAULT '[]'::jsonb,
    ac_id character varying,
    document character varying,
    contact_email character varying,
    bank character varying,
    agency character varying,
    account_number character varying,
    birth_at date,
    calendar_external_link character varying,
    external_id_payment character varying,
    cc_line_1 character varying,
    cc_line_2 character varying,
    cc_zip_code character varying,
    cc_city character varying,
    cc_state character varying,
    cc_country character varying,
    cc_neighborhood character varying,
    cc_address_number character varying,
    terms_accepted boolean DEFAULT false,
    terms_accepted_at timestamp without time zone,
    meeting_default_value integer,
    mentorship_paid boolean DEFAULT true,
    mentorship_paid_month integer DEFAULT 5,
    mentorship_free_month integer DEFAULT 5,
    mentorship_fee integer DEFAULT 20,
    hard_skills text,
    salary character varying,
    comment text,
    tier character varying,
    chair character varying,
    email_optin boolean DEFAULT true,
    availability integer DEFAULT 0,
    work_model character varying,
    important_cases_connecting_customers character varying,
    biggest_team_responsibility character varying,
    business_model character varying,
    business_moment character varying,
    last_request_fill_profile timestamp without time zone,
    total_request_fill_profile integer DEFAULT 0,
    profile_percentage integer DEFAULT 0,
    portuguese_level character varying,
    english_level character varying,
    spanish_level character varying,
    others_language character varying,
    biggest_problems text,
    relevant_problems text,
    resumed_calls text,
    state character varying,
    availability_status character varying,
    info_extracted text,
    ac_pending_removal boolean,
    ac_pending_removal_set_at timestamp without time zone,
    openai_sync_at timestamp without time zone,
    openai_file_id character varying,
    cv_laudo_invite_sent_at timestamp without time zone
);


--
-- Name: chiefs_csv_exports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chiefs_csv_exports (
    id bigint NOT NULL,
    status character varying DEFAULT 'generated'::character varying NOT NULL,
    trigger character varying DEFAULT 'manual'::character varying NOT NULL,
    row_count integer,
    generated_by_id integer,
    filename character varying,
    error_message text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: chiefs_csv_exports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chiefs_csv_exports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chiefs_csv_exports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chiefs_csv_exports_id_seq OWNED BY public.chiefs_csv_exports.id;


--
-- Name: chiefs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chiefs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chiefs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chiefs_id_seq OWNED BY public.chiefs.id;


--
-- Name: chiefs_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chiefs_posts (
    chief_id bigint,
    post_id bigint
);


--
-- Name: chiefs_projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chiefs_projects (
    chief_id bigint NOT NULL,
    project_id bigint NOT NULL,
    "position" integer
);


--
-- Name: chiefs_shortlists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chiefs_shortlists (
    chief_id bigint,
    shortlist_id bigint
);


--
-- Name: chiefs_start; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chiefs_start (
    id bigint NOT NULL,
    name character varying,
    status character varying DEFAULT 'pending'::character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    slug character varying,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp without time zone,
    remember_created_at timestamp without time zone,
    role integer DEFAULT 0,
    job_title character varying,
    gender character varying,
    company character varying,
    phone character varying,
    city character varying,
    linkedin character varying,
    resume_experience text,
    resume_project text,
    c_level_experience character varying,
    company_profiles character varying,
    industries_experience character varying,
    sectors_experience character varying,
    main_companies character varying,
    wallet character varying,
    tags jsonb DEFAULT '"{}"'::jsonb,
    views integer DEFAULT 0,
    provider character varying,
    uid character varying,
    picture_url character varying,
    linkedin_token character varying,
    linkedin_expires integer,
    "tokenId" integer,
    firebase_id character varying,
    firebase_id_token character varying,
    onepercent_chief_id character varying,
    onepercent_asset_id character varying,
    firebase_password character varying,
    onepercent_transaction_id character varying,
    "position" integer DEFAULT 999,
    approved_operator boolean DEFAULT false,
    crop_settings jsonb,
    blacklist jsonb DEFAULT '[]'::jsonb,
    ac_id character varying,
    document character varying,
    contact_email character varying,
    bank character varying,
    agency character varying,
    account_number character varying,
    birth_at date,
    calendar_external_link character varying,
    external_id_payment character varying,
    cc_line_1 character varying,
    cc_line_2 character varying,
    cc_zip_code character varying,
    cc_city character varying,
    cc_state character varying,
    cc_country character varying,
    cc_neighborhood character varying,
    cc_address_number character varying,
    terms_accepted boolean DEFAULT false,
    terms_accepted_at timestamp without time zone,
    meeting_default_value integer,
    mentorship_paid boolean DEFAULT true,
    mentorship_paid_month integer DEFAULT 5,
    mentorship_free_month integer DEFAULT 5,
    mentorship_fee integer DEFAULT 20,
    hard_skills text,
    salary character varying,
    comment text,
    tier character varying,
    chair character varying,
    email_optin boolean DEFAULT true,
    availability integer DEFAULT 0,
    work_model character varying,
    important_cases_connecting_customers character varying,
    biggest_team_responsibility character varying,
    business_model character varying,
    business_moment character varying,
    last_request_fill_profile timestamp without time zone,
    total_request_fill_profile integer DEFAULT 0,
    profile_percentage integer DEFAULT 0,
    portuguese_level character varying,
    english_level character varying,
    spanish_level character varying,
    others_language character varying,
    biggest_problems text,
    relevant_problems text
);


--
-- Name: chiefs_start_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chiefs_start_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chiefs_start_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chiefs_start_id_seq OWNED BY public.chiefs_start.id;


--
-- Name: chiefs_startup_ads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chiefs_startup_ads (
    id bigint NOT NULL,
    chief_id bigint NOT NULL,
    startup_ad_id bigint NOT NULL,
    score double precision,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    vote boolean,
    source character varying,
    feedback text
);


--
-- Name: chiefs_startup_ads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chiefs_startup_ads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chiefs_startup_ads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chiefs_startup_ads_id_seq OWNED BY public.chiefs_startup_ads.id;


--
-- Name: companies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.companies (
    id bigint NOT NULL,
    name character varying,
    startup_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    cnpj character varying,
    site character varying,
    linkedin character varying,
    description text,
    sector character varying,
    size character varying,
    city character varying,
    contact_email character varying,
    contact_phone character varying,
    revenue character varying,
    company_stage character varying,
    slug character varying,
    market character varying,
    target character varying,
    fulltime_team character varying,
    fundation_year character varying,
    status character varying DEFAULT 'active'::character varying
);


--
-- Name: companies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.companies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: companies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.companies_id_seq OWNED BY public.companies.id;


--
-- Name: conta_azul_oauth_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conta_azul_oauth_tokens (
    id bigint NOT NULL,
    access_token text NOT NULL,
    refresh_token text NOT NULL,
    access_token_expires_at timestamp without time zone NOT NULL,
    last_refreshed_at timestamp without time zone,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    company_cnpj character varying,
    company_name character varying,
    scope character varying,
    last_full_synced_at timestamp without time zone,
    last_delta_synced_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: conta_azul_oauth_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.conta_azul_oauth_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: conta_azul_oauth_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.conta_azul_oauth_tokens_id_seq OWNED BY public.conta_azul_oauth_tokens.id;


--
-- Name: contract_mentorships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contract_mentorships (
    id bigint NOT NULL,
    startup_id integer,
    chief_id integer,
    installments integer,
    compensation integer,
    options integer,
    talent integer,
    part integer,
    transaction_id character varying,
    transaction_hash character varying,
    invite_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    status character varying,
    external_id_contract integer,
    my_project_id integer,
    start_at timestamp without time zone,
    end_at timestamp without time zone
);


--
-- Name: contract_mentorships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contract_mentorships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contract_mentorships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contract_mentorships_id_seq OWNED BY public.contract_mentorships.id;


--
-- Name: coupons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.coupons (
    id bigint NOT NULL,
    name character varying,
    status character varying,
    validate_email character varying,
    coupon_type character varying,
    expire_at timestamp without time zone,
    description text,
    total_value integer,
    use_limit integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    cycles integer DEFAULT 12,
    plan_ids text[] DEFAULT '{}'::text[]
);


--
-- Name: coupons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.coupons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: coupons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.coupons_id_seq OWNED BY public.coupons.id;


--
-- Name: credit_cards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credit_cards (
    id bigint NOT NULL,
    chief_id integer,
    last_digits character varying,
    pagarme_token character varying,
    cpf character varying,
    cnpj character varying,
    external_id character varying,
    brand character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    startup_id integer,
    cc_line_1 character varying,
    cc_line_2 character varying,
    cc_zip_code character varying,
    cc_city character varying,
    cc_state character varying,
    cc_country character varying,
    cc_neighborhood character varying,
    cc_address_number character varying
);


--
-- Name: credit_cards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.credit_cards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: credit_cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.credit_cards_id_seq OWNED BY public.credit_cards.id;


--
-- Name: curriculos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.curriculos (
    id bigint NOT NULL,
    chief_id bigint NOT NULL,
    uploaded_by_id bigint NOT NULL,
    source character varying,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    current boolean DEFAULT true NOT NULL
);


--
-- Name: curriculos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.curriculos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: curriculos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.curriculos_id_seq OWNED BY public.curriculos.id;


--
-- Name: friendly_id_slugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.friendly_id_slugs (
    id bigint NOT NULL,
    slug character varying NOT NULL,
    sluggable_id integer NOT NULL,
    sluggable_type character varying(50),
    scope character varying,
    created_at timestamp without time zone
);


--
-- Name: friendly_id_slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.friendly_id_slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: friendly_id_slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.friendly_id_slugs_id_seq OWNED BY public.friendly_id_slugs.id;


--
-- Name: invite_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invite_orders (
    id bigint NOT NULL,
    uuid character varying,
    startup_id integer,
    status character varying DEFAULT 'new'::character varying,
    gateway character varying DEFAULT 'pagarme'::character varying,
    payload jsonb DEFAULT '{}'::jsonb,
    coupon character varying,
    splits integer DEFAULT 1,
    cc_zip_code character varying,
    cc_line_1 character varying,
    cc_line_2 character varying,
    cc_city character varying,
    cc_state character varying,
    cc_country character varying,
    cc_address_number character varying,
    cc_neighborhood character varying,
    value integer,
    discount integer,
    total_value integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    chief_id integer,
    quantity integer DEFAULT 1,
    share_fee integer DEFAULT 20,
    share_chief integer DEFAULT 80,
    mentorings_used integer DEFAULT 0
);


--
-- Name: invite_orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invite_orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invite_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invite_orders_id_seq OWNED BY public.invite_orders.id;


--
-- Name: invites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invites (
    id bigint NOT NULL,
    chief_id integer,
    startup_id integer,
    status character varying,
    accepted_at timestamp without time zone,
    main_reason text,
    code character varying,
    proposal_1 timestamp without time zone,
    proposal_2 timestamp without time zone,
    proposal_3 timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    accepted_time timestamp without time zone,
    comment_time text,
    inviterable_id bigint,
    inviterable_type character varying,
    inviteeable_id bigint,
    inviteeable_type character varying,
    invite_type character varying,
    calcom_id character varying,
    invite_order_id integer
);


--
-- Name: invites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invites_id_seq OWNED BY public.invites.id;


--
-- Name: journeys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.journeys (
    id bigint NOT NULL,
    chief_id integer,
    step character varying,
    status boolean,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: journeys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.journeys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: journeys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.journeys_id_seq OWNED BY public.journeys.id;


--
-- Name: legal_pages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legal_pages (
    id bigint NOT NULL,
    slug character varying,
    title character varying,
    content text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: legal_pages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.legal_pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: legal_pages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.legal_pages_id_seq OWNED BY public.legal_pages.id;


--
-- Name: libraries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.libraries (
    id bigint NOT NULL,
    name character varying,
    link character varying,
    content_type character varying,
    chief_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: libraries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.libraries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: libraries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.libraries_id_seq OWNED BY public.libraries.id;


--
-- Name: linkedin_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.linkedin_profiles (
    id bigint NOT NULL,
    chief_id integer,
    description text,
    location character varying,
    name character varying,
    about text,
    sales_link character varying,
    link character varying,
    experiences jsonb,
    skills jsonb,
    education jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    resume text,
    hardskills jsonb
);


--
-- Name: linkedin_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.linkedin_profiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: linkedin_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.linkedin_profiles_id_seq OWNED BY public.linkedin_profiles.id;


--
-- Name: matches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.matches (
    id bigint NOT NULL,
    chief_id integer,
    startup_ad_id integer,
    status character varying DEFAULT 'new_match'::character varying,
    match_type character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    description text,
    chief_ad_id integer,
    startup_id integer,
    hours_avaliable character varying,
    hours_value integer DEFAULT 0,
    payment character varying,
    hire_method character varying,
    budget character varying,
    months_expected character varying,
    phone character varying,
    name character varying
);


--
-- Name: matches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.matches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: matches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.matches_id_seq OWNED BY public.matches.id;


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id integer NOT NULL,
    topic character varying,
    body text,
    received_messageable_type character varying,
    received_messageable_id bigint,
    sent_messageable_type character varying,
    sent_messageable_id bigint,
    opened boolean DEFAULT false,
    recipient_delete boolean DEFAULT false,
    sender_delete boolean DEFAULT false,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    ancestry character varying,
    recipient_permanent_delete boolean DEFAULT false,
    sender_permanent_delete boolean DEFAULT false,
    opened_at timestamp without time zone
);


--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.messages_id_seq OWNED BY public.messages.id;


--
-- Name: my_projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.my_projects (
    id bigint NOT NULL,
    chief_id integer,
    title character varying,
    status character varying,
    startup_id integer,
    description text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    start_at timestamp without time zone,
    end_at timestamp without time zone,
    total_value integer,
    chiefgroup_value integer,
    chief_value integer,
    payment_type character varying,
    investment_term character varying,
    installments integer,
    part integer,
    project_id integer,
    kpis text
);


--
-- Name: my_projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.my_projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: my_projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.my_projects_id_seq OWNED BY public.my_projects.id;


--
-- Name: nps_responses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nps_responses (
    id bigint NOT NULL,
    chief_id bigint NOT NULL,
    score integer NOT NULL,
    feedback text,
    dismissed_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: nps_responses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.nps_responses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nps_responses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.nps_responses_id_seq OWNED BY public.nps_responses.id;


--
-- Name: oauth_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth_accounts (
    id bigint NOT NULL,
    chief_id bigint,
    provider character varying,
    uid character varying,
    image_url character varying,
    profile_url character varying,
    access_token character varying,
    raw_data text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: oauth_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oauth_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oauth_accounts_id_seq OWNED BY public.oauth_accounts.id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id bigint NOT NULL,
    uuid character varying DEFAULT 'fee4e649-1d3f-4f90-8de7-91ada707dc2f'::character varying,
    chief_id integer,
    status character varying DEFAULT 'pending'::character varying,
    gateway character varying DEFAULT 'evermart'::character varying,
    payload jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    plan_id integer,
    coupon character varying,
    splits integer DEFAULT 12,
    cc_zip_code character varying,
    cc_line_1 character varying,
    cc_line_2 character varying,
    cc_city character varying,
    cc_state character varying,
    cc_country character varying,
    cc_address_number character varying,
    cc_neighborhood character varying,
    plan_price integer,
    discount integer,
    total_value integer
);


--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.orders_id_seq OWNED BY public.orders.id;


--
-- Name: page_views; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.page_views (
    id bigint NOT NULL,
    path character varying,
    event_at timestamp without time zone,
    startup_id integer,
    chief_id integer,
    user_agent character varying,
    facebook_cookie_id character varying,
    google_cookie_id character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: page_views_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.page_views_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: page_views_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.page_views_id_seq OWNED BY public.page_views.id;


--
-- Name: pipedrive_deal_files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipedrive_deal_files (
    id bigint NOT NULL,
    file_id bigint NOT NULL,
    deal_pipedrive_id bigint NOT NULL,
    file_name character varying,
    file_type character varying,
    file_size bigint,
    url text,
    remote_location character varying,
    added_at timestamp without time zone,
    updated_at_remote timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: pipedrive_deal_files_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pipedrive_deal_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pipedrive_deal_files_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pipedrive_deal_files_id_seq OWNED BY public.pipedrive_deal_files.id;


--
-- Name: pipedrive_deal_heat_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipedrive_deal_heat_snapshots (
    id bigint NOT NULL,
    deal_pipedrive_id bigint NOT NULL,
    heat_score numeric(5,2) NOT NULL,
    heat_breakdown jsonb DEFAULT '{}'::jsonb NOT NULL,
    heat_signals jsonb DEFAULT '{}'::jsonb NOT NULL,
    stage_id bigint,
    stage_name character varying,
    value numeric(15,2),
    captured_at timestamp without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: pipedrive_deal_heat_snapshots_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pipedrive_deal_heat_snapshots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pipedrive_deal_heat_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pipedrive_deal_heat_snapshots_id_seq OWNED BY public.pipedrive_deal_heat_snapshots.id;


--
-- Name: pipedrive_deal_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipedrive_deal_notes (
    id bigint NOT NULL,
    note_id bigint NOT NULL,
    deal_pipedrive_id bigint NOT NULL,
    content text,
    author_name character varying,
    added_at timestamp without time zone,
    updated_at_remote timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: pipedrive_deal_notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pipedrive_deal_notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pipedrive_deal_notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pipedrive_deal_notes_id_seq OWNED BY public.pipedrive_deal_notes.id;


--
-- Name: pipedrive_deal_stage_changes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipedrive_deal_stage_changes (
    id bigint NOT NULL,
    pipedrive_deal_id bigint NOT NULL,
    from_stage_id integer,
    to_stage_id integer NOT NULL,
    from_stage_name character varying,
    to_stage_name character varying,
    changed_at timestamp without time zone NOT NULL,
    source character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: pipedrive_deal_stage_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pipedrive_deal_stage_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pipedrive_deal_stage_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pipedrive_deal_stage_changes_id_seq OWNED BY public.pipedrive_deal_stage_changes.id;


--
-- Name: pipedrive_deals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipedrive_deals (
    id bigint NOT NULL,
    pipedrive_id bigint NOT NULL,
    title character varying,
    status character varying,
    pipeline_id bigint,
    pipeline_name character varying,
    stage_id bigint,
    stage_name character varying,
    value numeric(15,2),
    currency character varying,
    owner_id bigint,
    owner_name character varying,
    org_id bigint,
    org_name character varying,
    person_name character varying,
    person_email character varying,
    label_ids jsonb DEFAULT '[]'::jsonb NOT NULL,
    added_at timestamp without time zone,
    updated_at_remote timestamp without time zone,
    raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    close_time timestamp without time zone,
    lost_reason character varying,
    expected_close_date date,
    probability integer,
    weighted_value numeric(15,2),
    last_activity_date date,
    person_phone character varying,
    next_activity_date date,
    activities_count integer,
    source_name character varying,
    heat_score numeric(5,2),
    heat_breakdown jsonb DEFAULT '{}'::jsonb NOT NULL,
    heat_signals jsonb DEFAULT '{}'::jsonb NOT NULL,
    heat_calculated_at timestamp without time zone,
    deleted_at timestamp without time zone
);


--
-- Name: pipedrive_deals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pipedrive_deals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pipedrive_deals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pipedrive_deals_id_seq OWNED BY public.pipedrive_deals.id;


--
-- Name: pipedrive_owner_contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipedrive_owner_contacts (
    id bigint NOT NULL,
    owner_id bigint NOT NULL,
    owner_name character varying,
    email character varying,
    whatsapp_number character varying,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: pipedrive_owner_contacts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pipedrive_owner_contacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pipedrive_owner_contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pipedrive_owner_contacts_id_seq OWNED BY public.pipedrive_owner_contacts.id;


--
-- Name: plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plans (
    id bigint NOT NULL,
    name character varying,
    price integer,
    description text,
    status character varying DEFAULT 'paused'::character varying,
    external_id character varying,
    subscription_frequency character varying,
    url character varying,
    featured boolean,
    "position" integer,
    benefits text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    slug character varying
);


--
-- Name: plans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.plans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: plans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.plans_id_seq OWNED BY public.plans.id;


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posts (
    id bigint NOT NULL,
    title character varying,
    body text,
    description text,
    publish_at timestamp without time zone,
    keywords character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    slug character varying,
    views integer DEFAULT 0,
    shares integer,
    post_type character varying,
    category character varying,
    chief_id integer
);


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.posts_id_seq OWNED BY public.posts.id;


--
-- Name: project_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_categories (
    id bigint NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: project_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.project_categories_id_seq OWNED BY public.project_categories.id;


--
-- Name: project_matches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_matches (
    id bigint NOT NULL,
    project_id integer,
    startup_id integer,
    question_1 text,
    question_2 text,
    question_3 text,
    chief_id integer,
    name character varying,
    whatsapp character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    my_project_id integer,
    job_title character varying
);


--
-- Name: project_matches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_matches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_matches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.project_matches_id_seq OWNED BY public.project_matches.id;


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id bigint NOT NULL,
    title character varying,
    description text,
    features text,
    price integer,
    splits integer,
    spots_left integer,
    content1 text,
    content2 text,
    content3 text,
    status character varying DEFAULT '0'::character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    slug character varying,
    small_description character varying,
    "position" integer DEFAULT 0,
    investiment_badge integer,
    duration_badge integer,
    project_category_id integer,
    project_size character varying
);


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.projects_id_seq OWNED BY public.projects.id;


--
-- Name: recording_calls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recording_calls (
    id bigint NOT NULL,
    resume text,
    chief_id integer,
    title character varying,
    participants character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    full_text text
);


--
-- Name: recording_calls_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.recording_calls_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: recording_calls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.recording_calls_id_seq OWNED BY public.recording_calls.id;


--
-- Name: recordings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recordings (
    id bigint NOT NULL,
    startup_ad_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    startup_ad_match_id integer
);


--
-- Name: recordings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.recordings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: recordings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.recordings_id_seq OWNED BY public.recordings.id;


--
-- Name: recruiter_survey_responses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recruiter_survey_responses (
    id bigint NOT NULL,
    chief_id bigint NOT NULL,
    startup_ad_id bigint NOT NULL,
    score integer NOT NULL,
    feedback text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: recruiter_survey_responses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.recruiter_survey_responses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: recruiter_survey_responses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.recruiter_survey_responses_id_seq OWNED BY public.recruiter_survey_responses.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: searches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.searches (
    id bigint NOT NULL,
    query jsonb,
    chief_id integer,
    startup_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: searches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.searches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: searches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.searches_id_seq OWNED BY public.searches.id;


--
-- Name: settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.settings (
    id bigint NOT NULL,
    key character varying,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.settings_id_seq OWNED BY public.settings.id;


--
-- Name: short_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.short_links (
    id bigint NOT NULL,
    token character varying NOT NULL,
    destination_url text NOT NULL,
    expires_at timestamp without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: short_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.short_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: short_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.short_links_id_seq OWNED BY public.short_links.id;


--
-- Name: shortlists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shortlists (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    startup_id integer,
    name character varying,
    views integer DEFAULT 0,
    slug character varying
);


--
-- Name: shortlists_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.shortlists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: shortlists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.shortlists_id_seq OWNED BY public.shortlists.id;


--
-- Name: skill_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.skill_values (
    id bigint NOT NULL,
    skill_id integer,
    startup_ad_match_id integer,
    chief_id integer,
    rating integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: skill_values_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.skill_values_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: skill_values_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.skill_values_id_seq OWNED BY public.skill_values.id;


--
-- Name: skills; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.skills (
    id bigint NOT NULL,
    name character varying,
    startup_ad_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: skills_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.skills_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: skills_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.skills_id_seq OWNED BY public.skills.id;


--
-- Name: stars; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stars (
    id bigint NOT NULL,
    chief_id integer,
    startup_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    owner character varying
);


--
-- Name: stars_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stars_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stars_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stars_id_seq OWNED BY public.stars.id;


--
-- Name: startup_ad_match_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.startup_ad_match_comments (
    id bigint NOT NULL,
    startup_ad_match_id bigint NOT NULL,
    chief_id bigint NOT NULL,
    author_id bigint NOT NULL,
    content text NOT NULL,
    visible_to_chief boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: startup_ad_match_comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.startup_ad_match_comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: startup_ad_match_comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.startup_ad_match_comments_id_seq OWNED BY public.startup_ad_match_comments.id;


--
-- Name: startup_ad_matches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.startup_ad_matches (
    id bigint NOT NULL,
    startup_ad_id integer,
    chief_id integer,
    review text,
    "position" integer,
    status character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    video_review character varying,
    startup_feedback text,
    startup_rating integer,
    interview_comments text,
    similar_success text,
    profile_decision character varying,
    stage character varying DEFAULT 'screening'::character varying NOT NULL,
    disqualified_reason text,
    disqualified_feedback text,
    disqualified_at timestamp without time zone,
    requalified_reason text,
    requalified_feedback text,
    requalified_at timestamp without time zone,
    ai_source boolean DEFAULT false,
    ai_origin character varying
);


--
-- Name: startup_ad_matches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.startup_ad_matches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: startup_ad_matches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.startup_ad_matches_id_seq OWNED BY public.startup_ad_matches.id;


--
-- Name: startup_ads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.startup_ads (
    id bigint NOT NULL,
    title character varying,
    challenge text,
    requirement text,
    non_requirement text,
    owner character varying,
    estimated_duration character varying,
    estimated_budget character varying,
    startup_id integer,
    status character varying DEFAULT 'active'::character varying,
    views integer DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    anonymous boolean DEFAULT false,
    chief_id integer,
    shortlist_id integer,
    expires_at timestamp without time zone,
    review_chiefs text,
    funil_1 integer,
    funil_2 integer,
    funil_3 integer,
    funil_4 integer,
    video_review character varying,
    chief_selected_at timestamp without time zone,
    recruiter_id integer,
    model_of_work character varying,
    location character varying,
    reason character varying,
    company_id integer,
    culture text,
    responsibilities text,
    requirements text,
    benefits text,
    description text,
    chief_profile text,
    contract_conditions text,
    state character varying,
    city character varying,
    funil_5 integer,
    external_id character varying
);


--
-- Name: startup_ads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.startup_ads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: startup_ads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.startup_ads_id_seq OWNED BY public.startup_ads.id;


--
-- Name: startup_companies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.startup_companies (
    id bigint NOT NULL,
    startup_id bigint,
    company_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: startup_companies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.startup_companies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: startup_companies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.startup_companies_id_seq OWNED BY public.startup_companies.id;


--
-- Name: startups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.startups (
    id bigint NOT NULL,
    name character varying,
    cnpj character varying,
    site character varying,
    linkedin character varying,
    revenue character varying,
    contact_name character varying,
    contact_email character varying,
    contact_phone character varying,
    contact_job_title character varying,
    contact_linkedin character varying,
    service_type character varying,
    referral character varying,
    referral_other character varying,
    status character varying,
    slug character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp without time zone,
    remember_created_at timestamp without time zone,
    fundation_year character varying,
    company_stage character varying,
    description text,
    sector character varying,
    market character varying,
    target character varying,
    linkedin_founders text,
    city character varying,
    monetization character varying,
    fulltime_team character varying,
    customers character varying,
    investment_stage character varying,
    founders integer,
    monday_id character varying,
    monday_contact_id character varying,
    ac_id character varying,
    revenue_last_month integer,
    email_optin boolean DEFAULT true,
    "tokenId" integer,
    wallet character varying,
    firebase_id character varying,
    firebase_id_token character varying,
    onepercent_startup_id character varying,
    onepercent_asset_id character varying,
    firebase_password character varying,
    onepercent_transaction_id character varying,
    approved_operator boolean DEFAULT false,
    utm_source character varying,
    utm_medium character varying,
    utm_campaign character varying,
    ref character varying,
    startup_id integer,
    holding boolean DEFAULT false,
    blacklist jsonb DEFAULT '[]'::jsonb,
    website character varying,
    external_id_payment character varying,
    cc_line_1 character varying,
    cc_line_2 character varying,
    cc_zip_code character varying,
    cc_city character varying,
    cc_state character varying,
    cc_country character varying,
    cc_neighborhood character varying,
    cc_address_number character varying,
    size character varying,
    representative_position character varying,
    company_id integer,
    invitation_token character varying,
    invitation_created_at timestamp without time zone,
    invitation_sent_at timestamp without time zone,
    invitation_accepted_at timestamp without time zone,
    invitation_limit integer,
    invited_by_id bigint,
    invited_by_type character varying,
    invitations_count integer DEFAULT 0,
    invitation_resent_count integer DEFAULT 0 NOT NULL,
    invitation_revoked_at timestamp without time zone,
    invitation_revoked_by_id bigint,
    invitation_sent_by_id bigint
);


--
-- Name: startups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.startups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: startups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.startups_id_seq OWNED BY public.startups.id;


--
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscriptions (
    id bigint NOT NULL,
    uuid character varying DEFAULT 'dfa72cc2-3809-4433-89c0-d53af5b601eb'::character varying,
    chief_id integer,
    status character varying DEFAULT 'pending'::character varying,
    plan_id integer,
    cancel_at timestamp without time zone,
    valid_until timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    order_id integer,
    external_id character varying
);


--
-- Name: subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.subscriptions_id_seq OWNED BY public.subscriptions.id;


--
-- Name: survey_responses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.survey_responses (
    id bigint NOT NULL,
    survey_id bigint NOT NULL,
    respondent_name character varying NOT NULL,
    respondent_email character varying NOT NULL,
    answered_at timestamp without time zone NOT NULL,
    responses jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    chief_id bigint
);


--
-- Name: survey_responses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.survey_responses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: survey_responses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.survey_responses_id_seq OWNED BY public.survey_responses.id;


--
-- Name: surveys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.surveys (
    id bigint NOT NULL,
    title character varying NOT NULL,
    description text,
    fields_schema jsonb DEFAULT '{}'::jsonb NOT NULL,
    slug character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    created_by_id bigint,
    status character varying DEFAULT 'active'::character varying NOT NULL
);


--
-- Name: surveys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.surveys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: surveys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.surveys_id_seq OWNED BY public.surveys.id;


--
-- Name: terms_of_uses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.terms_of_uses (
    id bigint NOT NULL,
    chief_id integer,
    accepted boolean,
    ip character varying,
    browser character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: terms_of_uses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.terms_of_uses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: terms_of_uses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.terms_of_uses_id_seq OWNED BY public.terms_of_uses.id;


--
-- Name: ticket_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ticket_comments (
    id bigint NOT NULL,
    body text NOT NULL,
    ticket_id bigint NOT NULL,
    chief_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ticket_comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ticket_comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ticket_comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ticket_comments_id_seq OWNED BY public.ticket_comments.id;


--
-- Name: tickets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tickets (
    id bigint NOT NULL,
    number character varying NOT NULL,
    title character varying NOT NULL,
    body text NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    assigned_chief_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    category integer DEFAULT 0 NOT NULL,
    owner_type character varying NOT NULL,
    owner_id bigint NOT NULL,
    admin_unread boolean DEFAULT false NOT NULL,
    chief_unread boolean DEFAULT false NOT NULL
);


--
-- Name: tickets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tickets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tickets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tickets_id_seq OWNED BY public.tickets.id;


--
-- Name: timesheets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.timesheets (
    id bigint NOT NULL,
    chief_id integer,
    my_project_id integer,
    description text,
    hours integer,
    when_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: timesheets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.timesheets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: timesheets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.timesheets_id_seq OWNED BY public.timesheets.id;


--
-- Name: transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transactions (
    id bigint NOT NULL,
    transaction_type character varying,
    chief_id integer,
    startup_id integer,
    description character varying,
    total integer DEFAULT 0,
    transaction_hash character varying,
    status character varying DEFAULT 'active'::character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    token_type character varying,
    status_firebase character varying,
    transactionable_id bigint,
    transactionable_type character varying
);


--
-- Name: transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.transactions_id_seq OWNED BY public.transactions.id;


--
-- Name: trix_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trix_images (
    id bigint NOT NULL,
    image_date text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: trix_images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.trix_images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trix_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.trix_images_id_seq OWNED BY public.trix_images.id;


--
-- Name: versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.versions (
    id bigint NOT NULL,
    item_type character varying NOT NULL,
    item_id bigint NOT NULL,
    event character varying NOT NULL,
    whodunnit character varying,
    object text,
    created_at timestamp without time zone,
    object_changes text,
    company_id bigint,
    startup_ad_id bigint
);


--
-- Name: versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.versions_id_seq OWNED BY public.versions.id;


--
-- Name: vw_ca_categorias_classificadas; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_ca_categorias_classificadas AS
 SELECT conta_azul_id,
    nome,
    tipo,
        CASE
            WHEN ((nome)::text ~* '(descentraliz|fora.*sistema|extra.*conta)'::text) THEN 'descentralizado'::text
            WHEN ((nome)::text ~* '(centraliz|repasse.*chief|chief.*centraliz)'::text) THEN 'centralizado'::text
            ELSE 'outros'::text
        END AS classificacao
   FROM public.ca_categories c;


--
-- Name: vw_ca_clientes_ouro; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_ca_clientes_ouro AS
 SELECT ct.conta_azul_id AS contrato_id,
    ct.numero AS contrato_numero,
    ct.cliente_uuid,
    ct.cliente_nome,
    p.documento AS cliente_documento,
    ct.valor_recorrente,
    (NULLIF((ct.raw_payload ->> 'data_proxima_emissao'::text), ''::text))::date AS proxima_emissao,
    (NULLIF((ct.raw_payload ->> 'data_proximo_vencimento'::text), ''::text))::date AS proximo_vencimento,
    (NULLIF((ct.raw_payload ->> 'data_ultima_emissao'::text), ''::text))::date AS ultima_emissao,
    (EXISTS ( SELECT 1
           FROM public.ca_service_invoices nf
          WHERE (((nf.contrato_uuid)::text = (ct.conta_azul_id)::text) AND (COALESCE(nf.data_competencia, nf.data_emissao) >= (CURRENT_DATE - '30 days'::interval))))) AS nf_ciclo_atual
   FROM (public.ca_contracts ct
     LEFT JOIN public.ca_people p ON (((p.conta_azul_id)::text = (ct.cliente_uuid)::text)))
  WHERE ((upper((COALESCE(ct.status, ''::character varying))::text) = 'ATIVO'::text) AND (COALESCE(ct.valor_recorrente, (0)::numeric) > (0)::numeric) AND ((NULLIF((ct.raw_payload ->> 'data_proxima_emissao'::text), ''::text))::date IS NOT NULL) AND (((NULLIF((ct.raw_payload ->> 'data_proxima_emissao'::text), ''::text))::date >= CURRENT_DATE) AND ((NULLIF((ct.raw_payload ->> 'data_proxima_emissao'::text), ''::text))::date <= (CURRENT_DATE + '3 mons'::interval))));


--
-- Name: vw_ca_comissao_mensal; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_ca_comissao_mensal AS
 WITH receita_competencia AS (
         SELECT (date_trunc('month'::text, (COALESCE(nf.data_competencia, nf.data_emissao))::timestamp with time zone))::date AS mes,
            sum(nf.valor_total) AS valor
           FROM public.ca_service_invoices nf
          WHERE ((COALESCE(nf.data_competencia, nf.data_emissao) IS NOT NULL) AND ((COALESCE(nf.status, ''::character varying))::text <> ALL (ARRAY[('CANCELADA'::character varying)::text, ('CANCELLED'::character varying)::text, ('INUTILIZADA'::character varying)::text, ('INUTILIZED'::character varying)::text, ('REJEITADA'::character varying)::text, ('REJECTED'::character varying)::text, ('NEGADA'::character varying)::text, ('NEGATED'::character varying)::text])))
          GROUP BY ((date_trunc('month'::text, (COALESCE(nf.data_competencia, nf.data_emissao))::timestamp with time zone))::date)
        ), repasse_centralizado_competencia AS (
         SELECT (date_trunc('month'::text, (COALESCE(ev.data_competencia, ev.data_vencimento))::timestamp with time zone))::date AS mes,
            sum(ev.valor) AS valor
           FROM (public.ca_financial_events ev
             JOIN public.vw_ca_categorias_classificadas cat ON (((cat.conta_azul_id)::text = (ev.categoria_uuid)::text)))
          WHERE (((ev.tipo)::text = 'PAGAR'::text) AND (cat.classificacao = 'centralizado'::text) AND (COALESCE(ev.data_competencia, ev.data_vencimento) IS NOT NULL))
          GROUP BY ((date_trunc('month'::text, (COALESCE(ev.data_competencia, ev.data_vencimento))::timestamp with time zone))::date)
        ), receita_caixa AS (
         SELECT (date_trunc('month'::text, (ev.data_competencia)::timestamp with time zone))::date AS mes,
            sum(((ev.raw_payload ->> 'pago'::text))::numeric) AS valor
           FROM public.ca_financial_events ev
          WHERE (((ev.tipo)::text = 'RECEBER'::text) AND ((ev.status)::text = 'ACQUITTED'::text) AND (ev.data_competencia IS NOT NULL) AND ((ev.raw_payload ->> 'pago'::text) IS NOT NULL))
          GROUP BY ((date_trunc('month'::text, (ev.data_competencia)::timestamp with time zone))::date)
        ), repasse_caixa AS (
         SELECT (date_trunc('month'::text, (ev.data_competencia)::timestamp with time zone))::date AS mes,
            sum(((ev.raw_payload ->> 'pago'::text))::numeric) AS valor
           FROM (public.ca_financial_events ev
             JOIN public.vw_ca_categorias_classificadas cat ON (((cat.conta_azul_id)::text = (ev.categoria_uuid)::text)))
          WHERE (((ev.tipo)::text = 'PAGAR'::text) AND ((ev.status)::text = 'ACQUITTED'::text) AND (cat.classificacao = 'centralizado'::text) AND (ev.data_competencia IS NOT NULL) AND ((ev.raw_payload ->> 'pago'::text) IS NOT NULL))
          GROUP BY ((date_trunc('month'::text, (ev.data_competencia)::timestamp with time zone))::date)
        )
 SELECT m.mes,
    COALESCE(rc.valor, (0)::numeric) AS receita_competencia,
    COALESCE(rpc.valor, (0)::numeric) AS repasse_competencia,
    (COALESCE(rc.valor, (0)::numeric) - COALESCE(rpc.valor, (0)::numeric)) AS comissao_competencia,
    COALESCE(rcx.valor, (0)::numeric) AS receita_caixa,
    COALESCE(rpx.valor, (0)::numeric) AS repasse_caixa,
    (COALESCE(rcx.valor, (0)::numeric) - COALESCE(rpx.valor, (0)::numeric)) AS comissao_caixa
   FROM ((((( SELECT receita_competencia.mes
           FROM receita_competencia
        UNION
         SELECT repasse_centralizado_competencia.mes
           FROM repasse_centralizado_competencia
        UNION
         SELECT receita_caixa.mes
           FROM receita_caixa
        UNION
         SELECT repasse_caixa.mes
           FROM repasse_caixa) m
     LEFT JOIN receita_competencia rc ON ((rc.mes = m.mes)))
     LEFT JOIN repasse_centralizado_competencia rpc ON ((rpc.mes = m.mes)))
     LEFT JOIN receita_caixa rcx ON ((rcx.mes = m.mes)))
     LEFT JOIN repasse_caixa rpx ON ((rpx.mes = m.mes)));


--
-- Name: vw_ca_contratos_ltv; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_ca_contratos_ltv AS
 SELECT ct.conta_azul_id AS contrato_id,
    ct.numero AS contrato_numero,
    ct.cliente_uuid,
    ct.cliente_nome,
    ct.data_inicio,
    ct.data_fim,
    ct.valor_total AS valor_contrato,
    ct.valor_recorrente,
    COALESCE(sum(nf.valor_total), (0)::numeric) AS faturamento_realizado,
    count(nf.conta_azul_id) AS qtd_nfs,
    min(COALESCE(nf.data_competencia, nf.data_emissao)) AS primeira_nf,
    max(COALESCE(nf.data_competencia, nf.data_emissao)) AS ultima_nf
   FROM (public.ca_contracts ct
     LEFT JOIN public.ca_service_invoices nf ON ((((nf.contrato_uuid)::text = (ct.conta_azul_id)::text) AND ((COALESCE(nf.status, ''::character varying))::text <> ALL (ARRAY[('CANCELADA'::character varying)::text, ('CANCELLED'::character varying)::text, ('INUTILIZADA'::character varying)::text, ('INUTILIZED'::character varying)::text, ('REJEITADA'::character varying)::text, ('REJECTED'::character varying)::text, ('NEGADA'::character varying)::text, ('NEGATED'::character varying)::text])))))
  GROUP BY ct.conta_azul_id, ct.numero, ct.cliente_uuid, ct.cliente_nome, ct.data_inicio, ct.data_fim, ct.valor_total, ct.valor_recorrente;


--
-- Name: vw_ca_inadimplencia; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_ca_inadimplencia AS
 SELECT ev.conta_azul_id AS evento_id,
    NULL::text AS parcela_id,
    NULL::text AS venda_id,
    ev.pessoa_uuid,
    p.nome AS cliente_nome,
    p.documento AS cliente_documento,
    ev.descricao,
    ev.valor AS valor_evento,
    COALESCE(((ev.raw_payload ->> 'pago'::text))::numeric, (0)::numeric) AS valor_pago,
    COALESCE(((ev.raw_payload ->> 'nao_pago'::text))::numeric, ev.valor) AS valor_aberto,
    ev.data_vencimento,
    (CURRENT_DATE - ev.data_vencimento) AS dias_atraso,
        CASE
            WHEN (ev.data_vencimento >= (CURRENT_DATE - '30 days'::interval)) THEN '0-30'::text
            WHEN (ev.data_vencimento >= (CURRENT_DATE - '60 days'::interval)) THEN '31-60'::text
            WHEN (ev.data_vencimento >= (CURRENT_DATE - '90 days'::interval)) THEN '61-90'::text
            ELSE '90+'::text
        END AS faixa_aging
   FROM (public.ca_financial_events ev
     LEFT JOIN public.ca_people p ON (((p.conta_azul_id)::text = (ev.pessoa_uuid)::text)))
  WHERE (((ev.tipo)::text = 'RECEBER'::text) AND ((ev.status)::text = 'OVERDUE'::text) AND (ev.data_vencimento IS NOT NULL) AND (COALESCE(((ev.raw_payload ->> 'nao_pago'::text))::numeric, ev.valor) > (0)::numeric));


--
-- Name: vw_ca_mrr_ativo; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_ca_mrr_ativo AS
 SELECT conta_azul_id AS contrato_id,
    numero AS contrato_numero,
    cliente_uuid,
    cliente_nome,
    periodicidade,
    data_inicio,
    data_fim,
    valor_recorrente,
    status
   FROM public.ca_contracts ct
  WHERE ((COALESCE(valor_recorrente, (0)::numeric) > (0)::numeric) AND ((data_fim IS NULL) OR (data_fim >= CURRENT_DATE)) AND (COALESCE(upper((status)::text), ''::text) <> ALL (ARRAY['CANCELADO'::text, 'CANCELLED'::text, 'ENCERRADO'::text, 'FINALIZADO'::text, 'INATIVO'::text])));


--
-- Name: vw_ca_repasse_chiefs_mensal; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_ca_repasse_chiefs_mensal AS
 SELECT (date_trunc('month'::text, (COALESCE(ev.data_competencia, ev.data_vencimento))::timestamp with time zone))::date AS mes,
    ev.pessoa_uuid,
    p.nome AS chief_nome,
    p.documento AS chief_documento,
    cat.nome AS categoria_nome,
    cat.classificacao AS categoria_classificacao,
    sum(ev.valor) AS valor_total,
    count(*) AS qtd_eventos
   FROM ((public.ca_financial_events ev
     JOIN public.vw_ca_categorias_classificadas cat ON (((cat.conta_azul_id)::text = (ev.categoria_uuid)::text)))
     LEFT JOIN public.ca_people p ON (((p.conta_azul_id)::text = (ev.pessoa_uuid)::text)))
  WHERE (((ev.tipo)::text = 'PAGAR'::text) AND (cat.classificacao = ANY (ARRAY['centralizado'::text, 'descentralizado'::text])) AND (COALESCE(ev.data_competencia, ev.data_vencimento) IS NOT NULL))
  GROUP BY ((date_trunc('month'::text, (COALESCE(ev.data_competencia, ev.data_vencimento))::timestamp with time zone))::date), ev.pessoa_uuid, p.nome, p.documento, cat.nome, cat.classificacao;


--
-- Name: vw_ca_tpv_mensal; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_ca_tpv_mensal AS
 WITH receita_nf AS (
         SELECT (date_trunc('month'::text, (COALESCE(nf.data_competencia, nf.data_emissao))::timestamp with time zone))::date AS mes,
            sum(nf.valor_total) AS valor
           FROM public.ca_service_invoices nf
          WHERE ((COALESCE(nf.data_competencia, nf.data_emissao) IS NOT NULL) AND ((COALESCE(nf.status, ''::character varying))::text <> ALL (ARRAY[('CANCELADA'::character varying)::text, ('CANCELLED'::character varying)::text, ('INUTILIZADA'::character varying)::text, ('INUTILIZED'::character varying)::text, ('REJEITADA'::character varying)::text, ('REJECTED'::character varying)::text, ('NEGADA'::character varying)::text, ('NEGATED'::character varying)::text])))
          GROUP BY ((date_trunc('month'::text, (COALESCE(nf.data_competencia, nf.data_emissao))::timestamp with time zone))::date)
        ), pagar_descentralizado AS (
         SELECT (date_trunc('month'::text, (COALESCE(ev.data_competencia, ev.data_vencimento))::timestamp with time zone))::date AS mes,
            sum(ev.valor) AS valor
           FROM (public.ca_financial_events ev
             JOIN public.vw_ca_categorias_classificadas cat ON (((cat.conta_azul_id)::text = (ev.categoria_uuid)::text)))
          WHERE (((ev.tipo)::text = 'PAGAR'::text) AND (cat.classificacao = 'descentralizado'::text) AND (COALESCE(ev.data_competencia, ev.data_vencimento) IS NOT NULL))
          GROUP BY ((date_trunc('month'::text, (COALESCE(ev.data_competencia, ev.data_vencimento))::timestamp with time zone))::date)
        )
 SELECT m.mes,
    COALESCE(r.valor, (0)::numeric) AS receita_centralizada,
    COALESCE(d.valor, (0)::numeric) AS valor_descentralizado,
    (COALESCE(r.valor, (0)::numeric) + COALESCE(d.valor, (0)::numeric)) AS tpv_total
   FROM ((( SELECT receita_nf.mes
           FROM receita_nf
        UNION
         SELECT pagar_descentralizado.mes
           FROM pagar_descentralizado) m
     LEFT JOIN receita_nf r ON ((r.mes = m.mes)))
     LEFT JOIN pagar_descentralizado d ON ((d.mes = m.mes)));


--
-- Name: vw_ca_take_rate_mensal; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_ca_take_rate_mensal AS
 SELECT tpv.mes,
    tpv.tpv_total,
    com.comissao_competencia,
        CASE
            WHEN (tpv.tpv_total > (0)::numeric) THEN round((com.comissao_competencia / tpv.tpv_total), 4)
            ELSE NULL::numeric
        END AS take_rate
   FROM (public.vw_ca_tpv_mensal tpv
     LEFT JOIN public.vw_ca_comissao_mensal com ON ((com.mes = tpv.mes)))
  WHERE (tpv.mes < (date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone))::date);


--
-- Name: vw_ca_top_clientes_receita_12m; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_ca_top_clientes_receita_12m AS
 SELECT nf.cliente_uuid,
    p.nome AS cliente_nome,
    p.documento AS cliente_documento,
    sum(nf.valor_total) AS receita_12m,
    count(*) AS qtd_nfs,
    min(COALESCE(nf.data_competencia, nf.data_emissao)) AS primeira_nf,
    max(COALESCE(nf.data_competencia, nf.data_emissao)) AS ultima_nf
   FROM (public.ca_service_invoices nf
     LEFT JOIN public.ca_people p ON (((p.conta_azul_id)::text = (nf.cliente_uuid)::text)))
  WHERE ((nf.cliente_uuid IS NOT NULL) AND (COALESCE(nf.data_competencia, nf.data_emissao) >= (CURRENT_DATE - '1 year'::interval)) AND ((COALESCE(nf.status, ''::character varying))::text <> ALL (ARRAY[('CANCELADA'::character varying)::text, ('CANCELLED'::character varying)::text, ('INUTILIZADA'::character varying)::text, ('INUTILIZED'::character varying)::text, ('REJEITADA'::character varying)::text, ('REJECTED'::character varying)::text, ('NEGADA'::character varying)::text, ('NEGATED'::character varying)::text])))
  GROUP BY nf.cliente_uuid, p.nome, p.documento;


--
-- Name: active_campaign_campaigns id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_campaign_campaigns ALTER COLUMN id SET DEFAULT nextval('public.active_campaign_campaigns_id_seq'::regclass);


--
-- Name: active_campaign_contact_messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_campaign_contact_messages ALTER COLUMN id SET DEFAULT nextval('public.active_campaign_contact_messages_id_seq'::regclass);


--
-- Name: active_campaign_contact_monthly_snapshots id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_campaign_contact_monthly_snapshots ALTER COLUMN id SET DEFAULT nextval('public.active_campaign_contact_monthly_snapshots_id_seq'::regclass);


--
-- Name: active_campaign_contacts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_campaign_contacts ALTER COLUMN id SET DEFAULT nextval('public.active_campaign_contacts_id_seq'::regclass);


--
-- Name: active_campaign_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_campaign_tags ALTER COLUMN id SET DEFAULT nextval('public.active_campaign_tags_id_seq'::regclass);


--
-- Name: active_campaign_webhook_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_campaign_webhook_events ALTER COLUMN id SET DEFAULT nextval('public.active_campaign_webhook_events_id_seq'::regclass);


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: agent_conversations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_conversations ALTER COLUMN id SET DEFAULT nextval('public.agent_conversations_id_seq'::regclass);


--
-- Name: agent_messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_messages ALTER COLUMN id SET DEFAULT nextval('public.agent_messages_id_seq'::regclass);


--
-- Name: analytics_chief_view_rankings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_chief_view_rankings ALTER COLUMN id SET DEFAULT nextval('public.analytics_chief_view_rankings_id_seq'::regclass);


--
-- Name: analytics_page_view_summaries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_page_view_summaries ALTER COLUMN id SET DEFAULT nextval('public.analytics_page_view_summaries_id_seq'::regclass);


--
-- Name: api_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens ALTER COLUMN id SET DEFAULT nextval('public.api_tokens_id_seq'::regclass);


--
-- Name: ca_acquittances id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_acquittances ALTER COLUMN id SET DEFAULT nextval('public.ca_acquittances_id_seq'::regclass);


--
-- Name: ca_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_categories ALTER COLUMN id SET DEFAULT nextval('public.ca_categories_id_seq'::regclass);


--
-- Name: ca_contracts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_contracts ALTER COLUMN id SET DEFAULT nextval('public.ca_contracts_id_seq'::regclass);


--
-- Name: ca_cost_centers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_cost_centers ALTER COLUMN id SET DEFAULT nextval('public.ca_cost_centers_id_seq'::regclass);


--
-- Name: ca_dre_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_dre_categories ALTER COLUMN id SET DEFAULT nextval('public.ca_dre_categories_id_seq'::regclass);


--
-- Name: ca_dre_category_categorias id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_dre_category_categorias ALTER COLUMN id SET DEFAULT nextval('public.ca_dre_category_categorias_id_seq'::regclass);


--
-- Name: ca_event_apportionments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_event_apportionments ALTER COLUMN id SET DEFAULT nextval('public.ca_event_apportionments_id_seq'::regclass);


--
-- Name: ca_financial_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_financial_accounts ALTER COLUMN id SET DEFAULT nextval('public.ca_financial_accounts_id_seq'::regclass);


--
-- Name: ca_financial_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_financial_events ALTER COLUMN id SET DEFAULT nextval('public.ca_financial_events_id_seq'::regclass);


--
-- Name: ca_financial_installments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_financial_installments ALTER COLUMN id SET DEFAULT nextval('public.ca_financial_installments_id_seq'::regclass);


--
-- Name: ca_people id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_people ALTER COLUMN id SET DEFAULT nextval('public.ca_people_id_seq'::regclass);


--
-- Name: ca_sale_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_sale_items ALTER COLUMN id SET DEFAULT nextval('public.ca_sale_items_id_seq'::regclass);


--
-- Name: ca_sales id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_sales ALTER COLUMN id SET DEFAULT nextval('public.ca_sales_id_seq'::regclass);


--
-- Name: ca_sellers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_sellers ALTER COLUMN id SET DEFAULT nextval('public.ca_sellers_id_seq'::regclass);


--
-- Name: ca_service_invoices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_service_invoices ALTER COLUMN id SET DEFAULT nextval('public.ca_service_invoices_id_seq'::regclass);


--
-- Name: careers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.careers ALTER COLUMN id SET DEFAULT nextval('public.careers_id_seq'::regclass);


--
-- Name: chief_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_accounts ALTER COLUMN id SET DEFAULT nextval('public.chief_accounts_id_seq'::regclass);


--
-- Name: chief_ads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_ads ALTER COLUMN id SET DEFAULT nextval('public.chief_ads_id_seq'::regclass);


--
-- Name: chief_comments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_comments ALTER COLUMN id SET DEFAULT nextval('public.chief_comments_id_seq'::regclass);


--
-- Name: chiefs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chiefs ALTER COLUMN id SET DEFAULT nextval('public.chiefs_id_seq'::regclass);


--
-- Name: chiefs_csv_exports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chiefs_csv_exports ALTER COLUMN id SET DEFAULT nextval('public.chiefs_csv_exports_id_seq'::regclass);


--
-- Name: chiefs_start id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chiefs_start ALTER COLUMN id SET DEFAULT nextval('public.chiefs_start_id_seq'::regclass);


--
-- Name: chiefs_startup_ads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chiefs_startup_ads ALTER COLUMN id SET DEFAULT nextval('public.chiefs_startup_ads_id_seq'::regclass);


--
-- Name: companies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies ALTER COLUMN id SET DEFAULT nextval('public.companies_id_seq'::regclass);


--
-- Name: conta_azul_oauth_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conta_azul_oauth_tokens ALTER COLUMN id SET DEFAULT nextval('public.conta_azul_oauth_tokens_id_seq'::regclass);


--
-- Name: contract_mentorships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_mentorships ALTER COLUMN id SET DEFAULT nextval('public.contract_mentorships_id_seq'::regclass);


--
-- Name: coupons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupons ALTER COLUMN id SET DEFAULT nextval('public.coupons_id_seq'::regclass);


--
-- Name: credit_cards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_cards ALTER COLUMN id SET DEFAULT nextval('public.credit_cards_id_seq'::regclass);


--
-- Name: curriculos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculos ALTER COLUMN id SET DEFAULT nextval('public.curriculos_id_seq'::regclass);


--
-- Name: friendly_id_slugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendly_id_slugs ALTER COLUMN id SET DEFAULT nextval('public.friendly_id_slugs_id_seq'::regclass);


--
-- Name: invite_orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invite_orders ALTER COLUMN id SET DEFAULT nextval('public.invite_orders_id_seq'::regclass);


--
-- Name: invites id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invites ALTER COLUMN id SET DEFAULT nextval('public.invites_id_seq'::regclass);


--
-- Name: journeys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journeys ALTER COLUMN id SET DEFAULT nextval('public.journeys_id_seq'::regclass);


--
-- Name: legal_pages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_pages ALTER COLUMN id SET DEFAULT nextval('public.legal_pages_id_seq'::regclass);


--
-- Name: libraries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.libraries ALTER COLUMN id SET DEFAULT nextval('public.libraries_id_seq'::regclass);


--
-- Name: linkedin_profiles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.linkedin_profiles ALTER COLUMN id SET DEFAULT nextval('public.linkedin_profiles_id_seq'::regclass);


--
-- Name: matches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches ALTER COLUMN id SET DEFAULT nextval('public.matches_id_seq'::regclass);


--
-- Name: messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ALTER COLUMN id SET DEFAULT nextval('public.messages_id_seq'::regclass);


--
-- Name: my_projects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.my_projects ALTER COLUMN id SET DEFAULT nextval('public.my_projects_id_seq'::regclass);


--
-- Name: nps_responses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nps_responses ALTER COLUMN id SET DEFAULT nextval('public.nps_responses_id_seq'::regclass);


--
-- Name: oauth_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_accounts ALTER COLUMN id SET DEFAULT nextval('public.oauth_accounts_id_seq'::regclass);


--
-- Name: orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders ALTER COLUMN id SET DEFAULT nextval('public.orders_id_seq'::regclass);


--
-- Name: page_views id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.page_views ALTER COLUMN id SET DEFAULT nextval('public.page_views_id_seq'::regclass);


--
-- Name: pipedrive_deal_files id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipedrive_deal_files ALTER COLUMN id SET DEFAULT nextval('public.pipedrive_deal_files_id_seq'::regclass);


--
-- Name: pipedrive_deal_heat_snapshots id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipedrive_deal_heat_snapshots ALTER COLUMN id SET DEFAULT nextval('public.pipedrive_deal_heat_snapshots_id_seq'::regclass);


--
-- Name: pipedrive_deal_notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipedrive_deal_notes ALTER COLUMN id SET DEFAULT nextval('public.pipedrive_deal_notes_id_seq'::regclass);


--
-- Name: pipedrive_deal_stage_changes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipedrive_deal_stage_changes ALTER COLUMN id SET DEFAULT nextval('public.pipedrive_deal_stage_changes_id_seq'::regclass);


--
-- Name: pipedrive_deals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipedrive_deals ALTER COLUMN id SET DEFAULT nextval('public.pipedrive_deals_id_seq'::regclass);


--
-- Name: pipedrive_owner_contacts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipedrive_owner_contacts ALTER COLUMN id SET DEFAULT nextval('public.pipedrive_owner_contacts_id_seq'::regclass);


--
-- Name: plans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plans ALTER COLUMN id SET DEFAULT nextval('public.plans_id_seq'::regclass);


--
-- Name: posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);


--
-- Name: project_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_categories ALTER COLUMN id SET DEFAULT nextval('public.project_categories_id_seq'::regclass);


--
-- Name: project_matches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_matches ALTER COLUMN id SET DEFAULT nextval('public.project_matches_id_seq'::regclass);


--
-- Name: projects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects ALTER COLUMN id SET DEFAULT nextval('public.projects_id_seq'::regclass);


--
-- Name: recording_calls id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_calls ALTER COLUMN id SET DEFAULT nextval('public.recording_calls_id_seq'::regclass);


--
-- Name: recordings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recordings ALTER COLUMN id SET DEFAULT nextval('public.recordings_id_seq'::regclass);


--
-- Name: recruiter_survey_responses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recruiter_survey_responses ALTER COLUMN id SET DEFAULT nextval('public.recruiter_survey_responses_id_seq'::regclass);


--
-- Name: searches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.searches ALTER COLUMN id SET DEFAULT nextval('public.searches_id_seq'::regclass);


--
-- Name: settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settings ALTER COLUMN id SET DEFAULT nextval('public.settings_id_seq'::regclass);


--
-- Name: short_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.short_links ALTER COLUMN id SET DEFAULT nextval('public.short_links_id_seq'::regclass);


--
-- Name: shortlists id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shortlists ALTER COLUMN id SET DEFAULT nextval('public.shortlists_id_seq'::regclass);


--
-- Name: skill_values id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.skill_values ALTER COLUMN id SET DEFAULT nextval('public.skill_values_id_seq'::regclass);


--
-- Name: skills id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.skills ALTER COLUMN id SET DEFAULT nextval('public.skills_id_seq'::regclass);


--
-- Name: stars id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stars ALTER COLUMN id SET DEFAULT nextval('public.stars_id_seq'::regclass);


--
-- Name: startup_ad_match_comments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.startup_ad_match_comments ALTER COLUMN id SET DEFAULT nextval('public.startup_ad_match_comments_id_seq'::regclass);


--
-- Name: startup_ad_matches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.startup_ad_matches ALTER COLUMN id SET DEFAULT nextval('public.startup_ad_matches_id_seq'::regclass);


--
-- Name: startup_ads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.startup_ads ALTER COLUMN id SET DEFAULT nextval('public.startup_ads_id_seq'::regclass);


--
-- Name: startup_companies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.startup_companies ALTER COLUMN id SET DEFAULT nextval('public.startup_companies_id_seq'::regclass);


--
-- Name: startups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.startups ALTER COLUMN id SET DEFAULT nextval('public.startups_id_seq'::regclass);


--
-- Name: subscriptions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions ALTER COLUMN id SET DEFAULT nextval('public.subscriptions_id_seq'::regclass);


--
-- Name: survey_responses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_responses ALTER COLUMN id SET DEFAULT nextval('public.survey_responses_id_seq'::regclass);


--
-- Name: surveys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surveys ALTER COLUMN id SET DEFAULT nextval('public.surveys_id_seq'::regclass);


--
-- Name: terms_of_uses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.terms_of_uses ALTER COLUMN id SET DEFAULT nextval('public.terms_of_uses_id_seq'::regclass);


--
-- Name: ticket_comments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_comments ALTER COLUMN id SET DEFAULT nextval('public.ticket_comments_id_seq'::regclass);


--
-- Name: tickets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets ALTER COLUMN id SET DEFAULT nextval('public.tickets_id_seq'::regclass);


--
-- Name: timesheets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timesheets ALTER COLUMN id SET DEFAULT nextval('public.timesheets_id_seq'::regclass);


--
-- Name: transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions ALTER COLUMN id SET DEFAULT nextval('public.transactions_id_seq'::regclass);


--
-- Name: trix_images id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trix_images ALTER COLUMN id SET DEFAULT nextval('public.trix_images_id_seq'::regclass);


--
-- Name: versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions ALTER COLUMN id SET DEFAULT nextval('public.versions_id_seq'::regclass);


--
-- Name: active_campaign_campaigns active_campaign_campaigns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_campaign_campaigns
    ADD CONSTRAINT active_campaign_campaigns_pkey PRIMARY KEY (id);


--
-- Name: active_campaign_contact_messages active_campaign_contact_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_campaign_contact_messages
    ADD CONSTRAINT active_campaign_contact_messages_pkey PRIMARY KEY (id);


--
-- Name: active_campaign_contact_monthly_snapshots active_campaign_contact_monthly_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_campaign_contact_monthly_snapshots
    ADD CONSTRAINT active_campaign_contact_monthly_snapshots_pkey PRIMARY KEY (id);


--
-- Name: active_campaign_contacts active_campaign_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_campaign_contacts
    ADD CONSTRAINT active_campaign_contacts_pkey PRIMARY KEY (id);


--
-- Name: active_campaign_tags active_campaign_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_campaign_tags
    ADD CONSTRAINT active_campaign_tags_pkey PRIMARY KEY (id);


--
-- Name: active_campaign_webhook_events active_campaign_webhook_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_campaign_webhook_events
    ADD CONSTRAINT active_campaign_webhook_events_pkey PRIMARY KEY (id);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: agent_conversations agent_conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_conversations
    ADD CONSTRAINT agent_conversations_pkey PRIMARY KEY (id);


--
-- Name: agent_messages agent_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_messages
    ADD CONSTRAINT agent_messages_pkey PRIMARY KEY (id);


--
-- Name: analytics_chief_view_rankings analytics_chief_view_rankings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_chief_view_rankings
    ADD CONSTRAINT analytics_chief_view_rankings_pkey PRIMARY KEY (id);


--
-- Name: analytics_page_view_summaries analytics_page_view_summaries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_page_view_summaries
    ADD CONSTRAINT analytics_page_view_summaries_pkey PRIMARY KEY (id);


--
-- Name: api_tokens api_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT api_tokens_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: ca_acquittances ca_acquittances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_acquittances
    ADD CONSTRAINT ca_acquittances_pkey PRIMARY KEY (id);


--
-- Name: ca_categories ca_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_categories
    ADD CONSTRAINT ca_categories_pkey PRIMARY KEY (id);


--
-- Name: ca_contracts ca_contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_contracts
    ADD CONSTRAINT ca_contracts_pkey PRIMARY KEY (id);


--
-- Name: ca_cost_centers ca_cost_centers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_cost_centers
    ADD CONSTRAINT ca_cost_centers_pkey PRIMARY KEY (id);


--
-- Name: ca_dre_categories ca_dre_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_dre_categories
    ADD CONSTRAINT ca_dre_categories_pkey PRIMARY KEY (id);


--
-- Name: ca_dre_category_categorias ca_dre_category_categorias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_dre_category_categorias
    ADD CONSTRAINT ca_dre_category_categorias_pkey PRIMARY KEY (id);


--
-- Name: ca_event_apportionments ca_event_apportionments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_event_apportionments
    ADD CONSTRAINT ca_event_apportionments_pkey PRIMARY KEY (id);


--
-- Name: ca_financial_accounts ca_financial_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_financial_accounts
    ADD CONSTRAINT ca_financial_accounts_pkey PRIMARY KEY (id);


--
-- Name: ca_financial_events ca_financial_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_financial_events
    ADD CONSTRAINT ca_financial_events_pkey PRIMARY KEY (id);


--
-- Name: ca_financial_installments ca_financial_installments_origem_uuid_chk; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.ca_financial_installments
    ADD CONSTRAINT ca_financial_installments_origem_uuid_chk CHECK (((((origem)::text = 'event'::text) AND (evento_uuid IS NOT NULL)) OR (((origem)::text = 'sale'::text) AND (venda_uuid IS NOT NULL)))) NOT VALID;


--
-- Name: ca_financial_installments ca_financial_installments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_financial_installments
    ADD CONSTRAINT ca_financial_installments_pkey PRIMARY KEY (id);


--
-- Name: ca_people ca_people_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_people
    ADD CONSTRAINT ca_people_pkey PRIMARY KEY (id);


--
-- Name: ca_sale_items ca_sale_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_sale_items
    ADD CONSTRAINT ca_sale_items_pkey PRIMARY KEY (id);


--
-- Name: ca_sales ca_sales_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_sales
    ADD CONSTRAINT ca_sales_pkey PRIMARY KEY (id);


--
-- Name: ca_sellers ca_sellers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_sellers
    ADD CONSTRAINT ca_sellers_pkey PRIMARY KEY (id);


--
-- Name: ca_service_invoices ca_service_invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_service_invoices
    ADD CONSTRAINT ca_service_invoices_pkey PRIMARY KEY (id);


--
-- Name: careers careers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.careers
    ADD CONSTRAINT careers_pkey PRIMARY KEY (id);


--
-- Name: chief_accounts chief_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_accounts
    ADD CONSTRAINT chief_accounts_pkey PRIMARY KEY (id);


--
-- Name: chief_ads chief_ads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_ads
    ADD CONSTRAINT chief_ads_pkey PRIMARY KEY (id);


--
-- Name: chief_comments chief_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_comments
    ADD CONSTRAINT chief_comments_pkey PRIMARY KEY (id);


--
-- Name: chiefs_csv_exports chiefs_csv_exports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chiefs_csv_exports
    ADD CONSTRAINT chiefs_csv_exports_pkey PRIMARY KEY (id);


--
-- Name: chiefs chiefs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chiefs
    ADD CONSTRAINT chiefs_pkey PRIMARY KEY (id);


--
-- Name: chiefs_start chiefs_start_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chiefs_start
    ADD CONSTRAINT chiefs_start_pkey PRIMARY KEY (id);


--
-- Name: chiefs_startup_ads chiefs_startup_ads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chiefs_startup_ads
    ADD CONSTRAINT chiefs_startup_ads_pkey PRIMARY KEY (id);


--
-- Name: companies companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (id);


--
-- Name: conta_azul_oauth_tokens conta_azul_oauth_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conta_azul_oauth_tokens
    ADD CONSTRAINT conta_azul_oauth_tokens_pkey PRIMARY KEY (id);


--
-- Name: contract_mentorships contract_mentorships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_mentorships
    ADD CONSTRAINT contract_mentorships_pkey PRIMARY KEY (id);


--
-- Name: coupons coupons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupons
    ADD CONSTRAINT coupons_pkey PRIMARY KEY (id);


--
-- Name: credit_cards credit_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_cards
    ADD CONSTRAINT credit_cards_pkey PRIMARY KEY (id);


--
-- Name: curriculos curriculos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculos
    ADD CONSTRAINT curriculos_pkey PRIMARY KEY (id);


--
-- Name: friendly_id_slugs friendly_id_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendly_id_slugs
    ADD CONSTRAINT friendly_id_slugs_pkey PRIMARY KEY (id);


--
-- Name: invite_orders invite_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invite_orders
    ADD CONSTRAINT invite_orders_pkey PRIMARY KEY (id);


--
-- Name: invites invites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invites
    ADD CONSTRAINT invites_pkey PRIMARY KEY (id);


--
-- Name: journeys journeys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journeys
    ADD CONSTRAINT journeys_pkey PRIMARY KEY (id);


--
-- Name: legal_pages legal_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legal_pages
    ADD CONSTRAINT legal_pages_pkey PRIMARY KEY (id);


--
-- Name: libraries libraries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.libraries
    ADD CONSTRAINT libraries_pkey PRIMARY KEY (id);


--
-- Name: linkedin_profiles linkedin_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.linkedin_profiles
    ADD CONSTRAINT linkedin_profiles_pkey PRIMARY KEY (id);


--
-- Name: matches matches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: my_projects my_projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.my_projects
    ADD CONSTRAINT my_projects_pkey PRIMARY KEY (id);


--
-- Name: nps_responses nps_responses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nps_responses
    ADD CONSTRAINT nps_responses_pkey PRIMARY KEY (id);


--
-- Name: oauth_accounts oauth_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_accounts
    ADD CONSTRAINT oauth_accounts_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: page_views page_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.page_views
    ADD CONSTRAINT page_views_pkey PRIMARY KEY (id);


--
-- Name: pipedrive_deal_files pipedrive_deal_files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipedrive_deal_files
    ADD CONSTRAINT pipedrive_deal_files_pkey PRIMARY KEY (id);


--
-- Name: pipedrive_deal_heat_snapshots pipedrive_deal_heat_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipedrive_deal_heat_snapshots
    ADD CONSTRAINT pipedrive_deal_heat_snapshots_pkey PRIMARY KEY (id);


--
-- Name: pipedrive_deal_notes pipedrive_deal_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipedrive_deal_notes
    ADD CONSTRAINT pipedrive_deal_notes_pkey PRIMARY KEY (id);


--
-- Name: pipedrive_deal_stage_changes pipedrive_deal_stage_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipedrive_deal_stage_changes
    ADD CONSTRAINT pipedrive_deal_stage_changes_pkey PRIMARY KEY (id);


--
-- Name: pipedrive_deals pipedrive_deals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipedrive_deals
    ADD CONSTRAINT pipedrive_deals_pkey PRIMARY KEY (id);


--
-- Name: pipedrive_owner_contacts pipedrive_owner_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipedrive_owner_contacts
    ADD CONSTRAINT pipedrive_owner_contacts_pkey PRIMARY KEY (id);


--
-- Name: plans plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plans
    ADD CONSTRAINT plans_pkey PRIMARY KEY (id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: project_categories project_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_categories
    ADD CONSTRAINT project_categories_pkey PRIMARY KEY (id);


--
-- Name: project_matches project_matches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_matches
    ADD CONSTRAINT project_matches_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: recording_calls recording_calls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recording_calls
    ADD CONSTRAINT recording_calls_pkey PRIMARY KEY (id);


--
-- Name: recordings recordings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recordings
    ADD CONSTRAINT recordings_pkey PRIMARY KEY (id);


--
-- Name: recruiter_survey_responses recruiter_survey_responses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recruiter_survey_responses
    ADD CONSTRAINT recruiter_survey_responses_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: searches searches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.searches
    ADD CONSTRAINT searches_pkey PRIMARY KEY (id);


--
-- Name: settings settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT settings_pkey PRIMARY KEY (id);


--
-- Name: short_links short_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.short_links
    ADD CONSTRAINT short_links_pkey PRIMARY KEY (id);


--
-- Name: shortlists shortlists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shortlists
    ADD CONSTRAINT shortlists_pkey PRIMARY KEY (id);


--
-- Name: skill_values skill_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.skill_values
    ADD CONSTRAINT skill_values_pkey PRIMARY KEY (id);


--
-- Name: skills skills_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.skills
    ADD CONSTRAINT skills_pkey PRIMARY KEY (id);


--
-- Name: stars stars_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stars
    ADD CONSTRAINT stars_pkey PRIMARY KEY (id);


--
-- Name: startup_ad_match_comments startup_ad_match_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.startup_ad_match_comments
    ADD CONSTRAINT startup_ad_match_comments_pkey PRIMARY KEY (id);


--
-- Name: startup_ad_matches startup_ad_matches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.startup_ad_matches
    ADD CONSTRAINT startup_ad_matches_pkey PRIMARY KEY (id);


--
-- Name: startup_ads startup_ads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.startup_ads
    ADD CONSTRAINT startup_ads_pkey PRIMARY KEY (id);


--
-- Name: startup_companies startup_companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.startup_companies
    ADD CONSTRAINT startup_companies_pkey PRIMARY KEY (id);


--
-- Name: startups startups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.startups
    ADD CONSTRAINT startups_pkey PRIMARY KEY (id);


--
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


--
-- Name: survey_responses survey_responses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_responses
    ADD CONSTRAINT survey_responses_pkey PRIMARY KEY (id);


--
-- Name: surveys surveys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surveys
    ADD CONSTRAINT surveys_pkey PRIMARY KEY (id);


--
-- Name: terms_of_uses terms_of_uses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.terms_of_uses
    ADD CONSTRAINT terms_of_uses_pkey PRIMARY KEY (id);


--
-- Name: ticket_comments ticket_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_comments
    ADD CONSTRAINT ticket_comments_pkey PRIMARY KEY (id);


--
-- Name: tickets tickets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_pkey PRIMARY KEY (id);


--
-- Name: timesheets timesheets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timesheets
    ADD CONSTRAINT timesheets_pkey PRIMARY KEY (id);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- Name: trix_images trix_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trix_images
    ADD CONSTRAINT trix_images_pkey PRIMARY KEY (id);


--
-- Name: versions versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions
    ADD CONSTRAINT versions_pkey PRIMARY KEY (id);


--
-- Name: acts_as_messageable_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX acts_as_messageable_ids ON public.messages USING btree (sent_messageable_id, received_messageable_id);


--
-- Name: acts_as_messageable_received; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX acts_as_messageable_received ON public.messages USING btree (received_messageable_id, received_messageable_type);


--
-- Name: acts_as_messageable_sent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX acts_as_messageable_sent ON public.messages USING btree (sent_messageable_id, sent_messageable_type);


--
-- Name: chiefss_pkey; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX chiefss_pkey ON public.chiefs_start USING btree (id);


--
-- Name: idx_ac_snap_on_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ac_snap_on_contact ON public.active_campaign_contact_monthly_snapshots USING btree (active_campaign_contact_id);


--
-- Name: idx_ac_snap_on_contact_and_month; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_ac_snap_on_contact_and_month ON public.active_campaign_contact_monthly_snapshots USING btree (active_campaign_contact_id, year_month);


--
-- Name: idx_agent_messages_on_conversation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agent_messages_on_conversation ON public.agent_messages USING btree (agent_conversation_id);


--
-- Name: idx_ca_dre_node_categoria_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_ca_dre_node_categoria_unique ON public.ca_dre_category_categorias USING btree (dre_node_uuid, categoria_uuid);


--
-- Name: idx_ca_oauth_singleton; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_ca_oauth_singleton ON public.conta_azul_oauth_tokens USING btree ((true));


--
-- Name: idx_chiefs_provider_uid_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_chiefs_provider_uid_unique ON public.chiefs USING btree (provider, uid) WHERE (uid IS NOT NULL);


--
-- Name: idx_curriculos_one_current_per_chief; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_curriculos_one_current_per_chief ON public.curriculos USING btree (chief_id) WHERE (current = true);


--
-- Name: idx_heat_snap_captured; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_heat_snap_captured ON public.pipedrive_deal_heat_snapshots USING btree (captured_at);


--
-- Name: idx_heat_snap_deal; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_heat_snap_deal ON public.pipedrive_deal_heat_snapshots USING btree (deal_pipedrive_id);


--
-- Name: idx_heat_snap_deal_captured; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_heat_snap_deal_captured ON public.pipedrive_deal_heat_snapshots USING btree (deal_pipedrive_id, captured_at);


--
-- Name: idx_pipedrive_deals_pipeline_stage_heat; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pipedrive_deals_pipeline_stage_heat ON public.pipedrive_deals USING btree (pipeline_id, stage_id, heat_score);


--
-- Name: idx_pipedrive_stage_changes_dedupe; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_pipedrive_stage_changes_dedupe ON public.pipedrive_deal_stage_changes USING btree (pipedrive_deal_id, changed_at, to_stage_id);


--
-- Name: idx_pipedrive_stage_changes_on_deal_and_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pipedrive_stage_changes_on_deal_and_time ON public.pipedrive_deal_stage_changes USING btree (pipedrive_deal_id, changed_at);


--
-- Name: index_ac_contact_messages_on_campaign; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ac_contact_messages_on_campaign ON public.active_campaign_contact_messages USING btree (active_campaign_campaign_id);


--
-- Name: index_ac_contact_messages_on_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ac_contact_messages_on_contact ON public.active_campaign_contact_messages USING btree (active_campaign_contact_id);


--
-- Name: index_ac_contact_messages_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ac_contact_messages_unique ON public.active_campaign_contact_messages USING btree (active_campaign_contact_id, ac_campaign_id, sent_at) WHERE ((sent_at IS NOT NULL) AND (ac_campaign_id IS NOT NULL));


--
-- Name: index_active_campaign_campaigns_on_ac_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_campaign_campaigns_on_ac_id ON public.active_campaign_campaigns USING btree (ac_id);


--
-- Name: index_active_campaign_campaigns_on_sent_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_campaigns_on_sent_at ON public.active_campaign_campaigns USING btree (sent_at);


--
-- Name: index_active_campaign_contact_messages_on_ac_campaign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_contact_messages_on_ac_campaign_id ON public.active_campaign_contact_messages USING btree (ac_campaign_id);


--
-- Name: index_active_campaign_contact_messages_on_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_contact_messages_on_chief_id ON public.active_campaign_contact_messages USING btree (chief_id);


--
-- Name: index_active_campaign_contact_messages_on_sent_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_contact_messages_on_sent_at ON public.active_campaign_contact_messages USING btree (sent_at);


--
-- Name: index_active_campaign_contact_monthly_snapshots_on_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_contact_monthly_snapshots_on_chief_id ON public.active_campaign_contact_monthly_snapshots USING btree (chief_id);


--
-- Name: index_active_campaign_contact_monthly_snapshots_on_year_month; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_contact_monthly_snapshots_on_year_month ON public.active_campaign_contact_monthly_snapshots USING btree (year_month);


--
-- Name: index_active_campaign_contacts_on_ac_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_campaign_contacts_on_ac_id ON public.active_campaign_contacts USING btree (ac_id);


--
-- Name: index_active_campaign_contacts_on_ac_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_contacts_on_ac_updated_at ON public.active_campaign_contacts USING btree (ac_updated_at);


--
-- Name: index_active_campaign_contacts_on_aggregates_refreshed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_contacts_on_aggregates_refreshed_at ON public.active_campaign_contacts USING btree (aggregates_refreshed_at);


--
-- Name: index_active_campaign_contacts_on_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_contacts_on_chief_id ON public.active_campaign_contacts USING btree (chief_id);


--
-- Name: index_active_campaign_contacts_on_derived_score; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_contacts_on_derived_score ON public.active_campaign_contacts USING btree (derived_score);


--
-- Name: index_active_campaign_contacts_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_contacts_on_email ON public.active_campaign_contacts USING btree (email);


--
-- Name: index_active_campaign_contacts_on_last_activity_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_contacts_on_last_activity_at ON public.active_campaign_contacts USING btree (last_activity_at);


--
-- Name: index_active_campaign_contacts_on_last_click_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_contacts_on_last_click_at ON public.active_campaign_contacts USING btree (last_click_at);


--
-- Name: index_active_campaign_contacts_on_last_open_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_contacts_on_last_open_at ON public.active_campaign_contacts USING btree (last_open_at);


--
-- Name: index_active_campaign_contacts_on_startup_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_contacts_on_startup_id ON public.active_campaign_contacts USING btree (startup_id);


--
-- Name: index_active_campaign_contacts_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_contacts_on_status ON public.active_campaign_contacts USING btree (status);


--
-- Name: index_active_campaign_tags_on_ac_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_campaign_tags_on_ac_id ON public.active_campaign_tags USING btree (ac_id);


--
-- Name: index_active_campaign_tags_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_tags_on_name ON public.active_campaign_tags USING btree (name);


--
-- Name: index_active_campaign_webhook_events_on_ac_contact_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_webhook_events_on_ac_contact_id ON public.active_campaign_webhook_events USING btree (ac_contact_id);


--
-- Name: index_active_campaign_webhook_events_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_webhook_events_on_created_at ON public.active_campaign_webhook_events USING btree (created_at);


--
-- Name: index_active_campaign_webhook_events_on_event_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_webhook_events_on_event_type ON public.active_campaign_webhook_events USING btree (event_type);


--
-- Name: index_active_campaign_webhook_events_on_processed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_campaign_webhook_events_on_processed_at ON public.active_campaign_webhook_events USING btree (processed_at);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_agent_conversations_on_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_conversations_on_chief_id ON public.agent_conversations USING btree (chief_id);


--
-- Name: index_agent_conversations_on_openai_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agent_conversations_on_openai_conversation_id ON public.agent_conversations USING btree (openai_conversation_id);


--
-- Name: index_agent_messages_on_agent_conversation_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_messages_on_agent_conversation_id_and_position ON public.agent_messages USING btree (agent_conversation_id, "position");


--
-- Name: index_agent_messages_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_messages_on_created_at ON public.agent_messages USING btree (created_at);


--
-- Name: index_analytics_chief_view_rankings_on_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analytics_chief_view_rankings_on_chief_id ON public.analytics_chief_view_rankings USING btree (chief_id);


--
-- Name: index_analytics_chief_view_rankings_on_ranking_type_and_rank; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analytics_chief_view_rankings_on_ranking_type_and_rank ON public.analytics_chief_view_rankings USING btree (ranking_type, rank);


--
-- Name: index_analytics_page_view_summaries_on_period; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_analytics_page_view_summaries_on_period ON public.analytics_page_view_summaries USING btree (period);


--
-- Name: index_api_tokens_on_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_tokens_on_company_id ON public.api_tokens USING btree (company_id);


--
-- Name: index_api_tokens_on_revoked_at_and_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_tokens_on_revoked_at_and_expires_at ON public.api_tokens USING btree (revoked_at, expires_at);


--
-- Name: index_api_tokens_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_api_tokens_on_slug ON public.api_tokens USING btree (slug);


--
-- Name: index_api_tokens_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_api_tokens_on_token_digest ON public.api_tokens USING btree (token_digest);


--
-- Name: index_ca_acquittances_on_conta_azul_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ca_acquittances_on_conta_azul_id ON public.ca_acquittances USING btree (conta_azul_id);


--
-- Name: index_ca_acquittances_on_parcela_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_acquittances_on_parcela_uuid ON public.ca_acquittances USING btree (parcela_uuid);


--
-- Name: index_ca_categories_on_categoria_pai; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_categories_on_categoria_pai ON public.ca_categories USING btree (categoria_pai);


--
-- Name: index_ca_categories_on_conta_azul_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ca_categories_on_conta_azul_id ON public.ca_categories USING btree (conta_azul_id);


--
-- Name: index_ca_categories_on_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_categories_on_tipo ON public.ca_categories USING btree (tipo);


--
-- Name: index_ca_contracts_on_cliente_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_contracts_on_cliente_uuid ON public.ca_contracts USING btree (cliente_uuid);


--
-- Name: index_ca_contracts_on_conta_azul_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ca_contracts_on_conta_azul_id ON public.ca_contracts USING btree (conta_azul_id);


--
-- Name: index_ca_contracts_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_contracts_on_status ON public.ca_contracts USING btree (status);


--
-- Name: index_ca_cost_centers_on_conta_azul_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ca_cost_centers_on_conta_azul_id ON public.ca_cost_centers USING btree (conta_azul_id);


--
-- Name: index_ca_dre_categories_on_codigo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_dre_categories_on_codigo ON public.ca_dre_categories USING btree (codigo);


--
-- Name: index_ca_dre_categories_on_conta_azul_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ca_dre_categories_on_conta_azul_id ON public.ca_dre_categories USING btree (conta_azul_id);


--
-- Name: index_ca_dre_categories_on_parent_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_dre_categories_on_parent_uuid ON public.ca_dre_categories USING btree (parent_uuid);


--
-- Name: index_ca_dre_category_categorias_on_categoria_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_dre_category_categorias_on_categoria_uuid ON public.ca_dre_category_categorias USING btree (categoria_uuid);


--
-- Name: index_ca_event_apportionments_on_target_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_event_apportionments_on_target_uuid ON public.ca_event_apportionments USING btree (target_uuid);


--
-- Name: index_ca_event_apportionments_on_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_event_apportionments_on_tipo ON public.ca_event_apportionments USING btree (tipo);


--
-- Name: index_ca_event_apportionments_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ca_event_apportionments_unique ON public.ca_event_apportionments USING btree (evento_uuid, tipo, target_uuid);


--
-- Name: index_ca_financial_accounts_on_conta_azul_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ca_financial_accounts_on_conta_azul_id ON public.ca_financial_accounts USING btree (conta_azul_id);


--
-- Name: index_ca_financial_events_on_conta_azul_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ca_financial_events_on_conta_azul_id ON public.ca_financial_events USING btree (conta_azul_id);


--
-- Name: index_ca_financial_events_on_data_vencimento; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_financial_events_on_data_vencimento ON public.ca_financial_events USING btree (data_vencimento);


--
-- Name: index_ca_financial_events_on_pessoa_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_financial_events_on_pessoa_uuid ON public.ca_financial_events USING btree (pessoa_uuid);


--
-- Name: index_ca_financial_events_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_financial_events_on_status ON public.ca_financial_events USING btree (status);


--
-- Name: index_ca_financial_events_on_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_financial_events_on_tipo ON public.ca_financial_events USING btree (tipo);


--
-- Name: index_ca_financial_installments_on_conta_azul_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ca_financial_installments_on_conta_azul_id ON public.ca_financial_installments USING btree (conta_azul_id);


--
-- Name: index_ca_financial_installments_on_evento_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_financial_installments_on_evento_uuid ON public.ca_financial_installments USING btree (evento_uuid);


--
-- Name: index_ca_financial_installments_on_origem; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_financial_installments_on_origem ON public.ca_financial_installments USING btree (origem);


--
-- Name: index_ca_financial_installments_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_financial_installments_on_status ON public.ca_financial_installments USING btree (status);


--
-- Name: index_ca_financial_installments_on_venda_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_financial_installments_on_venda_uuid ON public.ca_financial_installments USING btree (venda_uuid);


--
-- Name: index_ca_people_on_ativo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_people_on_ativo ON public.ca_people USING btree (ativo);


--
-- Name: index_ca_people_on_conta_azul_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ca_people_on_conta_azul_id ON public.ca_people USING btree (conta_azul_id);


--
-- Name: index_ca_people_on_perfis; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_people_on_perfis ON public.ca_people USING gin (perfis);


--
-- Name: index_ca_sale_items_on_centro_custo_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_sale_items_on_centro_custo_uuid ON public.ca_sale_items USING btree (centro_custo_uuid);


--
-- Name: index_ca_sale_items_on_conta_azul_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ca_sale_items_on_conta_azul_id ON public.ca_sale_items USING btree (conta_azul_id);


--
-- Name: index_ca_sale_items_on_id_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_sale_items_on_id_item ON public.ca_sale_items USING btree (id_item);


--
-- Name: index_ca_sale_items_on_venda_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_sale_items_on_venda_uuid ON public.ca_sale_items USING btree (venda_uuid);


--
-- Name: index_ca_sales_on_cliente_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_sales_on_cliente_uuid ON public.ca_sales USING btree (cliente_uuid);


--
-- Name: index_ca_sales_on_conta_azul_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ca_sales_on_conta_azul_id ON public.ca_sales USING btree (conta_azul_id);


--
-- Name: index_ca_sales_on_contrato_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_sales_on_contrato_uuid ON public.ca_sales USING btree (contrato_uuid);


--
-- Name: index_ca_sales_on_data; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_sales_on_data ON public.ca_sales USING btree (data);


--
-- Name: index_ca_sales_on_evento_financeiro_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_sales_on_evento_financeiro_uuid ON public.ca_sales USING btree (evento_financeiro_uuid);


--
-- Name: index_ca_sales_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_sales_on_status ON public.ca_sales USING btree (status);


--
-- Name: index_ca_sellers_on_conta_azul_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ca_sellers_on_conta_azul_id ON public.ca_sellers USING btree (conta_azul_id);


--
-- Name: index_ca_sellers_on_nome; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_sellers_on_nome ON public.ca_sellers USING btree (nome);


--
-- Name: index_ca_service_invoices_on_cliente_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_service_invoices_on_cliente_uuid ON public.ca_service_invoices USING btree (cliente_uuid);


--
-- Name: index_ca_service_invoices_on_conta_azul_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ca_service_invoices_on_conta_azul_id ON public.ca_service_invoices USING btree (conta_azul_id);


--
-- Name: index_ca_service_invoices_on_contrato_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_service_invoices_on_contrato_uuid ON public.ca_service_invoices USING btree (contrato_uuid);


--
-- Name: index_ca_service_invoices_on_data_competencia; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_service_invoices_on_data_competencia ON public.ca_service_invoices USING btree (data_competencia);


--
-- Name: index_ca_service_invoices_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_service_invoices_on_status ON public.ca_service_invoices USING btree (status);


--
-- Name: index_ca_service_invoices_on_venda_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ca_service_invoices_on_venda_uuid ON public.ca_service_invoices USING btree (venda_uuid);


--
-- Name: index_chief_comments_on_author_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chief_comments_on_author_id ON public.chief_comments USING btree (author_id);


--
-- Name: index_chief_comments_on_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chief_comments_on_chief_id ON public.chief_comments USING btree (chief_id);


--
-- Name: index_chiefs_csv_exports_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chiefs_csv_exports_on_created_at ON public.chiefs_csv_exports USING btree (created_at);


--
-- Name: index_chiefs_csv_exports_on_generated_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chiefs_csv_exports_on_generated_by_id ON public.chiefs_csv_exports USING btree (generated_by_id);


--
-- Name: index_chiefs_csv_exports_on_trigger; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chiefs_csv_exports_on_trigger ON public.chiefs_csv_exports USING btree (trigger);


--
-- Name: index_chiefs_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chiefs_on_email ON public.chiefs USING btree (email);


--
-- Name: index_chiefs_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chiefs_on_reset_password_token ON public.chiefs USING btree (reset_password_token);


--
-- Name: index_chiefs_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chiefs_on_slug ON public.chiefs USING btree (slug);


--
-- Name: index_chiefs_posts_on_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chiefs_posts_on_chief_id ON public.chiefs_posts USING btree (chief_id);


--
-- Name: index_chiefs_posts_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chiefs_posts_on_post_id ON public.chiefs_posts USING btree (post_id);


--
-- Name: index_chiefs_projects_on_chief_id_and_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chiefs_projects_on_chief_id_and_project_id ON public.chiefs_projects USING btree (chief_id, project_id);


--
-- Name: index_chiefs_shortlists_on_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chiefs_shortlists_on_chief_id ON public.chiefs_shortlists USING btree (chief_id);


--
-- Name: index_chiefs_shortlists_on_shortlist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chiefs_shortlists_on_shortlist_id ON public.chiefs_shortlists USING btree (shortlist_id);


--
-- Name: index_chiefs_startup_ads_on_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chiefs_startup_ads_on_chief_id ON public.chiefs_startup_ads USING btree (chief_id);


--
-- Name: index_chiefs_startup_ads_on_startup_ad_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chiefs_startup_ads_on_startup_ad_id ON public.chiefs_startup_ads USING btree (startup_ad_id);


--
-- Name: index_chiefs_startup_ads_on_startup_ad_id_chief_id_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chiefs_startup_ads_on_startup_ad_id_chief_id_unique ON public.chiefs_startup_ads USING btree (startup_ad_id, chief_id);


--
-- Name: index_chiefss_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chiefss_on_email ON public.chiefs_start USING btree (email);


--
-- Name: index_chiefss_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chiefss_on_reset_password_token ON public.chiefs_start USING btree (reset_password_token);


--
-- Name: index_chiefss_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chiefss_on_slug ON public.chiefs_start USING btree (slug);


--
-- Name: index_companies_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_companies_on_slug ON public.companies USING btree (slug);


--
-- Name: index_curriculos_on_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_curriculos_on_chief_id ON public.curriculos USING btree (chief_id);


--
-- Name: index_curriculos_on_uploaded_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_curriculos_on_uploaded_by_id ON public.curriculos USING btree (uploaded_by_id);


--
-- Name: index_friendly_id_slugs_on_slug_and_sluggable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_friendly_id_slugs_on_slug_and_sluggable_type ON public.friendly_id_slugs USING btree (slug, sluggable_type);


--
-- Name: index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope ON public.friendly_id_slugs USING btree (slug, sluggable_type, scope);


--
-- Name: index_friendly_id_slugs_on_sluggable_type_and_sluggable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_friendly_id_slugs_on_sluggable_type_and_sluggable_id ON public.friendly_id_slugs USING btree (sluggable_type, sluggable_id);


--
-- Name: index_legal_pages_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_legal_pages_on_slug ON public.legal_pages USING btree (slug);


--
-- Name: index_messages_on_ancestry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_ancestry ON public.messages USING btree (ancestry);


--
-- Name: index_nps_responses_on_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_nps_responses_on_chief_id ON public.nps_responses USING btree (chief_id);


--
-- Name: index_nps_responses_on_chief_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_nps_responses_on_chief_id_and_created_at ON public.nps_responses USING btree (chief_id, created_at);


--
-- Name: index_oauth_accounts_on_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oauth_accounts_on_chief_id ON public.oauth_accounts USING btree (chief_id);


--
-- Name: index_pipedrive_deal_files_on_deal_pipedrive_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pipedrive_deal_files_on_deal_pipedrive_id ON public.pipedrive_deal_files USING btree (deal_pipedrive_id);


--
-- Name: index_pipedrive_deal_files_on_file_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_pipedrive_deal_files_on_file_id ON public.pipedrive_deal_files USING btree (file_id);


--
-- Name: index_pipedrive_deal_notes_on_deal_pipedrive_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pipedrive_deal_notes_on_deal_pipedrive_id ON public.pipedrive_deal_notes USING btree (deal_pipedrive_id);


--
-- Name: index_pipedrive_deal_notes_on_deal_pipedrive_id_and_added_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pipedrive_deal_notes_on_deal_pipedrive_id_and_added_at ON public.pipedrive_deal_notes USING btree (deal_pipedrive_id, added_at);


--
-- Name: index_pipedrive_deal_notes_on_note_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_pipedrive_deal_notes_on_note_id ON public.pipedrive_deal_notes USING btree (note_id);


--
-- Name: index_pipedrive_deal_stage_changes_on_to_stage_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pipedrive_deal_stage_changes_on_to_stage_id ON public.pipedrive_deal_stage_changes USING btree (to_stage_id);


--
-- Name: index_pipedrive_deals_on_close_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pipedrive_deals_on_close_time ON public.pipedrive_deals USING btree (close_time);


--
-- Name: index_pipedrive_deals_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pipedrive_deals_on_deleted_at ON public.pipedrive_deals USING btree (deleted_at);


--
-- Name: index_pipedrive_deals_on_heat_score_desc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pipedrive_deals_on_heat_score_desc ON public.pipedrive_deals USING btree (heat_score DESC);


--
-- Name: index_pipedrive_deals_on_next_activity_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pipedrive_deals_on_next_activity_date ON public.pipedrive_deals USING btree (next_activity_date);


--
-- Name: index_pipedrive_deals_on_org_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pipedrive_deals_on_org_id ON public.pipedrive_deals USING btree (org_id);


--
-- Name: index_pipedrive_deals_on_owner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pipedrive_deals_on_owner_id ON public.pipedrive_deals USING btree (owner_id);


--
-- Name: index_pipedrive_deals_on_owner_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pipedrive_deals_on_owner_name ON public.pipedrive_deals USING btree (owner_name);


--
-- Name: index_pipedrive_deals_on_pipedrive_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_pipedrive_deals_on_pipedrive_id ON public.pipedrive_deals USING btree (pipedrive_id);


--
-- Name: index_pipedrive_deals_on_pipeline_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pipedrive_deals_on_pipeline_id ON public.pipedrive_deals USING btree (pipeline_id);


--
-- Name: index_pipedrive_deals_on_pipeline_id_and_stage_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pipedrive_deals_on_pipeline_id_and_stage_id ON public.pipedrive_deals USING btree (pipeline_id, stage_id);


--
-- Name: index_pipedrive_deals_on_probability; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pipedrive_deals_on_probability ON public.pipedrive_deals USING btree (probability);


--
-- Name: index_pipedrive_deals_on_stage_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pipedrive_deals_on_stage_id ON public.pipedrive_deals USING btree (stage_id);


--
-- Name: index_pipedrive_deals_on_stage_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pipedrive_deals_on_stage_name ON public.pipedrive_deals USING btree (stage_name);


--
-- Name: index_pipedrive_deals_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pipedrive_deals_on_status ON public.pipedrive_deals USING btree (status);


--
-- Name: index_pipedrive_deals_on_status_and_updated_at_remote; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pipedrive_deals_on_status_and_updated_at_remote ON public.pipedrive_deals USING btree (status, updated_at_remote);


--
-- Name: index_pipedrive_deals_on_updated_at_remote; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pipedrive_deals_on_updated_at_remote ON public.pipedrive_deals USING btree (updated_at_remote);


--
-- Name: index_pipedrive_owner_contacts_on_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pipedrive_owner_contacts_on_active ON public.pipedrive_owner_contacts USING btree (active);


--
-- Name: index_pipedrive_owner_contacts_on_owner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_pipedrive_owner_contacts_on_owner_id ON public.pipedrive_owner_contacts USING btree (owner_id);


--
-- Name: index_plans_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_plans_on_slug ON public.plans USING btree (slug);


--
-- Name: index_posts_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_posts_on_slug ON public.posts USING btree (slug);


--
-- Name: index_projects_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_slug ON public.projects USING btree (slug);


--
-- Name: index_recordings_on_startup_ad_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recordings_on_startup_ad_id ON public.recordings USING btree (startup_ad_id);


--
-- Name: index_recordings_on_startup_ad_match_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recordings_on_startup_ad_match_id ON public.recordings USING btree (startup_ad_match_id);


--
-- Name: index_recruiter_survey_responses_on_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recruiter_survey_responses_on_chief_id ON public.recruiter_survey_responses USING btree (chief_id);


--
-- Name: index_recruiter_survey_responses_on_startup_ad_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recruiter_survey_responses_on_startup_ad_id ON public.recruiter_survey_responses USING btree (startup_ad_id);


--
-- Name: index_recruiter_survey_responses_on_startup_ad_id_and_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_recruiter_survey_responses_on_startup_ad_id_and_chief_id ON public.recruiter_survey_responses USING btree (startup_ad_id, chief_id);


--
-- Name: index_short_links_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_short_links_on_expires_at ON public.short_links USING btree (expires_at);


--
-- Name: index_short_links_on_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_short_links_on_token ON public.short_links USING btree (token);


--
-- Name: index_shortlists_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_shortlists_on_slug ON public.shortlists USING btree (slug);


--
-- Name: index_startup_ad_match_comments_on_author_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_startup_ad_match_comments_on_author_id ON public.startup_ad_match_comments USING btree (author_id);


--
-- Name: index_startup_ad_match_comments_on_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_startup_ad_match_comments_on_chief_id ON public.startup_ad_match_comments USING btree (chief_id);


--
-- Name: index_startup_ad_match_comments_on_startup_ad_match_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_startup_ad_match_comments_on_startup_ad_match_id ON public.startup_ad_match_comments USING btree (startup_ad_match_id);


--
-- Name: index_startup_ads_on_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_startup_ads_on_external_id ON public.startup_ads USING btree (external_id) WHERE (external_id IS NOT NULL);


--
-- Name: index_startup_companies_on_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_startup_companies_on_company_id ON public.startup_companies USING btree (company_id);


--
-- Name: index_startup_companies_on_startup_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_startup_companies_on_startup_id ON public.startup_companies USING btree (startup_id);


--
-- Name: index_startup_companies_on_startup_id_and_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_startup_companies_on_startup_id_and_company_id ON public.startup_companies USING btree (startup_id, company_id);


--
-- Name: index_startups_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_startups_on_email ON public.startups USING btree (email);


--
-- Name: index_startups_on_invitation_accepted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_startups_on_invitation_accepted_at ON public.startups USING btree (invitation_accepted_at);


--
-- Name: index_startups_on_invitation_revoked_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_startups_on_invitation_revoked_by_id ON public.startups USING btree (invitation_revoked_by_id);


--
-- Name: index_startups_on_invitation_sent_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_startups_on_invitation_sent_by_id ON public.startups USING btree (invitation_sent_by_id);


--
-- Name: index_startups_on_invitation_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_startups_on_invitation_token ON public.startups USING btree (invitation_token);


--
-- Name: index_startups_on_invited_by_type_and_invited_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_startups_on_invited_by_type_and_invited_by_id ON public.startups USING btree (invited_by_type, invited_by_id);


--
-- Name: index_startups_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_startups_on_reset_password_token ON public.startups USING btree (reset_password_token);


--
-- Name: index_startups_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_startups_on_slug ON public.startups USING btree (slug);


--
-- Name: index_survey_responses_on_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_survey_responses_on_chief_id ON public.survey_responses USING btree (chief_id);


--
-- Name: index_survey_responses_on_survey_and_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_survey_responses_on_survey_and_email ON public.survey_responses USING btree (survey_id, respondent_email);


--
-- Name: index_survey_responses_on_survey_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_survey_responses_on_survey_id ON public.survey_responses USING btree (survey_id);


--
-- Name: index_survey_responses_on_survey_id_and_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_survey_responses_on_survey_id_and_chief_id ON public.survey_responses USING btree (survey_id, chief_id) WHERE (chief_id IS NOT NULL);


--
-- Name: index_surveys_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_surveys_on_created_by_id ON public.surveys USING btree (created_by_id);


--
-- Name: index_surveys_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_surveys_on_slug ON public.surveys USING btree (slug);


--
-- Name: index_surveys_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_surveys_on_status ON public.surveys USING btree (status);


--
-- Name: index_ticket_comments_on_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ticket_comments_on_chief_id ON public.ticket_comments USING btree (chief_id);


--
-- Name: index_ticket_comments_on_ticket_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ticket_comments_on_ticket_id ON public.ticket_comments USING btree (ticket_id);


--
-- Name: index_tickets_on_assigned_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tickets_on_assigned_chief_id ON public.tickets USING btree (assigned_chief_id);


--
-- Name: index_tickets_on_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tickets_on_number ON public.tickets USING btree (number);


--
-- Name: index_tickets_on_owner_type_and_owner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tickets_on_owner_type_and_owner_id ON public.tickets USING btree (owner_type, owner_id);


--
-- Name: index_versions_on_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_versions_on_company_id ON public.versions USING btree (company_id) WHERE (company_id IS NOT NULL);


--
-- Name: index_versions_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_versions_on_created_at ON public.versions USING btree (created_at DESC);


--
-- Name: index_versions_on_item_type_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_versions_on_item_type_and_created_at ON public.versions USING btree (item_type, created_at DESC);


--
-- Name: index_versions_on_item_type_and_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_versions_on_item_type_and_item_id ON public.versions USING btree (item_type, item_id);


--
-- Name: index_versions_on_startup_ad_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_versions_on_startup_ad_id ON public.versions USING btree (startup_ad_id) WHERE (startup_ad_id IS NOT NULL);


--
-- Name: invites_e_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX invites_e_index ON public.invites USING btree (inviteeable_id, inviteeable_type);


--
-- Name: invites_r_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX invites_r_index ON public.invites USING btree (inviterable_id, inviterable_type);


--
-- Name: page_views_chief_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX page_views_chief_id_index ON public.page_views USING btree (chief_id);


--
-- Name: page_views_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX page_views_created_at_index ON public.page_views USING btree (created_at);


--
-- Name: transactions_tran_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX transactions_tran_index ON public.transactions USING btree (transactionable_id, transactionable_type);


--
-- Name: startup_ads fk_rails_02795943c7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.startup_ads
    ADD CONSTRAINT fk_rails_02795943c7 FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: ticket_comments fk_rails_02c3c635e5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_comments
    ADD CONSTRAINT fk_rails_02c3c635e5 FOREIGN KEY (chief_id) REFERENCES public.chiefs(id);


--
-- Name: startup_ad_match_comments fk_rails_06ef4f95cf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.startup_ad_match_comments
    ADD CONSTRAINT fk_rails_06ef4f95cf FOREIGN KEY (chief_id) REFERENCES public.chiefs(id);


--
-- Name: active_campaign_contact_messages fk_rails_0b7940c17d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_campaign_contact_messages
    ADD CONSTRAINT fk_rails_0b7940c17d FOREIGN KEY (chief_id) REFERENCES public.chiefs(id);


--
-- Name: startup_companies fk_rails_0bdb0e97f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.startup_companies
    ADD CONSTRAINT fk_rails_0bdb0e97f0 FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: active_campaign_contact_messages fk_rails_0dd43d477f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_campaign_contact_messages
    ADD CONSTRAINT fk_rails_0dd43d477f FOREIGN KEY (active_campaign_contact_id) REFERENCES public.active_campaign_contacts(id);


--
-- Name: curriculos fk_rails_1b54ac4a14; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculos
    ADD CONSTRAINT fk_rails_1b54ac4a14 FOREIGN KEY (chief_id) REFERENCES public.chiefs(id);


--
-- Name: active_campaign_contact_monthly_snapshots fk_rails_333d294601; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_campaign_contact_monthly_snapshots
    ADD CONSTRAINT fk_rails_333d294601 FOREIGN KEY (chief_id) REFERENCES public.chiefs(id);


--
-- Name: startups fk_rails_3a00d18810; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.startups
    ADD CONSTRAINT fk_rails_3a00d18810 FOREIGN KEY (invitation_revoked_by_id) REFERENCES public.chiefs(id) ON DELETE SET NULL;


--
-- Name: startup_ad_match_comments fk_rails_3e2fc8a928; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.startup_ad_match_comments
    ADD CONSTRAINT fk_rails_3e2fc8a928 FOREIGN KEY (author_id) REFERENCES public.chiefs(id);


--
-- Name: recruiter_survey_responses fk_rails_45542ca761; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recruiter_survey_responses
    ADD CONSTRAINT fk_rails_45542ca761 FOREIGN KEY (chief_id) REFERENCES public.chiefs(id);


--
-- Name: chiefs_startup_ads fk_rails_4864c83a11; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chiefs_startup_ads
    ADD CONSTRAINT fk_rails_4864c83a11 FOREIGN KEY (startup_ad_id) REFERENCES public.startup_ads(id);


--
-- Name: chief_comments fk_rails_4d7daf58d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_comments
    ADD CONSTRAINT fk_rails_4d7daf58d2 FOREIGN KEY (author_id) REFERENCES public.chiefs(id);


--
-- Name: active_campaign_contact_monthly_snapshots fk_rails_50a565933d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_campaign_contact_monthly_snapshots
    ADD CONSTRAINT fk_rails_50a565933d FOREIGN KEY (active_campaign_contact_id) REFERENCES public.active_campaign_contacts(id);


--
-- Name: startups fk_rails_50c8493e90; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.startups
    ADD CONSTRAINT fk_rails_50c8493e90 FOREIGN KEY (invitation_sent_by_id) REFERENCES public.chiefs(id) ON DELETE SET NULL;


--
-- Name: analytics_chief_view_rankings fk_rails_5628627fd4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_chief_view_rankings
    ADD CONSTRAINT fk_rails_5628627fd4 FOREIGN KEY (chief_id) REFERENCES public.chiefs(id);


--
-- Name: nps_responses fk_rails_5b4f4902cd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nps_responses
    ADD CONSTRAINT fk_rails_5b4f4902cd FOREIGN KEY (chief_id) REFERENCES public.chiefs(id);


--
-- Name: tickets fk_rails_6046005ea3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT fk_rails_6046005ea3 FOREIGN KEY (assigned_chief_id) REFERENCES public.chiefs(id);


--
-- Name: recruiter_survey_responses fk_rails_711efb99de; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recruiter_survey_responses
    ADD CONSTRAINT fk_rails_711efb99de FOREIGN KEY (startup_ad_id) REFERENCES public.startup_ads(id);


--
-- Name: agent_messages fk_rails_71374ce01d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_messages
    ADD CONSTRAINT fk_rails_71374ce01d FOREIGN KEY (agent_conversation_id) REFERENCES public.agent_conversations(id);


--
-- Name: startup_ad_match_comments fk_rails_75a8303af0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.startup_ad_match_comments
    ADD CONSTRAINT fk_rails_75a8303af0 FOREIGN KEY (startup_ad_match_id) REFERENCES public.startup_ad_matches(id);


--
-- Name: chief_comments fk_rails_789d56d0e7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_comments
    ADD CONSTRAINT fk_rails_789d56d0e7 FOREIGN KEY (chief_id) REFERENCES public.chiefs(id);


--
-- Name: startup_companies fk_rails_8f07e70cbb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.startup_companies
    ADD CONSTRAINT fk_rails_8f07e70cbb FOREIGN KEY (startup_id) REFERENCES public.startups(id);


--
-- Name: oauth_accounts fk_rails_9560f4a98d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_accounts
    ADD CONSTRAINT fk_rails_9560f4a98d FOREIGN KEY (chief_id) REFERENCES public.chiefs(id);


--
-- Name: curriculos fk_rails_97d3d8a9ff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculos
    ADD CONSTRAINT fk_rails_97d3d8a9ff FOREIGN KEY (uploaded_by_id) REFERENCES public.chiefs(id);


--
-- Name: active_campaign_contact_messages fk_rails_98f6bcfb0d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_campaign_contact_messages
    ADD CONSTRAINT fk_rails_98f6bcfb0d FOREIGN KEY (active_campaign_campaign_id) REFERENCES public.active_campaign_campaigns(id);


--
-- Name: surveys fk_rails_9a615d35d0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surveys
    ADD CONSTRAINT fk_rails_9a615d35d0 FOREIGN KEY (created_by_id) REFERENCES public.chiefs(id);


--
-- Name: ticket_comments fk_rails_b96043ab8e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_comments
    ADD CONSTRAINT fk_rails_b96043ab8e FOREIGN KEY (ticket_id) REFERENCES public.tickets(id);


--
-- Name: active_campaign_contacts fk_rails_bafa136a8b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_campaign_contacts
    ADD CONSTRAINT fk_rails_bafa136a8b FOREIGN KEY (chief_id) REFERENCES public.chiefs(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: agent_conversations fk_rails_c96108501f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_conversations
    ADD CONSTRAINT fk_rails_c96108501f FOREIGN KEY (chief_id) REFERENCES public.chiefs(id);


--
-- Name: chiefs_startup_ads fk_rails_d2d5dc7964; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chiefs_startup_ads
    ADD CONSTRAINT fk_rails_d2d5dc7964 FOREIGN KEY (chief_id) REFERENCES public.chiefs(id);


--
-- Name: active_campaign_contacts fk_rails_d442541466; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_campaign_contacts
    ADD CONSTRAINT fk_rails_d442541466 FOREIGN KEY (startup_id) REFERENCES public.startups(id);


--
-- Name: survey_responses fk_rails_d838a83d59; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_responses
    ADD CONSTRAINT fk_rails_d838a83d59 FOREIGN KEY (chief_id) REFERENCES public.chiefs(id);


--
-- Name: recordings fk_rails_e01ccd7b2a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recordings
    ADD CONSTRAINT fk_rails_e01ccd7b2a FOREIGN KEY (startup_ad_id) REFERENCES public.startup_ads(id);


--
-- Name: survey_responses fk_rails_ec71731d4b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_responses
    ADD CONSTRAINT fk_rails_ec71731d4b FOREIGN KEY (survey_id) REFERENCES public.surveys(id);


--
-- Name: pipedrive_deal_stage_changes fk_rails_f42a70759d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipedrive_deal_stage_changes
    ADD CONSTRAINT fk_rails_f42a70759d FOREIGN KEY (pipedrive_deal_id) REFERENCES public.pipedrive_deals(id);


--
-- Name: 00_validate_before_start; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER "00_validate_before_start" ON ddl_command_start
   EXECUTE FUNCTION _heroku.extension_before_run();


--
-- Name: 00_validate_extension_after; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER "00_validate_extension_after" ON ddl_command_end
   EXECUTE FUNCTION _heroku.validate_extension();


--
-- Name: 01_configure_extension_after; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER "01_configure_extension_after" ON ddl_command_end
   EXECUTE FUNCTION _heroku.create_ext();


--
-- Name: 01_configure_extension_drop; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER "01_configure_extension_drop" ON sql_drop
   EXECUTE FUNCTION _heroku.drop_ext();


--
-- Name: 01_extension_before_drop; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER "01_extension_before_drop" ON ddl_command_start
   EXECUTE FUNCTION _heroku.extension_before_drop();


--
-- PostgreSQL database dump complete
--

