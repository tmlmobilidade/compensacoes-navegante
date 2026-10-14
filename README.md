# TML - Receitas e Compensações do Passe Navegante

Pipeline em **R** para o cálculo mensal da repartição de receitas tarifárias do sistema **Navegante** e apuramento provisório das compensações aos operadores de transporte público da Área Metropolitana de Lisboa (TML).

Replica com precisão matemática a metodologia regulamentar (Regulamento n.º 1362-C/2023):

- **Passageiros Transportados (PT)** e agregação dos Recibos B
- **Distâncias Médias** (APEX dinâmicas para CM e CAP; de referência para os restantes)
- **Passageiro-Quilómetro (PKM)** e **Quotas de Repartição**
- **Vendas A** (operadores) e **Vendas K** (Portal VIVA e ATM)
- **Repartição de Receitas (B)** e **Congelamento Tarifário (TAT)**
- **Compensação por Obrigações de Serviço Público — COSP (D)**
- **Apuramento Final de Transferências Financeiras (F)**
- **Relatório Oficial em Excel (XLSX)**: Quadro cruzado de 14 colunas com transferências entre operadores (MTS/FT), rateio de canais partilhados (Total K) e verbas do Incentiva +TP
- **Documentos Técnicos Oficiais (PDF via Typst)**: Informação Técnica e Ofícios de pagamento gerados automaticamente com Quarto e Typst (`tinytable`).

---

## 🗓️ Como Preparar um Novo Mês (ex: Agosto de 2026)

Antes de correr o pipeline pela primeira vez para um novo mês, há um conjunto de passos obrigatórios. Segue-os **por esta ordem**.

### 1. Criar a pasta de dados do mês (dentro de `data/`)

Cria a pasta `data/08_ago_2026/input/` (a pasta `data/` está no `.gitignore`, pelo que **não é preciso** alterar o `.gitignore` em cada mês). Dentro de `input/`, cria a sub-pasta `Recibos B/`. A pasta `output/` é criada automaticamente.

### 2. Recolher e colocar os ficheiros de dados

#### 2a. Recibos B dos operadores

Descompactar as pastas dos Recibos B de cada operador para `data/08_ago_2026/input/Recibos B/`:

```
data/08_ago_2026/input/Recibos B/
├── reg_CP_reciboB_082026_<DATA>/
├── reg_ML_reciboB_082026_<DATA>/
├── reg_Carris_reciboB_082026_<DATA>/
├── ...   (operadores: CP, ML, Carris, FT, MS, TB, CAP, BQ, A1–A4, TT, SL)
└── ReciboB_082026_Separa_receita_PV_e_ATM.xlsx   ← ficheiro Excel de separação PV/ATM
```

O ficheiro `ReciboB_082026_Separa_receita_PV_e_ATM.xlsx` é fornecido pelo Dept. ITS / SIBS e **é obrigatório** para separar as receitas do Portal VIVA (PV) das do Multibanco (ATM).

#### 2b. Exportações Oracle (`PDBDWPROD`)

Executar as queries e guardar os CSVs (separador `;`) em `data/08_ago_2026/input/`:


| Ficheiro a gravar em`input/`                       | Consulta / Script                                                                                                   | Objetivo                                                                                        |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `V_REG_AVERAGE_DISTANCE_FINAL_ALL_<timestamp>.csv` | `SELECT * FROM DW_PROC.V_REG_AVERAGE_DISTANCE_FINAL_ALL WHERE distribution_month = 8 AND distribution_year = 2026;` | Distâncias médias dinâmicas APEX para Carris Metropolitana (`75`) e Cascais Próxima (`22`). |
| `entity23_<timestamp>.csv`                         | [`code/sql/query_CM_fiscaismoveis.sql`](code/sql/query_CM_fiscaismoveis.sql)                                        | Validações em terminais móveis dos fiscais da Carris Metropolitana (`ENTITY_ID = 23`).       |

> [!NOTE]
> **Separação Transtejo (TT) / Soflusa (SL) direta via APEX:**
> O APEX emite o Recibo B separado da Soflusa (`reg_SL_reciboB`) e o conjunto TT+SL (`reg_TT_reciboB`). Por isso, a separação é feita **diretamente no R** ($PT_{\text{SL}} = \text{Recibo B (SL)}$ e $PT_{\text{TT}} = \text{Recibo B (TT)} - \text{Recibo B (SL)}$), sendo **desnecessário** executar a consulta [`code/code-old/query_SL_TT.sql`](code/code-old/query_SL_TT.sql) ou descarregar ficheiros `tt_sl_*.csv` na rotina mensal (mantidos apenas como fallback histórico).

