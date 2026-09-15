# TML — Compensações e Distribuição de Receitas Navegante

Pipeline em **R** para o cálculo mensal da repartição de receitas tarifárias do sistema **Navegante** e apuramento das compensações aos operadores de transporte público da Área Metropolitana de Lisboa (TML).

Replica com precisão matemática a metodologia regulamentar (Regulamento n.º 1362-C/2023):

- **Passageiros Transportados (PT)** e agregação dos Recibos B
- **Distâncias Médias** (APEX dinâmicas para CM e CAP; de referência para os restantes)
- **Passageiro-Quilómetro (PKM)** e **Quotas de Repartição**
- **Vendas A** (operadores) e **Vendas K** (Portal VIVA e ATM)
- **Repartição de Receitas (B)** e **Congelamento Tarifário (TAT)**
- **Compensação por Obrigações de Serviço Público — COSP (D)**
- **Apuramento Final de Transferências Financeiras (F)**
- **Relatório Oficial em Excel (XLSX)**: Quadro cruzado de 14 colunas com transferências entre operadores (MTS/FT), rateio de canais partilhados (Total K) e verbas do Incentiva +TP

---

## 📋 Checklist de Dados Pré-Execução

Antes de executar o pipeline para um determinado mês (ex.: Maio de 2026 $\rightarrow$ `05_mai_2026`), é necessário garantir que os seguintes ficheiros estão nos respetivos diretórios:

### 1. Recibos B dos Operadores

Colocar em `{MES}_{mes_abrev}_{ANO}/Recibos B/`:

- Pastas descompactadas dos operadores: `reg_[OPERADOR]_reciboB_[ANOMES]_[DATA]/`
  - Contendo os ficheiros `*_PTconsideredByProduct_*.csv` (validações/PT) e `*_transactionsOperatorSystem_*.csv` (vendas/receita A).
  - Operadores esperados: `CP`, `ML`, `Carris`, `FT`, `MS`, `TB`, `CAP`, `BQ`, `A1`, `A2`, `A3`, `A4`, `TT`, `SL`.
- **Ficheiro de Separação PV / ATM (Receita K)**:
  - Ficheiro Excel fornecido pelo Dept. ITS / SIBS (ex.: `ReciboB_052026_Separa_receita_PV_e_ATM.xlsx`) colocado na pasta `Recibos B/`.

### 2. Exportações Oracle (`PDBDWPROD`)

Executar as seguintes consultas na base de dados Oracle e exportar os CSVs (separador `;`) para `{MES}_{mes_abrev}_{ANO}_replicate/input/`:


| Ficheiro a gravar em`input/`                        | Consulta / Script                                                                                                        | Objetivo                                                                                        |
| ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `V_REG_AVERAGE_DISTANCE_FINAL_ALL_*(timestamp).csv` | `SELECT * FROM DW_PROC.V_REG_AVERAGE_DISTANCE_FINAL_ALL WHERE distribution_month = <MES> AND distribution_year = <ANO>;` | Distâncias médias dinâmicas APEX para Carris Metropolitana (`75`) e Cascais Próxima (`22`). |
| `tt_sl_*(timestamp).csv`                            | [`code/query_SL_TT.sql`](code/query_SL_TT.sql) (Query 2b)                                                                | Rácios de georreferenciação por`RUN_CODE` para separar Transtejo (`TT`) de Soflusa (`SL`).   |
| `entity23_*(timestamp).csv`                         | [`code/query_CM_fiscaismoveis.sql`](code/query_CM_fiscaismoveis.sql) (Query 2c)                                          | Validações em terminais móveis dos fiscais da Carris Metropolitana (`ENTITY_ID = 23`).       |

> **Dica de versionamento de ficheiros:**
>
> - O script seleciona automaticamente o ficheiro com o **timestamp numérico mais recente**.
> - Se precisares de substituir ou atualizar um ficheiro, basta adicionar `_update` ao nome (ex: `tt_sl_202609111613_update.csv`) — os ficheiros com `_update` têm **prioridade automática**.

---

## 🚀 Como Executar

### Passo 1: Configuração do Mês/Ano

Edita o ficheiro [`code/config.R`](code/config.R) para definir o ano e o mês:

```r
ANO <- 2026
MES <- 5       # 5 = Maio, 6 = Junho, etc.
```

*(Em alternativa, podes passar variáveis de ambiente: `ANO=2026 MES=5 Rscript code/99_run_all.R`)*

### Passo 2: Instalação de Dependências (apenas na 1ª vez)

```bash
Rscript code/00_setup.R
```

*(Verifica e instala automaticamente os pacotes: `tidyverse`, `readxl`, `writexl`, `janitor`, `glue`, `here`, `lubridate`, `scales`, `openxlsx`)*

### Passo 3: Executar o Pipeline Completo

```bash
Rscript code/99_run_all.R
```

Tempo de execução típico: **~3 a 4 segundos**.

---

## 📊 Ficheiros de Saída (Output)

Os resultados são gerados na pasta `{MES}_{mes_abrev}_{ANO}_replicate/output/` com o sufixo do mês (ex: `mai26`):

