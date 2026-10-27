# Banco de produção do ControlLab

## Projeto escolhido

O banco de produção escolhido pelo responsável é **ControlLab**, na organização
**Senai**, referência `crenurcbsaptzenwkqnf`, em São Paulo (`sa-east-1`).
O navegador autenticado tem acesso a esse projeto; o conector Supabase permanece
associado a outra conta. A estrutura da Senai foi aplicada pelo SQL Editor.

O projeto `ofjcaoetqphjovhygvtr`, preparado anteriormente na organização pessoal,
é um destino separado e não deve ser usado na configuração de produção da Senai.
Ele não foi excluído nem migrado sobre o projeto escolar.

## Estrutura aplicada na Senai

A inspeção inicial encontrou zero tabelas em `public`. Foi aplicada a estrutura
equivalente à migration `20261026224833_controllab_estrutura_inicial.sql`:
15 tabelas, índices, relações, geração de IDs e validações de saldo. Todas as
15 tabelas têm RLS ativado. `anon` e `authenticated` não recebem acesso direto.
A aplicação continua usando a autenticação e o adaptador PostgreSQL existentes.

Os testes de inserção de usuário e item, geração de identificadores e rejeição
de reserva maior que o estoque passaram. A transação de teste foi revertida:
o resultado final confirmou 15 tabelas com RLS, zero usuários persistidos e
permissões SELECT negadas a `anon` e `authenticated` na tabela de usuários.
Não foram criadas contas com senhas de demonstração em produção.

## Acesso do backend

A migration `20261026225247_acesso_backend_controllab.sql` contém o papel
`controllab_app` e as permissões planejadas. No projeto Senai, essa etapa e a
credencial exclusiva de produção ainda precisam ser concluídas.

O papel não será superusuário, não criará bancos ou papéis e não ignorará RLS.
Ele receberá acesso somente às tabelas e sequências da aplicação. Movimentações
e auditoria permitirão somente leitura e inserção. As permissões de aluno,
docente e administração continuam verificadas na API.

A senha será provisionada fora do Git e das migrations, e armazenada somente
como segredo de Production na Vercel. A senha do administrador `postgres`
não deve ser usada pelo backend.

## Conexão e certificado

O painel da Senai confirmou o Transaction pooler:

- Host: `aws-1-sa-east-1.pooler.supabase.com`;
- Porta: `6543`;
- Banco: `postgres`;
- Usuário do backend: `controllab_app.crenurcbsaptzenwkqnf`.

Configure `DATABASE_PROVIDER=postgres`, `DATABASE_SSL=verify` e
`DATABASE_SSL_CA=certificados/supabase-prod-ca-2021.crt`. O certificado público
foi obtido pelo link Download certificate do painel Supabase. Está válido até
26/04/2031 e é incluído no pacote da função pelo `vercel.json`.

SHA-256 do certificado:
`807025AD50D4ED219D2C9C7D299C004F824EB00CF7F65AFEF607D07B72E6CAFA`.

A biblioteca `pg` não usa prepared statements nomeados. Nenhuma chave privada,
senha ou URL com senha deve entrar no repositório.

## Estado da conexão

A estrutura está aplicada e validada no projeto Senai. O acesso de produção
pela Vercel ainda está pendente da criação da credencial exclusiva do backend.
`GET /api/health` deve retornar 200 somente depois de validar configuração,
conexão e tabela principal. A configuração de destino não deve reutilizar a
credencial do projeto pessoal. Contas reais e os fluxos autenticados serão
verificados depois de concluir a conexão.
