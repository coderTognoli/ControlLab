# Auditoria do banco e deploy — 06/11/2026

## Escopo e limites

Análise do commit `74e6bdc08b55e917c68b3923e063566de763c19e`, igual ao commit do deploy de produção consultado na Vercel. Foram inspecionados código, schema, sete migrações PostgreSQL, configuração do projeto na Vercel e respostas HTTP. Nenhum dado, schema ou configuração de produção foi alterado. Nenhum segredo foi descriptografado.

A comparação com as tabelas reais do Supabase ficou pendente por falta de acesso ao banco. Portanto, migrações ausentes são uma hipótese fundamentada, não uma constatação sobre o banco remoto.

## 1. Confirmado: frontend publicado, endpoint da API indisponível

- Projeto Vercel: `controllab`, framework configurado como `vite`, Node `24.x`.
- Deploy: `dpl_5tXe1ToKB5c5fnnvaeBJuRFmmWWp`, estado `READY`, produção.
- `https://controllab.vercel.app/`: HTTP 200, HTML do aplicativo.
- `https://controllab.vercel.app/api/trpc/system.health`: HTTP 404, `x-vercel-error: NOT_FOUND`.
- O mesmo endpoint na URL específica do deploy também respondeu 404.
- O frontend chama `/api/trpc` no mesmo domínio (`client/src/main.tsx`). Não conecta diretamente ao Supabase.
- O backend Express está em `server/_core/index.ts`; o build o gera em `dist/index.js`, enquanto o Vite gera os arquivos do navegador em `dist/public`.
- Não há `vercel.json`, diretório `api/` ou integração explícita do backend com o deploy Vite no repositório.

**Impacto:** a interface abre, mas o endpoint de diagnóstico não chega ao servidor Express. A evidência aponta para publicação/roteamento incompleto do backend. Atualizar apenas o banco não resolve esse 404. `READY` comprova conclusão do deploy, não funcionamento do sistema inteiro.

O README afirma que Vercel não serve para Express. Essa afirmação é ampla demais: a Vercel suporta Express, mas exige que o backend seja reconhecido e publicado corretamente. É necessário também adaptar armazenamento e concorrência.