> [!TIP]
> O script seleciona automaticamente o ficheiro com o **timestamp numérico mais recente**. Para substituir um ficheiro sem apagar o anterior, adiciona `_update` ao nome (ex: `entity23_202608151400_update.csv`) — os ficheiros `_update` têm **prioridade automática**.

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

Editar [`code/config.R`](code/config.R) e alterar o mês, o ano e as flags de renderização:

```r
ANO <- 2026
MES <- 8       # ← alterar para o mês pretendido

# Ativar/desativar os documentos a gerar:
RENDER_INFORMACAO1 <- TRUE
RENDER_METODOLOGIA <- TRUE
RENDER_OFICIO1     <- TRUE
RENDER_OFICIO2     <- TRUE
RENDER_DOCX        <- TRUE    # TRUE gera também versões Word (.docx) nativas via Quarto
```

### 5. Atualizar os parâmetros de emissão em `code/doc_params.R`

Todos os parâmetros de emissão estão centralizados num único ficheiro — editar apenas [`code/doc_params.R`](code/doc_params.R):

```r
# Datas de receção dos dados de bilhética:
data_dados_dits <- "XX de setembro de 2026"
data_dados_its  <- "XX de setembro de 2026"

# Financiamento do Fundo Ambiental (Incentiva +TP):
# TRUE  = verba ainda NÃO transferida → faturação parcelar
# FALSE = verba já disponível → faturação imediata total
incentiva_tp_pendente <- TRUE

# Números de referência:
numero_informacao <- "TML-XXXX-XXXX-INF-XXXX-DEP"
numero_oficio     <- "TML-XXXX-XXXX-OF-XXXX-DEP"
numero_oficio2    <- "TML-YYYY-YYYY-OF-YYYY-DEP"
```

> A `load_version` é lida automaticamente de [`lists/load_versions.csv`](lists/load_versions.csv) (ver passo 3). Os campos de autoria (`de_pessoa1_nome`, etc.) raramente mudam — só atualizar se houver alteração de intervenientes.

### 6. Verificar pré-requisitos e restaurar ambiente R (`renv`)

