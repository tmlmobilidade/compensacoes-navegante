# =============================================================================
# 01_recibos_b.R — Agrega os Recibos B de todos os operadores
# Distribuição de Receitas Navegante — TML
#
# Inputs:
#   [DATA_DIR]/Recibos B/reg_[OP]_reciboB_[ANO][MES]_*/
#     - *_PTconsideredByProduct_*.csv  → passageiros transportados
#     - *_transactionsOperatorSystem_*.csv → vendas/receitas
#
# Outputs (em OUT_DIR):
#   PT_mesano.csv               — passageiros transportados por título e operador
#   receitas_titulo_mesano.csv  — receitas de venda por título e operador
# =============================================================================

source(here::here("code", "config.R"))

recibos_dir <- file.path(DATA_DIR, "Recibos B")

# ---- Funções auxiliares ------------------------------------------------------

#' Lê um CSV de Recibo B com separador ";"
#' Lê todas as colunas como character para evitar conflitos de tipo entre operadores
read_recibo_csv <- function(path) {
  read.csv(path, sep = ";", header = TRUE, stringsAsFactors = FALSE,
           fileEncoding = "UTF-8-BOM", check.names = FALSE,
           colClasses = "character")
}

#' Extrai o código do operador (ex: "A1", "CP") do caminho da pasta
extract_op_from_dir <- function(dirpath) {
  # Formato: reg_[OP]_reciboB_[ANOMES]_[DATA]
  basename(dirpath) |> strsplit("_") |> sapply(`[`, 2)
}

# ---- Descobrir todas as pastas de operadores ---------------------------------
op_dirs <- list.dirs(recibos_dir, full.names = TRUE, recursive = FALSE)
op_dirs <- op_dirs[grepl("reg_.*_reciboB_", basename(op_dirs))]

if (length(op_dirs) == 0)
  stop("Nenhuma pasta de operador encontrada em: ", recibos_dir)

message(sprintf("Encontradas %d pastas de operadores.", length(op_dirs)))

# ---- 1. Passageiros Transportados (PT) ---------------------------------------

ler_pt <- function(dir_path, op_code) {
  f <- list.files(dir_path, pattern = "_PTconsideredByProduct_.*\\.csv$",
                  full.names = TRUE)
  if (length(f) == 0) {
    warning("Nenhum ficheiro PT encontrado para operador: ", op_code)
    return(NULL)
  }
  df <- read_recibo_csv(f[1])
  df$OPERADOR <- op_code
  df
}

pt_list <- Map(ler_pt,
               op_dirs,
               sapply(op_dirs, extract_op_from_dir))

PT_raw <- bind_rows(pt_list)

# Normalizar nomes de colunas
PT_raw <- PT_raw |> clean_names()
# Esperado: distribution_year, distribution_month, ticket_operator_code,
#           ticket_code, sistema_total, operador_total, operador

# Converter colunas numéricas (lidas como character para evitar conflito de tipo)
PT_raw <- PT_raw |>
  dplyr::mutate(
    distribution_year  = as.integer(distribution_year),
    distribution_month = as.integer(distribution_month),
    ticket_operator_code = as.integer(ticket_operator_code),
    ticket_code        = as.integer(ticket_code),
    sistema_total      = as.numeric(sistema_total),
    operador_total     = as.numeric(operador_total)
  )

# Verificar colunas essenciais
stopifnot(all(c("ticket_code", "operador_total", "operador") %in% names(PT_raw)))

# ---- Tratar CM = A1 + A2 + A3 + A4 -----------------------------------------
# Os sub-operadores A1-A4 são enviados em ficheiros separados e representam
# as áreas operacionais da Carris Metropolitana.
# Guardar um ficheiro CM intermediário com a soma dos 4, sem as colunas SISTEMA
# (que são constantes, iguais em todos os operadores).

cm_subops_raw <- PT_raw |>
  dplyr::filter(operador %in% CM_SUBOPS)

