/** Integracao em PostgreSQL local DESCARTAVEL, iniciado separadamente na porta 55439. */
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const psql = "C:/Program Files/PostgreSQL/17/bin/psql.exe";
const args = ["-X", "-w", "-h", "127.0.0.1", "-p", "55439", "-U", "postgres", "-v", "ON_ERROR_STOP=1", "-At"];
const run = (db, sql) => execFileSync(psql, [...args, "-d", db], { input: sql, encoding: "utf8", stdio: ["pipe", "pipe", "pipe"] }).trim();
const baseline = readFileSync(path.join(root, "drizzle/postgres/0000_controllab_baseline.sql"), "utf8");
const upgrade = readFileSync(path.join(root, "docs/sql/atualizar_banco_controllab.sql"), "utf8");
const audit = readFileSync(path.join(root, "docs/sql/auditoria_colunas_supabase.sql"), "utf8");
const tables = [...baseline.matchAll(/CREATE TABLE IF NOT EXISTS "(\w+)"/g)].map(m => m[1]);
// Retira somente colunas novas de cada tabela; createdBy/archivedAt ja existiam em outras.
const additions = {
  users: ["classroomId"], inventory_items: ["icon"], inventory_loans: ["classroomId"],
  inventory_movements: ["classroomId"], learning_activities: ["createdBy"],
  learning_modules: ["archivedAt"], learning_resources: ["attachments"], learning_steps: ["attachments", "quiz"],
};
const snapshot = db => Object.fromEntries(tables.map(t => {
  const remove = (additions[t] ?? []).map(c => `'${c}'`).join(",");
  const row = remove ? `to_jsonb(t) - ARRAY[${remove}]::text[]` : "to_jsonb(t)";
  return [t, JSON.parse(run(db, `SELECT coalesce(jsonb_agg(r ORDER BY r::text), '[]'::jsonb) FROM (SELECT ${row} AS r FROM public."${t}" t) s;`))];
}));
const fixture = `
INSERT INTO users ("openId", name, email, "passwordHash") VALUES ('local-test', 'Aluno preservado', 'local@example.test', 'hash-preservado');
INSERT INTO learning_modules (id, code, title, kind, description, objective, cover, duration, "createdBy")
 VALUES ('m1', 'M1', 'Modulo preservado', 'test', 'descricao', 'objetivo', 'cover', '30 min', 1);
INSERT INTO student_progress ("userId", "moduleId", progress, "studiedMinutes") VALUES (1, 'm1', 75, 42);
INSERT INTO student_step_sessions ("userId", "moduleId", "stepIndex", "elapsedSeconds") VALUES (1, 'm1', 0, 120);
INSERT INTO student_badges ("userId", label, detail, "awardedBy") VALUES (1, 'Conquista', 'Detalhe', 1);
INSERT INTO learning_steps (id, "moduleId", position, title, description, tip) VALUES ('s1', 'm1', 0, 'Etapa', 'Descricao', 'Dica');
INSERT INTO learning_resources (id, "moduleId", category, label, title, detail, status, "modelUrl", color)
 VALUES ('r1', 'm1', 'test', 'Recurso', 'Titulo', 'Detalhe', 'test', 'model', 'blue');
INSERT INTO learning_activities (id, "moduleId", title, subtitle, "activityType", "startsAt", "endsAt", color)
 VALUES ('a1', 'm1', 'Atividade', 'Subtitulo', 'test', 1000, 2000, 'blue');
INSERT INTO inventory_categories (name, "createdBy") VALUES ('Categoria', 1);
INSERT INTO inventory_items (code, name, "itemType", "categoryId", sector, location, "quantityPhysical", "quantityReserved", "createdBy")
 VALUES ('ITEM-1', 'Ferramenta preservada', 'tool', 1, 'Oficina', 'A1', 12, 3, 1);
INSERT INTO inventory_loans ("itemId", "borrowerUserId", "borrowerName", quantity, purpose, "moduleId", "createdBy")
 VALUES (1, 1, 'Aluno', 3, 'Aula', 'm1', 1);
INSERT INTO inventory_movements ("itemId", "movementType", quantity, "physicalBefore", "physicalAfter", "reservedBefore", "reservedAfter", reason, "loanId", "moduleId", "itemCodeSnapshot", "itemNameSnapshot", "unitSnapshot", "userId")
 VALUES (1, 'reserve', 3, 12, 12, 0, 3, 'Aula', 1, 'm1', 'ITEM-1', 'Ferramenta preservada', 'UN', 1);
INSERT INTO inventory_audit_log ("entityType", "entityId", action, changes, "userId") VALUES ('item', 1, 'create', '{}', 1);
INSERT INTO instructors (name, role, badge, initials) VALUES ('Professor', 'teacher', 'badge', 'PR');
INSERT INTO auth_sessions (jti, "openId", "expiresAt") VALUES ('session-local', 'local-test', 2000000000000);
`;

