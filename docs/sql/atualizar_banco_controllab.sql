-- ControlLab: atualizar o banco existente, preservando dados.
-- Gerado por node scripts/export-upgrade-postgres.mjs.
-- Fazer backup/restauracao de teste e pausar escritas do aplicativo antes de executar.
-- Executar TODO o arquivo de uma vez, com papel postgres, no projeto correto.
-- Limpeza DELETE/UPDATE da 0005 substituida por validacao estrita das FKs.
-- Se houver orfaos, duplicidades ou estrutura incompativel, a transacao falha.
-- Historico ao final registra reconciliacao equivalente a 0000..0006, nao execucao
-- das limpezas antigas. Nao altera arquivos de migrations originais.

BEGIN;
SET LOCAL search_path = public;
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '120s';
SELECT pg_advisory_xact_lock(hashtext('controllab_existing_database_upgrade'));

-- Este procedimento atende a baseline auditada, nao a bancos vazios ou arbitrarios.
DO $preflight$
DECLARE problems text;
BEGIN
  WITH expected(table_name, column_name, data_type, is_nullable) AS (
  VALUES
  ('auth_sessions', 'jti', 'text', 'NO'),
  ('auth_sessions', 'openId', 'text', 'NO'),
  ('auth_sessions', 'expiresAt', 'bigint', 'NO'),
  ('auth_sessions', 'revokedAt', 'bigint', 'YES'),
  ('auth_sessions', 'createdAt', 'bigint', 'NO'),
  ('classrooms', 'id', 'integer', 'NO'),
  ('classrooms', 'name', 'text', 'NO'),
  ('classrooms', 'teacherId', 'integer', 'YES'),
  ('classrooms', 'archivedAt', 'bigint', 'YES'),
  ('classrooms', 'createdAt', 'bigint', 'NO'),
  ('classrooms', 'updatedAt', 'bigint', 'NO'),
  ('instructors', 'id', 'integer', 'NO'),
  ('instructors', 'name', 'text', 'NO'),
  ('instructors', 'role', 'text', 'NO'),
  ('instructors', 'badge', 'text', 'NO'),
  ('instructors', 'initials', 'text', 'NO'),
  ('instructors', 'avatarUrl', 'text', 'YES'),
  ('instructors', 'active', 'integer', 'NO'),
  ('instructors', 'createdAt', 'bigint', 'NO'),
  ('inventory_audit_log', 'id', 'integer', 'NO'),
  ('inventory_audit_log', 'entityType', 'text', 'NO'),
  ('inventory_audit_log', 'entityId', 'integer', 'NO'),
  ('inventory_audit_log', 'action', 'text', 'NO'),
  ('inventory_audit_log', 'changes', 'text', 'NO'),
  ('inventory_audit_log', 'userId', 'integer', 'NO'),
  ('inventory_audit_log', 'createdAt', 'bigint', 'NO'),
  ('inventory_categories', 'id', 'integer', 'NO'),
  ('inventory_categories', 'name', 'text', 'NO'),
  ('inventory_categories', 'description', 'text', 'YES'),
  ('inventory_categories', 'archivedAt', 'bigint', 'YES'),
  ('inventory_categories', 'createdBy', 'integer', 'YES'),
  ('inventory_categories', 'createdAt', 'bigint', 'NO'),
  ('inventory_categories', 'updatedAt', 'bigint', 'NO'),
  ('inventory_items', 'id', 'integer', 'NO'),
  ('inventory_items', 'code', 'text', 'NO'),
  ('inventory_items', 'sapCode', 'text', 'YES'),
  ('inventory_items', 'name', 'text', 'NO'),
  ('inventory_items', 'description', 'text', 'YES'),
  ('inventory_items', 'itemType', 'text', 'NO'),
  ('inventory_items', 'categoryId', 'integer', 'YES'),
  ('inventory_items', 'unit', 'text', 'NO'),
  ('inventory_items', 'returnable', 'integer', 'NO'),
  ('inventory_items', 'quantityPhysical', 'integer', 'NO'),
  ('inventory_items', 'quantityReserved', 'integer', 'NO'),
  ('inventory_items', 'minQuantity', 'integer', 'NO'),
  ('inventory_items', 'sector', 'text', 'NO'),
  ('inventory_items', 'location', 'text', 'NO'),
  ('inventory_items', 'conservation', 'text', 'NO'),
  ('inventory_items', 'status', 'text', 'NO'),
  ('inventory_items', 'icon', 'text', 'YES'),
  ('inventory_items', 'version', 'integer', 'NO'),
  ('inventory_items', 'archivedAt', 'bigint', 'YES'),
  ('inventory_items', 'archivedBy', 'integer', 'YES'),
  ('inventory_items', 'archiveReason', 'text', 'YES'),
  ('inventory_items', 'createdBy', 'integer', 'YES'),
  ('inventory_items', 'updatedBy', 'integer', 'YES'),
  ('inventory_items', 'createdAt', 'bigint', 'NO'),
  ('inventory_items', 'updatedAt', 'bigint', 'NO'),
  ('inventory_loans', 'id', 'integer', 'NO'),
  ('inventory_loans', 'itemId', 'integer', 'NO'),
  ('inventory_loans', 'borrowerUserId', 'integer', 'YES'),
  ('inventory_loans', 'borrowerName', 'text', 'NO'),
  ('inventory_loans', 'classroomId', 'integer', 'YES'),
  ('inventory_loans', 'quantity', 'integer', 'NO'),
  ('inventory_loans', 'returnedQuantity', 'integer', 'NO'),
  ('inventory_loans', 'damagedQuantity', 'integer', 'NO'),
  ('inventory_loans', 'status', 'text', 'NO'),
  ('inventory_loans', 'purpose', 'text', 'NO'),
  ('inventory_loans', 'moduleId', 'text', 'YES'),
  ('inventory_loans', 'dueAt', 'bigint', 'YES'),
  ('inventory_loans', 'cancelReason', 'text', 'YES'),
  ('inventory_loans', 'requestKey', 'text', 'YES'),
  ('inventory_loans', 'createdBy', 'integer', 'NO'),
  ('inventory_loans', 'deliveredBy', 'integer', 'YES'),
  ('inventory_loans', 'closedBy', 'integer', 'YES'),
  ('inventory_loans', 'createdAt', 'bigint', 'NO'),
  ('inventory_loans', 'deliveredAt', 'bigint', 'YES'),
  ('inventory_loans', 'closedAt', 'bigint', 'YES'),
  ('inventory_loans', 'updatedAt', 'bigint', 'NO'),
  ('inventory_movements', 'id', 'integer', 'NO'),
  ('inventory_movements', 'itemId', 'integer', 'NO'),
  ('inventory_movements', 'movementType', 'text', 'NO'),
  ('inventory_movements', 'quantity', 'integer', 'NO'),
  ('inventory_movements', 'physicalBefore', 'integer', 'NO'),
  ('inventory_movements', 'physicalAfter', 'integer', 'NO'),
  ('inventory_movements', 'reservedBefore', 'integer', 'NO'),
  ('inventory_movements', 'reservedAfter', 'integer', 'NO'),
  ('inventory_movements', 'reason', 'text', 'NO'),
  ('inventory_movements', 'reference', 'text', 'YES'),
  ('inventory_movements', 'note', 'text', 'YES'),
  ('inventory_movements', 'loanId', 'integer', 'YES'),
  ('inventory_movements', 'classroomId', 'integer', 'YES'),
  ('inventory_movements', 'moduleId', 'text', 'YES'),
  ('inventory_movements', 'moduleTitleSnapshot', 'text', 'YES'),
  ('inventory_movements', 'itemCodeSnapshot', 'text', 'NO'),
  ('inventory_movements', 'itemNameSnapshot', 'text', 'NO'),
  ('inventory_movements', 'unitSnapshot', 'text', 'NO'),
  ('inventory_movements', 'requestKey', 'text', 'YES'),
  ('inventory_movements', 'userId', 'integer', 'NO'),
  ('inventory_movements', 'createdAt', 'bigint', 'NO'),
  ('learning_activities', 'id', 'text', 'NO'),
  ('learning_activities', 'moduleId', 'text', 'NO'),
  ('learning_activities', 'title', 'text', 'NO'),
  ('learning_activities', 'subtitle', 'text', 'NO'),
  ('learning_activities', 'activityType', 'text', 'NO'),
  ('learning_activities', 'startsAt', 'bigint', 'NO'),
  ('learning_activities', 'endsAt', 'bigint', 'NO'),
  ('learning_activities', 'color', 'text', 'NO'),
  ('learning_activities', 'createdBy', 'integer', 'YES'),
  ('learning_modules', 'id', 'text', 'NO'),
  ('learning_modules', 'code', 'text', 'NO'),
  ('learning_modules', 'title', 'text', 'NO'),
  ('learning_modules', 'kind', 'text', 'NO'),
  ('learning_modules', 'description', 'text', 'NO'),
  ('learning_modules', 'objective', 'text', 'NO'),
  ('learning_modules', 'cover', 'text', 'NO'),
  ('learning_modules', 'coverImage', 'text', 'YES'),
  ('learning_modules', 'progress', 'integer', 'NO'),
  ('learning_modules', 'duration', 'text', 'NO'),
  ('learning_modules', 'published', 'integer', 'NO'),
  ('learning_modules', 'createdBy', 'integer', 'YES'),
  ('learning_modules', 'archivedAt', 'bigint', 'YES'),
  ('learning_modules', 'createdAt', 'bigint', 'NO'),
  ('learning_modules', 'updatedAt', 'bigint', 'NO'),
  ('learning_resources', 'id', 'text', 'NO'),
  ('learning_resources', 'moduleId', 'text', 'NO'),
  ('learning_resources', 'category', 'text', 'NO'),
  ('learning_resources', 'label', 'text', 'NO'),
  ('learning_resources', 'title', 'text', 'NO'),
  ('learning_resources', 'detail', 'text', 'NO'),
  ('learning_resources', 'status', 'text', 'NO'),
  ('learning_resources', 'progress', 'integer', 'NO'),
  ('learning_resources', 'modelUrl', 'text', 'NO'),
  ('learning_resources', 'attachments', 'text', 'NO'),
  ('learning_resources', 'color', 'text', 'NO'),
  ('learning_resources', 'inventoryItemId', 'integer', 'YES'),
  ('learning_steps', 'id', 'text', 'NO'),
  ('learning_steps', 'moduleId', 'text', 'NO'),
  ('learning_steps', 'position', 'integer', 'NO'),
  ('learning_steps', 'title', 'text', 'NO'),
  ('learning_steps', 'description', 'text', 'NO'),
  ('learning_steps', 'tip', 'text', 'NO'),
  ('learning_steps', 'imageUrl', 'text', 'YES'),
  ('learning_steps', 'attachments', 'text', 'NO'),
  ('learning_steps', 'quiz', 'text', 'YES'),
  ('student_badges', 'id', 'integer', 'NO'),
  ('student_badges', 'userId', 'integer', 'NO'),
  ('student_badges', 'label', 'text', 'NO'),
  ('student_badges', 'detail', 'text', 'NO'),
  ('student_badges', 'awardedBy', 'integer', 'NO'),
  ('student_badges', 'awardedAt', 'bigint', 'NO'),
  ('student_notes', 'userId', 'integer', 'NO'),
  ('student_notes', 'content', 'text', 'NO'),
  ('student_notes', 'updatedAt', 'bigint', 'NO'),
  ('student_progress', 'id', 'integer', 'NO'),
  ('student_progress', 'userId', 'integer', 'NO'),
  ('student_progress', 'moduleId', 'text', 'NO'),
  ('student_progress', 'stepIndex', 'integer', 'NO'),
  ('student_progress', 'progress', 'integer', 'NO'),
  ('student_progress', 'studiedMinutes', 'integer', 'NO'),
  ('student_progress', 'streakDays', 'integer', 'NO'),
  ('student_progress', 'updatedAt', 'bigint', 'NO'),
  ('student_quiz_attempts', 'id', 'integer', 'NO'),
  ('student_quiz_attempts', 'userId', 'integer', 'NO'),
  ('student_quiz_attempts', 'moduleId', 'text', 'NO'),
  ('student_quiz_attempts', 'stepId', 'text', 'NO'),
  ('student_quiz_attempts', 'selectedIndex', 'integer', 'NO'),
  ('student_quiz_attempts', 'correct', 'integer', 'NO'),
  ('student_quiz_attempts', 'createdAt', 'bigint', 'NO'),
  ('student_step_sessions', 'id', 'integer', 'NO'),
  ('student_step_sessions', 'userId', 'integer', 'NO'),
  ('student_step_sessions', 'moduleId', 'text', 'NO'),
  ('student_step_sessions', 'stepIndex', 'integer', 'NO'),
  ('student_step_sessions', 'startedAt', 'bigint', 'NO'),
  ('student_step_sessions', 'completedAt', 'bigint', 'YES'),
  ('student_step_sessions', 'elapsedSeconds', 'integer', 'NO'),
  ('users', 'id', 'integer', 'NO'),
  ('users', 'openId', 'text', 'NO'),
  ('users', 'name', 'text', 'YES'),
  ('users', 'email', 'text', 'YES'),
  ('users', 'avatarUrl', 'text', 'YES'),
  ('users', 'loginMethod', 'text', 'YES'),
  ('users', 'passwordHash', 'text', 'YES'),
  ('users', 'role', 'text', 'NO'),
  ('users', 'active', 'integer', 'NO'),
  ('users', 'classroomId', 'integer', 'YES'),
  ('users', 'createdAt', 'bigint', 'NO'),
  ('users', 'updatedAt', 'bigint', 'NO'),
  ('users', 'lastSignedIn', 'bigint', 'NO')
)
  SELECT string_agg(e.table_name || '.' || e.column_name, ', ' ORDER BY e.table_name, e.column_name)
  INTO problems
  FROM expected e
  LEFT JOIN information_schema.columns c
    ON c.table_schema = 'public' AND c.table_name = e.table_name AND c.column_name = e.column_name
  WHERE e.table_name IN ('users', 'auth_sessions', 'student_badges', 'learning_modules', 'learning_steps', 'learning_resources', 'student_progress', 'student_step_sessions', 'instructors', 'learning_activities', 'inventory_categories', 'inventory_items', 'inventory_loans', 'inventory_movements', 'inventory_audit_log')
    AND e.table_name || '.' || e.column_name NOT IN ('inventory_items.icon', 'inventory_loans.classroomId', 'inventory_movements.classroomId', 'learning_activities.createdBy', 'learning_modules.archivedAt', 'learning_resources.attachments', 'learning_steps.attachments', 'learning_steps.quiz', 'users.classroomId')
    AND (c.column_name IS NULL OR c.data_type <> e.data_type OR c.is_nullable <> e.is_nullable);
  IF problems IS NOT NULL THEN
    RAISE EXCEPTION 'Baseline incompativel; nada sera aplicado. Colunas: %', problems;
  END IF;
