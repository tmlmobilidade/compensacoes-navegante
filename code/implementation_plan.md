# Navegante — Distribuição de Receitas (R Scripts)

## Objetivo

Replicar em R o cálculo manual (feito em Excel) da distribuição mensal das receitas Navegante pelos operadores de transporte da AML, para maio e junho de 2026, seguindo o Regulamento 278-A/2023 (alterado pelo 1362-C/2023).

Os resultados serão gravados em `05_mai_2026_replicate/` e `06_jun_2026_replicate/`.

---

## Estrutura proposta de scripts (em `code/`)

Os scripts são numerados e modulares — podem ser corridos para qualquer mês, passando os parâmetros `ANO` e `MES`.

```
code/
├── procedure.md          (já existe)
├── config.R              [NEW] Parâmetros globais e constantes regulamentares
├── 00_setup.R            [NEW] Instala/carrega pacotes necessários
├── 01_recibos_b.R        [NEW] Lê e agrega os Recibos B (PT + transações)
├── 02_distancias.R       [NEW] Resolve as distâncias médias por título e operador
├── 03_quotas.R           [NEW] Calcula PKM e quotas por título e operador
├── 04_vendas_AK.R        [NEW] Agrega receitas de venda A (operadores) e K (PV/ATM)
├── 05_reparticao_B.R     [NEW] Distribui receita por título/operador (B) + Congelamento
├── 06_cosp_D.R           [NEW] Calcula COSP (Compensação Obrigação Serviço Público) (D)
├── 07_transferencias_F.R [NEW] Calcula transferências finais (F = B + D - A)
└── 99_run_all.R          [NEW] Script mestre que corre todos os passos em sequência
```

---

## Detalhe por script

### `config.R` — Parâmetros e constantes
- `ANO`, `MES` (parâmetros mutáveis)
- Caminho base dos dados
- Constantes regulamentares:
  - TAT por ano (de `lists/tat.csv`)
  - VMC 2023 = 112 562 432,41 €
  - Nº passes a compensar = 8 472 289
  - Retenção TML = 2,5%
- Identificação dos operadores APEX (CM: entity_id 75, CAP: entity_id 22)
- Meses de verão: junho, julho, agosto

### `00_setup.R` — Setup
- Verifica/instala: `tidyverse`, `readxl`, `writexl`, `janitor`, `glue`

### `01_recibos_b.R` — Agrega Recibos B
**Input:** `[MES_ANO]/Recibos B/reg_[OP]_reciboB_*/`
- Lê todos os `_PTconsideredByProduct_*.csv` → agrega em `PT_mesano` (passageiros transportados por título e operador)
  - Filtra: excluir Scotturb (entity SC), excluir validadores móveis fiscais (entity 23/PV)
  - Nota: CM = soma de A1+A2+A3+A4
- Lê todos os `_transactionsOperatorSystem_*.csv` → agrega em `receitas_titulo_mesano`
  - Filtra `SOURCE == "Transaction"` (excluir "Validations as Transactions")
  - `qty_operador = OPERADOR_QUANTITY + SIIT_QTY`
  - `receita_operador = OPERADOR_PRICE + SIIT_PRICE`

**Output (CSV em replicate/):**
- `PT_mesano.csv`
- `receitas_titulo_mesano.csv`

### `02_distancias.R` — Distâncias médias
**Input:**
- `[MES_ANO]_replicate/V_REG_AVERAGE_DISTANCE_FINAL_ALL_*.csv` (distâncias dinâmicas APEX para CM e CAP)
- `lists/distanciasref_out21_incompleto.csv` e `distanciasref_ago21_incompleto.csv` (referência para os restantes)
- `lists/operadores.csv`

**Lógica:**
1. Para CM (entity 75) e CAP (entity 22): usar `CALC_FINAL_VALUE` do ficheiro APEX
2. Para os restantes operadores: usar as tabelas de referência (`out21` para meses não-verão; `ago21` para junho/julho/agosto)
   - Converter de wide para long format
   - Fazer join com `PT_mesano` por `ticket_code` e operador
3. Se distância = 0 ou não encontrada: aplicar a hierarquia de fallback do regulamento

**Output:** `distancias_mesano.csv` (ticket_code × operador → distância)

> [!IMPORTANT]
> O ficheiro `distanciasref_ago21_incompleto.csv` existe mas serve de referência para verão. Para maio (mês não-verão), usar `out21`. Para junho (verão), usar `ago21`.

### `03_quotas.R` — PKM e Quotas
**Input:** `PT_mesano.csv`, `distancias_mesano.csv`, `lists/pesos_pkm.csv`

**Fórmula:**
```
PKM(i,j) = PT(i,j) × distância(i,j)
Quota_raw(i,j) = peso(j) × PKM(i,j)
Quota(i,j) = Quota_raw(i,j) / sum_j(Quota_raw(i,j))   # normalizar para somar 1 por título
```

> [!NOTE]
> Quando não há validações para um título em nenhum operador, usar a quota média do operador (média das quotas dos outros títulos com validações).

**Output:** `quotas_mesano.csv`

### `04_vendas_AK.R` — Receitas de venda A e K
**Input:**
- `receitas_titulo_mesano.csv`
- `[MES_ANO]/Recibos B/ReciboB_[MES][ANO]_Separação_PV_ATM.xlsx` (canal K: PV e SIBS)
- `lists/titulos.csv` (pvp por ticket_code)

