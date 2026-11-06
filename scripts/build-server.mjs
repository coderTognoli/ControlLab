// Empacota o servidor para produção com NODE_ENV fixado em "production".
// Script em Node puro para funcionar igual no Windows, macOS e Linux.
import { build } from "esbuild";

await build({
  entryPoints: ["server/_core/index.ts"],
  platform: "node",
  packages: "external",
  bundle: true,
  format: "esm",
  outdir: "dist",
  define: { "process.env.NODE_ENV": '"production"' },
  // As dependências externas (Express, tRPC) leem o NODE_ENV real: sem isto, um
  // deploy que esqueça NODE_ENV=production devolveria stack traces ao navegador.
  banner: { js: 'process.env.NODE_ENV ??= "production";' },
  logLevel: "info",
});

// A Function precisa de um bundle proprio: Node ESM nao resolve os imports
// sem extensao nem os aliases TypeScript usados nos fontes do servidor.
await build({
  entryPoints: ["server/vercel.ts"],
  platform: "node",
  packages: "external",
  bundle: true,
  format: "esm",
  outfile: "dist/vercel-api.js",
  define: { "process.env.NODE_ENV": '"production"' },
  banner: { js: 'process.env.NODE_ENV ??= "production";' },
  logLevel: "info",
});