END
$preflight$;

-- Evita escritas concorrentes durante contagem, validacao e mudancas de schema.
LOCK TABLE public."users", public."auth_sessions", public."student_badges", public."learning_modules", public."learning_steps", public."learning_resources", public."student_progress", public."student_step_sessions", public."instructors", public."learning_activities", public."inventory_categories", public."inventory_items", public."inventory_loans", public."inventory_movements", public."inventory_audit_log" IN SHARE ROW EXCLUSIVE MODE;
CREATE TEMP TABLE controllab_upgrade_counts (table_name text PRIMARY KEY, before_count bigint) ON COMMIT DROP;
DO $counts$
DECLARE t text; n bigint;
BEGIN
  FOREACH t IN ARRAY ARRAY['users', 'auth_sessions', 'student_badges', 'learning_modules', 'learning_steps', 'learning_resources', 'student_progress', 'student_step_sessions', 'instructors', 'learning_activities', 'inventory_categories', 'inventory_items', 'inventory_loans', 'inventory_movements', 'inventory_audit_log']
  LOOP
    EXECUTE format('SELECT count(*) FROM public.%I', t) INTO n;
    INSERT INTO pg_temp.controllab_upgrade_counts VALUES (t, n);
  END LOOP;
END
$counts$;

CREATE TABLE IF NOT EXISTS public.__drizzle_migrations (id serial PRIMARY KEY, hash text NOT NULL, created_at bigint);
ALTER TABLE public.__drizzle_migrations ENABLE ROW LEVEL SECURITY;
-- Recusa historico que nao corresponda exatamente aos arquivos desta versao.
DO $history$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.__drizzle_migrations h
    WHERE h.created_at IS NULL OR NOT EXISTS (
      SELECT 1 FROM (VALUES ('89d1035f1962e40fc3127bb3710e967b80e1db434d3ac87f8eb1cd0ab7a07d3c', 1792710000000::bigint),
        ('5d59d7761e593064f429a5a6854d258452d713c53a1018448a432237e4b366f1', 1792800000000::bigint),
        ('08c33d2325350985ca80034eeb0ed845a15d6b30d43826f9f6a2f1e000d593b6', 1793000000000::bigint),
        ('efa01d5079939957a6c002bfc215e01e6a19216bf67478ccfbbca3613257c1c3', 1793100000000::bigint),
        ('4a1403a0382d18a473e723c49382e71982d35f94a88970fad391293f2807aa39', 1793200000000::bigint),
        ('140c664a46b640fd380438271d3faf9f2735f2b29be41930134be7b4c24a532f', 1793300000000::bigint),
        ('4ae79f4eabbcd32bb42a59021adf13e4724388e5a6ff39cc23497a4537b06949', 1793400000000::bigint)) expected(hash, created_at)
      WHERE expected.hash = h.hash AND expected.created_at = h.created_at
    )
  ) OR EXISTS (SELECT 1 FROM public.__drizzle_migrations GROUP BY created_at HAVING count(*) > 1) THEN
    RAISE EXCEPTION 'Historico desconhecido ou duplicado; revisar antes de atualizar.';
  END IF;
