-- Papel exclusivo do backend. A senha é provisionada fora do Git e das migrations.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'controllab_app') THEN
    CREATE ROLE controllab_app NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS CONNECTION LIMIT 10;
  END IF;
END $$;
GRANT controllab_app TO postgres;
GRANT CONNECT ON DATABASE postgres TO controllab_app;
GRANT USAGE ON SCHEMA public TO controllab_app;
DO $$
DECLARE tabela text; sequencia text;
BEGIN
  FOREACH tabela IN ARRAY ARRAY['users','auth_sessions','student_badges','learning_modules','learning_steps','learning_resources','student_progress','student_step_sessions','instructors','learning_activities','inventory_categories','inventory_items','inventory_loans','inventory_movements','inventory_audit_log'] LOOP
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC, anon, authenticated', tabela);
    EXECUTE format('GRANT SELECT, INSERT ON TABLE public.%I TO controllab_app', tabela);
    IF tabela NOT IN ('inventory_movements', 'inventory_audit_log') THEN
      EXECUTE format('GRANT UPDATE, DELETE ON TABLE public.%I TO controllab_app', tabela);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename=tabela AND policyname='backend_controllab') THEN
      EXECUTE format('CREATE POLICY backend_controllab ON public.%I FOR ALL TO controllab_app USING (true) WITH CHECK (true)', tabela);
    END IF;
    sequencia := NULL;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name=tabela AND column_name='id') THEN
      sequencia := pg_get_serial_sequence(format('public.%I',tabela),'id');
    END IF;
    IF sequencia IS NOT NULL THEN
      EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %s TO controllab_app', sequencia);
    END IF;
  END LOOP;
END $$;
REVOKE EXECUTE ON FUNCTION public.unixepoch() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.controllab_fill_serial_id() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.unixepoch(), public.controllab_fill_serial_id() TO controllab_app;
ALTER ROLE controllab_app SET statement_timeout = '15s';
