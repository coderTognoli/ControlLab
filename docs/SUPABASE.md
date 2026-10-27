# Banco de produção do ControlLab

Projeto Supabase exclusivo: `ControlLab` (`ofjcaoetqphjovhygvtr`), na organização
`brunin dus projetu`, região São Paulo (`sa-east-1`). O projeto anterior não foi alterado.

## Estrutura aplicada

As migrations em `supabase/migrations/` reproduzem as versões aplicadas no
Supabase: estrutura inicial com 15 tabelas, índices, relações, validação de saldo
e permissões do backend. A aplicação mantém o adaptador PostgreSQL existente.

O papel `controllab_app` tem acesso somente aos dados e sequências da aplicação.
Não é superusuário, não cria bancos ou papéis e não ignora RLS. Suas políticas
autorizam o backend confiável; as permissões de aluno, docente e administração
continuam sendo verificadas pela API. `anon` e `authenticated` não podem ler ou
gravar as tabelas diretamente. Movimentações e auditoria permitem apenas leitura
e inserção para o backend.

A migration cria o papel sem login. O login foi posteriormente habilitado com
uma senha aleatória exclusiva, provisionada fora das migrations e salva no
segredo `DATABASE_URL` da Vercel. A senha do administrador `postgres` não é usada.

## Conexão com a Vercel

Use o endereço exato exibido no painel **Connect → Transaction pooler** e o
usuário dedicado `controllab_app.<referência-do-projeto>`. A biblioteca `pg`
existente não usa prepared statements nomeados. Configure em Production:

- `DATABASE_PROVIDER=postgres`;
- `DATABASE_URL`: conexão com a credencial exclusiva do backend;
- `DATABASE_SSL=verify`, usando a cadeia de certificados do serviço;
- `SESSION_SECRET`: já provisionado como segredo na Vercel.

Se o certificado exigir uma CA específica, configure a CA antes de ativar a
validação. Não publique credenciais, URLs com senha ou certificados privados no Git.

`GET /api/health` verifica configuração, conexão e presença da tabela principal.
Retorna 200 somente quando todos esses passos passam e não revela endereço,
usuário ou senha do banco. A autenticação real ainda exige contas cadastradas
com o script `user:create`; a seed de demonstração não foi aplicada em produção.

## Verificações realizadas na criação

- 15 tabelas com RLS ativado;
- inserção de usuário e item com o papel do backend, incluindo geração de IDs;
- rejeição de reserva maior que o estoque físico;
- bloqueio de alteração/exclusão dos históricos pelo backend;
- ausência de acesso direto de `anon` e `authenticated` às tabelas de usuários;
- análise de segurança Supabase sem alertas;
- testes de escrita revertidos na mesma transação, sem dados fictícios persistidos.

Conexão de produção: pendente da obtenção do endereço do pooler no painel.
O teste do endereço direto fornecido pelo Supabase falhou na Vercel com
`ENOTFOUND`. O deploy recebe as variáveis de configuração, mas o endpoint
`/api/health` retorna 503 com `configured=true` e `database.connected=false`.
Esse resultado não comprova a credencial em uma conexão externa: o endereço
do pooler ainda precisa substituir o endereço direto, seguido de novo deploy
e testes de conexão, autenticação e gravação pela aplicação.