END
$history$;

-- 0000_controllab_baseline
CREATE OR REPLACE FUNCTION public.unixepoch() RETURNS bigint
LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT floor(extract(epoch FROM now()))::bigint
$$;

CREATE OR REPLACE FUNCTION public.controllab_fill_serial_id() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF NEW.id IS NULL THEN
    NEW.id := nextval(pg_get_serial_sequence(format('%I.%I', TG_TABLE_SCHEMA, TG_TABLE_NAME), 'id'));
  END IF;
  RETURN NEW;
END
$$;

CREATE TABLE IF NOT EXISTS "users" (
	"id" serial PRIMARY KEY,
	"openId" text NOT NULL,
	"name" text,
	"email" text,
	"avatarUrl" text,
	"loginMethod" text,
	"passwordHash" text,
	"role" text NOT NULL DEFAULT 'student',
	"active" integer NOT NULL DEFAULT 1,
	"createdAt" bigint NOT NULL DEFAULT (unixepoch() * 1000),
	"updatedAt" bigint NOT NULL DEFAULT (unixepoch() * 1000),
	"lastSignedIn" bigint NOT NULL DEFAULT (unixepoch() * 1000)
);

CREATE UNIQUE INDEX IF NOT EXISTS "users_email_unique" ON "users" ("email");

CREATE UNIQUE INDEX IF NOT EXISTS "users_openId_unique" ON "users" ("openId");

CREATE TABLE IF NOT EXISTS "auth_sessions" (
	"jti" text PRIMARY KEY NOT NULL,
	"openId" text NOT NULL,
	"expiresAt" bigint NOT NULL,
	"revokedAt" bigint,
	"createdAt" bigint NOT NULL DEFAULT (unixepoch() * 1000)
);

CREATE INDEX IF NOT EXISTS "auth_sessions_open_id_idx" ON "auth_sessions" ("openId");

CREATE INDEX IF NOT EXISTS "auth_sessions_active_idx" ON "auth_sessions" ("revokedAt","expiresAt");

CREATE TABLE IF NOT EXISTS "student_badges" (
	"id" serial PRIMARY KEY,
	"userId" integer NOT NULL,
	"label" text NOT NULL,
	"detail" text NOT NULL,
	"awardedBy" integer NOT NULL,
	"awardedAt" bigint NOT NULL DEFAULT (unixepoch() * 1000)
);

CREATE INDEX IF NOT EXISTS "student_badges_user_idx" ON "student_badges" ("userId");

CREATE TABLE IF NOT EXISTS "learning_modules" (
	"id" text PRIMARY KEY NOT NULL,
	"code" text NOT NULL,
	"title" text NOT NULL,
	"kind" text NOT NULL,
	"description" text NOT NULL,
	"objective" text NOT NULL,
	"cover" text NOT NULL,
	"coverImage" text,
	"progress" integer NOT NULL DEFAULT 0,
	"duration" text NOT NULL,
	"published" integer NOT NULL DEFAULT 0,
	"createdBy" integer,
	"createdAt" bigint NOT NULL DEFAULT (unixepoch() * 1000),
	"updatedAt" bigint NOT NULL DEFAULT (unixepoch() * 1000)
);

CREATE INDEX IF NOT EXISTS "learning_modules_published_idx" ON "learning_modules" ("published");

CREATE TABLE IF NOT EXISTS "learning_steps" (
	"id" text PRIMARY KEY NOT NULL,
	"moduleId" text NOT NULL,
	"position" integer NOT NULL,
	"title" text NOT NULL,
	"description" text NOT NULL,
	"tip" text NOT NULL,
	"imageUrl" text
);

CREATE INDEX IF NOT EXISTS "learning_steps_module_idx" ON "learning_steps" ("moduleId");

CREATE TABLE IF NOT EXISTS "learning_resources" (
	"id" text PRIMARY KEY NOT NULL,
	"moduleId" text NOT NULL,
	"category" text NOT NULL,
	"label" text NOT NULL,
	"title" text NOT NULL,
	"detail" text NOT NULL,
	"status" text NOT NULL,
	"progress" integer NOT NULL DEFAULT 0,
	"modelUrl" text NOT NULL,
	"color" text NOT NULL,
	"inventoryItemId" integer
);

CREATE INDEX IF NOT EXISTS "learning_resources_module_idx" ON "learning_resources" ("moduleId");

CREATE INDEX IF NOT EXISTS "learning_resources_inventory_idx" ON "learning_resources" ("inventoryItemId");

CREATE TABLE IF NOT EXISTS "student_progress" (
	"id" serial PRIMARY KEY,
	"userId" integer NOT NULL,
	"moduleId" text NOT NULL,
	"stepIndex" integer NOT NULL DEFAULT 0,
	"progress" integer NOT NULL DEFAULT 0,
	"studiedMinutes" integer NOT NULL DEFAULT 0,
	"streakDays" integer NOT NULL DEFAULT 0,
	"updatedAt" bigint NOT NULL DEFAULT (unixepoch() * 1000)
);