if (nrow(cm_subops_raw) > 0) {
  cm_agregado <- cm_subops_raw |>
    dplyr::group_by(
      distribution_year, distribution_month,
      ticket_operator_code, ticket_code
    ) |>
    dplyr::summarise(
      pt_operador  = sum(operador_total, na.rm = TRUE),
      # sistema_total é constante entre sub-ops — guardar o max por consistência
      pt_sistema   = max(sistema_total, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(operador = "CM")

  cm_out <- F_PT_CM
  write.csv2(cm_agregado, cm_out, row.names = FALSE)
  message("CM agregado (A1+A2+A3+A4) gravado em: ", cm_out)
} else {
  message("AVISO: nenhum sub-operador CM (A1-A4) encontrado nos Recibos B.")
}

PT_raw <- PT_raw |>
  dplyr::mutate(operador_final = dplyr::if_else(operador %in% CM_SUBOPS, "CM", operador))

# Agregar PT por ticket_code e operador_final
# (soma operador_total; sistema_total é o mesmo para todos — manter o max)
PT_mesano <- PT_raw |>
  group_by(
    distribution_year, distribution_month,
    ticket_operator_code, ticket_code,
    operador = operador_final
  ) |>
  summarise(
    pt_operador = sum(operador_total, na.rm = TRUE),
    pt_sistema  = max(sistema_total, na.rm = TRUE),
    .groups = "drop"
  ) |>
  # Excluir operadores a ignorar:
  # - Scotturb (SC): excluído por regulamento
  # - PV (Portal VIVA, entity 23): validadores móveis de fiscais — não têm pasta própria
  #   mas podem aparecer no interior de outros ficheiros
  dplyr::filter(!operador %in% c("SC"))   # Scotturb

# Manter apenas linhas com ticket_operator_code == 31 (Navegante)
# e excluir ticket_code == -1 (linha de totais/inválidos)
PT_mesano <- PT_mesano |>
  filter(ticket_operator_code == 31, ticket_code > 0)

message(sprintf("PT agregado: %d linhas, %d operadores, %d títulos únicos.",
                nrow(PT_mesano),
                n_distinct(PT_mesano$operador),
                n_distinct(PT_mesano$ticket_code)))

# ---- 2. Receitas de Venda (Transações) ---------------------------------------

ler_transacoes <- function(dir_path, op_code) {
  f <- list.files(dir_path, pattern = "_transactionsOperatorSystem_.*\\.csv$",
                  full.names = TRUE)
  if (length(f) == 0) {
    warning("Nenhum ficheiro de transações encontrado para: ", op_code)
    return(NULL)
  }
  df <- read_recibo_csv(f[1])
  df$OPERADOR <- op_code
  df
}

tx_list <- Map(ler_transacoes,
               op_dirs,
               sapply(op_dirs, extract_op_from_dir))

TX_raw <- bind_rows(tx_list)
TX_raw <- TX_raw |> clean_names()
# Esperado: source, period, ticket_operator_code, ticket_code,
#           sistema_quantity, sistema_total_price,
#           operador_quantity, operador_price, siit_qty, siit_price, operador

# Converter colunas numéricas
TX_raw <- TX_raw |>
  dplyr::mutate(
    ticket_operator_code = as.integer(ticket_operator_code),
    ticket_code          = as.integer(ticket_code),
    sistema_quantity     = as.numeric(sistema_quantity),
    sistema_total_price  = as.numeric(sistema_total_price),
    operador_quantity    = as.numeric(operador_quantity),
    operador_price       = as.numeric(operador_price),
    siit_qty             = as.numeric(siit_qty),
    siit_price           = as.numeric(siit_price)
  )

stopifnot(all(c("source", "ticket_code", "operador_quantity",
                "operador_price", "siit_qty", "siit_price") %in% names(TX_raw)))

# Excluir "Validations as Transactions" — são títulos sem carregamento
# (contados só quando há pelo menos 1 validação; tratados separadamente na quota)
TX_transacoes <- TX_raw |>
  filter(source == "Transaction")

TX_transacoes <- TX_transacoes |>
  dplyr::mutate(operador_final = dplyr::if_else(operador %in% CM_SUBOPS, "CM", operador)) |>
  dplyr::filter(!operador %in% c("SC"))  # Excluir Scotturb (se presente)

# Calcular quantidade e receita líquidas (incluindo SIIT = devoluções/erros)
TX_transacoes <- TX_transacoes |>
  mutate(
    qty_operador     = operador_quantity + siit_qty,
    receita_operador = operador_price    + siit_price
  )

# Filtrar Navegante (ticket_operator_code == 31) e tickets válidos
TX_transacoes <- TX_transacoes |>
  filter(ticket_operator_code == 31, ticket_code > 0)

# Agregar CM = A1+A2+A3+A4
receitas_titulo_mesano <- TX_transacoes |>
  group_by(
    ticket_operator_code, ticket_code,
    operador = operador_final
  ) |>
  summarise(
    qty_operador     = sum(qty_operador,     na.rm = TRUE),
    receita_operador = sum(receita_operador, na.rm = TRUE),
    sistema_quantity = max(sistema_quantity, na.rm = TRUE),  # total sistema
    .groups = "drop"
  )

message(sprintf("Receitas agregadas: %d linhas, %d operadores, %d títulos.",
                nrow(receitas_titulo_mesano),
                n_distinct(receitas_titulo_mesano$operador),
                n_distinct(receitas_titulo_mesano$ticket_code)))

# ---- Guardar outputs ---------------------------------------------------------
pt_out <- F_PT
rx_out <- F_RECEITAS

write.csv2(PT_mesano,             pt_out, row.names = FALSE)
write.csv2(receitas_titulo_mesano, rx_out, row.names = FALSE)

message("Output gravado:")
message("  ", pt_out)
message("  ", rx_out)

# ---- Verificações básicas ----------------------------------------------------
cat("\n--- Verificação: totais PT por operador ---\n")
PT_mesano |>
  group_by(operador) |>
  summarise(total_pt = sum(pt_operador)) |>
  arrange(desc(total_pt)) |>
  print()

cat("\n--- Verificação: receita total por operador (€) ---\n")
receitas_titulo_mesano |>
  group_by(operador) |>
  summarise(receita_total = sum(receita_operador)) |>
  arrange(desc(receita_total)) |>
  print()
