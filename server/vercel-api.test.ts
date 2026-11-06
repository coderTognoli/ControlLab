import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import type { Server } from "node:http";
import type { AddressInfo } from "node:net";

// O limite testado e HTTP -> API; nao usa contas nem banco de producao.
vi.mock("./db", async importOriginal => ({
  ...(await importOriginal<typeof import("./db")>()),
  checkDatabaseConnection: vi.fn(async () => ({
    ok: true,
    migrated: true,
    provider: "postgres",
    file: "postgres://local/test",
  })),
}));

const { createApiApp } = await import("./_core/app");
let server: Server;
let origin: string;

beforeAll(async () => {
  server = createApiApp().listen(0, "127.0.0.1");
  await new Promise<void>(resolve => server.once("listening", resolve));
  origin = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});
afterAll(async () => {
  await new Promise<void>((resolve, reject) =>
    server.close(error => (error ? reject(error) : resolve()))
  );
});

describe("entrada HTTP compartilhada com a Vercel", () => {
  it("responde health no caminho completo usado pelo site", async () => {
    const response = await fetch(`${origin}/api/trpc/system.health`);
    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toContain("application/json");
    expect((await response.json()).result.data.json.database).toMatchObject({
      ok: true,
      provider: "postgres",
    });
    expect(response.headers.get("x-powered-by")).toBeNull();
  });

  it("preserva chamadas em lote do cliente tRPC", async () => {
    const response = await fetch(
      `${origin}/api/trpc/system.info,system.health?batch=1`
    );
    expect(response.status).toBe(200);
    const results = await response.json();
    expect(results).toHaveLength(2);
    expect(results[1].result.data.json.database.ok).toBe(true);
  });

  it("encaminha POST para a validacao tRPC sem cair no HTML", async () => {
    const response = await fetch(`${origin}/api/trpc/auth.login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ json: {} }),
    });
    expect(response.status).toBe(400);
    expect((await response.json()).error.json.data.code).toBe("BAD_REQUEST");
  });

  it("retorna 404 JSON para API desconhecida", async () => {
    const response = await fetch(`${origin}/api/inexistente`);
    expect(response.status).toBe(404);
    expect(await response.json()).toEqual({ error: "Rota de API inexistente" });
  });
});