**Calcula:**
- **A**: receita por operador = soma das `receita_operador` de todos os títulos
- **K**: receita por canal genérico (PV + SIBS) lida do ficheiro de separação
- `receita_titulo_distribuir(i)` = soma(A por título i) + K(i)  *(receita total a distribuir por título)*
- `receita_posse_operador(j)` = soma(A por operador j, todos os títulos)

**Output:** `vendas_AK_mesano.csv`, `receita_titulo_distribuir_mesano.csv`

### `05_reparticao_B.R` — Repartição + Congelamento
**Input:** `quotas_mesano.csv`, `receita_titulo_distribuir_mesano.csv`, `lists/tat.csv`

**Calcula:**
- `dist_receita_operador_titulo(i,j) = quota(i,j) × receita_titulo_distribuir(i)` (arredondar ao cêntimo)
- `B(j) = sum_i(dist_receita_operador_titulo(i,j))` — receita bilheteira devida
- Fator TAT = (1+TAT_2024)(1+TAT_2025)(1+TAT_2026) - 1
- `receita_compensar(i,j) = dist_receita_operador_titulo(i,j) × fator_TAT`
- `Congelamento(j) = sum_i(receita_compensar(i,j))`

**Output:** `reparticao_B_mesano.csv`, `congelamento_mesano.csv`

### `06_cosp_D.R` — COSP
**Input:** `receita_titulo_distribuir_mesano.csv`, `quotas_mesano.csv`, `lists/sazonalidade.csv`, `lists/tat.csv`

**Calcula:**
- `VMC_2026 = VMC_2023 × (1+TAT_2024)(1+TAT_2025)(1+TAT_2026)` (arredondar ao cêntimo)
- `valor_medio_passe = VMC_2026 / 8_472_289`
- `estimativa_passes_anuais = sum(SISTEMA_QUANTITY do mês) / sazonalidade(mês)`
- `pct_compensar = min(1, 8_472_289 / estimativa_passes_anuais)`
- `passes_compensar(i) = pct_compensar × qty_total_titulo(i)`
- `COSP(i) = passes_compensar(i) × valor_medio_passe × (1 - 0.025)`
- `COSP_dist(i,j) = COSP(i) × quota(i,j)`
- `D(j) = sum_i(COSP_dist(i,j))`

**Output:** `cosp_D_mesano.csv`

### `07_transferencias_F.R` — Transferências
**Input:** `vendas_AK_mesano.csv`, `reparticao_B_mesano.csv`, `cosp_D_mesano.csv`, `congelamento_mesano.csv`

**Calcula por operador:**
- `F(j) = B(j) + D(j) - A(j)`
- `Total_transferir(j) = F(j) + Congelamento(j)`

> [!NOTE]
> Se `Total_transferir < 0` (excedente — normalmente TST), registar a nota de possível devolução a membro do mesmo grupo económico (Fertagus) ou à TML.

> [!NOTE]
> Cascais (CAP) — não pagar mensalmente; aguardar acerto anual.

**Output:** `transferencias_F_mesano.csv` (tabela final por operador)

### `99_run_all.R` — Script mestre
- Define `ANO` e `MES` (ex: 2026, 5)
- Corre scripts 01 a 07 em sequência
- Imprime um sumário final com totais de verificação

---

## Open Questions / Questões em aberto

> [!IMPORTANT]
> **TAT**: O `lists/tat.csv` tem os valores 2024=0.0228, 2025=0.0202, 2026=0.0643, mas o `procedure.md` lista 2024:6.43%, 2025:2.02%, 2026:2.28%. Parece que os anos estão trocados no CSV. **Qual é a versão correta?**

> [!IMPORTANT]
> **CM = A1+A2+A3+A4**: Para os Recibos B, a CM não tem pasta própria — os dados vêm das pastas A1, A2, A3, A4. A agregação deve ser feita antes ou depois do cálculo das quotas? (proponho: agregar nos dados de entrada, tratar CM como um operador único)

> [!IMPORTANT]
> **Distâncias `ago21`**: O ficheiro `distanciasref_ago21_incompleto.csv` tem a mesma estrutura que `out21`? Confirmar se junho é considerado verão para efeitos de distâncias (o procedure.md diz "junho, julho, agosto").

> [!NOTE]
> **Recibos K (PV/ATM)**: O ficheiro `ReciboB_202605_Separação_PV_ATM.xlsx` — qual é a estrutura de colunas? Há um ficheiro equivalente para junho?

> [!NOTE]
> **Scotturb**: A nota no procedure.md diz "excluir os da Scotturb". Os dados dos Recibos B não incluem pasta `reg_SC_*` — confirmar que a exclusão já é feita na origem ou se há dados de SC a filtrar dentro das outras pastas.

---

## Plano de verificação

1. Comparar `receita_titulo_distribuir` com o total do `vendas_mai26.xlsx`
2. Verificar que `sum(quota por título) == 1` para cada `ticket_code`
3. Comparar `B(j)` e `D(j)` com `Anexo_Calculos_mai26.xlsx`
4. Verificar que `sum(B) == sum(receita_titulo_distribuir)`
5. Comparar `Total_transferir` com os valores dos ofícios em `05_mai_2026/`