CREATE INDEX IF NOT EXISTS "student_progress_user_module_idx" ON "student_progress" ("userId","moduleId");

CREATE UNIQUE INDEX IF NOT EXISTS "student_progress_user_module_unique" ON "student_progress" ("userId","moduleId");

CREATE TABLE IF NOT EXISTS "student_step_sessions" (
	"id" serial PRIMARY KEY,
	"userId" integer NOT NULL,
	"moduleId" text NOT NULL,
	"stepIndex" integer NOT NULL,
	"startedAt" bigint NOT NULL DEFAULT (unixepoch() * 1000),
	"completedAt" bigint,
	"elapsedSeconds" integer NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX IF NOT EXISTS "student_step_sessions_user_step_idx" ON "student_step_sessions" ("userId","moduleId","stepIndex");

CREATE INDEX IF NOT EXISTS "student_step_sessions_module_idx" ON "student_step_sessions" ("userId","moduleId");

CREATE TABLE IF NOT EXISTS "instructors" (
	"id" serial PRIMARY KEY,
	"name" text NOT NULL,
	"role" text NOT NULL,
	"badge" text NOT NULL,
	"initials" text NOT NULL,
	"avatarUrl" text,
	"active" integer NOT NULL DEFAULT 1,
	"createdAt" bigint NOT NULL DEFAULT (unixepoch() * 1000)
);

CREATE TABLE IF NOT EXISTS "learning_activities" (
	"id" text PRIMARY KEY NOT NULL,
	"moduleId" text NOT NULL,
	"title" text NOT NULL,
	"subtitle" text NOT NULL,
	"activityType" text NOT NULL,
	"startsAt" bigint NOT NULL,
	"endsAt" bigint NOT NULL,
	"color" text NOT NULL
);

CREATE TABLE IF NOT EXISTS "inventory_categories" (
	"id" serial PRIMARY KEY,
	"name" text NOT NULL,
	"description" text,
	"archivedAt" bigint,
	"createdBy" integer,
	"createdAt" bigint NOT NULL DEFAULT (unixepoch() * 1000),
	"updatedAt" bigint NOT NULL DEFAULT (unixepoch() * 1000),
	FOREIGN KEY ("createdBy") REFERENCES "users"("id") ON UPDATE no action ON DELETE set null
);

CREATE UNIQUE INDEX IF NOT EXISTS "inventory_categories_name_unique" ON "inventory_categories" ("name");

CREATE TABLE IF NOT EXISTS "inventory_items" (
	"id" serial PRIMARY KEY,
	"code" text NOT NULL,
	"sapCode" text,
	"name" text NOT NULL,
	"description" text,
	"itemType" text NOT NULL,
	"categoryId" integer,
	"unit" text NOT NULL DEFAULT 'UN',
	"returnable" integer NOT NULL DEFAULT 1,
	"quantityPhysical" integer NOT NULL DEFAULT 0,
	"quantityReserved" integer NOT NULL DEFAULT 0,
	"minQuantity" integer NOT NULL DEFAULT 0,
	"sector" text NOT NULL,
	"location" text NOT NULL,
	"conservation" text NOT NULL DEFAULT 'bom',
	"status" text NOT NULL DEFAULT 'disponivel',
	"version" integer NOT NULL DEFAULT 0,
	"archivedAt" bigint,
	"archivedBy" integer,
	"archiveReason" text,
	"createdBy" integer,
	"updatedBy" integer,
	"createdAt" bigint NOT NULL DEFAULT (unixepoch() * 1000),
	"updatedAt" bigint NOT NULL DEFAULT (unixepoch() * 1000),
	FOREIGN KEY ("categoryId") REFERENCES "inventory_categories"("id") ON UPDATE no action ON DELETE set null,
	FOREIGN KEY ("createdBy") REFERENCES "users"("id") ON UPDATE no action ON DELETE set null,
	FOREIGN KEY ("updatedBy") REFERENCES "users"("id") ON UPDATE no action ON DELETE set null,
	FOREIGN KEY ("archivedBy") REFERENCES "users"("id") ON UPDATE no action ON DELETE set null,
	CONSTRAINT "inventory_items_physical_check" CHECK("quantityPhysical" >= 0),
	CONSTRAINT "inventory_items_reserved_check" CHECK("quantityReserved" >= 0 AND "quantityReserved" <= "quantityPhysical"),
	CONSTRAINT "inventory_items_min_check" CHECK("minQuantity" >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS "inventory_items_code_unique" ON "inventory_items" ("code");

CREATE INDEX IF NOT EXISTS "inventory_items_sap_idx" ON "inventory_items" ("sapCode");

CREATE INDEX IF NOT EXISTS "inventory_items_type_idx" ON "inventory_items" ("itemType");

CREATE INDEX IF NOT EXISTS "inventory_items_category_idx" ON "inventory_items" ("categoryId");

CREATE INDEX IF NOT EXISTS "inventory_items_archived_idx" ON "inventory_items" ("archivedAt");

CREATE TABLE IF NOT EXISTS "inventory_loans" (
	"id" serial PRIMARY KEY,
	"itemId" integer NOT NULL,
	"borrowerUserId" integer,
	"borrowerName" text NOT NULL,
	"quantity" integer NOT NULL,
	"returnedQuantity" integer NOT NULL DEFAULT 0,
	"damagedQuantity" integer NOT NULL DEFAULT 0,
	"status" text NOT NULL DEFAULT 'reservado',
	"purpose" text NOT NULL,
	"moduleId" text,
	"dueAt" bigint,
	"cancelReason" text,
	"requestKey" text,
	"createdBy" integer NOT NULL,
	"deliveredBy" integer,
	"closedBy" integer,
	"createdAt" bigint NOT NULL DEFAULT (unixepoch() * 1000),
	"deliveredAt" bigint,
	"closedAt" bigint,
	"updatedAt" bigint NOT NULL DEFAULT (unixepoch() * 1000),
	FOREIGN KEY ("itemId") REFERENCES "inventory_items"("id") ON UPDATE no action ON DELETE no action,
	FOREIGN KEY ("borrowerUserId") REFERENCES "users"("id") ON UPDATE no action ON DELETE set null,
	FOREIGN KEY ("moduleId") REFERENCES "learning_modules"("id") ON UPDATE cascade ON DELETE set null,
	FOREIGN KEY ("createdBy") REFERENCES "users"("id") ON UPDATE no action ON DELETE no action,
	FOREIGN KEY ("deliveredBy") REFERENCES "users"("id") ON UPDATE no action ON DELETE set null,
	FOREIGN KEY ("closedBy") REFERENCES "users"("id") ON UPDATE no action ON DELETE set null,
	CONSTRAINT "inventory_loans_quantity_check" CHECK("quantity" > 0),
	CONSTRAINT "inventory_loans_return_check" CHECK("returnedQuantity" >= 0 AND "damagedQuantity" >= 0 AND "returnedQuantity" + "damagedQuantity" <= "quantity")
);

CREATE UNIQUE INDEX IF NOT EXISTS "inventory_loans_request_key_unique" ON "inventory_loans" ("requestKey");

CREATE INDEX IF NOT EXISTS "inventory_loans_item_idx" ON "inventory_loans" ("itemId");

CREATE INDEX IF NOT EXISTS "inventory_loans_status_idx" ON "inventory_loans" ("status");

CREATE TABLE IF NOT EXISTS "inventory_movements" (
	"id" serial PRIMARY KEY,
	"itemId" integer NOT NULL,
	"movementType" text NOT NULL,
	"quantity" integer NOT NULL,
	"physicalBefore" integer NOT NULL,
	"physicalAfter" integer NOT NULL,
	"reservedBefore" integer NOT NULL,
	"reservedAfter" integer NOT NULL,
	"reason" text NOT NULL,
	"reference" text,
	"note" text,
	"loanId" integer,
	"moduleId" text,
	"moduleTitleSnapshot" text,
	"itemCodeSnapshot" text NOT NULL,
	"itemNameSnapshot" text NOT NULL,
	"unitSnapshot" text NOT NULL,
	"requestKey" text,
	"userId" integer NOT NULL,
	"createdAt" bigint NOT NULL DEFAULT (unixepoch() * 1000),
	FOREIGN KEY ("itemId") REFERENCES "inventory_items"("id") ON UPDATE no action ON DELETE no action,
	FOREIGN KEY ("loanId") REFERENCES "inventory_loans"("id") ON UPDATE no action ON DELETE no action,
	FOREIGN KEY ("moduleId") REFERENCES "learning_modules"("id") ON UPDATE cascade ON DELETE set null,
	FOREIGN KEY ("userId") REFERENCES "users"("id") ON UPDATE no action ON DELETE no action,
	CONSTRAINT "inventory_movements_quantity_check" CHECK("quantity" > 0),
	CONSTRAINT "inventory_movements_balance_check" CHECK("physicalAfter" >= 0 AND "reservedAfter" >= 0 AND "reservedAfter" <= "physicalAfter")
);

CREATE UNIQUE INDEX IF NOT EXISTS "inventory_movements_request_key_unique" ON "inventory_movements" ("requestKey");

CREATE INDEX IF NOT EXISTS "inventory_movements_item_idx" ON "inventory_movements" ("itemId","createdAt");

CREATE INDEX IF NOT EXISTS "inventory_movements_type_idx" ON "inventory_movements" ("movementType");

CREATE INDEX IF NOT EXISTS "inventory_movements_user_idx" ON "inventory_movements" ("userId");

CREATE INDEX IF NOT EXISTS "inventory_movements_loan_idx" ON "inventory_movements" ("loanId");

CREATE TABLE IF NOT EXISTS "inventory_audit_log" (
	"id" serial PRIMARY KEY,
	"entityType" text NOT NULL,
	"entityId" integer NOT NULL,
	"action" text NOT NULL,
	"changes" text NOT NULL,
	"userId" integer NOT NULL,
	"createdAt" bigint NOT NULL DEFAULT (unixepoch() * 1000),
	FOREIGN KEY ("userId") REFERENCES "users"("id") ON UPDATE no action ON DELETE no action
);

CREATE INDEX IF NOT EXISTS "inventory_audit_entity_idx" ON "inventory_audit_log" ("entityType","entityId");

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'learning_resources_inventory_fk' AND conrelid = 'public.learning_resources'::regclass) THEN
    ALTER TABLE "learning_resources" ADD CONSTRAINT "learning_resources_inventory_fk"
      FOREIGN KEY ("inventoryItemId") REFERENCES "inventory_items"("id") ON UPDATE cascade ON DELETE set null;
  END IF;
END
$$;

DROP TRIGGER IF EXISTS "users_fill_id" ON "users";

CREATE TRIGGER "users_fill_id" BEFORE INSERT ON "users" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

DROP TRIGGER IF EXISTS "student_badges_fill_id" ON "student_badges";

CREATE TRIGGER "student_badges_fill_id" BEFORE INSERT ON "student_badges" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

DROP TRIGGER IF EXISTS "student_progress_fill_id" ON "student_progress";

CREATE TRIGGER "student_progress_fill_id" BEFORE INSERT ON "student_progress" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

DROP TRIGGER IF EXISTS "student_step_sessions_fill_id" ON "student_step_sessions";

CREATE TRIGGER "student_step_sessions_fill_id" BEFORE INSERT ON "student_step_sessions" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

DROP TRIGGER IF EXISTS "instructors_fill_id" ON "instructors";

CREATE TRIGGER "instructors_fill_id" BEFORE INSERT ON "instructors" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

DROP TRIGGER IF EXISTS "inventory_categories_fill_id" ON "inventory_categories";

CREATE TRIGGER "inventory_categories_fill_id" BEFORE INSERT ON "inventory_categories" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

DROP TRIGGER IF EXISTS "inventory_items_fill_id" ON "inventory_items";

CREATE TRIGGER "inventory_items_fill_id" BEFORE INSERT ON "inventory_items" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

DROP TRIGGER IF EXISTS "inventory_loans_fill_id" ON "inventory_loans";

CREATE TRIGGER "inventory_loans_fill_id" BEFORE INSERT ON "inventory_loans" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

DROP TRIGGER IF EXISTS "inventory_movements_fill_id" ON "inventory_movements";

CREATE TRIGGER "inventory_movements_fill_id" BEFORE INSERT ON "inventory_movements" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

DROP TRIGGER IF EXISTS "inventory_audit_log_fill_id" ON "inventory_audit_log";

CREATE TRIGGER "inventory_audit_log_fill_id" BEFORE INSERT ON "inventory_audit_log" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

ALTER TABLE "users" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "auth_sessions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "student_badges" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "learning_modules" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "learning_steps" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "learning_resources" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "student_progress" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "student_step_sessions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "instructors" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "learning_activities" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "inventory_categories" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "inventory_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "inventory_loans" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "inventory_movements" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "inventory_audit_log" ENABLE ROW LEVEL SECURITY;

-- 0001_ownership_archive_notes
ALTER TABLE "learning_modules" ADD COLUMN IF NOT EXISTS "archivedAt" bigint;

CREATE INDEX IF NOT EXISTS "learning_modules_archived_idx" ON "learning_modules" ("archivedAt");

ALTER TABLE "learning_activities" ADD COLUMN IF NOT EXISTS "createdBy" integer;

CREATE INDEX IF NOT EXISTS "learning_activities_created_by_idx" ON "learning_activities" ("createdBy");

CREATE TABLE IF NOT EXISTS "student_notes" (
	"userId" integer PRIMARY KEY NOT NULL,
	"content" text DEFAULT '[]' NOT NULL,
	"updatedAt" bigint NOT NULL DEFAULT (unixepoch() * 1000),
	FOREIGN KEY ("userId") REFERENCES "users"("id") ON UPDATE no action ON DELETE cascade
);

ALTER TABLE "student_notes" ENABLE ROW LEVEL SECURITY;

-- 0002_classrooms
CREATE TABLE IF NOT EXISTS "classrooms" (
	"id" serial PRIMARY KEY,
	"name" text NOT NULL,
	"teacherId" integer,
	"archivedAt" bigint,
	"createdAt" bigint NOT NULL DEFAULT (unixepoch() * 1000),
	"updatedAt" bigint NOT NULL DEFAULT (unixepoch() * 1000),
	FOREIGN KEY ("teacherId") REFERENCES "users"("id") ON UPDATE no action ON DELETE set null
);

CREATE UNIQUE INDEX IF NOT EXISTS "classrooms_name_unique" ON "classrooms" ("name");

CREATE INDEX IF NOT EXISTS "classrooms_teacher_idx" ON "classrooms" ("teacherId");

DROP TRIGGER IF EXISTS "classrooms_fill_id" ON "classrooms";

CREATE TRIGGER "classrooms_fill_id" BEFORE INSERT ON "classrooms" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

ALTER TABLE "classrooms" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "classroomId" integer REFERENCES "classrooms"("id") ON DELETE set null;

CREATE INDEX IF NOT EXISTS "users_classroom_idx" ON "users" ("classroomId");

ALTER TABLE "inventory_loans" ADD COLUMN IF NOT EXISTS "classroomId" integer REFERENCES "classrooms"("id") ON DELETE set null;

ALTER TABLE "inventory_movements" ADD COLUMN IF NOT EXISTS "classroomId" integer REFERENCES "classrooms"("id") ON DELETE set null;

-- 0003_module_attachments
ALTER TABLE "learning_resources" ADD COLUMN IF NOT EXISTS "attachments" text DEFAULT '[]' NOT NULL;

ALTER TABLE "learning_steps" ADD COLUMN IF NOT EXISTS "attachments" text DEFAULT '[]' NOT NULL;

-- 0004_inventory_item_icon
ALTER TABLE "inventory_items" ADD COLUMN IF NOT EXISTS "icon" text;

-- 0005_learning_foreign_keys
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'student_progress_user_fk' AND conrelid = 'public.student_progress'::regclass) THEN
    ALTER TABLE "student_progress" ADD CONSTRAINT "student_progress_user_fk"
      FOREIGN KEY ("userId") REFERENCES "users"("id") ON UPDATE no action ON DELETE cascade;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'student_progress_module_fk' AND conrelid = 'public.student_progress'::regclass) THEN
    ALTER TABLE "student_progress" ADD CONSTRAINT "student_progress_module_fk"
      FOREIGN KEY ("moduleId") REFERENCES "learning_modules"("id") ON UPDATE cascade ON DELETE cascade;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'student_step_sessions_user_fk' AND conrelid = 'public.student_step_sessions'::regclass) THEN
    ALTER TABLE "student_step_sessions" ADD CONSTRAINT "student_step_sessions_user_fk"
      FOREIGN KEY ("userId") REFERENCES "users"("id") ON UPDATE no action ON DELETE cascade;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'student_step_sessions_module_fk' AND conrelid = 'public.student_step_sessions'::regclass) THEN
    ALTER TABLE "student_step_sessions" ADD CONSTRAINT "student_step_sessions_module_fk"
      FOREIGN KEY ("moduleId") REFERENCES "learning_modules"("id") ON UPDATE cascade ON DELETE cascade;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'student_badges_user_fk' AND conrelid = 'public.student_badges'::regclass) THEN
    ALTER TABLE "student_badges" ADD CONSTRAINT "student_badges_user_fk"
      FOREIGN KEY ("userId") REFERENCES "users"("id") ON UPDATE no action ON DELETE cascade;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'learning_steps_module_fk' AND conrelid = 'public.learning_steps'::regclass) THEN
    ALTER TABLE "learning_steps" ADD CONSTRAINT "learning_steps_module_fk"
      FOREIGN KEY ("moduleId") REFERENCES "learning_modules"("id") ON UPDATE cascade ON DELETE cascade;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'learning_resources_module_fk' AND conrelid = 'public.learning_resources'::regclass) THEN
    ALTER TABLE "learning_resources" ADD CONSTRAINT "learning_resources_module_fk"
      FOREIGN KEY ("moduleId") REFERENCES "learning_modules"("id") ON UPDATE cascade ON DELETE cascade;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'learning_activities_module_fk' AND conrelid = 'public.learning_activities'::regclass) THEN
    ALTER TABLE "learning_activities" ADD CONSTRAINT "learning_activities_module_fk"
      FOREIGN KEY ("moduleId") REFERENCES "learning_modules"("id") ON UPDATE cascade ON DELETE cascade;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'learning_activities_created_by_fk' AND conrelid = 'public.learning_activities'::regclass) THEN
    ALTER TABLE "learning_activities" ADD CONSTRAINT "learning_activities_created_by_fk"
      FOREIGN KEY ("createdBy") REFERENCES "users"("id") ON UPDATE no action ON DELETE set null;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'learning_modules_created_by_fk' AND conrelid = 'public.learning_modules'::regclass) THEN
    ALTER TABLE "learning_modules" ADD CONSTRAINT "learning_modules_created_by_fk"
      FOREIGN KEY ("createdBy") REFERENCES "users"("id") ON UPDATE no action ON DELETE set null;
  END IF;
