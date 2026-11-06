# Atualizar o banco existente preservando dados

O arquivo [sql/atualizar_banco_controllab.sql](sql/atualizar_banco_controllab.sql)
atende a baseline identificada pela auditoria: 15 tabelas existentes, sem historico
Drizzle, faltando `classrooms`, `student_notes`, `student_quiz_attempts` e nove
colunas adicionais. Nao usar o bootstrap `novo_banco_controllab.sql` neste banco.

## Aplicacao

1. Fazer backup de estrutura e dados e testar a restauracao em um banco separado.
2. Aplicar primeiro o SQL na copia restaurada. Conferir login, estoque,
   emprestimos, progresso, turmas, anexos e questionarios.
3. Pausar escritas do aplicativo e conferir o projeto selecionado no Supabase.
4. No SQL Editor, conectado como `postgres`, executar **todo** o arquivo de
   atualizacao de uma vez. Nao selecionar apenas trechos nem executar em paralelo
   com `pnpm db:migrate`.
5. Esperar `ATUALIZACAO_CONCLUIDA` e `migrations_registradas = 7`.
6. Executar `sql/auditoria_colunas_supabase.sql`: deve retornar zero linhas.
   Conferir tambem RLS e gatilhos com a auditoria original. Retomar o aplicativo
   e verificar as funcionalidades com os dados reais.

Se qualquer instrucao falhar, a transacao nao deve ser confirmada. Em uma sessao
SQL que permanecer aberta em estado de erro, executar `ROLLBACK;` antes de novas
tentativas. Enviar o erro completo para diagnostico; nao remover validacoes.

## Preservacao e historico

O SQL reaplica a baseline idempotente e as mudancas estruturais 0001..0006.
Cria tres tabelas e nove colunas faltantes; as novas colunas `attachments` recebem
`[]`, enquanto as novas colunas opcionais recebem NULL. Nao muda IDs, senhas,
saldos, progresso ou conteudo das colunas existentes. Recria os gatilhos padrao
de IDs e remove somente o indice redundante previsto na migration 0005.

Os DELETE e UPDATE da migration 0005 foram retirados: registros orfaos causam
erro ao criar/validar as chaves estrangeiras e cancelam a atualizacao inteira.
Nao sao removidos nem associados automaticamente a outro usuario/modulo. As
acoes futuras `ON DELETE CASCADE`/`SET NULL` das FKs continuam iguais ao schema
do projeto; preservar dados nesta atualizacao nao altera as regras futuras de
exclusao de usuarios/modulos pelo aplicativo.

O script verifica colunas/tipos/nulabilidade, valida as FKs adicionadas e as FKs
anteriormente nao validadas, e confere as contagens das 15 tabelas iniciais. As
escritas ficam bloqueadas na transacao, com limite de espera de 10 segundos por
bloqueio e limite de 120 segundos por instrucao. Bancos grandes podem precisar de
uma janela e limites revistos.

Somente apos sucesso registra os hashes originais das sete migrations em
`public.__drizzle_migrations`, reconciliando o estado existente com esta versao.
Isso **nao afirma que as limpezas antigas foram executadas**: a integridade e
validada sem essas limpezas. Nao copiar o historico do bootstrap separadamente.
O migrador do projeto usa essa tabela, nao `supabase_migrations.schema_migrations`.
Depois da atualizacao validada, `pnpm db:migrate` pode seguir com migrations
futuras. Nao editar os SQLs antigos nem seus hashes.

A auditoria de colunas nao verifica todas as definicoes preexistentes de
indices, defaults e constraints. Objetos com nomes iguais e definicoes
personalizadas exigem revisao do schema restaurado; `IF NOT EXISTS` nao compara
definicoes. O teste local usa a baseline do repositorio e nao substitui o teste
na copia do banco real.

## Regenerar

`node scripts/export-upgrade-postgres.mjs` gera o arquivo sem abrir conexoes nem
ler credenciais. O gerador e especifico das sete migrations atuais e exige
revisao quando essa sequencia evoluir.

## Validacao realizada

Testado em PostgreSQL 17.2 local, em cluster temporario independente do Supabase:

- Atualizacao da baseline com registros nas 15 tabelas e comparacao de todos os
  valores preexistentes antes/depois, incluindo senha, saldos e progresso.
- Auditoria final sem divergencias de coluna; RLS nas 18 tabelas e no historico;
  nenhuma FK pendente de validacao.
- Reexecucao sem duplicar dados/historico e insercoes nas tres tabelas novas,
  incluindo IDs enviados como NULL nos novos gatilhos.
- Registro orfao: falha com rollback dos objetos novos e preservacao dos dados.
- Tipo de coluna divergente: bloqueio na verificacao inicial sem alterar dados.

O teste reproduzivel esta em `scripts/test-upgrade-postgres.mjs` e exige um
PostgreSQL **descartavel** em `127.0.0.1:55439`, usuario `postgres`, sem senha,
com o executavel na instalacao Windows indicada no arquivo. Ele cria bancos de
teste nesse cluster, sem ler `.env` nem acessar projetos remotos.
