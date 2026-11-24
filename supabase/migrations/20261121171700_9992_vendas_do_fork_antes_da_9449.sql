-- manifest: Fork orken — prepara a tabela de vendas do fork (coluna `moeda`, gatilho 9991) para a forma oficial (9449/9450): marca os negócios que já têm venda como "valor pelas vendas", sem inventar um "valor digitado" que o fork nunca guardou.
--
-- Só age num banco que AINDA tem a coluna `moeda` em `vendas_registradas` — o
-- banco do fork antes da conversão. Num banco novo, ou já convertido, não faz
-- nada. Roda ANTES da 9449, que renomeia `moeda` para `currency`, e da 9450,
-- que troca o gatilho e preenche `valor_digitado_cents`.
--
-- Por que isto existe: no fork, o Valor do negócio com vendas era a soma, e SEM
-- vendas ficava nulo. A 9450 oficial, ao ver um negócio com venda e
-- `valor_pelas_vendas = false`, guardaria a SOMA como "valor digitado" — e,
-- ao apagar a última venda, devolveria essa soma como se alguém a tivesse
-- digitado. Marcar o negócio antes mantém o comportamento que a equipe já usa:
-- sem vendas, o Valor volta a ficar vazio.
--
-- Idempotente: as colunas são `add column if not exists` (a 9450 repete a mesma
-- definição) e o `update` só toca quem ainda não está marcado.
do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'vendas_registradas' and column_name = 'moeda') then
    alter table public.crm_leads
      add column if not exists valor_pelas_vendas boolean not null default false,
      add column if not exists valor_digitado_cents bigint;

    update public.crm_leads l
       set valor_pelas_vendas = true
     where not l.valor_pelas_vendas
       and exists (select 1 from public.vendas_registradas v where v.lead_id = l.id);
  end if;
end $$;
