# Novo banco ControlLab com preservação do banco anterior

O arquivo [`sql/novo_banco_controllab.sql`](sql/novo_banco_controllab.sql) cria a estrutura completa da versão atual: 18 tabelas da aplicação e 189 colunas, índices, chaves estrangeiras, funções auxiliares, gatilhos de IDs, RLS e histórico das sete migrações Drizzle.

## Preservação dos dados

Use um **projeto Supabase novo**, mantendo o projeto anterior intacto. Os dados antigos continuam no banco anterior; este SQL não copia contas, módulos, arquivos, progresso ou estoque. A transferência desses dados precisa ser planejada depois de inspecionar o banco de origem.

O script verifica primeiro se já existem objetos do ControlLab em `public`. Se encontrar qualquer tabela do aplicativo, histórico ou função auxiliar existente, ele interrompe com erro. Toda a criação ocorre em uma transação: se qualquer etapa falhar, as alterações não são confirmadas. Reexecutar o script após uma instalação bem-sucedida também interrompe; ele não é um atualizador de bancos existentes.

As rotinas de limpeza de registros órfãos da migração antiga não foram incluídas: não são necessárias em banco vazio. Nenhuma conta ou senha de demonstração é criada. As tabelas usam RLS sem políticas públicas, conforme a arquitetura atual: o backend conecta diretamente ao PostgreSQL, usando uma conta apropriada; o navegador usa a API do aplicativo.

## Criar e verificar

1. Criar o projeto novo no Supabase, na organização confirmada pelo responsável.
2. Executar `sql/novo_banco_controllab.sql` no SQL Editor **do projeto novo**.
3. Executar [`sql/auditoria_supabase_somente_leitura.sql`](sql/auditoria_supabase_somente_leitura.sql). O primeiro resultado deve estar vazio; todas as tabelas esperadas devem existir e ter RLS habilitado. Conferir funções e gatilhos nos resultados seguintes.
4. Conferir o histórico:

   ```sql
   SELECT id, hash, created_at
   FROM public.__drizzle_migrations
   ORDER BY created_at, id;
   ```

   Devem existir sete entradas. Os hashes correspondem aos arquivos originais de `drizzle/postgres`; a estrutura criada equivale ao resultado dessas migrações sobre um banco vazio.

5. Obter a connection string no painel do novo projeto e configurar o backend em ambiente de teste com `DATABASE_PROVIDER=postgres`. Não trocar a conexão da produção antes de verificar o novo ambiente e definir como os dados antigos serão transferidos.
6. Criar contas reais com o comando existente `pnpm user:create`; não usar credenciais de exemplo em produção.

O SQL não corrige o endpoint `/api/trpc` indisponível no deploy atual e não transfere os arquivos de `/uploads`. Essas duas partes precisam de tratamento separado.

## Regenerar o arquivo

```sh
node scripts/export-new-postgres.mjs
```

O gerador não abre conexões nem lê segredos. Ele lê as migrações PostgreSQL e confere tabelas/colunas contra o snapshot atual `drizzle/meta/0006_snapshot.json`. Não altera os arquivos de migração originais. Ao evoluir o schema, atualizar a referência ao snapshot no gerador.

A criação e execução no Supabase dependem da confirmação da organização e da disponibilidade do novo projeto. Gerar o arquivo local não significa que um banco remoto já foi criado.
