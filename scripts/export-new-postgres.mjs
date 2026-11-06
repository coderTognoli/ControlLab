/** Exporta a estrutura atual para um banco NOVO, sem acessar banco ou segredos. */
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const folder = path.join(root, "drizzle", "postgres");
const journal = JSON.parse(readFileSync(path.join(folder, "meta", "_journal.json"), "utf8"));
const snapshot = JSON.parse(readFileSync(path.join(root, "drizzle", "meta", "0006_snapshot.json"), "utf8"));
const quote = value => `'${String(value).replaceAll("'", "''")}'`;
const appTables = [...Object.keys(snapshot.tables), "__drizzle_migrations"];
const definitions = new Map();
const migrations = [];

for (const entry of journal.entries) {
  const original = readFileSync(path.join(folder, `${entry.tag}.sql`), "utf8");
  const statements = [];
  for (const part of original.split("--> statement-breakpoint")) {
    const statement = part.replace(/^\s*--[^\n]*$/gm, "").trim();
    if (!statement) continue;
    // Limpeza de dados antigos nao se aplica a um banco novo e vazio.
    if (/^(DELETE\s+FROM|UPDATE\s+"|DROP\s+TRIGGER|DROP\s+INDEX)\b/i.test(statement)) continue;
    // A migration 0005 remove este indice redundante; nao o criar no banco novo.
    if (/^CREATE INDEX IF NOT EXISTS "student_progress_user_module_idx"/.test(statement)) continue;
    const safe = statement.replace(/CREATE OR REPLACE FUNCTION/g, "CREATE FUNCTION");
    if (/^\s*(DELETE|UPDATE|DROP|TRUNCATE)\b/im.test(safe)) {
      throw new Error(`Operacao inesperada no bootstrap: ${entry.tag}`);
    }
    for (const table of safe.matchAll(/CREATE TABLE IF NOT EXISTS "(\w+)" \(([\s\S]*?)\n\);/g)) {
      for (const column of table[2].matchAll(/^\s*"(\w+)" (serial|integer|bigint|text)\b/gm)) {
        definitions.set(`${table[1]}.${column[1]}`, column[2]);
      }
    }
    for (const column of safe.matchAll(/ALTER TABLE "(\w+)" ADD COLUMN IF NOT EXISTS "(\w+)" (integer|bigint|text)\b/g)) {
      definitions.set(`${column[1]}.${column[2]}`, column[3]);
    }
    statements.push(safe);
  }
  const hash = createHash("sha256").update(original).digest("hex");
  migrations.push(`-- ${entry.tag}\n${statements.join("\n\n")}\n\nINSERT INTO public.__drizzle_migrations (hash, created_at) VALUES (${quote(hash)}, ${entry.when});`);
}

let columnCount = 0;
for (const table of Object.values(snapshot.tables)) {
  for (const column of Object.values(table.columns)) {
    const key = `${table.name}.${column.name}`;
    const actualType = definitions.get(key);
    if (!actualType || (column.type === "text" ? actualType !== "text" : !["integer", "bigint", "serial"].includes(actualType))) {
      throw new Error(`Coluna ausente ou incompativel no SQL: ${key}`);
    }
    definitions.delete(key);
    columnCount++;
  }
}
if (definitions.size) throw new Error(`Colunas fora do schema: ${[...definitions.keys()].join(", ")}`);

const output = `-- ControlLab: estrutura completa para um NOVO banco PostgreSQL/Supabase.
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
    AND c.relname IN (${appTables.map(quote).join(", ")});
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

${migrations.join("\n\n")}

COMMIT;
`;
const destination = path.join(root, "docs", "sql", "novo_banco_controllab.sql");
mkdirSync(path.dirname(destination), { recursive: true });
writeFileSync(destination, output, "utf8");
console.log(`SQL gerado: docs/sql/novo_banco_controllab.sql (${Object.keys(snapshot.tables).length} tabelas, ${columnCount} colunas, ${journal.entries.length} migrations).`);
