/** Servidor local: API Express e frontend no mesmo endereco. */
import "dotenv/config";
import { createServer } from "http";
import net from "net";
import { createApiApp } from "./app";
import { checkDatabaseConnection } from "../db";
import { assertServerEnv, ENV } from "./env";
import { serveStatic, setupVite } from "./vite";
function isPortAvailable(port: number): Promise<boolean> {
  return new Promise(resolve => {
    const server = net.createServer();
    server.listen(port, () => {
      server.close(() => resolve(true));
    });
    server.on("error", () => resolve(false));
  });
}

async function findAvailablePort(startPort = 3000): Promise<number> {
  for (let port = startPort; port < startPort + 20; port++) {
    if (await isPortAvailable(port)) return port;
  }
  throw new Error(`Nenhuma porta livre encontrada a partir de ${startPort}`);
}

async function startServer() {
  assertServerEnv();

  const database = await checkDatabaseConnection();
  if (!database.ok) {
    console.error(
      database.provider === "postgres"
        ? `\n[ControlLab] NÃ£o foi possÃ­vel conectar ao Postgres em ${database.file} (${database.error}).\n` +
            "  1. Confira DATABASE_URL no .env (Supabase: Project Settings â†’ Database â†’ Connection string, modo Session pooler).\n" +
            "  2. Confira a senha do banco e se o projeto do Supabase nÃ£o estÃ¡ pausado.\n" +
            "  3. Rode `pnpm db:setup` para criar as tabelas.\n"
        : `\n[ControlLab] NÃ£o foi possÃ­vel abrir o banco SQLite em ${database.file} (${database.error}).\n` +
            "  1. Use o Node.js 22.16 ou mais novo (o SQLite vem embutido no Node).\n" +
            "  2. Confira DATABASE_FILE no arquivo .env.\n" +
            "  3. Rode `pnpm db:setup` para criar o banco, aplicar as migrations e a seed.\n"
    );
  } else if (!database.migrated) {
    console.warn(
      `[ControlLab] O banco ${database.file} ainda nÃ£o tem as tabelas. Rode \`pnpm db:setup\`.`
    );
  } else {
    console.log(
      `[ControlLab] Banco ${database.provider === "postgres" ? "Postgres" : "SQLite"}: ${database.file}`
    );
  }
  if (
    ENV.isProduction &&
    ENV.databaseProvider === "postgres" &&
    (process.env.DATABASE_SSL ?? "require").trim().toLowerCase() === "require"
  ) {
    console.warn(
      "[ControlLab] DATABASE_SSL=require criptografa a conexÃ£o, mas nÃ£o confere o certificado do Postgres. Em produÃ§Ã£o prefira DATABASE_SSL=verify com DATABASE_SSL_CA."
    );
  }

  const app = createApiApp();
  const server = createServer(app);

  if (!ENV.isProduction) {
    await setupVite(app, server);
  } else {
    serveStatic(app);
  }

  const preferredPort = parseInt(process.env.PORT || "3000", 10);
  // Porta ocupada quase sempre Ã© outro `pnpm dev` aberto. Subir em outra porta
  // deixaria dois servidores gravando no mesmo banco (e travando o db:reset).
  if (!(await isPortAvailable(preferredPort))) {
    const free = await findAvailablePort(preferredPort + 1).catch(() => null);
    throw new Error(
      `Porta ${preferredPort} ocupada â€” provavelmente outro Control Lab jÃ¡ estÃ¡ rodando. ` +
        `Feche-o (Ctrl+C no terminal dele) ou escolha outra porta: PORT=${free ?? preferredPort + 1} pnpm dev`
    );
  }
  const port = preferredPort;
  server.listen(port, () => {
    console.log(`Control Lab em http://localhost:${port}/`);
  });
}

startServer().catch(error => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
