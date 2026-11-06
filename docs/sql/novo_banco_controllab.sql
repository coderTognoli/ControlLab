-- ControlLab: estrutura completa para um NOVO banco PostgreSQL/Supabase.
-- Gerado por: node scripts/export-new-postgres.mjs
-- Nao executar para atualizar banco antigo; usa bloqueio de colisao e transacao.
-- Nao copia contas, conteudo ou estoque do banco antigo.
-- Sem seed e sem troca automatica do DATABASE_URL.
-- Historico Drizzle registra o estado equivalente a 0000..0006 em banco vazio.

BEGIN;
SET LOCAL search_path = public;
SELECT pg_advisory_xact_lock(hashtext('controllab_new_database_bootstrap'));

-- Recusa qualquer tabela do aplicativo ja existente, inclusive em outra sessao.
DO $guard$
DECLARE collisions text;
BEGIN
  SELECT string_agg(c.relname, ', ' ORDER BY c.relname) INTO collisions
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('auth_sessions', 'classrooms', 'instructors', 'inventory_audit_log', 'inventory_categories', 'inventory_items', 'inventory_loans', 'inventory_movements', 'learning_activities', 'learning_modules', 'learning_resources', 'learning_steps', 'student_badges', 'student_notes', 'student_progress', 'student_quiz_attempts', 'student_step_sessions', 'users', '__drizzle_migrations');
  IF collisions IS NOT NULL THEN
    RAISE EXCEPTION 'Banco nao esta vazio para o ControlLab. Nada foi alterado. Objetos: %', collisions;
  END IF;
  IF to_regprocedure('public.unixepoch()') IS NOT NULL
     OR to_regprocedure('public.controllab_fill_serial_id()') IS NOT NULL THEN
    RAISE EXCEPTION 'Funcoes ControlLab ja existem. Nada foi alterado. Use um projeto novo.';
  END IF;
END
$guard$;

CREATE TABLE public.__drizzle_migrations (
  id serial PRIMARY KEY,
  hash text NOT NULL,
  created_at bigint
);
ALTER TABLE public.__drizzle_migrations ENABLE ROW LEVEL SECURITY;

-- 0000_controllab_baseline
CREATE FUNCTION public.unixepoch() RETURNS bigint
LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT floor(extract(epoch FROM now()))::bigint
$$;

CREATE FUNCTION public.controllab_fill_serial_id() RETURNS trigger
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
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'learning_resources_inventory_fk') THEN
    ALTER TABLE "learning_resources" ADD CONSTRAINT "learning_resources_inventory_fk"
      FOREIGN KEY ("inventoryItemId") REFERENCES "inventory_items"("id") ON UPDATE cascade ON DELETE set null;
  END IF;
END
$$;

CREATE TRIGGER "users_fill_id" BEFORE INSERT ON "users" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

CREATE TRIGGER "student_badges_fill_id" BEFORE INSERT ON "student_badges" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

CREATE TRIGGER "student_progress_fill_id" BEFORE INSERT ON "student_progress" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

CREATE TRIGGER "student_step_sessions_fill_id" BEFORE INSERT ON "student_step_sessions" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

CREATE TRIGGER "instructors_fill_id" BEFORE INSERT ON "instructors" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

CREATE TRIGGER "inventory_categories_fill_id" BEFORE INSERT ON "inventory_categories" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

CREATE TRIGGER "inventory_items_fill_id" BEFORE INSERT ON "inventory_items" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

CREATE TRIGGER "inventory_loans_fill_id" BEFORE INSERT ON "inventory_loans" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

CREATE TRIGGER "inventory_movements_fill_id" BEFORE INSERT ON "inventory_movements" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

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

INSERT INTO public.__drizzle_migrations (hash, created_at) VALUES ('89d1035f1962e40fc3127bb3710e967b80e1db434d3ac87f8eb1cd0ab7a07d3c', 1792710000000);

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

INSERT INTO public.__drizzle_migrations (hash, created_at) VALUES ('5d59d7761e593064f429a5a6854d258452d713c53a1018448a432237e4b366f1', 1792800000000);

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

CREATE TRIGGER "classrooms_fill_id" BEFORE INSERT ON "classrooms" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

ALTER TABLE "classrooms" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "classroomId" integer REFERENCES "classrooms"("id") ON DELETE set null;

CREATE INDEX IF NOT EXISTS "users_classroom_idx" ON "users" ("classroomId");

ALTER TABLE "inventory_loans" ADD COLUMN IF NOT EXISTS "classroomId" integer REFERENCES "classrooms"("id") ON DELETE set null;

ALTER TABLE "inventory_movements" ADD COLUMN IF NOT EXISTS "classroomId" integer REFERENCES "classrooms"("id") ON DELETE set null;

