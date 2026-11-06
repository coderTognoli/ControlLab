/** API Express compartilhada pelo servidor local e pela Function da Vercel. */
import express from "express";
import { createExpressMiddleware } from "@trpc/server/adapters/express";
import { registerStorageProxy } from "./storageProxy";
import { registerAttachmentUpload } from "../attachmentUpload";
import { appRouter } from "../routers";
import { createContext } from "./context";
import { ENV } from "./env";
import { sdk } from "./sdk";
const SMALL_BODY_LIMIT = "1mb";
// Imagens enviadas no editor chegam em base64; o limite cobre capa + etapas.
const LARGE_BODY_LIMIT = "25mb";
const LARGE_UPLOAD_PROCEDURES = new Set([
  "learning.saveModule",
  "profile.uploadAvatar",
]);

/**
 * SÃ³ executa scripts do prÃ³prio servidor (nenhum inline: o tema inicial vem de
 * /theme-init.js). Estilos inline ficam liberados porque o React e as animaÃ§Ãµes
 * usam `style=`. Imagens e modelos 3D podem vir de links HTTPS que o docente cadastra.
 */
const CONTENT_SECURITY_POLICY = [
  "default-src 'self'",
  "script-src 'self'",
  "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
  "font-src 'self' data: https://fonts.gstatic.com",
  "img-src 'self' data: blob: https:",
  "connect-src 'self' https:",
  "media-src 'self' blob: https:",
  "object-src 'none'",
  "base-uri 'self'",
  "form-action 'self'",
  "frame-ancestors 'self'",
].join("; ");

/** `/learning.saveModule` ou um lote (`/a,b`) em que todas as chamadas aceitam corpo grande. */
function isLargeUploadPath(path: string) {
  const procedures = path.replace(/^\//, "").split(",");
  return (
    procedures.length > 0 &&
    procedures.every(name => LARGE_UPLOAD_PROCEDURES.has(name))
  );
}

export function createApiApp() {
  const app = express();
  app.disable("x-powered-by");
  if (ENV.trustProxy !== undefined) app.set("trust proxy", ENV.trustProxy);

  app.use((_req, res, next) => {
    res.setHeader("X-Content-Type-Options", "nosniff");
    res.setHeader("Referrer-Policy", "same-origin");
    res.setHeader("X-Frame-Options", "SAMEORIGIN");
    // Em desenvolvimento o Vite injeta scripts inline (HMR); a CSP vale no build de produÃ§Ã£o.
    if (ENV.isProduction)
      res.setHeader("Content-Security-Policy", CONTENT_SECURITY_POLICY);
    next();
  });
  // Corpo pequeno por padrÃ£o. SÃ³ o editor e a foto de perfil (imagens em base64)
  // aceitam corpos grandes, e apenas de quem apresenta uma sessÃ£o assinada: um
  // visitante anÃ´nimo nÃ£o consegue fazer o servidor ler 25 MB.
  const smallJson = express.json({ limit: SMALL_BODY_LIMIT });
  const largeJson = express.json({ limit: LARGE_BODY_LIMIT });
  app.use("/api/trpc", (req, res, next) => {
    if (!isLargeUploadPath(req.path)) return smallJson(req, res, next);
    sdk
      .hasValidSignature(req)
      .then(signed => (signed ? largeJson : smallJson)(req, res, next), next);
  });
  registerAttachmentUpload(app);
  app.use(express.json({ limit: SMALL_BODY_LIMIT }));
  app.use(express.urlencoded({ limit: "1mb", extended: false }));
  registerStorageProxy(app);
  app.use(
    "/api/trpc",
    createExpressMiddleware({
      router: appRouter,
      createContext,
      maxBodySize: 25 * 1024 * 1024,
      onError: ({ error, path }) => {
        if (error.code === "INTERNAL_SERVER_ERROR")
          console.error(`[tRPC] ${path ?? "?"}:`, error);
      },
    })
  );
  app.use("/api", (_req, res) =>
    res.status(404).json({ error: "Rota de API inexistente" })
  );

  return app;
}