END
$$;

DROP INDEX IF EXISTS "student_progress_user_module_idx";

-- 0006_step_quiz
CREATE TABLE IF NOT EXISTS "student_quiz_attempts" (
	"id" serial PRIMARY KEY,
	"userId" integer NOT NULL,
	"moduleId" text NOT NULL,
	"stepId" text NOT NULL,
	"selectedIndex" integer NOT NULL,
	"correct" integer NOT NULL,
	"createdAt" bigint NOT NULL DEFAULT (unixepoch() * 1000),
	CONSTRAINT "student_quiz_attempts_user_fk" FOREIGN KEY ("userId") REFERENCES "users"("id") ON UPDATE no action ON DELETE cascade,
	CONSTRAINT "student_quiz_attempts_module_fk" FOREIGN KEY ("moduleId") REFERENCES "learning_modules"("id") ON UPDATE cascade ON DELETE cascade
);

CREATE INDEX IF NOT EXISTS "student_quiz_attempts_user_step_idx" ON "student_quiz_attempts" ("userId","stepId");

CREATE INDEX IF NOT EXISTS "student_quiz_attempts_module_idx" ON "student_quiz_attempts" ("moduleId");

DROP TRIGGER IF EXISTS "student_quiz_attempts_fill_id" ON "student_quiz_attempts";

