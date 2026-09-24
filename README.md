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
- **Documentos Técnicos Oficiais (PDF via Typst)**: Geração automatizada e imediata da Informação Técnica e Ofícios de pagamento em PDF de alta qualidade gráfica via Quarto e Typst, com tabelas dinâmicas padronizadas (`tinytable`).

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

## 🗓️ Como Preparar um Novo Mês (ex: Agosto de 2026)

Antes de correr o pipeline pela primeira vez para um novo mês, há um conjunto de passos de preparação obrigatórios. Segue-os **por esta ordem**.

### 1. Criar a pasta de dados do mês

Cria a pasta `08_ago_2026/` na raiz do projecto (por analogia com `05_mai_2026/`, `06_jun_2026/`). Dentro desta pasta, cria a sub-pasta `Recibos B/`.

### 2. Recolher e colocar os ficheiros de dados

#### 2a. Recibos B dos operadores

Descompactar as pastas dos Recibos B de cada operador para `08_ago_2026/Recibos B/`:

```
08_ago_2026/Recibos B/
├── reg_CP_reciboB_082026_<DATA>/
├── reg_ML_reciboB_082026_<DATA>/
├── reg_Carris_reciboB_082026_<DATA>/
├── ...
└── ReciboB_082026_Separa_receita_PV_e_ATM.xlsx   ← ficheiro Excel de separação PV/ATM
```

O ficheiro `ReciboB_082026_Separa_receita_PV_e_ATM.xlsx` é fornecido pelo Dept. ITS / SIBS e **é obrigatório** para separar as receitas do Portal VIVA (PV) das do Multibanco (ATM).

#### 2b. Exportações Oracle (inputs do cálculo)

Executar as queries e guardar os CSV (separador `;`) em `08_ago_2026_replicate/input/`:

| Ficheiro | Query / Script |
| --- | --- |
| `V_REG_AVERAGE_DISTANCE_FINAL_ALL_<timestamp>.csv` | `SELECT * FROM DW_PROC.V_REG_AVERAGE_DISTANCE_FINAL_ALL WHERE distribution_month = 8 AND distribution_year = 2026;` |
| `tt_sl_<timestamp>.csv` | [`code/query_SL_TT.sql`](code/query_SL_TT.sql) |
| `entity23_<timestamp>.csv` | [`code/query_CM_fiscaismoveis.sql`](code/query_CM_fiscaismoveis.sql) |

> [!TIP]
> Para substituir um ficheiro de input já existente sem apagar o anterior, basta renomear o novo com o sufixo `_update` (ex: `tt_sl_202608151400_update.csv`). Os ficheiros `_update` têm prioridade automática sobre os demais.

### 3. Registar a `load_version` do mês em `lists/load_versions.csv`

A `load_version` identifica a versão do processamento de distâncias da Carris Metropolitana (Trino/APEX). É fornecida pelo Dept. ITS e **tem de ser registada antes de renderizar qualquer documento**.

Abrir [`lists/load_versions.csv`](lists/load_versions.csv) e adicionar uma linha para o novo mês:

```csv
mes;ano;load_version
...
6;2026;31
8;2026;XX    ← adicionar esta linha (substituir XX pelo número correto)
```

> [!IMPORTANT]
> Se esta linha não existir, a Informação 1 não irá encontrar a versão de processamento e o documento terá um campo em branco ou com erro.

### 4. Atualizar `code/config.R`

Editar [`code/config.R`](code/config.R) e alterar:

```r
ANO <- 2026
MES <- 8       # ← alterar para o mês pretendido

# Ativar/desativar os documentos a gerar:
RENDER_INFORMACAO1 <- TRUE
RENDER_METODOLOGIA <- TRUE
RENDER_OFICIO1     <- TRUE
RENDER_OFICIO2     <- TRUE
RENDER_DOCX        <- FALSE   # TRUE gera também versão Word (requer PDF24 instalado)
```

### 5. Atualizar os parâmetros específicos da emissão nos documentos

Cada documento `.qmd` tem um bloco `# PARÂMETROS ESPECÍFICOS DESTE DOCUMENTO` no início que deve ser revisto para a emissão do novo mês.

#### [`code/informacao1.qmd`](code/informacao1.qmd)

