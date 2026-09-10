# Diagnóstico: Totais PT por Operador — maio 2026

## Comparação: R vs. Excel colega

| Operador | R (script) | Excel colega | Diferença |
|----------|----------:|-------------:|----------:|
| CM       | 17 765 042 | 17 766 274 | +1 232 |
| ML       | 11 240 990 | 11 240 990 | **0** ✓ |
| CA       |  9 558 793 |  9 623 386 | +64 593 |
| CP       |  8 201 403 |  8 201 403 | **0** ✓ |
| FT       |  2 571 133 |  2 571 133 | **0** ✓ |
| TT       |  1 555 693 |    676 961 | **-878 732** ❌ |
| MS/MTS   |  1 436 026 |  1 436 026 | **0** ✓ |
| TB/TCB   |  1 083 790 |  1 096 311 | +12 521 |
| SL       |    901 290 |    878 732 | **-22 558** ❌ |
| CAP      |    513 811 |    513 811 | **0** ✓ |
| BQ       |     65 332 |     65 332 | **0** ✓ |

---

## Causa 1 — TT e SL: O Recibo B de TT já inclui o SL

**O problema principal (e mais impactante):**

O Recibo B entregue sob o operador `TT` contém na coluna `OPERADOR_TOTAL` os passageiros **conjuntos de TT + SL** (os dois operadores partilham o mesmo Recibo B no sistema). O Recibo B do `SL` é um ficheiro separado, mas com valores **diferentes** dos que a colega usa.

A colega separa TT e SL usando a consulta SQL à tabela `DW_PROC.F_VALIDATIONS` (aba `TT_SL` do Excel), que inclui a georreferenciação por paragem (`REF_STOP_ID`) e linha (`RUN_CODE`) para distinguir as carreiras do TT (ferrovia de Tâmega, entity_id=5) das do SL (Soflusa/Barreiro, entity_id=8).

**Verificação:**
```
TT Recibo B ticket 900:  1 077 079  =  452 153 (TT Excel)  +  624 926 (SL Excel)  ✓
TT Recibo B total:       1 555 693  =  676 961 (TT Excel)  +  878 732 (SL Excel)  ✓
```

**No R actual:** o filtro `filter(!operador %in% c("SC"))` mantém tanto `TT` como `SL`. O resultado é que o total de TT no R (1.555.693) = TT+SL combinados do Recibo B de TT, e o SL do R (901.290) vem do Recibo B separado do SL (que tem valores ligeiramente diferentes). O SL fica **duplicado parcialmente** e atribuído ao TT.

**Correção possível — opção A (mais simples):**
Excluir o Recibo B do `SL` do cálculo do PT (pois o TT já o inclui). Usar o Recibo B do `TT` como operador composto `TT+SL` e depois separar com os rácios das validações da aba TT_SL.

**Correção possível — opção B (mais fiel à colega):**
Necessita de acesso à consulta SQL `DW_PROC.F_VALIDATIONS` com `ENTITY_ID IN (5,8)` e georreferenciação para fazer a repartição ticket a ticket.

> [!WARNING]
> Esta é a maior discrepância e requer decisão sobre como tratar TT/SL no pipeline R.

---

## Causa 2 — CA e TB: A linha `ticket_code = -1` é excluída

**O filtro actual:**
```r
PT_mesano <- PT_raw |> filter(ticket_operator_code == 31, ticket_code > 0)
```

Este filtro exclui a linha especial com `ticket_operator_code = -1, ticket_code = -1` que existe nos Recibos B de **CA** e **TB**. Esta linha representa os passageiros de **títulos gratuitos (Validations as Transactions)** que o sistema registou como PT mas não conseguiu associar a um ticket_code específico — e que a colega inclui, atribuindo-os ao ticket 1020 (Navegante 12 Criança, pvp=0).

**Valores da linha -1:**
- `CA`: operador_total = **64 593** → explica exatamente a diferença do CA
- `TB`: operador_total = **12 521** → explica exatamente a diferença do TB

