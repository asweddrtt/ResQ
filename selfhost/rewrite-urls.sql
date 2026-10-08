-- Replace the old Supabase host inside any text/json column of the public schema,
-- for rows that stored full URLs (e.g. image links) instead of bucket + path.
--
-- Usage (on the VPS):
--   docker exec -i supabase-db psql -U supabase_admin -d postgres \
--     -v old='https://dgwrsfjpxuvgqrbhhjro.supabase.co' -v new='https://api.example.com' \
--     < rewrite-urls.sql

SELECT set_config('resq.old_host', :'old', false), set_config('resq.new_host', :'new', false);

DO $$
DECLARE
  col record;
  old_host text := current_setting('resq.old_host');
  new_host text := current_setting('resq.new_host');
  n bigint;
BEGIN
  FOR col IN
    SELECT c.table_name, c.column_name, c.data_type
    FROM information_schema.columns c
    JOIN information_schema.tables t
      ON t.table_schema = c.table_schema AND t.table_name = c.table_name
    WHERE c.table_schema = 'public'
      AND t.table_type = 'BASE TABLE'
      AND c.data_type IN ('text', 'character varying', 'json', 'jsonb')
  LOOP
    EXECUTE format(
      'UPDATE public.%I SET %I = replace(%I::text, $1, $2)::%s WHERE %I::text LIKE ''%%'' || $1 || ''%%''',
      col.table_name, col.column_name, col.column_name,
      CASE col.data_type WHEN 'character varying' THEN 'varchar' ELSE col.data_type END,
      col.column_name)
    USING old_host, new_host;
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n > 0 THEN
      RAISE NOTICE 'public.%.%: % row(s) updated', col.table_name, col.column_name, n;
    END IF;
  END LOOP;
END $$;