```r
# Datas de receção dos dados de bilhética:
data_dados_dits   <- "XX de setembro de 2026"   # data em que o DITS enviou os dados
data_dados_its    <- "XX de setembro de 2026"   # data em que o ITS enviou os dados

# Financiamento do Fundo Ambiental (Incentiva +TP):
# TRUE  = verba ainda NÃO transferida → faturação parcelar
# FALSE = verba já disponível → faturação imediata total
incentiva_tp_pendente <- TRUE

# Número de referência da informação:
numero_informacao <- "TML-XXXX-XXXX-INF-XXXX-DEP"
```

> A `load_version` é lida automaticamente de [`lists/load_versions.csv`](lists/load_versions.csv) (ver passo 3).

#### [`code/oficio1.qmd`](code/oficio1.qmd) e [`code/oficio1_alt.qmd`](code/oficio1_alt.qmd)

```r
numero_informacao <- "TML-XXXX-XXXX-INF-XXXX-DEP"
numero_oficio     <- "TML-XXXX-XXXX-OF-XXXX-DEP"
```

#### [`code/oficio2.qmd`](code/oficio2.qmd)

```r
numero_informacao <- "TML-XXXX-XXXX-INF-XXXX-DEP"
numero_oficio     <- "TML-XXXX-XXXX-OF-XXXX-DEP"
numero_oficio2    <- "TML-YYYY-YYYY-OF-YYYY-DEP"
```

### 6. Verificar pré-requisitos do sistema (apenas uma vez por máquina)