Referências: [Express na Vercel](https://vercel.com/docs/frameworks/backend/express), [filesystem das Functions](https://vercel.com/docs/functions/runtimes).

## 2. Confirmado: acesso ao banco remoto não foi possível

Projetos retornados pela integração Supabase:

| Projeto | Referência | Resultado |
|---|---|---|
| ControlLab | `ofjcaoetqphjovhygvtr` | `INACTIVE`; consulta de tabelas retornou banco possivelmente inacessível |
| Outro projeto da conta | `irnntvgqjuztjntrvykv` | `ACTIVE_HEALTHY`; consulta falhou na autenticação de `supabase_read_only_user` |

Isso não prova que a senha usada pela aplicação esteja incorreta. A falha é da consulta pela integração. Também não foi possível confirmar qual desses projetos é o destino de `DATABASE_URL`.

Na Vercel existem `DATABASE_PROVIDER=postgres`, `DATABASE_SSL=verify`, `DATABASE_SSL_CA`, `DATABASE_URL` e `SESSION_SECRET`, somente para produção. Valores secretos não foram lidos. A configuração de Preview não tem essas variáveis na listagem consultada; um backend publicado em Preview precisará delas nesse ambiente.

Não houve logs de runtime nos últimos 30 minutos consultados. Isso não comprova ausência de erros anteriores.

## 3. Confirmado no repositório: importar só a baseline não atende ao sistema atual

README e `docs/BANCO_DE_DADOS.md` ainda oferecem importar somente `drizzle/postgres/0000_controllab_baseline.sql` como alternativa ao setup completo. A versão atual depende também de:

| Migração | Estrutura adicional | Funcionalidade afetada se faltar |
|---|---|---|
| 0001 | `learning_modules.archivedAt`, `learning_activities.createdBy`, `student_notes` | Catálogo, autoria da agenda, diário |
| 0002 | `classrooms`, `users.classroomId`, `inventory_loans.classroomId`, `inventory_movements.classroomId` | Login com seleção completa de usuário, administração, supervisão e estoque por turma |
| 0003 | `learning_steps.attachments`, `learning_resources.attachments` | Leitor e editor de conteúdo |
| 0004 | `inventory_items.icon` | Consulta e edição de itens do estoque |
| 0005 | Chaves estrangeiras da área educacional e limpeza de órfãos | Integridade entre usuários, módulos, etapas e progresso |
| 0006 | `student_quiz_attempts`, `learning_steps.quiz` | Quizzes, acompanhamento e métricas |

Se o banco recebeu apenas a baseline, haverá incompatibilidade. Se recebeu estrutura de outro sistema, é preciso conferir também nomes, tipos, índices e relacionamentos; `CREATE TABLE IF NOT EXISTS` não converte tabelas antigas já existentes.

## 4. Confirmado: o health-check não detecta schema incompleto

`server/db.ts:160` verifica apenas se existe a tabela `inventory_items` e retorna `migrated: true` quando ela existe. Não verifica as outras tabelas, colunas ou histórico de migrações. Além disso, `system.health` retorna `ok: true` no nível superior mesmo quando `database.ok` é falso.

**Impacto:** um banco parcialmente atualizado pode aparentar estar pronto no diagnóstico atual. O endpoint está indisponível no deploy testado; este achado é da revisão do código.

## 5. Confirmado: uploads dependem de disco persistente

`server/storage.ts` grava fotos, imagens e anexos em `UPLOAD_DIR`, usando `mkdir`/`writeFile`, e o banco guarda URLs `/uploads/...`. Não existe implementação de Supabase Storage neste projeto.

As Functions da Vercel têm filesystem de aplicação somente para leitura e espaço temporário em `/tmp`. Portanto, a implementação atual precisa de armazenamento externo para manter os uploads. Restaurar as tabelas não restaura os arquivos referenciados por `/uploads/...`.

## 6. Risco concreto no código: concorrência do estoque entre instâncias

`server/inventory.ts:122` e `:128` usam nomes `lockItem`/`lockLoan`, mas executam SELECT comum, sem bloqueio de linha no PostgreSQL. `applyMovement` calcula o saldo em memória e grava valores absolutos, filtrando apenas pelo ID. O mutex em `server/_core/db-lock.ts` protege apenas um processo.

**Cenário possível:** duas instâncias leem saldo 10 e registram saídas de 3 e 4. Cada uma calcula e grava seu saldo; o resultado pode terminar em 7 ou 6, embora as duas movimentações estejam registradas e o correto seja 3. Os CHECKs de saldo não impedem essa perda de atualização.

É necessário proteger as operações no próprio PostgreSQL (bloqueios de linha com ordem consistente ou atualizações atômicas com validação e tratamento de conflito). O cenário não foi reproduzido no banco remoto nesta auditoria.

## 7. Cuidados antes de atualizar um banco antigo

- `0005_learning_foreign_keys.sql` contém DELETEs de registros órfãos e UPDATEs de autoria inválida. Não é uma atualização puramente aditiva; levantar esses registros e fazer backup antes de aplicá-la.
- O migrador em `scripts/lib/database.ts` decide o que pular pelo maior `created_at`. Ele registra hashes, mas não confere os hashes existentes nem lacunas no histórico. Um histórico importado incorretamente pode fazer o sistema pular migrações necessárias.
- O schema espera IDs de usuário inteiros, datas em BIGINT de milissegundos, flags em inteiros 0/1 e JSON de anexos/quiz em TEXT. Importar UUIDs, timestamps nativos ou booleanos exige conversão compatível.
- O login é próprio do aplicativo: `public.users.passwordHash` em formato scrypt e `auth_sessions`. Contas apenas em `auth.users` do Supabase, ou hashes de outro algoritmo, não bastam para esse login.
- Os testes PostgreSQL existentes verificam tradução de SQL/configuração; não substituem teste de integração das migrações e operações contra PostgreSQL real.

## Sequência de correção sugerida

1. Confirmar o projeto Supabase usado pelo deploy e recuperar o acesso de leitura a ele.
2. Executar `docs/sql/auditoria_supabase_somente_leitura.sql` no SQL Editor desse projeto e conferir separadamente o histórico `__drizzle_migrations`, se existir. O SQL compara as tabelas e colunas esperadas, RLS, funções e gatilhos auxiliares; não modifica o banco nem valida todos os dados, índices ou FKs.
3. Fazer backup e levantar órfãos, duplicidades, formatos antigos de senha e arquivos de uploads antes de escrever uma migração de compatibilidade.
4. Corrigir publicação/roteamento do backend na Vercel; validar que `system.health` retorna JSON do aplicativo e testar o fluxo de login.
5. Aplicar apenas as migrações realmente necessárias, depois de revisar os efeitos sobre os dados. Conferir o resultado contra o schema atual.
6. Adaptar os uploads para armazenamento persistente e a concorrência para múltiplas instâncias.
7. Validar login, turmas, módulos, quizzes, anexos, movimentações, reserva, retirada e devolução no ambiente de teste antes de publicar a correção.

Não foram instaladas dependências nem executados testes automatizados nesta revisão: a pasta está sem `node_modules` e `pnpm` não está disponível no terminal. As validações realizadas foram revisão estática, consulta das integrações e testes HTTP do deploy.