CREATE TRIGGER "student_quiz_attempts_fill_id" BEFORE INSERT ON "student_quiz_attempts" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

ALTER TABLE "student_quiz_attempts" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "learning_steps" ADD COLUMN IF NOT EXISTS "quiz" text;

-- Confirma todas as colunas antes de registrar o estado reconciliado.
DO $verify$
DECLARE problems text; r record; n bigint;
BEGIN
  WITH expected(table_name, column_name, data_type, is_nullable) AS (
  VALUES
  ('auth_sessions', 'jti', 'text', 'NO'),
  ('auth_sessions', 'openId', 'text', 'NO'),
  ('auth_sessions', 'expiresAt', 'bigint', 'NO'),
  ('auth_sessions', 'revokedAt', 'bigint', 'YES'),
  ('auth_sessions', 'createdAt', 'bigint', 'NO'),
  ('classrooms', 'id', 'integer', 'NO'),
  ('classrooms', 'name', 'text', 'NO'),
  ('classrooms', 'teacherId', 'integer', 'YES'),
  ('classrooms', 'archivedAt', 'bigint', 'YES'),
  ('classrooms', 'createdAt', 'bigint', 'NO'),
  ('classrooms', 'updatedAt', 'bigint', 'NO'),
  ('instructors', 'id', 'integer', 'NO'),
  ('instructors', 'name', 'text', 'NO'),
  ('instructors', 'role', 'text', 'NO'),
  ('instructors', 'badge', 'text', 'NO'),
  ('instructors', 'initials', 'text', 'NO'),
  ('instructors', 'avatarUrl', 'text', 'YES'),
  ('instructors', 'active', 'integer', 'NO'),
  ('instructors', 'createdAt', 'bigint', 'NO'),
  ('inventory_audit_log', 'id', 'integer', 'NO'),
  ('inventory_audit_log', 'entityType', 'text', 'NO'),
  ('inventory_audit_log', 'entityId', 'integer', 'NO'),
  ('inventory_audit_log', 'action', 'text', 'NO'),
  ('inventory_audit_log', 'changes', 'text', 'NO'),
  ('inventory_audit_log', 'userId', 'integer', 'NO'),
  ('inventory_audit_log', 'createdAt', 'bigint', 'NO'),
  ('inventory_categories', 'id', 'integer', 'NO'),
  ('inventory_categories', 'name', 'text', 'NO'),
  ('inventory_categories', 'description', 'text', 'YES'),
  ('inventory_categories', 'archivedAt', 'bigint', 'YES'),
  ('inventory_categories', 'createdBy', 'integer', 'YES'),
  ('inventory_categories', 'createdAt', 'bigint', 'NO'),
  ('inventory_categories', 'updatedAt', 'bigint', 'NO'),
  ('inventory_items', 'id', 'integer', 'NO'),
  ('inventory_items', 'code', 'text', 'NO'),
  ('inventory_items', 'sapCode', 'text', 'YES'),
  ('inventory_items', 'name', 'text', 'NO'),
  ('inventory_items', 'description', 'text', 'YES'),
  ('inventory_items', 'itemType', 'text', 'NO'),
  ('inventory_items', 'categoryId', 'integer', 'YES'),
  ('inventory_items', 'unit', 'text', 'NO'),
  ('inventory_items', 'returnable', 'integer', 'NO'),
  ('inventory_items', 'quantityPhysical', 'integer', 'NO'),
  ('inventory_items', 'quantityReserved', 'integer', 'NO'),
  ('inventory_items', 'minQuantity', 'integer', 'NO'),
  ('inventory_items', 'sector', 'text', 'NO'),
  ('inventory_items', 'location', 'text', 'NO'),
  ('inventory_items', 'conservation', 'text', 'NO'),
  ('inventory_items', 'status', 'text', 'NO'),
  ('inventory_items', 'icon', 'text', 'YES'),
  ('inventory_items', 'version', 'integer', 'NO'),
  ('inventory_items', 'archivedAt', 'bigint', 'YES'),
  ('inventory_items', 'archivedBy', 'integer', 'YES'),
  ('inventory_items', 'archiveReason', 'text', 'YES'),
  ('inventory_items', 'createdBy', 'integer', 'YES'),
  ('inventory_items', 'updatedBy', 'integer', 'YES'),
  ('inventory_items', 'createdAt', 'bigint', 'NO'),
  ('inventory_items', 'updatedAt', 'bigint', 'NO'),
  ('inventory_loans', 'id', 'integer', 'NO'),
  ('inventory_loans', 'itemId', 'integer', 'NO'),
  ('inventory_loans', 'borrowerUserId', 'integer', 'YES'),
  ('inventory_loans', 'borrowerName', 'text', 'NO'),
  ('inventory_loans', 'classroomId', 'integer', 'YES'),
  ('inventory_loans', 'quantity', 'integer', 'NO'),
  ('inventory_loans', 'returnedQuantity', 'integer', 'NO'),
  ('inventory_loans', 'damagedQuantity', 'integer', 'NO'),
  ('inventory_loans', 'status', 'text', 'NO'),
  ('inventory_loans', 'purpose', 'text', 'NO'),
  ('inventory_loans', 'moduleId', 'text', 'YES'),
  ('inventory_loans', 'dueAt', 'bigint', 'YES'),
  ('inventory_loans', 'cancelReason', 'text', 'YES'),
  ('inventory_loans', 'requestKey', 'text', 'YES'),
  ('inventory_loans', 'createdBy', 'integer', 'NO'),
  ('inventory_loans', 'deliveredBy', 'integer', 'YES'),
  ('inventory_loans', 'closedBy', 'integer', 'YES'),
  ('inventory_loans', 'createdAt', 'bigint', 'NO'),
  ('inventory_loans', 'deliveredAt', 'bigint', 'YES'),
  ('inventory_loans', 'closedAt', 'bigint', 'YES'),
  ('inventory_loans', 'updatedAt', 'bigint', 'NO'),
  ('inventory_movements', 'id', 'integer', 'NO'),
  ('inventory_movements', 'itemId', 'integer', 'NO'),
  ('inventory_movements', 'movementType', 'text', 'NO'),
  ('inventory_movements', 'quantity', 'integer', 'NO'),
  ('inventory_movements', 'physicalBefore', 'integer', 'NO'),
  ('inventory_movements', 'physicalAfter', 'integer', 'NO'),
  ('inventory_movements', 'reservedBefore', 'integer', 'NO'),
  ('inventory_movements', 'reservedAfter', 'integer', 'NO'),
  ('inventory_movements', 'reason', 'text', 'NO'),
  ('inventory_movements', 'reference', 'text', 'YES'),
  ('inventory_movements', 'note', 'text', 'YES'),
  ('inventory_movements', 'loanId', 'integer', 'YES'),
  ('inventory_movements', 'classroomId', 'integer', 'YES'),
  ('inventory_movements', 'moduleId', 'text', 'YES'),
  ('inventory_movements', 'moduleTitleSnapshot', 'text', 'YES'),
  ('inventory_movements', 'itemCodeSnapshot', 'text', 'NO'),
  ('inventory_movements', 'itemNameSnapshot', 'text', 'NO'),
  ('inventory_movements', 'unitSnapshot', 'text', 'NO'),
  ('inventory_movements', 'requestKey', 'text', 'YES'),
  ('inventory_movements', 'userId', 'integer', 'NO'),
  ('inventory_movements', 'createdAt', 'bigint', 'NO'),
  ('learning_activities', 'id', 'text', 'NO'),
  ('learning_activities', 'moduleId', 'text', 'NO'),
  ('learning_activities', 'title', 'text', 'NO'),
  ('learning_activities', 'subtitle', 'text', 'NO'),
  ('learning_activities', 'activityType', 'text', 'NO'),
  ('learning_activities', 'startsAt', 'bigint', 'NO'),
  ('learning_activities', 'endsAt', 'bigint', 'NO'),
  ('learning_activities', 'color', 'text', 'NO'),
  ('learning_activities', 'createdBy', 'integer', 'YES'),
  ('learning_modules', 'id', 'text', 'NO'),
  ('learning_modules', 'code', 'text', 'NO'),
  ('learning_modules', 'title', 'text', 'NO'),
  ('learning_modules', 'kind', 'text', 'NO'),
  ('learning_modules', 'description', 'text', 'NO'),
  ('learning_modules', 'objective', 'text', 'NO'),
  ('learning_modules', 'cover', 'text', 'NO'),
  ('learning_modules', 'coverImage', 'text', 'YES'),
  ('learning_modules', 'progress', 'integer', 'NO'),
  ('learning_modules', 'duration', 'text', 'NO'),
  ('learning_modules', 'published', 'integer', 'NO'),
  ('learning_modules', 'createdBy', 'integer', 'YES'),
  ('learning_modules', 'archivedAt', 'bigint', 'YES'),
  ('learning_modules', 'createdAt', 'bigint', 'NO'),
  ('learning_modules', 'updatedAt', 'bigint', 'NO'),
  ('learning_resources', 'id', 'text', 'NO'),
  ('learning_resources', 'moduleId', 'text', 'NO'),
  ('learning_resources', 'category', 'text', 'NO'),
  ('learning_resources', 'label', 'text', 'NO'),
  ('learning_resources', 'title', 'text', 'NO'),
  ('learning_resources', 'detail', 'text', 'NO'),
  ('learning_resources', 'status', 'text', 'NO'),
  ('learning_resources', 'progress', 'integer', 'NO'),
  ('learning_resources', 'modelUrl', 'text', 'NO'),
  ('learning_resources', 'attachments', 'text', 'NO'),
  ('learning_resources', 'color', 'text', 'NO'),
  ('learning_resources', 'inventoryItemId', 'integer', 'YES'),
  ('learning_steps', 'id', 'text', 'NO'),
  ('learning_steps', 'moduleId', 'text', 'NO'),
  ('learning_steps', 'position', 'integer', 'NO'),
  ('learning_steps', 'title', 'text', 'NO'),
  ('learning_steps', 'description', 'text', 'NO'),
  ('learning_steps', 'tip', 'text', 'NO'),
  ('learning_steps', 'imageUrl', 'text', 'YES'),
  ('learning_steps', 'attachments', 'text', 'NO'),
  ('learning_steps', 'quiz', 'text', 'YES'),
  ('student_badges', 'id', 'integer', 'NO'),
  ('student_badges', 'userId', 'integer', 'NO'),
  ('student_badges', 'label', 'text', 'NO'),
  ('student_badges', 'detail', 'text', 'NO'),
  ('student_badges', 'awardedBy', 'integer', 'NO'),
  ('student_badges', 'awardedAt', 'bigint', 'NO'),
  ('student_notes', 'userId', 'integer', 'NO'),
  ('student_notes', 'content', 'text', 'NO'),
  ('student_notes', 'updatedAt', 'bigint', 'NO'),
  ('student_progress', 'id', 'integer', 'NO'),
  ('student_progress', 'userId', 'integer', 'NO'),
  ('student_progress', 'moduleId', 'text', 'NO'),
  ('student_progress', 'stepIndex', 'integer', 'NO'),
  ('student_progress', 'progress', 'integer', 'NO'),
  ('student_progress', 'studiedMinutes', 'integer', 'NO'),
  ('student_progress', 'streakDays', 'integer', 'NO'),
  ('student_progress', 'updatedAt', 'bigint', 'NO'),
  ('student_quiz_attempts', 'id', 'integer', 'NO'),
  ('student_quiz_attempts', 'userId', 'integer', 'NO'),
  ('student_quiz_attempts', 'moduleId', 'text', 'NO'),
  ('student_quiz_attempts', 'stepId', 'text', 'NO'),
  ('student_quiz_attempts', 'selectedIndex', 'integer', 'NO'),
  ('student_quiz_attempts', 'correct', 'integer', 'NO'),
  ('student_quiz_attempts', 'createdAt', 'bigint', 'NO'),
  ('student_step_sessions', 'id', 'integer', 'NO'),
  ('student_step_sessions', 'userId', 'integer', 'NO'),
  ('student_step_sessions', 'moduleId', 'text', 'NO'),
  ('student_step_sessions', 'stepIndex', 'integer', 'NO'),
  ('student_step_sessions', 'startedAt', 'bigint', 'NO'),
  ('student_step_sessions', 'completedAt', 'bigint', 'YES'),
  ('student_step_sessions', 'elapsedSeconds', 'integer', 'NO'),
  ('users', 'id', 'integer', 'NO'),
  ('users', 'openId', 'text', 'NO'),
  ('users', 'name', 'text', 'YES'),
  ('users', 'email', 'text', 'YES'),
  ('users', 'avatarUrl', 'text', 'YES'),
  ('users', 'loginMethod', 'text', 'YES'),
  ('users', 'passwordHash', 'text', 'YES'),
  ('users', 'role', 'text', 'NO'),
  ('users', 'active', 'integer', 'NO'),
  ('users', 'classroomId', 'integer', 'YES'),
  ('users', 'createdAt', 'bigint', 'NO'),
  ('users', 'updatedAt', 'bigint', 'NO'),
  ('users', 'lastSignedIn', 'bigint', 'NO')
)
  SELECT string_agg(e.table_name || '.' || e.column_name, ', ' ORDER BY e.table_name, e.column_name)
  INTO problems
  FROM expected e
  LEFT JOIN information_schema.columns c
    ON c.table_schema = 'public' AND c.table_name = e.table_name AND c.column_name = e.column_name
  WHERE c.column_name IS NULL OR c.data_type <> e.data_type OR c.is_nullable <> e.is_nullable;
  IF problems IS NOT NULL THEN RAISE EXCEPTION 'Verificacao falhou: %', problems; END IF;
  -- Valida inclusive FKs preexistentes que estivessem NOT VALID.
  FOR r IN SELECT conrelid::regclass AS rel, conname FROM pg_constraint
    WHERE contype = 'f' AND NOT convalidated
      AND connamespace = 'public'::regnamespace
      AND conrelid IN ('public.users'::regclass, 'public.auth_sessions'::regclass, 'public.student_badges'::regclass, 'public.learning_modules'::regclass, 'public.learning_steps'::regclass, 'public.learning_resources'::regclass, 'public.student_progress'::regclass, 'public.student_step_sessions'::regclass, 'public.instructors'::regclass, 'public.learning_activities'::regclass, 'public.inventory_categories'::regclass, 'public.inventory_items'::regclass, 'public.inventory_loans'::regclass, 'public.inventory_movements'::regclass, 'public.inventory_audit_log'::regclass, 'public.classrooms'::regclass, 'public.student_notes'::regclass, 'public.student_quiz_attempts'::regclass)
  LOOP
    EXECUTE format('ALTER TABLE %s VALIDATE CONSTRAINT %I', r.rel, r.conname);
  END LOOP;
  FOR r IN SELECT * FROM pg_temp.controllab_upgrade_counts LOOP
    EXECUTE format('SELECT count(*) FROM public.%I', r.table_name) INTO n;
    IF n <> r.before_count THEN RAISE EXCEPTION 'Contagem mudou em %; cancelando.', r.table_name; END IF;
  END LOOP;