- **R** ≥ 4.3 instalado.
- **Quarto CLI** ([quarto.org](https://quarto.org)) instalado e acessível em linha de comandos (`quarto --version`).
- **Restaurar ambiente de pacotes R com `renv`**:
  O projecto utiliza `renv` para garantir que as versões exatas de todos os pacotes são replicáveis:
  ```r
  # No terminal ou na consola R:
  renv::restore()
  ```

  *(Em alternativa, `Rscript code/00_setup.R` também pode ser usado para verificar ou carregar os pacotes base).*

---

## 🚀 Como Executar

Depois de concluídos todos os passos de preparação acima, corre o pipeline completo a partir da raiz do projecto:

```bash
Rscript code/99_run_all.R
```

O pipeline executa os cálculos (passos 01 a 08) em ~3 segundos e compila os documentos ativos (passo 10) em ~10 segundos.

Para correr para um mês diferente sem editar `config.R`, podes passar variáveis de ambiente:

```powershell
$env:MES=8; $env:ANO=2026; Rscript code/99_run_all.R
```

---

## 📄 Como Gerar os Documentos (Informações e Ofícios)

Os relatórios técnicos usam **Quarto** com o backend **Typst** e o pacote **`tinytable`**, produzindo PDFs de elevada qualidade gráfica com paginação profissional.

### Opção A: No Pipeline Geral (Recomendado)

Ao executar `Rscript code/99_run_all.R`, o script mestre executa automaticamente `code/10_documentos.R` para todos os documentos com flag `TRUE` em `config.R`.

### Opção B: Renderização Isolada (Rápida)

Se os cálculos já foram executados e queres apenas recompilar documentos (ex.: após rever texto ou números de referência):

```bash
# Todos os documentos ativos em config.R (PDF e DOCX nativo):
Rscript code/10_documentos.R
```

Para renderizar um único documento individual diretamente para Word (DOCX):

```powershell
quarto render code/informacao1.qmd --to docx
quarto render code/oficio1.qmd --to docx
quarto render code/oficio2.qmd --to docx
```

> **Nota:** Se alterares configurações de estilos, fontes ou margens de tabela em `code/templates/build_reference_doc.R`, é necessário regerar o modelo antes de renderizar:
>
> ```powershell
> Rscript code/templates/build_reference_doc.R
> quarto render code/informacao1.qmd --to docx
> ```
>
> *(Lembra-te de fechar o Word antes de correr o script para não bloquear o ficheiro de template).*

Os documentos são gravados em `data/{MES}_{mes_abrev}_{ANO}/output/docs/`:


| Documento                | Ficheiro                         |
| -------------------------- | ---------------------------------- |
| Informação 1 (PDF)     | `Informacao_{SUFIXO}.pdf`        |
| Informação 1 (Word)    | `Informacao_{SUFIXO}.docx`       |
| Anexo Metodologia (PDF)  | `Anexo_Metodologia_{SUFIXO}.pdf` |
| Ofício 1 (PDF)          | `Oficio1_{SUFIXO}.pdf`           |
| Ofício 1 variante (PDF) | `Oficio1_alt_{SUFIXO}.pdf`       |
| Ofício 2 (PDF)          | `Oficio2_{SUFIXO}.pdf`           |
| Cálculos Excel (XLSX)   | `Anexo_Calculos_{SUFIXO}.xlsx`   |

---

## 📊 Ficheiros de Saída (Output)

Os resultados são gerados na pasta `data/{MES}_{mes_abrev}_{ANO}/output/` com o sufixo do mês (ex: `ago26`):


| Ficheiro                                    | Descrição                                                                                                                                                                  |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **`docs/Informacao_{SUFIXO}.pdf`**          | **Informação 1 (PDF)**: Nota interna de apresentação dos resultados mensais, com narrativa formal, fórmulas e Tabelas 1 a 8 formatadas.                                 |
| **`docs/Informacao_{SUFIXO}.docx`**         | Versão Word da Informação 1 (gerada quando`RENDER_DOCX = TRUE`).                                                                                                          |
| **`docs/Anexo_Metodologia_{SUFIXO}.pdf`**   | **Anexo Metodologia (PDF com papel timbrado externo)**: Documento formal com fórmulas regulamentares detalhadas.                                                            |
| **`docs/Oficio1_{SUFIXO}.pdf`**             | **Ofício 1**: Comunicação formal de pagamentos imediatos a cada operador (receitas partilhadas Canal K).                                                                  |
| **`docs/Oficio1_alt_{SUFIXO}.pdf`**         | **Ofício 1 (variante)**: Idem, mas com tabelas no fim dos itens numerados.                                                                                                  |
| **`docs/Oficio2_{SUFIXO}.pdf`**             | **Ofício 2**: Comunicação formal relativa às verbas do Incentiva +TP.                                                                                                    |
| **`docs/Anexo_Calculos_{SUFIXO}.xlsx`**     | **Workbook Excel consolidado**: 6 folhas (0 - Global, 1 - Quotas, 2 - Vendas AK, 4 - Receita B e CongNav B, 5 - Pag Conta COSP D, 6 - Transferencias F).                     |
| **`6_transferencias_{SUFIXO}.csv`**         | **Tabela final de compensações (CSV)**: colunas `receita_A`, `receita_B`, `saldo_C`, `cosp_D`, `SG`, `F_transferencia`, `congelamento_B`, total a transferir por operador. |
| `1a_PT_{SUFIXO}.csv`                        | Passageiros transportados (validações) por título e operador.                                                                                                             |
| `1b_PT_CM_{SUFIXO}.csv`                     | Agregação A1+A2+A3+A4 + fiscais móveis da Carris Metropolitana.                                                                                                           |
| `1c_receitas_titulo_{SUFIXO}.csv`           | Quantidade e receita de vendas de títulos por operador (Recibos B).                                                                                                         |
| `1d_validacoes_{SUFIXO}.csv`                | Quantidades de títulos gratuitos sem carregamento prévio (VaT).                                                                                                            |
| `1e_distancias_{SUFIXO}.csv`                | Distâncias médias (km) por operador e título.                                                                                                                             |
| `1_quotas_{SUFIXO}.csv`                     | PKM e quotas de repartição regulamentares (0 a 1).                                                                                                                         |
| `2_vendas_A_{SUFIXO}.csv`                   | Receita e quantidades na posse de cada operador (Canais A — bilheteiras próprias).                                                                                         |
| `2_vendas_K_{SUFIXO}.csv`                   | Vendas e receitas dos canais partilhados TML (Portal VIVA e Multibanco/SIBS).                                                                                                |
| `4a_receita_titulo_distribuir_{SUFIXO}.csv` | Receita global do sistema a distribuir por título ($A + K$).                                                                                                                |
| `4b_reparticao_B_{SUFIXO}.csv`              | Detalhe da receita devida ($B$) e congelamento TAT por título e operador.                                                                                                   |
| `4_receitaB_congelamento_{SUFIXO}.csv`      | Resumo por operador:`receita_B` e `congelamento_B`.                                                                                                                          |
| `5a_cosp_{SUFIXO}.csv`                      | COSP tarifária ($D$) detalhada por título e operador.                                                                                                                      |
| `5_cosp_operador_{SUFIXO}.csv`              | COSP total devida por operador (`cosp_D`).                                                                                                                                   |

---

## 🏷️ Fecho do Mês e Criação de Tag Git (Congelamento de Versão)

Após executar o pipeline com sucesso, validar as tabelas de compensação e emitir os documentos finais do mês (PDFs/DOCX e Excel), deve-se **congelar o estado exato do código e das dependências** através de um commit de fecho e uma **tag Git**.

Isto permite que, no futuro (para auditorias, conferência ou recálculos), seja possível voltar a este instante com a certeza matemática de obter exatamente os mesmos resultados.

### 1. Registar o estado dos ficheiros e pacotes

Se tiveres instalado ou atualizado algum pacote durante o mês, atualiza o snapshot do `renv`:

```r
renv::snapshot()
```

Faz o commit das alterações de configuração, parâmetros do mês e lockfile:

```bash
git add code/config.R code/doc_params.R lists/load_versions.csv renv.lock
git commit -m "feat(fecho): fecho de contas e documentos de Agosto 2026"
```

### 2. Criar a Tag Git correspondente ao mês

Cria uma tag anotada com o identificador do mês:

```bash
# Formato padrão: run-AAAA-MM-<mes>
git tag -a run-2026-08-ago -m "Estimativa final de contas de Agosto 2026"
```

Enviar as alterações e a tag para o repositório remoto:

```bash
git push origin main --tags
```

### 3. Como reproduzir um mês anterior no futuro

Se for necessário auditar ou recalcular um mês antigo (ex: Maio de 2026):

```bash
# 1. Mudar para a tag desse mês
git checkout run-2026-05-mai

# 2. Restaurar o ambiente exato de pacotes R da altura
Rscript -e "renv::restore()"

# 3. Executar os cálculos
Rscript code/99_run_all.R
```

Para regressar ao ramo principal de trabalho:

```bash
git checkout main
Rscript -e "renv::restore()"
```

---

## 📁 Estrutura do Repositório

```
Compensacoes/
├── renv.lock                     # Snapshot de versões exatas de todos os pacotes R (reprodutibilidade)
├── renv/                         # Definições e script de ativação do renv
├── data/                         # Dados mensais (gitignored): data/MM_mes_AAAA/{input,output}/
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
│   ├── doc_params.R              # ← Parâmetros de emissão mensais (datas, refs, autores)
│   ├── utils_tables.R            # Funções de formatação de tabelas (tinytable / Typst)
│   ├── utils_extenso.R           # Funções auxiliares para montantes por extenso em euros
│   ├── sql/                      # Consultas Oracle SQL
│   │   ├── query_CM_fiscaismoveis.sql # Query Oracle para validações fiscais CM (Query 2c)
│   │   └── query_distancias_medias.sql # Query Oracle de apoio a distâncias médias
│   ├── code-old/                 # Scripts e queries legados / descontinuados
│   │   └── query_SL_TT.sql       # Query Oracle histórica para separação TT/SL (Query 2b)
│   └── templates/                # Modelos, filtros e recursos visuais institucionais
│       ├── custom_styles.typ     # Estilos Typst: cabeçalhos, fundos e papel timbrado
│       ├── linebreaks.lua        # Filtro Pandoc (quebras de linha e deteção de doc-tipo externo)
│       ├── docx_styles.lua       # Filtro Pandoc: formatação de tabelas e estilos Word (DOCX)
│       ├── build_reference_doc.R # Constrói o reference-doc com estilos XML para Word
│       ├── postprocess_docx.ps1  # Script PowerShell de pós-processamento de tabelas DOCX
│       ├── TML_template.docx     # Modelo base Word
│       ├── TML_Informacao_pandoc.docx # Modelo compilado de referência para o Pandoc
│       ├── folha_1.pdf           # Papel timbrado oficial TML (1.ª página, vetorial)
│       ├── folha_restantes.pdf   # Papel timbrado oficial TML (páginas seguintes, vetorial)
│       └── logo_tml.svg          # Logótipo vetorial institucional TML
├── lists/                        # Tabelas estáticas e regulamentares de referência
│   ├── operadores.csv            # Mapeamento de códigos e nomes de operadores
│   ├── pesos_pkm.csv             # Pesos operacionais para cálculo de quotas PKM
│   ├── load_versions.csv         # Versão de processamento de distâncias CM por mês (load_version)
│   ├── distanciasref_out21_incompleto.csv # Distâncias estáticas (meses de inverno/restantes)
│   ├── distanciasref_ago21_incompleto.csv # Distâncias estáticas (meses de verão: jun, jul, ago)
│   ├── tat.csv                   # Taxa de Atualização Tarifária anual (TAT)
│   ├── sazonalidade_cosp.csv     # Coeficientes mensais de sazonalidade COSP
│   └── receitas_anteriores.csv   # Receitas históricas por operador (gitignored — não versionado)
└── README.md
```

---

## 📖 Documentação Metodológica

Para conhecer todas as fórmulas regulamentares, regras de cálculo, filtros e especificidades da reconciliação, consulta o documento:
👉 **[`code/procedure.md`](code/procedure.md)**