- **R** ≥ 4.3 instalado.
- **Quarto CLI** ([quarto.org](https://quarto.org)) instalado e acessível na linha de comandos (`quarto --version`).
- Pacotes R instalados: `Rscript code/00_setup.R`
- (Opcional) **PDF24 Toolbox** instalado em `C:/Program Files/PDF24/` para conversão PDF → Word.

---

## 🚀 Como Executar

### Passo 1: Configuração do Mês/Ano e Opções

Edita o ficheiro [`code/config.R`](code/config.R) para definir o ano, o mês e as opções de renderização de documentos:

```r
ANO <- 2026
MES <- 5       # 5 = Maio, 6 = Junho, etc.

# Controlo de Documentos (Quarto / Typst)
RENDER_INFORMACAO1 <- TRUE   # Gerar Informação 1 (PDF)
RENDER_METODOLOGIA <- TRUE   # Gerar Anexo Metodologia (PDF com timbrado externo)
RENDER_OFICIO1     <- FALSE  # Gerar Ofício 1 (pagamento receitas partilhadas)
RENDER_OFICIO2     <- FALSE  # Gerar Ofício 2 (pagamento incentiva)
RENDER_DOCX        <- FALSE  # TRUE converte PDF para Word (DOCX) via PDF24 Toolbox
DOCX_MODE          <- "asposeFlow" # "asposeFlow" (fluxo contínuo) ou "asposeBlocks" (blocos)
```

*(Em alternativa, podes passar variáveis de ambiente: `ANO=2026 MES=5 Rscript code/99_run_all.R`)*

### Passo 2: Instalação de Dependências (apenas na 1ª vez)

```bash
Rscript code/00_setup.R
```

*(Instala e valida os pacotes R: `tidyverse`, `readxl`, `writexl`, `janitor`, `glue`, `here`, `lubridate`, `scales`, `openxlsx`, `tinytable`. Requer também o [Quarto CLI](https://quarto.org) instalado no sistema para compilação Typst).*

### Passo 3: Executar o Pipeline Completo

Para correr todo o cálculo matemático e gerar automaticamente os documentos configurados:

```bash
Rscript code/99_run_all.R
```

O pipeline executa os cálculos (passos 01 a 08) em ~3 segundos e compila os documentos ativos (passo 10) em ~10 segundos.

---

## 📄 Como Gerar os Documentos (Informações e Ofícios)

Os relatórios técnicos usam **Quarto** com o backend **Typst** e o pacote **`tinytable`**, produzindo ficheiros PDF de elevada qualidade gráfica com paginação profissional, totais em negrito e notas ajustadas.

### Opção A: No Pipeline Geral (Recomendado)

Ao executar `Rscript code/99_run_all.R`, o script mestre executa automaticamente o passo `code/10_documentos.R` caso `RENDER_INFORMACAO1` (ou dos ofícios) esteja como `TRUE` em `code/config.R`.

### Opção B: Renderização Isolada (Rápida)

Se os cálculos já tiverem sido executados e quiseres apenas recompilar a Informação 1 (por exemplo, após rever o texto ou os parâmetros no documento):

```bash
# Executa todos os documentos ativos em config.R (gera PDF Typst):
Rscript code/10_documentos.R

# Ou executa diretamente a Informação 1:
Rscript code/render_informacao1.R
```

Para gerar também a versão Word (DOCX) via PDF24 Toolbox na linha de comandos:

```powershell
# Gerar PDF e converter para Word (modo flow):
$env:RENDER_DOCX="TRUE"; Rscript code/10_documentos.R

# Gerar PDF e converter para Word em modo blocks:
$env:RENDER_DOCX="TRUE"; $env:DOCX_MODE="asposeBlocks"; Rscript code/10_documentos.R
```

### Personalização da Emissão

No cabeçalho de [`code/informacao1.qmd`](code/informacao1.qmd), podes ajustar os parâmetros específicos da emissão do mês:

- `data_dados_dits` e `data_dados_its`: datas de receção dos dados de bilhética;
- `load_version`: versão do cálculo de distâncias Trino/APEX;
- `incentiva_tp_pendente`: `TRUE` se o Fundo Ambiental ainda não tiver transferido a dotação (recomenda faturação parcelar), ou `FALSE` se o montante já estiver disponível;
- `numero_informacao` e intervenientes técnicos.

Os documentos gerados são gravados em `{MES}_{mes_abrev}_{ANO}_replicate/output/docs/`:

| Documento | Ficheiro |
| --- | --- |
| Informação 1 (PDF) | `Informacao_{SUFIXO}.pdf` |
| Informação 1 (Word) | `Informacao_{SUFIXO}.docx` |
| Anexo Metodologia (PDF) | `Anexo_Metodologia_{SUFIXO}.pdf` |
| Ofício 1 (PDF) | `Oficio1_{SUFIXO}.pdf` |
| Ofício 1 variante (PDF) | `Oficio1_alt_{SUFIXO}.pdf` |
| Ofício 2 (PDF) | `Oficio2_{SUFIXO}.pdf` |
| Cálculos Excel (XLSX) | `Anexo_Calculos_{SUFIXO}.xlsx` |


---

## 📊 Ficheiros de Saída (Output)

Os resultados são gerados na pasta `{MES}_{mes_abrev}_{ANO}_replicate/output/` com o sufixo do mês (ex: `mai26`):


| Ficheiro | Descrição |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`docs/Informacao_{SUFIXO}.pdf`**                   | **Informação 1 (PDF)**: Nota interna de apresentação dos resultados mensais, com narrativa formal, fórmulas e Tabelas 1 a 8 formatadas. |
| **`docs/Informacao_{SUFIXO}.docx`**                  | Versão Word da Informação 1 (gerada quando `RENDER_DOCX = TRUE`). |
| **`docs/Anexo_Metodologia_{SUFIXO}.pdf`**            | **Anexo Metodologia (PDF com papel timbrado externo)**: Documento formal com cabeçalho timbrado (`templates/folha_1.pdf` / `folha_restantes.pdf`) e fórmulas regulamentares detalhadas. |
| **`docs/Oficio1_{SUFIXO}.pdf`**                      | **Ofício 1**: Comunicação formal de pagamentos imediatos a cada operador (receitas partilhadas Canal K). |
| **`docs/Oficio1_alt_{SUFIXO}.pdf`**                  | **Ofício 1 (variante)**: Idem, mas com tabelas no fim dos itens numerados. |
| **`docs/Oficio2_{SUFIXO}.pdf`**                      | **Ofício 2**: Comunicação formal relativa às verbas do Incentiva +TP. |
| **`docs/Anexo_Calculos_{SUFIXO}.xlsx`**              | **Workbook Excel consolidado**: <br>• `0 - Global`: Quadro de 14 colunas com apuramento TML, acerto MTS→FT, rateio K e dotação Incentiva +TP.<br>• `1 - Quotas`: Matriz de quotas por título e operador.<br>• `2 - Vendas AK`: Resumo de bilheteiras (A) e canais externos (K).<br>• `4 - Receita B e CongNav B`: Síntese de receita devida e congelamento.<br>• `5 - Pag Conta COSP D`: Parâmetros regulamentares COSP.<br>• `6 - Transferencias F`: Formato longo por métrica. |
| **`6_transferencias_{SUFIXO}.csv`**                  | **Tabela final de compensações (CSV)**: colunas `receita_A`, `receita_B`, `saldo_C`, `cosp_D`, `SG`, `F_transferencia`, `congelamento_B`, total a transferir por operador. |
| `1a_PT_{SUFIXO}.csv`                                 | Passageiros transportados (validações) por título e operador. |
| `1b_PT_CM_{SUFIXO}.csv`                              | Agregação A1+A2+A3+A4 + fiscais móveis da Carris Metropolitana. |
| `1c_receitas_titulo_{SUFIXO}.csv`                    | Quantidade e receita de vendas de títulos por operador (Recibos B). |
| `1d_validacoes_{SUFIXO}.csv`                         | Quantidades de títulos gratuitos sem carregamento prévio (VaT). |
| `1e_distancias_{SUFIXO}.csv`                         | Distâncias médias (km) por operador e título. |
| `1_quotas_{SUFIXO}.csv`                              | PKM e quotas de repartição regulamentares (0 a 1). |
| `2_vendas_A_{SUFIXO}.csv`                            | Receita e quantidades na posse de cada operador (Canais A — bilheteiras próprias). |
| `2_vendas_K_{SUFIXO}.csv`                            | Vendas e receitas dos canais partilhados TML (Portal VIVA e Multibanco/SIBS). |
| `4a_receita_titulo_distribuir_{SUFIXO}.csv`          | Receita global do sistema a distribuir por título ($A + K$). |
| `4b_reparticao_B_{SUFIXO}.csv`                       | Detalhe da receita devida ($B$) e congelamento TAT por título e operador. |
| `4_receitaB_congelamento_{SUFIXO}.csv`               | Resumo por operador: `receita_B` e `congelamento_B`. |
| `5a_cosp_{SUFIXO}.csv`                               | COSP tarifária ($D$) detalhada por título e operador. |
| `5_cosp_operador_{SUFIXO}.csv`                       | COSP total devida por operador (`cosp_D`). |


---

## 📁 Estrutura do Repositório

```
Compensacoes/
├── code/
│   ├── config.R                  # Configuração global de caminhos, parâmetros e flags de documentos
│   ├── 00_setup.R                # Gestão e instalação de dependências R
│   ├── 01_recibos_b.R            # Agregação dos Recibos B e reconciliação Oracle
│   ├── 02_distancias.R           # Distâncias médias (APEX dinâmicas e estáticas)
│   ├── 03_quotas.R               # Cálculo de PKM e quotas de distribuição
│   ├── 04_vendas_AK.R            # Agregação de vendas A (operadores) e K (PV e ATM/SIBS)
│   ├── 05_reparticao_B.R         # Distribuição de receita B e congelamento TAT
│   ├── 06_cosp_D.R               # Cálculo da compensação COSP (D)
│   ├── 07_transferencias_F.R     # Apuramento das transferências finais (F)
│   ├── 08_tables.R               # Exportação do workbook Excel consolidado
│   ├── 10_documentos.R           # Renderização de todos os documentos Quarto (PDF + DOCX)
│   ├── 99_run_all.R              # Script mestre de execução sequencial (9 passos)
│   │
│   ├── informacao1.qmd           # Informação 1 — nota interna de resultados mensais
│   ├── metodologia.qmd           # Anexo Metodologia — documento externo com papel timbrado
│   ├── oficio1.qmd               # Ofício 1 — comunicação formal de pagamentos imediatos
│   ├── oficio1_alt.qmd           # Ofício 1 (variante) — tabelas no fim dos itens numerados
│   ├── oficio2.qmd               # Ofício 2 — comunicação formal Incentiva +TP
│   │
│   ├── render_informacao1.R      # Script de conveniência para renderizar só a Informação 1
│   ├── utils_tables.R            # Funções de formatação de tabelas (tinytable / Typst)
│   ├── utils_extenso.R           # Funções auxiliares para montantes por extenso em euros
│   ├── custom_styles.typ         # Estilos Typst: cabeçalhos, fundos e papel timbrado
│   ├── linebreaks.lua            # Filtro Pandoc (quebras de linha e deteção de doc-tipo externo)
│   ├── query_SL_TT.sql           # Query Oracle para separação TT / SL (Query 2b)
│   ├── query_CM_fiscaismoveis.sql# Query Oracle para validações fiscais CM (Query 2c)
│   └── templates/                # Modelos e recursos visuais institucionais (versionados no Git)
│       ├── folha_1.pdf           # Papel timbrado oficial TML (1.ª página, vetorial)
│       ├── folha_restantes.pdf   # Papel timbrado oficial TML (páginas seguintes, vetorial)
│       ├── logo_tml.svg          # Logótipo vetorial institucional TML
│       └── TML_template.docx     # Modelo de referência Word
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
