/** Entrada Node da Vercel; nao inicia porta, Vite, seed ou migrations. */
import "dotenv/config";
import { createApiApp } from "../server/_core/app";
import { assertServerEnv, ENV } from "../server/_core/env";

assertServerEnv();
if (ENV.databaseProvider !== "postgres") {
  throw new Error(
    "Na Vercel, configure DATABASE_PROVIDER=postgres e DATABASE_URL para o banco existente."
  );
}

const app = createApiApp();
export default app;