| Ficheiro | Descrição |
| --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`tabela_transferencias_{SUFIXO}.xlsx`**          | **Workbook Excel oficial consolidado**: <br>• `0 - Global`: Quadro oficial de 14 colunas com apuramento TML, acerto entre operadores (MTS $\rightarrow$ FT), rateio dos canais partilhados ($K$) e dotação Incentiva +TP.<br>• `1 - Quotas`: Matriz de quotas de repartição por título e operador.<br>• `2 - Vendas AK`: Resumo de bilheteiras (A) e canais externos (K).<br>• `4 - Receita B e CongNav B`: Síntese de receita devida e congelamento.<br>• `5 - Pag Conta COSP D`: Parâmetros regulamentares COSP e pagamentos.<br>• `6 - Transferencias F`: Formato longo por métrica. |
| **`6_transferencias_{SUFIXO}.csv`**                | **Tabela final de compensações (CSV)**: receitas na posse (`receita_A`), receitas devidas (`receita_B`), saldo (`saldo_C`), COSP (`cosp_D`), saldo global (`SG`), transferências (`F_transferencia`), congelamento (`congelamento_B`) e total a transferir por operador. |
| `1a_PT_{SUFIXO}.csv`                                | Passageiros transportados (validações) agregados por título e operador.                                                                                               |
| `1b_PT_CM_{SUFIXO}.csv`                             | Agregação explícita das áreas A1 a A4 + fiscais móveis da Carris Metropolitana.                                                                                      |
| `1c_receitas_titulo_{SUFIXO}.csv`                   | Quantidade e receita de vendas de títulos por operador (Recibos B).                                                                                                   |
| `1d_validacoes_{SUFIXO}.csv`                        | Quantidades de títulos gratuitos sem carregamento prévio (VaT).                                                                                                      |
| `1e_distancias_{SUFIXO}.csv`                        | Distâncias médias (km) utilizadas por operador e título.                                                                                                              |
| `1_quotas_{SUFIXO}.csv`                             | Passageiro-Quilómetro (PKM) e quotas de repartição regulamentares (0 a 1).                                                                                            |
| `2_vendas_A_{SUFIXO}.csv`                           | Receita e quantidades na posse de cada operador através de bilheteiras/canais próprios (Canais A).                                                                    |
| `2_vendas_K_{SUFIXO}.csv`                           | Vendas e receitas dos canais de receita partilhada TML (Portal VIVA e rede Multibanco/SIBS).                                                                         |
| `4a_receita_titulo_distribuir_{SUFIXO}.csv`         | Receita global do sistema a distribuir por título ($A + K$) e quantidades totais de títulos vendidos.                                                                 |
| `4b_reparticao_B_{SUFIXO}.csv`                      | Detalhe da receita bilheteira devida ($B$) e congelamento TAT por título e operador.                                                                                  |
| `4_receitaB_congelamento_{SUFIXO}.csv`              | Resumo por operador da receita devida (`receita_B`) e do congelamento tarifário (`congelamento_B`).                                                                   |
| `5a_cosp_{SUFIXO}.csv`                              | Compensação por OSP (COSP tarifária $D$) detalhada por título e operador.                                                                                             |
| `5_cosp_operador_{SUFIXO}.csv`                      | Compensação COSP total devida por operador (`cosp_D`).                                                                                                                |

---

## 📁 Estrutura do Repositório

```
Compensacoes/
├── code/
│   ├── config.R                  # Configuração global de caminhos e parâmetros regulamentares
│   ├── 00_setup.R                # Gestão e instalação de dependências R
│   ├── 01_recibos_b.R            # Agregação dos Recibos B e reconciliação Oracle
│   ├── 02_distancias.R           # Distâncias médias (APEX dinâmicas e estáticas)
│   ├── 03_quotas.R               # Cálculo de PKM e quotas de distribuição
│   ├── 04_vendas_AK.R            # Agregação de vendas A (operadores) e K (PV e ATM/SIBS)
│   ├── 05_reparticao_B.R         # Distribuição de receita B e congelamento TAT
│   ├── 06_cosp_D.R               # Cálculo da compensação COSP (D)
│   ├── 07_transferencias_F.R     # Apuramento das transferências finais (F)
│   ├── 08_tables.R               # Exportação do relatório consolidado em Excel (xlsx)
│   ├── 99_run_all.R              # Script mestre de execução sequencial
│   ├── procedure.md              # Documentação técnica e metodológica detalhada
│   ├── query_SL_TT.sql           # Query Oracle para separação TT / SL (Query 2b)
│   └── query_CM_fiscaismoveis.sql# Query Oracle para validações fiscais CM (Query 2c)
├── lists/                        # Tabelas estáticas e regulamentares de referência
│   ├── operadores.csv            # Mapeamento de códigos e nomes de operadores
│   ├── pesos_pkm.csv             # Pesos operacionais para cálculo de quotas PKM
│   ├── distanciasref_out21_incompleto.csv # Distâncias estáticas (meses de inverno/restantes)
│   ├── distanciasref_ago21_incompleto.csv # Distâncias estáticas (meses de verão: jun, jul, ago)
│   ├── tat.csv                   # Taxa de Atualização Tarifária anual (TAT)
│   └── sazonalidade_cosp.csv     # Coeficientes mensais de sazonalidade COSP
└── README.md
```

---

## 📖 Documentação Metodológica

Para conhecer todas as fórmulas regulamentares, regras de cálculo, filtros e especificidades da reconciliação, consulta o documento:
👉 **[`code/procedure.md`](code/procedure.md)**