const suffix = Date.now();
const success = `cl_upgrade_ok_${suffix}`;
const orphan = `cl_upgrade_orphan_${suffix}`;
const incompatible = `cl_upgrade_type_${suffix}`;
for (const db of [success, orphan, incompatible]) {
  run("postgres", `CREATE DATABASE "${db}";`);
  run(db, baseline + fixture);
}
const before = snapshot(success);
assert.match(run(success, upgrade), /ATUALIZACAO_CONCLUIDA\|7/);
assert.deepEqual(snapshot(success), before, "Todas as colunas e linhas preexistentes devem permanecer iguais");
assert.equal(run(success, audit), "");
assert.equal(run(success, `SELECT count(*) FROM learning_steps WHERE attachments = '[]';`), "1");
assert.equal(run(success, `SELECT count(*) FROM pg_class WHERE relnamespace='public'::regnamespace AND relkind='r' AND relrowsecurity;`), "19");
assert.equal(run(success, `SELECT count(*) FROM pg_constraint WHERE contype='f' AND NOT convalidated AND connamespace='public'::regnamespace;`), "0");
assert.match(run(success, upgrade), /ATUALIZACAO_CONCLUIDA\|7/, "Reexecucao nao duplica historico/dados");
assert.deepEqual(snapshot(success), before);
run(success, `INSERT INTO classrooms (id, name, "teacherId") VALUES (NULL, 'Turma local', 1);
INSERT INTO student_notes ("userId", content) VALUES (1, '["Nota"]');
INSERT INTO student_quiz_attempts (id, "userId", "moduleId", "stepId", "selectedIndex", correct) VALUES (NULL, 1, 'm1', 's1', 0, 1);`);
assert.equal(run(success, `SELECT count(*) FROM classrooms WHERE id IS NOT NULL;`), "1");
assert.equal(run(success, `SELECT count(*) FROM student_quiz_attempts WHERE id IS NOT NULL;`), "1");
console.log("OK: atualizacao, preservacao integral de 15 tabelas, RLS, colunas, reexecucao e insercoes nas novas tabelas.");

run(orphan, `INSERT INTO student_progress ("userId", "moduleId") VALUES (999, 'm1');`);
const orphanBefore = snapshot(orphan);
const failed = spawnSync(psql, [...args, "-d", orphan], { input: upgrade, encoding: "utf8" });
assert.notEqual(failed.status, 0);
assert.match(failed.stderr, /student_progress_user_fk/);
assert.deepEqual(snapshot(orphan), orphanBefore);
assert.equal(run(orphan, `SELECT to_regclass('public.classrooms') IS NULL AND to_regclass('public.__drizzle_migrations') IS NULL;`), "t");
console.log("OK: registro orfao causa rollback integral; sem exclusao nem historico falso.");

run(incompatible, `ALTER TABLE inventory_items ALTER COLUMN "quantityPhysical" TYPE bigint;`);
const badTypeBefore = snapshot(incompatible);
const badType = spawnSync(psql, [...args, "-d", incompatible], { input: upgrade, encoding: "utf8" });
assert.notEqual(badType.status, 0);
assert.match(badType.stderr, /Baseline incompativel/);
assert.deepEqual(snapshot(incompatible), badTypeBefore);
console.log("OK: divergencia de tipo impede atualizacao sem alterar dados.");
// Bancos permanecem apenas no cluster temporario para inspecao; nao toca no Supabase.
console.log(`Bancos locais de teste: ${success}, ${orphan}, ${incompatible}`);