INSERT INTO public.__drizzle_migrations (hash, created_at) VALUES ('08c33d2325350985ca80034eeb0ed845a15d6b30d43826f9f6a2f1e000d593b6', 1793000000000);

-- 0003_module_attachments
ALTER TABLE "learning_resources" ADD COLUMN IF NOT EXISTS "attachments" text DEFAULT '[]' NOT NULL;

ALTER TABLE "learning_steps" ADD COLUMN IF NOT EXISTS "attachments" text DEFAULT '[]' NOT NULL;

INSERT INTO public.__drizzle_migrations (hash, created_at) VALUES ('efa01d5079939957a6c002bfc215e01e6a19216bf67478ccfbbca3613257c1c3', 1793100000000);

-- 0004_inventory_item_icon
ALTER TABLE "inventory_items" ADD COLUMN IF NOT EXISTS "icon" text;

INSERT INTO public.__drizzle_migrations (hash, created_at) VALUES ('4a1403a0382d18a473e723c49382e71982d35f94a88970fad391293f2807aa39', 1793200000000);

-- 0005_learning_foreign_keys
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'student_progress_user_fk') THEN
    ALTER TABLE "student_progress" ADD CONSTRAINT "student_progress_user_fk"
      FOREIGN KEY ("userId") REFERENCES "users"("id") ON UPDATE no action ON DELETE cascade;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'student_progress_module_fk') THEN
    ALTER TABLE "student_progress" ADD CONSTRAINT "student_progress_module_fk"
      FOREIGN KEY ("moduleId") REFERENCES "learning_modules"("id") ON UPDATE cascade ON DELETE cascade;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'student_step_sessions_user_fk') THEN
    ALTER TABLE "student_step_sessions" ADD CONSTRAINT "student_step_sessions_user_fk"
      FOREIGN KEY ("userId") REFERENCES "users"("id") ON UPDATE no action ON DELETE cascade;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'student_step_sessions_module_fk') THEN
    ALTER TABLE "student_step_sessions" ADD CONSTRAINT "student_step_sessions_module_fk"
      FOREIGN KEY ("moduleId") REFERENCES "learning_modules"("id") ON UPDATE cascade ON DELETE cascade;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'student_badges_user_fk') THEN
    ALTER TABLE "student_badges" ADD CONSTRAINT "student_badges_user_fk"
      FOREIGN KEY ("userId") REFERENCES "users"("id") ON UPDATE no action ON DELETE cascade;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'learning_steps_module_fk') THEN
    ALTER TABLE "learning_steps" ADD CONSTRAINT "learning_steps_module_fk"
      FOREIGN KEY ("moduleId") REFERENCES "learning_modules"("id") ON UPDATE cascade ON DELETE cascade;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'learning_resources_module_fk') THEN
    ALTER TABLE "learning_resources" ADD CONSTRAINT "learning_resources_module_fk"
      FOREIGN KEY ("moduleId") REFERENCES "learning_modules"("id") ON UPDATE cascade ON DELETE cascade;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'learning_activities_module_fk') THEN
    ALTER TABLE "learning_activities" ADD CONSTRAINT "learning_activities_module_fk"
      FOREIGN KEY ("moduleId") REFERENCES "learning_modules"("id") ON UPDATE cascade ON DELETE cascade;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'learning_activities_created_by_fk') THEN
    ALTER TABLE "learning_activities" ADD CONSTRAINT "learning_activities_created_by_fk"
      FOREIGN KEY ("createdBy") REFERENCES "users"("id") ON UPDATE no action ON DELETE set null;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'learning_modules_created_by_fk') THEN
    ALTER TABLE "learning_modules" ADD CONSTRAINT "learning_modules_created_by_fk"
      FOREIGN KEY ("createdBy") REFERENCES "users"("id") ON UPDATE no action ON DELETE set null;
  END IF;
END
$$;

INSERT INTO public.__drizzle_migrations (hash, created_at) VALUES ('140c664a46b640fd380438271d3faf9f2735f2b29be41930134be7b4c24a532f', 1793300000000);

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

CREATE TRIGGER "student_quiz_attempts_fill_id" BEFORE INSERT ON "student_quiz_attempts" FOR EACH ROW EXECUTE FUNCTION public.controllab_fill_serial_id();

ALTER TABLE "student_quiz_attempts" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "learning_steps" ADD COLUMN IF NOT EXISTS "quiz" text;

INSERT INTO public.__drizzle_migrations (hash, created_at) VALUES ('4ae79f4eabbcd32bb42a59021adf13e4724388e5a6ff39cc23497a4537b06949', 1793400000000);

COMMIT;