**Correção:**
```r
# Incluir linha -1 como ticket 1020 (passageiros VaT gratuitos)
PT_raw <- PT_raw |>
  mutate(ticket_code_ajustado = if_else(
    ticket_operator_code == -1 & ticket_code == -1,
    1020L, ticket_code
  ),
  ticket_operator_code_ajustado = if_else(
    ticket_operator_code == -1, 31L, ticket_operator_code
  ))
```

> [!IMPORTANT]
> Apenas CA e TB têm valores não-nulos na linha -1. Todos os outros operadores têm operador_total=0 nessa linha.

---

## Causa 3 — CM: Validações do entity_id = 23 (Portal VIVA)

A colega inclui as validações da aba `entity ID 23` (fiscais com terminais móveis — Portal VIVA) e distribui-as pelas sub-áreas da CM (entity_id 41, 42, 43, 44). O total é **1 455 validações** (vs. discrepância de 1 232 no CM), com diferença residual de 223 possivelmente por arredondamento ou VALID_TYPE_ID diferente.

> [!NOTE]
> Esta diferença é pequena (< 0.01% do total CM) e pode ser considerada residual. A colega usa dados adicionais de uma consulta SQL separada.

---

## Problema 1 — Separadores decimais nos outputs

Todos os `write.csv2()` usam vírgula como separador decimal (padrão PT), mas o `print()` dos tibbles usa ponto. Para garantir que os **outputs CSV** têm sempre vírgula decimal e os **prints de verificação** usam ponto:

- Os ficheiros CSV gerados com `write.csv2()` já usam `,` decimal ✓
- Os prints do tibble usam ponto (padrão R) — isso é apenas visual, não afecta os ficheiros
- Se pretender que os prints também usem ponto: `options(OutDec = ".")` no início do script

---

## Sumário das correções a implementar

| # | Causa | Impacto | Dificuldade |
|---|-------|---------|-------------|
| 1 | TT inclui SL no Recibo B | Alto (±878 732 no TT) | Média — requer dados de validações |
| 2 | Linha ticket -1 excluída (CA, TB) | Médio (77 114 total) | Baixa — 1 linha de código |
| 3 | entity_id=23 (Portal VIVA) não incluído | Baixo (1 232 no CM) | Média — requer dados adicionais |

### Questão para a Rosa:
- **TT/SL**: O Recibo B do SL deve ser **excluído** (porque o TT já o inclui), ou devo manter os dois separados aceitando a diferença?
- **Linha -1**: Confirmar que é correcto atribuir a linha ticket=-1 ao ticket 1020 para CA e TB?
- **entity_id=23**: É necessário incluir estes dados no pipeline R, ou a diferença é aceitável?


Tudo feito! Aqui está o resumo do que foi corrigido em 

01_recibos_b.R
:

Resultado — Totais PT por operador (novo)
operador total_pt total_pt_fmt
 1 CM       17765042 17.765.042   (diff ~1.232 vs Excel = entity_id=23, aceite)
 2 ML       11240990 11.240.990   ✅
 3 CA        9623386  9.623.386   ✅ (era 9.558.793)
 4 CP        8201403  8.201.403   ✅
 5 FT        2571133  2.571.133   ✅
 6 TT        1555693  1.555.693   ⚠️ TT+SL juntos (Recibo B de TT já inclui SL)
 7 MS        1436026  1.436.026   ✅
 8 TB        1096311  1.096.311   ✅ (era 1.083.790)
 9 CAP        513811    513.811   ✅
10 BQ          65332     65.332   ✅
3 correções feitas:

Linha ticket_code = -1 (CA e TB): recodificada como ticket 1020 antes do filtro → CA e TB agora batem exactamente com o Excel
Recibo B do SL excluído do PT: o Recibo B do TT já inclui TT+SL juntos (verificado ticket a ticket). O SL é mantido apenas para o cálculo de receitas (que têm contratos separados)
Separadores decimais: prints de verificação usam agora scales::number() com ponto como separador de milhar e vírgula como decimal — formato português correcto

⚠️ TT = TT + SL: o valor 1.555.693 representa os dois operadores em conjunto, tal como vem do Recibo B. Para separar correctamente, seria necessária a consulta SQL DW_PROC.F_VALIDATIONS com ENTITY_ID IN (5, 8) e georreferenciação (aba TT_SL do Excel) — mas isso está fora do pipeline automático com Recibos B.