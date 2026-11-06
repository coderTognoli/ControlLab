# API do ControlLab na Vercel

O deploy auditado em 06/11/2026 publica o Vite, mas devolve 404 NOT_FOUND da
plataforma em `/api/trpc/system.health`. A requisicao nao chega ao Express nem
ao PostgreSQL; atualizar o schema do banco nao publica o backend.

`server/vercel.ts` exporta a aplicacao Express compartilhada com o servidor local,
sem abrir uma porta nem carregar o Vite. O build empacota essa entrada em
`dist/vercel-api.js`, carregado por `api/index.js` com extensao explicita.
Assim o Node ESM nao precisa resolver imports sem extensao ou aliases TypeScript
em producao. `vercel.json` inclui o bundle na Function e encaminha `/api/*` para
essa Function e serve o frontend em `dist/public`; rotas da interface recebem
`index.html`. O caminho completo e o query string devem chegar ao Express,
inclusive chamadas tRPC em lote. A leitura de uploads nao cria diretorios no
inicio da Function, pois o filesystem do deploy e somente leitura.

## Publicar e conferir

1. Incluir `api/index.js`, `server/vercel.ts`, `scripts/build-server.mjs`,
   `vercel.json` e as alteracoes do backend compartilhado no commit a publicar.
   Remover a antiga entrada `api/index.ts`. `dist/` continua gerado pelo build,
   fora do Git. Teste HTTP: `server/vercel-api.test.ts`. Depois de `pnpm build`,
   executar `node scripts/verify-vercel-bundle.mjs` para testar tambem a entrada
   compilada com o carregador ESM nativo, sem fontes TypeScript na copia de teste.
2. No projeto da Vercel associado ao dominio acessado, usar a raiz do
   repositorio, framework Vite, Node 24, build `pnpm build` e output `dist/public`.
3. Configurar no ambiente que sera publicado `NODE_ENV=production`,
   `DATABASE_PROVIDER=postgres`, `DATABASE_URL` do **banco existente atualizado**,
   `SESSION_SECRET` com pelo menos 32 caracteres e as variaveis SSL apropriadas.
   Nao usar prefixo VITE_ para credenciais. Preview exige configuracao propria;
   as variaveis de Production nao sao automaticamente herdadas por Preview.
4. Fazer novo deploy do commit com a entrada da API. Apenas executar novamente
   o deploy antigo nao acrescenta arquivos que ainda estao somente na maquina.
5. Consultar `/api/trpc/system.health`: deve devolver JSON tRPC, HTTP 200,
   `result.data.json.database.ok = true` e `migrated = true`. O `ok` externo
   sozinho nao confirma conexao. Conferir tambem login e carregamento de dados.

Se o JSON indicar erro no banco, consultar os Runtime Logs da Function e conferir
host, porta, usuario, senha, URL-encoding da senha e estado do projeto Supabase.
Nao publicar senhas/connection strings em mensagens ou logs. O Session pooler
usa a string fornecida em Connect no Supabase, incluindo o usuario com a
referencia correta do projeto.

Com `DATABASE_SSL=verify`, o codigo atual interpreta `DATABASE_SSL_CA` como
**caminho de um arquivo** que deve existir dentro da Function; um caminho local
do Windows nao existe no Linux da Vercel. Nao desabilitar a verificacao TLS para
contornar um certificado ausente; disponibilizar corretamente a CA, ou usar a
cadeia confiavel padrao quando adequada ao endpoint.

## Limites desta correcao

Esta mudanca publica a API de dados; nao migra arquivos locais para storage
persistente. Fotos, imagens e anexos escritos em `UPLOAD_DIR` precisam de disco
persistente numa hospedagem Node ou de uma integracao de object storage antes
de usar uploads na Vercel. A Function tambem tem limites de corpo diferentes do
servidor local. Nenhum banco, migration ou conta e criado automaticamente pelo
deploy.

Referencia: [Express na Vercel](https://vercel.com/docs/frameworks/backend/express).
