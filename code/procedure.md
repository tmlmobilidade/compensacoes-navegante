# Distribuição de Receitas Navegante — Procedimento e Documentação

> **Implementação em R**: `code/99_run_all.R`  
> Alterar `ANO` e `MES` em `code/config.R` e correr `Rscript code/99_run_all.R`.  
> Os outputs ficam em `{MES_ANO}_replicate/` com sufixo `{SUFIXO}` (ex: `mai26`, `jun26`).

---

## Estrutura de scripts

```
code/
├── config.R                  # Parâmetros globais, constantes e caminhos
├── 00_setup.R                # Instala/carrega pacotes R
├── 01_recibos_b.R            # Agrega Recibos B (PT + receitas)
├── 02_distancias.R           # Resolve distâncias médias por título × operador
├── 03_quotas.R               # Calcula PKM e quotas de distribuição
├── 04_vendas_AK.R            # Agrega receitas A (operadores) + K (PV/ATM)
├── 05_reparticao_B.R         # Distribui receita B + Congelamento TAT
├── 06_cosp_D.R               # Calcula COSP (D)
├── 07_transferencias_F.R     # Calcula transferências finais F
├── 99_run_all.R              # Script mestre — corre tudo em sequência
├── query_SL_TT.sql           # Query Oracle para separação TT/SL (Query 2b)
└── query_CM_fiscaismoveis.sql # Query Oracle para fiscais móveis CM (Query 2c)
```

## Variáveis principais em `config.R`

| Variável | Exemplo | Descrição |
|---|---|---|
| `ANO` | `2026` | Ano de distribuição |
| `MES` | `5` | Mês de distribuição (inteiro) |
| `SUFIXO` | `"mai26"` | Sufixo para nomes de ficheiros: `paste0(mes_abrev, ano_curto)` |
| `DATA_DIR` | `05_mai_2026/` | Pasta com dados do mês (Recibos B, etc.) |
| `REPLICATE_DIR` | `05_mai_2026_replicate/` | Pasta de replicação do mês |
| `INPUT_DIR` | `05_mai_2026_replicate/input/` | Pasta de inputs específicos do mês (ex: APEX distâncias) |
| `OUT_DIR` | `05_mai_2026_replicate/output/` | Pasta de outputs gerados pelos scripts |
| `LISTS_DIR` | `lists/` | Tabelas estáticas de referência |
| `DIST_REF_FILE` | `distanciasref_out21_incompleto.csv` | Distâncias de referência (verão → `ago21`) |
| `APEX_ENTITY_IDS` | `c(75, 22)` | Entidades com distâncias dinâmicas (CM, CAP) |
| `CM_SUBOPS` | `c("A1","A2","A3","A4")` | Sub-operadores da Carris Metropolitana |
| `VMC_2023` | `112562432.41` | Valor Máximo Compensação COSP regulado |
| `N_PASSES_COMPENSAR` | `8472289` | Nº máximo passes anuais a compensar |
| `RETENCAO_TML` | `0.025` | Retenção TML sobre COSP (2.5%) |
| `TAT_FILE` | `lists/tat.csv` | Taxa de Atualização Tarifária por ano |

## Ficheiros de output (em `OUT_DIR`)

Todos os ficheiros de output usam o sufixo `{SUFIXO}` no nome (ex: `mai26`).
As variáveis `F_*` em `config.R` centralizam todos os caminhos.

