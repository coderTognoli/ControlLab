/** Atualizacao assistida da baseline existente; nunca conecta no banco remoto. */
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const folder = path.join(root, "drizzle/postgres");
const journal = JSON.parse(readFileSync(path.join(folder, "meta/_journal.json"), "utf8"));
if (journal.entries.length !== 7) throw new Error("Revisar gerador para novas migrations.");
const literal = value => `'${String(value).replaceAll("'", "''")}'`;
const audit = readFileSync(path.join(root, "docs/sql/auditoria_colunas_supabase.sql"), "utf8");
const cte = audit.slice(audit.indexOf("WITH expected("), audit.indexOf("\nSELECT e.table_name"));
if (!cte.startsWith("WITH expected(") || !cte.trimEnd().endsWith(")")) throw new Error("Auditoria invalida.");
const baseline = readFileSync(path.join(folder, "0000_controllab_baseline.sql"), "utf8");
const baseTables = [...baseline.matchAll(/CREATE TABLE IF NOT EXISTS "(\w+)"/g)].map(m => m[1]);
const addedColumns = [
  "inventory_items.icon", "inventory_loans.classroomId", "inventory_movements.classroomId",
  "learning_activities.createdBy", "learning_modules.archivedAt", "learning_resources.attachments",
  "learning_steps.attachments", "learning_steps.quiz", "users.classroomId",
];
const migrations = journal.entries.map(entry => {
  const content = readFileSync(path.join(folder, `${entry.tag}.sql`), "utf8");
  const statements = content.split("--> statement-breakpoint").map(part => part.replace(/^\s*--[^\n]*$/gm, "").trim()).filter(Boolean);
  const retained = statements.filter(statement => !/^(DELETE\s+FROM|UPDATE\s+")/i.test(statement));
  // Escopo da verificacao de FKs: nomes iguais em outras tabelas nao devem oculta-las.
  const sql = retained.join("\n\n").replace(
    /WHERE conname = '([^']+)'\) THEN\s+ALTER TABLE "([^"]+)"/g,
    (_, constraint, table) => `WHERE conname = '${constraint}' AND conrelid = 'public.${table}'::regclass) THEN\n    ALTER TABLE "${table}"`,
  );
  if (/^\s*(DELETE\s+FROM|UPDATE\s+"|TRUNCATE|DROP\s+TABLE)\b/im.test(sql)) throw new Error(`DML inesperada: ${entry.tag}`);
  return { ...entry, sql, hash: createHash("sha256").update(content).digest("hex") };
});

const output = `-- ControlLab: atualizar o banco existente, preservando dados.
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
  ${cte}
  SELECT string_agg(e.table_name || '.' || e.column_name, ', ' ORDER BY e.table_name, e.column_name)
  INTO problems
  FROM expected e
  LEFT JOIN information_schema.columns c
    ON c.table_schema = 'public' AND c.table_name = e.table_name AND c.column_name = e.column_name
  WHERE e.table_name IN (${baseTables.map(literal).join(", ")})
    AND e.table_name || '.' || e.column_name NOT IN (${addedColumns.map(literal).join(", ")})
    AND (c.column_name IS NULL OR c.data_type <> e.data_type OR c.is_nullable <> e.is_nullable);
  IF problems IS NOT NULL THEN
    RAISE EXCEPTION 'Baseline incompativel; nada sera aplicado. Colunas: %', problems;
  END IF;
END
$preflight$;

-- Evita escritas concorrentes durante contagem, validacao e mudancas de schema.
LOCK TABLE ${baseTables.map(table => `public."${table}"`).join(", ")} IN SHARE ROW EXCLUSIVE MODE;
CREATE TEMP TABLE controllab_upgrade_counts (table_name text PRIMARY KEY, before_count bigint) ON COMMIT DROP;
DO $counts$
DECLARE t text; n bigint;
BEGIN
  FOREACH t IN ARRAY ARRAY[${baseTables.map(literal).join(", ")}]
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
      SELECT 1 FROM (VALUES ${migrations.map(m => `(${literal(m.hash)}, ${m.when}::bigint)`).join(",\n        ")}) expected(hash, created_at)
      WHERE expected.hash = h.hash AND expected.created_at = h.created_at
    )
  ) OR EXISTS (SELECT 1 FROM public.__drizzle_migrations GROUP BY created_at HAVING count(*) > 1) THEN
    RAISE EXCEPTION 'Historico desconhecido ou duplicado; revisar antes de atualizar.';
  END IF;
END
$history$;

${migrations.map(m => `-- ${m.tag}\n${m.sql}`).join("\n\n")}

-- Confirma todas as colunas antes de registrar o estado reconciliado.
DO $verify$
DECLARE problems text; r record; n bigint;
BEGIN
  ${cte}
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
      AND conrelid IN (${[...baseTables, "classrooms", "student_notes", "student_quiz_attempts"].map(t => `'public.${t}'::regclass`).join(", ")})
  LOOP
    EXECUTE format('ALTER TABLE %s VALIDATE CONSTRAINT %I', r.rel, r.conname);
  END LOOP;
  FOR r IN SELECT * FROM pg_temp.controllab_upgrade_counts LOOP
    EXECUTE format('SELECT count(*) FROM public.%I', r.table_name) INTO n;
    IF n <> r.before_count THEN RAISE EXCEPTION 'Contagem mudou em %; cancelando.', r.table_name; END IF;
  END LOOP;
END
$verify$;

${migrations.map(m => `INSERT INTO public.__drizzle_migrations (hash, created_at)\nSELECT ${literal(m.hash)}, ${m.when}\nWHERE NOT EXISTS (SELECT 1 FROM public.__drizzle_migrations WHERE created_at = ${m.when});`).join("\n\n")}

COMMIT;

SELECT 'ATUALIZACAO_CONCLUIDA' AS status,
  (SELECT count(*) FROM public.__drizzle_migrations) AS migrations_registradas;
`;
writeFileSync(path.join(root, "docs/sql/atualizar_banco_controllab.sql"), output, "utf8");
console.log("SQL gerado: docs/sql/atualizar_banco_controllab.sql (sem DELETE/UPDATE nos dados existentes).");
