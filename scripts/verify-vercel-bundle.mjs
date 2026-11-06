/** Regressao do ERR_MODULE_NOT_FOUND: usa Node ESM nativo, sem tsx/Vitest. */
import assert from "node:assert/strict";
import {
  copyFileSync,
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const temporaryRoot = path.join(root, "tmp");
mkdirSync(temporaryRoot, { recursive: true });
const fixture = mkdtempSync(path.join(temporaryRoot, "vercel-esm-"));
// A copia nao inclui server/, shared/ ou drizzle/. Somente dependencias npm
// continuam disponiveis no node_modules ancestral, como no pacote da Function.
process.env.NODE_ENV = "production";
process.env.DATABASE_PROVIDER = "postgres";
process.env.DATABASE_URL =
  "postgresql://postgres@127.0.0.1:1/unused_bundle_test";
process.env.SESSION_SECRET = "bundle-smoke-test-only-no-real-user-sessions";

let server;
try {
  mkdirSync(path.join(fixture, "api"));
  mkdirSync(path.join(fixture, "dist"));
  writeFileSync(path.join(fixture, "package.json"), '{"type":"module"}\n');
  copyFileSync(
    path.join(root, "api/index.js"),
    path.join(fixture, "api/index.js")
  );
  copyFileSync(
    path.join(root, "dist/vercel-api.js"),
    path.join(fixture, "dist/vercel-api.js")
  );
  const { default: app } = await import(
    pathToFileURL(path.join(fixture, "api/index.js")).href
  );
  server = app.listen(0, "127.0.0.1");
  await new Promise((resolve, reject) => {
    server.once("listening", resolve);
    server.once("error", reject);
  });
  const origin = `http://127.0.0.1:${server.address().port}`;
  // Sem cookies, auth.me deve funcionar sem consultar qualquer banco.
  const anonymous = await fetch(`${origin}/api/trpc/auth.me?batch=1`);
  assert.equal(anonymous.status, 200);
  assert.equal((await anonymous.json())[0].result.data.json, null);
  const info = await fetch(`${origin}/api/trpc/system.info`);
  assert.equal(info.status, 200);
  assert.equal((await info.json()).result.data.json.environment, "production");
  console.log(
    "OK: bundle carregado por Node ESM sem fontes TS; auth.me anonimo e system.info retornam HTTP 200."
  );
} finally {
  if (server?.listening) {
    server.closeAllConnections();
    await new Promise((resolve, reject) =>
      server.close(error => (error ? reject(error) : resolve()))
    );
  }
  const resolvedFixture = path.resolve(fixture);
  if (
    path.dirname(resolvedFixture) !== temporaryRoot ||
    !path.basename(resolvedFixture).startsWith("vercel-esm-")
  ) {
    throw new Error("Diretorio temporario fora do destino esperado.");
  }
  rmSync(resolvedFixture, { recursive: true, force: true });
}