| Variável R | Ficheiro | Produzido em | Conteúdo |
|---|---|---|---|
| `F_PT` | `PT_{SUFIXO}.csv` | `01_recibos_b.R` | Passageiros transportados por título × operador |
| `F_PT_CM` | `PT_CM_agregado_{SUFIXO}.csv` | `01_recibos_b.R` | CM = soma de A1+A2+A3+A4 |
| `F_RECEITAS` | `receitas_titulo_{SUFIXO}.csv` | `01_recibos_b.R` | Receitas de venda por título × operador (qty e €) |
| `F_DISTANCIAS` | `distancias_{SUFIXO}.csv` | `02_distancias.R` | Distância média (km) por título × operador |
| `F_QUOTAS` | `quotas_{SUFIXO}.csv` | `03_quotas.R` | PKM e quota (0–1) por título × operador |
| `F_VENDAS_AK` | `vendas_AK_{SUFIXO}.csv` | `04_vendas_AK.R` | Receita na posse de cada operador (A) |
| `F_RTD` | `receita_titulo_distribuir_{SUFIXO}.csv` | `04_vendas_AK.R` | Receita total a distribuir por título (A+K) |
| `F_REPARTICAO_B` | `reparticao_B_{SUFIXO}.csv` | `05_reparticao_B.R` | Distribuição B por título × operador + congelamento |
| `F_CONGELAMENTO` | `congelamento_{SUFIXO}.csv` | `05_reparticao_B.R` | Congelamento Navegante (TAT) por operador |
| `F_COSP_D` | `cosp_D_{SUFIXO}.csv` | `06_cosp_D.R` | COSP detalhe por título × operador |
| `F_D_OPERADOR` | `D_operador_{SUFIXO}.csv` | `06_cosp_D.R` | COSP total (D) por operador |
| `F_TRANSFERENCIAS` | `transferencias_F_{SUFIXO}.csv` | `07_transferencias_F.R` | **Tabela final**: A, B, D, Congelamento, F, Total |

---

# Dados iniciais: Recibos B

As receitas por título vendido, em quantidade e pvp, são enviadas por todos os operadores e validadas pela TML quando envia o "Recibo B" (eg: `05_mai_2026/Recibos B`).

Cada operador envia 3 ficheiros, com os nomes maisoumenos assim (tem datas no fim):

- **Passageiros Transportados por título**: `reg_[OPERADOR]_reciboB_PTconsideredByProduct_*.csv`

  - Tem ano (`DISTRIBUTION_YEAR`), mês (`DISTRIBUTION_MONTH`), código operador (`TICKET_OPERATOR_CODE`, 31 é o Navegante, -1 é ..?),
  - `TICKET_CODE`, `OPERADOR_TOTAL`- que é o número total de passageiros transportados por aquele operador, com aquele título
  - Tem também o `SISTEMA_TOTAL`, a soma do numero de passageiros transportados por todos os operadores com aquele título, mas isso é irrelevante para o operador, só por curiosidade.