END
$verify$;

INSERT INTO public.__drizzle_migrations (hash, created_at)
SELECT '89d1035f1962e40fc3127bb3710e967b80e1db434d3ac87f8eb1cd0ab7a07d3c', 1792710000000
WHERE NOT EXISTS (SELECT 1 FROM public.__drizzle_migrations WHERE created_at = 1792710000000);

INSERT INTO public.__drizzle_migrations (hash, created_at)
SELECT '5d59d7761e593064f429a5a6854d258452d713c53a1018448a432237e4b366f1', 1792800000000
WHERE NOT EXISTS (SELECT 1 FROM public.__drizzle_migrations WHERE created_at = 1792800000000);

INSERT INTO public.__drizzle_migrations (hash, created_at)
SELECT '08c33d2325350985ca80034eeb0ed845a15d6b30d43826f9f6a2f1e000d593b6', 1793000000000
WHERE NOT EXISTS (SELECT 1 FROM public.__drizzle_migrations WHERE created_at = 1793000000000);

INSERT INTO public.__drizzle_migrations (hash, created_at)
SELECT 'efa01d5079939957a6c002bfc215e01e6a19216bf67478ccfbbca3613257c1c3', 1793100000000
WHERE NOT EXISTS (SELECT 1 FROM public.__drizzle_migrations WHERE created_at = 1793100000000);

INSERT INTO public.__drizzle_migrations (hash, created_at)
SELECT '4a1403a0382d18a473e723c49382e71982d35f94a88970fad391293f2807aa39', 1793200000000
WHERE NOT EXISTS (SELECT 1 FROM public.__drizzle_migrations WHERE created_at = 1793200000000);

INSERT INTO public.__drizzle_migrations (hash, created_at)
SELECT '140c664a46b640fd380438271d3faf9f2735f2b29be41930134be7b4c24a532f', 1793300000000
WHERE NOT EXISTS (SELECT 1 FROM public.__drizzle_migrations WHERE created_at = 1793300000000);

INSERT INTO public.__drizzle_migrations (hash, created_at)
SELECT '4ae79f4eabbcd32bb42a59021adf13e4724388e5a6ff39cc23497a4537b06949', 1793400000000
WHERE NOT EXISTS (SELECT 1 FROM public.__drizzle_migrations WHERE created_at = 1793400000000);

COMMIT;

SELECT 'ATUALIZACAO_CONCLUIDA' AS status,
  (SELECT count(*) FROM public.__drizzle_migrations) AS migrations_registradas;
