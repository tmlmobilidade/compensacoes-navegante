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

# Usar ponto como separador decimal nos prints de verificação (os CSVs já usam vírgula via write.csv2)
options(OutDec = ".")

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

# ---- Recodificar linha ticket_code = -1 como ticket 1020 ----------------------
# Alguns Recibos B (CA, TB) têm uma linha especial com ticket_operator_code=-1 e
# ticket_code=-1 que representa passageiros de títulos gratuitos (VaT, ticket 1020
# = Navegante 12 Criança, pvp=0) que o sistema não conseguiu associar a um ticket
# específico. A colega inclui estes passageiros atribuindo-os ao ticket 1020.
# Apenas CA e TB têm operador_total > 0 nesta linha; todos os outros têm 0.
PT_raw <- PT_raw |>
  dplyr::mutate(
    ticket_operator_code = dplyr::if_else(
      ticket_operator_code == -1L & ticket_code == -1L, 31L, ticket_operator_code
    ),
    ticket_code = dplyr::if_else(
      ticket_operator_code == 31L & ticket_code == -1L, 1020L, ticket_code
    )
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

# ---- Excluir Recibo B do SL do cálculo de PT ----------------------------------
# O Recibo B entregue pelo operador TT contém na coluna OPERADOR_TOTAL os
# passageiros CONJUNTOS de TT + SL (os dois operadores partilham o mesmo Recibo B
# no sistema). O Recibo B separado do SL tem valores diferentes e duplicaria os
# passageiros do SL se somado ao do TT.
# Verificação: TT_Recibo_B_total = TT_Excel + SL_Excel (exacto ticket a ticket).
# Para o PT, usa-se APENAS o Recibo B do TT (que já inclui o SL).
# O Recibo B do SL é mantido para o cálculo de RECEITAS (transações), onde
# os dois operadores têm contratos de receita independentes.
PT_raw_pt <- PT_raw |>
  dplyr::filter(operador != "SL")

# Agregar PT por ticket_code e operador_final
# (soma operador_total; sistema_total é o mesmo para todos — manter o max)
PT_mesano <- PT_raw_pt |>
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
# ticket_code=-1 já foi recodificado como 1020 acima, por isso o filtro > 0 é seguro
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
cat("(Nota: TT inclui TT+SL — Recibo B de TT agrega ambos os operadores)\n")
PT_mesano |>
  group_by(operador) |>
  summarise(total_pt = sum(pt_operador)) |>
  dplyr::mutate(total_pt_fmt = scales::number(total_pt, big.mark = ".", decimal.mark = ",", accuracy = 1)) |>
  arrange(desc(total_pt)) |>
  dplyr::select(operador, total_pt, total_pt_fmt) |>
  print()

cat("\n--- Verificação: receita total por operador (€) ---\n")
receitas_titulo_mesano |>
  group_by(operador) |>
  summarise(receita_total = sum(receita_operador)) |>
  dplyr::mutate(receita_fmt = scales::number(receita_total, big.mark = ".", decimal.mark = ",", accuracy = 0.01)) |>
  arrange(desc(receita_total)) |>
  dplyr::select(operador, receita_total, receita_fmt) |>
  print()
