/** Entrada HTTP da API na Vercel; não abre porta nem grava no disco local. */
import "dotenv/config";
import express from "express";
import { createExpressMiddleware } from "@trpc/server/adapters/express";
import { appRouter } from "../routers";
import { createContext } from "./context";
import { assertServerEnv, ENV } from "./env";
import { checkDatabaseConnection } from "../db";

const app = express();
app.disable("x-powered-by");
app.use((_req, res, next) => {
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("X-Frame-Options", "SAMEORIGIN");
  res.setHeader("Referrer-Policy", "same-origin");
  res.setHeader("Cache-Control", "no-store");
  next();
});
app.use(express.json({ limit: "4mb" }));
app.use(express.urlencoded({ extended: false, limit: "1mb" }));

function configurationError(): string | null {
  try {
    assertServerEnv();
    if (ENV.databaseProvider !== "postgres") {
      return "Na Vercel, configure DATABASE_PROVIDER=postgres e DATABASE_URL. O SQLite local não é persistente.";
    }
    return null;
  } catch {
    return "Configure SESSION_SECRET (mínimo 32 caracteres), DATABASE_PROVIDER=postgres e DATABASE_URL na Vercel.";
  }
}

app.get("/api/health", async (_req, res) => {
  const error = configurationError();
  if (error) {
    res.status(503).json({ configured: false, error });
    return;
  }
  const database = await checkDatabaseConnection();
  res.status(database.ok && database.migrated ? 200 : 503).json({
    configured: true,
    database: { connected: database.ok, migrated: database.migrated },
  });
});

app.use("/api/trpc", (req, res, next) => {
  // Consultar uma sessão anônima permite exibir o login antes de conectar o banco.
  if (req.method === "GET" && req.path === "/auth.me") return next();
  const error = configurationError();
  if (error) {
    res.status(503).json({ error });
    return;
  }
  next();
});
app.use("/api/trpc", createExpressMiddleware({
  router: appRouter,
  createContext,
  onError: ({ error, path }) => {
    if (error.code === "INTERNAL_SERVER_ERROR") console.error(`[tRPC] ${path ?? "?"}:`, error);
  },
}));
app.use((_req, res) => res.status(404).json({ error: "Rota de API inexistente" }));

export default app;
