# Publicação na Vercel

A interface Vite é publicada a partir de `dist/public`. `dist/index.js` é o
servidor para hospedagem Node tradicional; não deve ser publicado como página.
O `vercel.json` mantém essa configuração no repositório e encaminha `/api/*`
para a função Express em `api/index.ts`. As demais rotas abrem a aplicação React.

## Estado e configuração

A interface e a consulta anônima de sessão funcionam sem banco, permitindo abrir
o login. As operações do sistema exigem, no ambiente Production da Vercel:

- `SESSION_SECRET`: segredo aleatório com pelo menos 32 caracteres.
- `DATABASE_PROVIDER=postgres`.
- `DATABASE_URL`: conexão do Postgres de produção, com as tabelas já migradas.

Cadastre segredos diretamente na Vercel. Não os inclua no Git.
`GET /api/health` informa somente se a configuração mínima está presente;
não comprova conexão, migrations ou credenciais do banco. Sem configuração,
retorna 503 com orientação, sem revelar valores de variáveis.

O banco SQLite, a criação de contas e os uploads em disco continuam adequados
à execução local/servidor com disco persistente. A função da Vercel não cria a
pasta de uploads. Antes de usar envio de imagens em produção, substitua esse
armazenamento por um serviço persistente. Não use `/tmp` como banco ou mídia.

Verificação desta correção: página HTML e recursos estáticos, rota `/login`,
consulta `auth.me` anônima e resposta de configuração pendente. Login com conta
real e operações de estoque exigem banco e contas de produção configurados.