- **Títulos vendidos**: `reg_[OPERADOR]_reciboB_transactionsOperatorSystem_*.csv`

  - Tem o `SOURCE` (tem "Transaction" e "Validations as Transcactions", estes últimos são títulos que não precisam de ser carregados mas tiveram pelo menos 1 utilização no sistema (não importa o operador).
  - Tem `PERIOD`(acho que é `DISTRIBUTION_YEAR "_" DISTRIBUTION_MONTH`), `TICKET_OPERATOR_CODE`
  - `TICKET_CODE`
  - `OPERADOR_QUANTITY`- que é o total de títulos com aquele código vendidos por esse operador; e `OPERADOR_PRICE`, a receita total de venda desse título que esse operador recebeu (em €)
  - `SIIT_QTY`e  `SIIT_PRICE` são "erros" e devoluções. Portanto deve-se considerar o anterior `+` este, para que bata certo, tanto para a quantidade como para a receita.
  - `SISTEMA_QUANTITY`e `SISTEMA_TOTAL_PRICE`, que são apenas curiosidade do total do sistema de títulos ventidos no total.
- **Lista de validações descartadas**: `reg_[OPERADOR]_reciboB_validationsUnconsidered_*.csv`
  este ficheiro tem a lista de validações incoerentes, de vários tipos, nas máquinas do operador, que não foram consideradas para os ficheiros anteriores. Para este cálculo, este ficheiro é irrelevante.


> Nota: o operador CM (Carris Metropolitana) é equivalente à soma dos operadores A1, A2, A3 e A4.  
> Ver `lists/operadores.csv` (`ENTITY_ABBREVIATION` e `OPERATOR_NAME_NAVEGANTE`) para correspondências nos caminhos dos ficheiros.

### Script: `01_recibos_b.R`

Lê todos os Recibos B de todos os operadores e reconcilia dados da Oracle para TT/SL e CM.

**Outputs:**
- `F_PT_CM` → `PT_CM_agregado_{SUFIXO}.csv`: CM = soma de A1+A2+A3+A4 + fiscais móveis (ficheiro intermédio explícito)
- `F_PT` → `PT_{SUFIXO}.csv`: passageiros transportados por título e operador (todos), coluna `pt_operador`
- `F_RECEITAS` → `receitas_titulo_{SUFIXO}.csv`: receitas de venda, colunas `qty_operador` e `receita_operador`

**Filtros aplicados:**
- `SOURCE == "Transaction"` (excluir "Validations as Transactions")
- `ticket_operator_code == 31` (Navegante)
- `ticket_code > 0` (excluir linhas de totais)
- Scotturb (`SC`) excluído

---

### Reconciliação Oracle: TT / SL e Carris Metropolitana

Para bater a 100% com as contas oficiais (folha Excel de validação), é necessário extrair dois ficheiros auxiliares da base de dados Oracle `PDBDWPROD` e colocá-los na pasta `{MES_ANO}_replicate/input/`:

1. **Separação TT / SL**: [`code/query_SL_TT.sql`](file:///c:/GIS/Compensacoes/code/query_SL_TT.sql) (Query 2b)
2. **Fiscais Móveis CM (Portal VIVA)**: [`code/query_CM_fiscaismoveis.sql`](file:///c:/GIS/Compensacoes/code/query_CM_fiscaismoveis.sql) (Query 2c)

```
{MES_ANO}_replicate/input/
├── tt_sl_*(timestamp).csv       ← gerado por query_SL_TT.sql
├── entity23_*(timestamp).csv    ← gerado por query_CM_fiscaismoveis.sql
└── V_REG_AVERAGE_DISTANCE_FINAL_ALL_*(timestamp).csv ← distâncias APEX (CM e Cascais)
```

---

#### 1. Separação TT (Transtejo) / SL (Soflusa) — Query 2b

O Recibo B entregue pela Transtejo (**TT**) contém na coluna `OPERADOR_TOTAL` os passageiros **conjuntos de TT + SL** (os dois operadores fluviais partilham o mesmo Recibo B). O Recibo B separado de SL tem valores diferentes e duplicaria o SL se fosse somado.

> [!IMPORTANT]
> **Armadilha do `ENTITY_ID` na separação TT/SL:**  
> Ao contrário do que seria intuitivo, **não se deve filtrar por `ENTITY_ID = 5` vs `ENTITY_ID = 8`**! Ambas as entidades têm validações registadas de forma cruzada nos cais.  
> A metodologia oficial da TML (reproduzida da fórmula Excel da colega) utiliza a **georreferenciação por `RUN_CODE`**:
> - **`RUN_CODE = 7` $\rightarrow$ Soflusa (SL)** (ligação fluvial do Barreiro).
> - **Todos os outros `RUN_CODE` (0, 1, 3, 5, 9) $\rightarrow$ Transtejo (TT)** (Cacilhas, Seixal, Montijo, Trafaria).
> 
> Além disso, é obrigatório filtrar:
> - `VALID_TYPE_ID = 0` (exclui testes / validações de serviço)
> - `VALBYPROF = 0` (exclui perfis profissionais especiais)
> - `TICKET_OPERATOR_CODE = 31` (títulos Navegante)

**Query 2b ([`code/query_SL_TT.sql`](file:///c:/GIS/Compensacoes/code/query_SL_TT.sql)):**
```sql
SELECT
    DISTRIBUTION_YEAR,
    DISTRIBUTION_MONTH,
    TICKET_OPERATOR_CODE,
    TICKET_CODE,
    ENTITY_ID,
    RUN_CODE,
    VALID_TYPE_ID,
    VALBYPROF,
    SUM(QNT_VALIDATION) AS PT_VALIDACOES
FROM DW_PROC.F_VALIDATIONS
WHERE DISTRIBUTION_YEAR  = <ANO>
  AND DISTRIBUTION_MONTH = <MES>
  AND ENTITY_ID IN (5, 8)          -- 5=TT (Transtejo), 8=SL (Soflusa)
  AND TICKET_OPERATOR_CODE = 31    -- Navegante
  AND VALID_TYPE_ID = 0
  AND VALBYPROF = 0
GROUP BY
    DISTRIBUTION_YEAR,
    DISTRIBUTION_MONTH,
    TICKET_OPERATOR_CODE,
    TICKET_CODE,
    ENTITY_ID,
    RUN_CODE,
    VALID_TYPE_ID,
    VALBYPROF
ORDER BY TICKET_CODE, ENTITY_ID, RUN_CODE;
```
- **Gravar em `input/` como:** `tt_sl_*(timestamp).csv` (ex: `tt_sl_202609111613.csv`).
- **Como o script calcula:** O total oficial de TT+SL é ancorado ao Recibo B de TT (`OPERADOR_TOTAL`). Os registos da Oracle fornecem apenas o *rateio percentual* entre TT e SL para cada título, assegurando que `TT + SL = Recibo B de TT` ao passageiro exato.

---

#### 2. Validações Fiscais Móveis CM (Portal VIVA, `ENTITY_ID = 23`) — Query 2c

> [!IMPORTANT]
> **Armadilha das validações em falta na Carris Metropolitana:**  
> Os Recibos B das 4 áreas operacionais da CM (A1 a A4) não contêm as validações efetuadas nos terminais móveis dos fiscais. Estas validações ficam registadas no Portal VIVA (`ENTITY_ID = 23`).  
> Se não forem somadas, a CM apresenta uma diferença negativa (ex.: -1.232 PT em maio de 2026).
> 
> **Regras essenciais da reconciliação:**
> 1. As validações móveis são distribuídas pelas 4 sub-áreas da CM através do cálculo:
>    $$\text{Área CM} = \lfloor \text{RUN\_CODE} / 1000 \rfloor + 40$$
>    - `1xxx` $\rightarrow$ Código 41 $\rightarrow$ **Área 1 (A1)**
>    - `2xxx` $\rightarrow$ Código 42 $\rightarrow$ **Área 2 (A2)**
>    - `3xxx` $\rightarrow$ Código 43 $\rightarrow$ **Área 3 (A3)**
>    - `4xxx` $\rightarrow$ Código 44 $\rightarrow$ **Área 4 (A4)**
> 2. **Apenas são considerados os títulos que já existem no Recibo B da CM**. Títulos não-Navegante (ex: ticket 33592) são automaticamente ignorados.

**Query 2c ([`code/query_CM_fiscaismoveis.sql`](file:///c:/GIS/Compensacoes/code/query_CM_fiscaismoveis.sql)):**
```sql
SELECT
    DISTRIBUTION_YEAR,
    DISTRIBUTION_MONTH,
    TICKET_OPERATOR_CODE,
    TICKET_CODE,
    23 AS ENTITY_ID,
    FLOOR(RUN_CODE / 1000) + 40 AS AREA_CM,
    VALID_TYPE_ID,
    VALBYPROF,
    SUM(QNT_VALIDATION) AS PT_VALIDACOES
FROM DW_PROC.F_VALIDATIONS
WHERE DISTRIBUTION_YEAR  = <ANO>
  AND DISTRIBUTION_MONTH = <MES>
  AND ENTITY_ID = 23               -- Portal VIVA (validadores móveis CM)
  AND TICKET_OPERATOR_CODE = 31    -- Navegante
  AND VALID_TYPE_ID = 0
  AND VALBYPROF = 0
  AND RUN_CODE BETWEEN 1000 AND 4999
GROUP BY
    DISTRIBUTION_YEAR,
    DISTRIBUTION_MONTH,
    TICKET_OPERATOR_CODE,
    TICKET_CODE,
    FLOOR(RUN_CODE / 1000) + 40,
    VALID_TYPE_ID,
    VALBYPROF
ORDER BY TICKET_CODE, AREA_CM;
```
- **Gravar em `input/` como:** `entity23_*(timestamp).csv` (ex: `entity23_202609111609.csv`).

---

#### 3. Cuidados no Oracle SQL Developer e Versionamento

> [!WARNING]
> **Armadilha do Limite de 200 Linhas no Oracle SQL Developer:**  
> Por omissão, o SQL Developer limita a busca em grelha a 200 registos. Se uma consulta devolver mais de 200 linhas e for exportada sem fazer scroll até ao fim, **o ficheiro CSV fica truncado em 200 linhas**, corrompendo os dados!  
> **Como foi resolvido**:
> As consultas foram pré-agrupadas e otimizadas no SQL:
> - `query_SL_TT.sql` devolve apenas ~93 linhas.
> - `query_CM_fiscaismoveis.sql` devolve apenas ~47 linhas.  
> Ambas ficam muito abaixo do limite de 200 linhas e podem ser exportadas diretamente em CSV com total segurança.

> [!TIP]
> **Regra de Seleção Automática de Ficheiros:**
> - Ao exportar, grava os ficheiros com os prefixos `tt_sl_` e `entity23_` seguidos de timestamp (ex.: `tt_sl_202609111613.csv`).
> - Se precisares de atualizar um ficheiro, podes adicionar `_update` ao nome (ex.: `tt_sl_202609111613_update.csv`). O script dá **prioridade máxima aos ficheiros com `_update`**.
> - Se houver múltiplos ficheiros (ou múltiplos updates), o script seleciona automaticamente o de **timestamp mais recente**.

**Comportamento em Fallback (se os ficheiros não existirem em `input/`):**
- TT/SL: assume TT como TT+SL e ignora SL (emitindo um aviso no console).
- CM: não adiciona validações do Portal VIVA (emite aviso de ausência do ficheiro).



---

# 1. Quotas

A partir dos recibos B, juntar as distâncias médias, com peso do operador, para estimar as quotas de cada operador por título.

## Distâncias

Regras para que distâncias utilizar, com a seguinte ordem de preferência:

1. Distância média calculada para a mesma tipologia de título, utilizado no mesmo Operador, em mês semelhante, considerando -se, para este efeito, dois grupos de meses com comportamento semelhante: i) junho, julho e agosto; ii) os restantes meses do ano;
2. Distância média calculada para a mesma tipologia de título, utilizada no mesmo Operador, em meses não semelhantes;
3. Distância média calculada de outro título, com o mesmo título base e modalidade, no mesmo Operador e no mesmo mês;
4. Distância média calculada do título base, no mesmo Operador e no mesmo mês;
5. Distância média definida nas tabelas 4 e 5 constantes da secção VIII. Distâncias Médias de Agosto e Outubro De 2021 (ver `lists/distanciasref_out21_incompleto.csv`).

### Distâncias médias de referência

* Para os meses de verão (Junho, Julho, Agosto), usa-se as distâncias de referência `ago21` → `lists/distanciasref_ago21_incompleto.csv`
* Para os restantes meses do ano (RA), usa-se as distâncias de referência `out21` → `lists/distanciasref_out21_incompleto.csv`

A seleção é feita automaticamente em `config.R` pela variável `DIST_REF_FILE`.

### Distâncias Médias Fabrik - Pedro (APEX)

Para os operadores que já usam a APEX, é possível ter as distâncias dinâmicas desse mês, como é o caso de:

* CM (`ENTITY_ID` 75)
* Cascais Proxima (`ENTITY_ID` 22)

Para isso, corro no ORACLE a query sql na `PDBDWPROD`

```SQL
SELECT * FROM DW_PROC.V_REG_AVERAGE_DISTANCE_FINAL_ALL 
where distribution_month = 05 and distribution_year = 2026;  -- Alterar ano e mês pretendido
```

que, carregando em "Export data" em csv, separado por ;, me dá o resultado em:
- `05_mai_2026_replicate/input/V_REG_AVERAGE_DISTANCE_FINAL_ALL_*.csv`
- `06_jun_2026_replicate/input/V_REG_AVERAGE_DISTANCE_FINAL_ALL_*.csv`

Deste ficheiro, preciso do `TICKET_CODE_REF`, `ENTITY_ID` e `CALC_FINAL_VALUE` - que já tem a distância média calculada internamente, para estes operadores (`ENTITY_ID`) e para cada título.

Portanto, para estes casos que já usam APEX, não usar as distâncias de referência.

### Script: `02_distancias.R`

**Outputs:**
- `F_DISTANCIAS` → `distancias_{SUFIXO}.csv`: colunas `operador`, `ticket_code`, `distancia_km`, `fonte`

**Campos de `fonte`:** `"APEX"` (CM, CAP) | `"ref_estatica"` (outros) | `"nao_encontrada"` (sem distância)

## Pesos

Os pesos são fixos, iguais para todos os meses, por operador. A soma não é 1.

São maiores quando as distâncias são menores, para compensar com os pkm.

Estão em `lists/pesos_pkm.csv` (formato: `operador_nome_navegante;peso`, sem header).

## Quotas cálculo final

Então, para cada título e operador,

$$
\begin{aligned}
\text{PKM}_{i, j} &= \text{Passageiros Transportados}_{i, j} \times \text{Distâncias Médias}_{i, j} \\[8pt]
\text{Quota}_{i, j} &= \text{Peso}_{i, j} \times \text{PKM}_{i, j} \\[8pt]
\sum_{j} \text{Quota}_{i, j} &= 1 \quad \forall i
\end{aligned}

$$

> *Onde:*
>
> - $i$: Título de transporte
> - $j$: Operador de transporte
> - $\overline{d}_{i,j}$: Distância média percorrida
> - $\text{PKM}_{i,j}$: Passageiro-Quilómetro (Passageiros $\times$ Distância)
> - $\forall i$: Para todo e qualquer título $i$ (a soma das quotas entre todos os operadores $j$ perfaz $1$ ou $100\%$)

Em percentagem. A soma para cada título é 1. Quando não há PKM para um título (distância=0 para todos os operadores), usa-se a quota média do operador.

### Script: `03_quotas.R`

**Outputs:**
- `F_QUOTAS` → `quotas_{SUFIXO}.csv`: colunas `operador`, `ticket_code`, `pt_operador`, `distancia_km`, `peso`, `pkm`, `quota_raw`, `quota`, `quota_fonte`

---

# 2. Vendas A e K

Quanto o título não exige um carregamento mensal, é considerado apenas quando existe **pelo menos 1 validação** nesse mês. (por exemplo, passe escolar). Se 0 validações, não é considerado.

Sabemos isso pela tabela `reg_[OPERADOR]_reciboB_transactionsOperatorSystem_*.csv`, campo `SOURCE` == "Validations as Transcactions". O valor de `SISTEMA_QUANTITY` diz-me quantas validações houve em títulos sem carregamento (global).

> Quanto há venda de um título, mas essse título não teve validações, usa-se a média das quotas para distribuir essa receita. Por exemplo: PAC (passe antigos combatentes) comprado a pvp 0€, mas que tem custo de 10€, mas não foi nunca usado pelo seu titular, tem de se compensar.

Temos:

- **A**: quantidades vendidas de cada título por cada operador = `OPERADOR_QUANTITY` + `SIIT_QTY`
- **K**: quantidades vendidas por canais de venda genéricos da TML: PV e SIBS, que vêm de uma tabela `ReciboB_{ANOMES}_Separação_PV_ATM.xlsx`, com a lista do ticket_code e a quantidade de venda, em PV e SIBS - **esta lista é extraída pelo Departamento ITS.**

Temos o pvp, sabemos as receitas de venda em € de cada operador (A), e dos canais de venda K.

Fazemos a soma por título (receita por título), incluindo os K [`receita_titulo_distribuir`]

Fazemos a receita na posse do operador (A), como a soma por operador, de todos os títulos.

### Script: `04_vendas_AK.R`

**Outputs:**
- `F_VENDAS_AK` → `vendas_AK_{SUFIXO}.csv`: receita A por operador (colunas `operador`, `receita_A`, `qty_A`)
- `F_RTD` → `receita_titulo_distribuir_{SUFIXO}.csv`: receita total a distribuir por título (colunas `ticket_code`, `receita_A_total`, `qty_A_total`, `receita_K`, `qty_K`, `receita_distribuir`)

---

# 4. Repartição das receitas operador + Compensação congelamento navegante

## Receita por título e operador (B)

Agora vamos ver quanto é que cada operador teria direito a receber, a partir da quota por título e operador, e do total de receita desse título [`receita_titulo_distribuir`]  (ver items anteriores). Portanto

Distribuição receita navegante, por operador e título [`dist_receita`] = quota * `receita_distribuir`, em € arredondados ao cêntimo.

Calculamos também a receita a compensar por operador j, como receita bilheteira devida ao operador (B)

## Parcela de congelamento

Uma vez que o pvp dos passes Navegante não é atualizado com a inflação e outras taxas, a que se chama de `TAT` (Taxa de Atualização Tarifária), é necessário compensar os operadores adicionalmente com esse valor.

Esta TAT é calculada pela AMT em final de outubro, e é aplicada cumulativamente, por ano, desde 2023:

- 2024: 6.43%
- 2025: 2.02%
- 2026: 2.28%

Estes valores estão em `lists/tat.csv` (em número, não em percentagem).

Calculamos a receita a compensar como:

se Valor = dist_receita_operador_titulo (i,j)

$$
\text{ReceitaCompensar i,j} = \text{Valor} \times \left[ (1 + \text{TAT}_{2024})(1 + \text{TAT}_{2025})(1 + \text{TAT}_{2026}) - 1 \right]

$$

 A parcela de congelamento por operador j é somada (Congelamento Navegante)

### Script: `05_reparticao_B.R`

**Outputs:**
- `F_REPARTICAO_B` → `reparticao_B_{SUFIXO}.csv`: colunas `operador`, `ticket_code`, `titulo_nome`, `dist_receita`, `receita_compensar`
- `F_CONGELAMENTO` → `congelamento_{SUFIXO}.csv`: colunas `operador`, `B` (receita devida total), `congelamento`

---

# 5. Distribuição COSP tarifária (D)

COSP - Compensação de Obrigação de Serviço Público

Há um valor máximo de compensação (VMC), atualizado à TAT todos os anos, quando se vende **até** 8.472.289 passes por ano.

O VMC regulado para 2023 = 112562432.41

nº passes a compensar = 8472289

Há sazonalidade mensal (`lists/sazonalidade.csv`)

Há uma retenção de 2.5% do valor a compensar, que fica na TML todos os meses, e que depois é apurado no fim do ano e acertado (retencao_tml = 2.5%)

Estimativa do N.º passes anuais vendidos = sazonalidade * número total de passes vendidos (sum SISTEMA_QUANTITY)

Percentagem do Nº Passes vendidos a compensar = se nº passes a compensar maior que Estimativa do N.º passes anuais vendidos, 100%. c.c. Estimativa do N.º passes anuais vendidos / nº passes a compensar. Dá uma percentagem

VMC_2026 = VMC_2023 (regulado) * [(1+TAT_2024)(1+TAT_2025)(1+TAT_2026) ], arredondado ao cêntimo.

O valor médio compensação por passe = VMC_2026 / nº passes a compensar

Nº passes a compensar i = Percentagem do Nº Passes vendidos a compensar * Quantidades vendidas por título i

COSP i = Nº passes a compensar i * valor médio compensação por passe * (1-retencao_tml)

Distribuição COSP i,j = COSP i * Quota i,j

Distribuição COSP j (D)= sum( Distribuição COSP i,j), j

### Script: `06_cosp_D.R`

**Outputs:**
- `F_COSP_D` → `cosp_D_{SUFIXO}.csv`: detalhe COSP por título × operador
- `F_D_OPERADOR` → `D_operador_{SUFIXO}.csv`: COSP total (D) por operador

---

# 6. Transferências (F)

Calcula-se  as tranferências da TML para os operadores, e também entre operadores (de evitar).

Usa-se os valores das tabelas anteriores, por operador

- receita na posse do operador (A), incluindo os K
- receita bilheteira devida ao operador (B)
  - o valor total destas duas receitas tem de ser igual: `sum(A) + sum(K) == sum(B)` ✓
- pagamento por conta COSP devida ao operador (D)
- Transferência (F) = B + D - A
- Congelamento Navegante
- Total a transferir = F + Congelamento

Se houver excedente (valor a transferir negativo), normalmente a TST, tenta-se que essa devolução seja feita para membros do mesmo grupo económico (Fertagus). Senão devolve à TML.

A COSP e o Congelamento são pagos pelo programa "Incentiva". O "Incentiva" é pago só depois da TML o receber do estado.

> Para Cascais não se paga nada todos os meses, e espera-se pelo acerto no final do ano devido à gratuitidade municipal que eles implementaram.

### Script: `07_transferencias_F.R`

**Outputs:**
- `F_TRANSFERENCIAS` → `transferencias_F_{SUFIXO}.csv`: tabela final por operador com colunas `operador`, `nome_operador`, `receita_A` (A), `B`, `D`, `congelamento`, `F_transferencia`, `total_transferir`, `nota`, `pagamento_imediato`, `pagamento_incentiva`

---

# 7. Informações e Ofícios

Faz-se 1 Informação interna (eg: `05_mai_2026/TML-I01880-20260807-INF-00256-DEP.docx`) e 2 ofícios, um deles para pagar já e o outro para pagar o remanescente quando o Incentiva for transferido.

> Para Cascais não se paga nada todos os meses, e espera-se pelo acerto no final do ano devido à gratuitidade municipal que eles implementaram.


# Outras notas

`PTs*.xlsx` são Passageiros transportados. Vem de um script. Tem de se excluir os da Scotturb. Tem também de se excluir os validadores móveis dos fiscais (entity 23).

Nas receitas, excluir os "Validators as Transactions", senão vai dar quantidades duplicadas.

# Importante

Seria bom ter alguns testes de comparação, para ver se a coisa está a fazer sentido. Por exemplo, comparar com o mês anterior para ver se há grande discrepância, ou com o mês homólogo do ano anterior.

* Criar as tabelas finais, sem espinhas, num só workbook.
* Criar os documentos de informação e ofícios automaticamente.

# Tabelas estáticas de referência (`lists/`)

| Ficheiro | Descrição |
|---|---|
| `operadores.csv` | Todos os operadores: `ENTITY_ID`, `ENTITY_ABBREVIATION`, `OPERATOR_NAME_NAVEGANTE` |
| `titulos.csv` | Títulos Navegante: `ticket_code`, `titulo_nome`, `modalidade`, `pvp`, `titulo_nome_base`, `preco_base` |
| `titulos2.csv` | Versão alternativa/expandida da lista de títulos |
| `titulos_alternativas.csv` | Mapeamento de alternativas de títulos |
| `distanciasref_out21_incompleto.csv` | Distâncias médias de referência (Outubro 2021) — formato wide por operador |
| `distanciasref_ago21_incompleto.csv` | Distâncias médias de referência (Agosto 2021) — para meses de verão |
| `pesos_pkm.csv` | Pesos por operador (sem header): `operador_nome_navegante;peso` |
| `sazonalidade.csv` | Sazonalidade mensal (12 meses): `mes;sazonalidade` |
| `tat.csv` | Taxa de Atualização Tarifária por ano: `ano;tat` |
