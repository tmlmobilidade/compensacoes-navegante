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
    distribution_year    = as.integer(distribution_year),
    distribution_month   = as.integer(distribution_month),
    ticket_operator_code = as.integer(ticket_operator_code),
    ticket_code          = as.integer(ticket_code),
    sistema_total        = as.numeric(gsub(",", ".", as.character(sistema_total))),
    operador_total       = as.numeric(gsub(",", ".", as.character(operador_total)))
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

# ---- Validações de fiscais móveis da CM (Portal VIVA - entity 23) ----------
# A colega distribui pelas 4 áreas operacionais com base no RUN_CODE / AREA_CM:
#   1xxx / 41 -> A1, 2xxx / 42 -> A2, 3xxx / 43 -> A3, 4xxx / 44 -> A4
# Apenas títulos presentes no Recibo B da CM são considerados.
usar_cm_viva <- !is.null(F_CM_VIVA_VALIDACOES) && file.exists(F_CM_VIVA_VALIDACOES)

if (usar_cm_viva) {
  message("CM: a usar ficheiro Portal VIVA (entity 23) → ", basename(F_CM_VIVA_VALIDACOES))
  cm_viva_raw <- read.csv(F_CM_VIVA_VALIDACOES,
                          sep = ";", header = TRUE,
                          stringsAsFactors = FALSE,
                          fileEncoding = "UTF-8-BOM",
                          check.names = FALSE)
  if (ncol(cm_viva_raw) <= 1) {
    cm_viva_raw <- read.csv(F_CM_VIVA_VALIDACOES,
                            sep = ",", header = TRUE,
                            stringsAsFactors = FALSE,
                            fileEncoding = "UTF-8-BOM",
                            check.names = FALSE)
  }
  cm_viva_raw <- cm_viva_raw |> janitor::clean_names()

  if ("sum_qnt_validation" %in% names(cm_viva_raw) && !"pt_validacoes" %in% names(cm_viva_raw)) {
    cm_viva_raw <- cm_viva_raw |> dplyr::rename(pt_validacoes = sum_qnt_validation)
  }

  cm_viva_filtered <- cm_viva_raw |>
    dplyr::filter(
      as.integer(distribution_year)    == ANO,
      as.integer(distribution_month)   == MES,
      as.integer(ticket_operator_code) == 31L,
      as.integer(ticket_code) > 0L
    )

  if ("valid_type_id" %in% names(cm_viva_filtered)) {
    cm_viva_filtered <- cm_viva_filtered |> dplyr::filter(as.integer(valid_type_id) == 0L)
  }
  if ("valbyprof" %in% names(cm_viva_filtered)) {
    cm_viva_filtered <- cm_viva_filtered |> dplyr::filter(as.integer(valbyprof) == 0L)
  }

  # Determinar área CM (A1 a A4): por area_cm ou por run_code
  if ("area_cm" %in% names(cm_viva_filtered)) {
    cm_viva_filtered <- cm_viva_filtered |>
      dplyr::mutate(operador = paste0("A", as.integer(area_cm) - 40L))
  } else if ("run_code" %in% names(cm_viva_filtered)) {
    cm_viva_filtered <- cm_viva_filtered |>
      dplyr::mutate(operador = paste0("A", floor(as.integer(run_code) / 1000L)))
  }

  cm_viva <- cm_viva_filtered |>
    dplyr::filter(operador %in% CM_SUBOPS) |>
    dplyr::mutate(
      operador_total = as.numeric(pt_validacoes),
      sistema_total  = 0
    ) |>
    dplyr::filter(ticket_code %in% unique(PT_raw$ticket_code[PT_raw$operador %in% CM_SUBOPS]))

  if (nrow(cm_viva) > 0) {
    PT_raw <- dplyr::bind_rows(PT_raw, cm_viva)
    message(sprintf("CM: %s validações do Portal VIVA (entity 23) adicionadas às áreas A1-A4.",
                    scales::number(sum(cm_viva$operador_total), big.mark = ".", decimal.mark = ",")))
  }
}

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

# ---- Excluir Recibo B do SL e separar TT/SL via Oracle (F_VALIDATIONS) --------
# O Recibo B de TT contém em OPERADOR_TOTAL os passageiros conjuntos de TT + SL.
# O Recibo B separado de SL tem valores diferentes → duplicaria o SL se somado.
#
# Quando disponível, o ficheiro F_TT_SL_VALIDACOES (query 2b de query_SL_TT.sql,
# exportado de PDBDWPROD) permite separar TT e SL correctamente com base nos
# registos de F_VALIDATIONS com ENTITY_ID IN (5=TT, 8=SL).
# Nesse caso, as linhas de TT e SL do PT_mesano são substituídas pelos valores Oracle.
# Caso contrário (fallback), usa-se o Recibo B de TT como TT+SL e exclui-se o SL.

usar_oracle_tt_sl <- !is.null(F_TT_SL_VALIDACOES) && file.exists(F_TT_SL_VALIDACOES)

if (usar_oracle_tt_sl) {
  message("TT/SL: a usar ficheiro Oracle F_VALIDATIONS → ", basename(F_TT_SL_VALIDACOES))
  oracle_raw <- read.csv(F_TT_SL_VALIDACOES,
                         sep = ";", header = TRUE,
                         stringsAsFactors = FALSE,
                         fileEncoding = "UTF-8-BOM",
                         check.names = FALSE)
  if (ncol(oracle_raw) <= 1) {
    oracle_raw <- read.csv(F_TT_SL_VALIDACOES,
                           sep = ",", header = TRUE,
                           stringsAsFactors = FALSE,
                           fileEncoding = "UTF-8-BOM",
                           check.names = FALSE)
  }
  oracle_raw <- oracle_raw |> janitor::clean_names()

  # Normalizar nome da coluna de contagem de validações se necessário (Query 2 vs 2b)
  if ("sum_qnt_validation" %in% names(oracle_raw) && !"pt_validacoes" %in% names(oracle_raw)) {
    oracle_raw <- oracle_raw |> dplyr::rename(pt_validacoes = sum_qnt_validation)
  }

  oracle_filtered <- oracle_raw |>
    dplyr::filter(
      as.integer(distribution_year)    == ANO,
      as.integer(distribution_month)   == MES,
      as.integer(ticket_operator_code) == 31L,
      as.integer(ticket_code) > 0L
    )

  if ("valid_type_id" %in% names(oracle_filtered)) {
    oracle_filtered <- oracle_filtered |> dplyr::filter(as.integer(valid_type_id) == 0L)
  }
  if ("valbyprof" %in% names(oracle_filtered)) {
    oracle_filtered <- oracle_filtered |> dplyr::filter(as.integer(valbyprof) == 0L)
  }

  # ---- Fonte de verdade: totais TT+SL por ticket_code do Recibo B de TT --------
  # O Recibo B de TT agrega TT+SL na coluna operador_total → é o PT oficial.
  # As validações Oracle são usadas APENAS para calcular o rácio TT vs. SL,
  # garantindo que TT + SL = total do Recibo B (sem inflar nem duplicar passageiros).
  tt_sl_recibob <- PT_raw |>
    dplyr::filter(
      operador == "TT",
      ticket_operator_code == 31L,
      ticket_code > 0L
    ) |>
    dplyr::group_by(ticket_operator_code, ticket_code) |>
    dplyr::summarise(pt_recibob = sum(operador_total, na.rm = TRUE), .groups = "drop")

  # ---- Rácios TT vs. SL a partir das validações Oracle -------------------------
  # Metodologia da colega (fórmula Excel na folha PT / aba TT_SL):
  #   =SOMA.SE.S(TT_SL!L:L; TT_SL!D:D; PT!$A3; TT_SL!K:K; 0; TT_SL!E:E; 0; TT_SL!C:C; 31) - F3
  # onde F3 (SL) filtra adicionalmente RUN_CODE == 7:
  #   RUN_CODE == SL_RUN_CODE (7) → SL (Soflusa / ferry Barreiro)
  #   outros RUN_CODEs (ou != 7)  → TT (Transtejo)
  tt_sl_filtered <- oracle_filtered |>
    dplyr::filter(as.integer(entity_id) %in% c(TT_ENTITY_ID, SL_ENTITY_ID))

  tt_sl_oracle_wide <- tt_sl_filtered |>
    dplyr::mutate(
      ticket_code          = as.integer(ticket_code),
      ticket_operator_code = as.integer(ticket_operator_code),
      pt_oracle            = as.numeric(pt_validacoes),
      operador             = if ("run_code" %in% names(tt_sl_filtered)) {
        dplyr::if_else(as.integer(run_code) == SL_RUN_CODE, "SL", "TT")
      } else {
        dplyr::if_else(as.integer(entity_id) == SL_ENTITY_ID, "SL", "TT")
      }
    ) |>
    # Agregar por ticket_code e operador (soma todos os RUN_CODEs de cada lado)
    dplyr::group_by(ticket_operator_code, ticket_code, operador) |>
    dplyr::summarise(pt_oracle = sum(pt_oracle, na.rm = TRUE), .groups = "drop") |>
    tidyr::pivot_wider(names_from = operador, values_from = pt_oracle,
                       values_fill = 0, names_prefix = "oracle_")

  if (!"oracle_TT" %in% names(tt_sl_oracle_wide)) tt_sl_oracle_wide$oracle_TT <- 0L
  if (!"oracle_SL" %in% names(tt_sl_oracle_wide)) tt_sl_oracle_wide$oracle_SL <- 0L

  tt_sl_oracle_wide <- tt_sl_oracle_wide |>
    dplyr::mutate(
      oracle_total = oracle_TT + oracle_SL,
      # Rácio TT; fallback 50/50 se não houver dados Oracle para o ticket
      ratio_TT = dplyr::if_else(oracle_total > 0, oracle_TT / oracle_total, 0.5)
    )

  # ---- Aplicar rácios ao total do Recibo B por ticket_code ---------------------
  tt_sl_pt <- tt_sl_recibob |>
    dplyr::left_join(
      tt_sl_oracle_wide |> dplyr::select(ticket_operator_code, ticket_code, ratio_TT),
      by = c("ticket_operator_code", "ticket_code")
    ) |>
    dplyr::mutate(
      # Se não há dados Oracle para este ticket_code, usar 50/50
      ratio_TT = dplyr::coalesce(ratio_TT, 0.5),
      pt_TT    = round(pt_recibob * ratio_TT),
      pt_SL    = pt_recibob - pt_TT   # garante TT + SL = total Recibo B exactamente
    ) |>
    tidyr::pivot_longer(cols = c(pt_TT, pt_SL),
                        names_to = "operador", values_to = "pt_operador") |>
    dplyr::mutate(
      operador             = dplyr::recode(operador, pt_TT = "TT", pt_SL = "SL"),
      distribution_year    = ANO,
      distribution_month   = MES,
      pt_sistema           = NA_real_
    ) |>
    dplyr::select(distribution_year, distribution_month,
                  ticket_operator_code, ticket_code,
                  operador, pt_operador, pt_sistema)

  total_oracle_TT <- sum(tt_sl_pt$pt_operador[tt_sl_pt$operador == "TT"])
  total_oracle_SL <- sum(tt_sl_pt$pt_operador[tt_sl_pt$operador == "SL"])
  total_recibob   <- sum(tt_sl_recibob$pt_recibob)
  message(sprintf(
    "TT/SL separados via rácios Oracle: TT=%s  SL=%s  Total=%s (Recibo B=%s).",
    scales::number(total_oracle_TT, big.mark = ".", decimal.mark = ",", accuracy = 1),
    scales::number(total_oracle_SL, big.mark = ".", decimal.mark = ",", accuracy = 1),
    scales::number(total_oracle_TT + total_oracle_SL, big.mark = ".", decimal.mark = ",", accuracy = 1),
    scales::number(total_recibob,   big.mark = ".", decimal.mark = ",", accuracy = 1)
  ))

  # Excluir TT e SL dos Recibos B (substituídos pelos valores acima)
  PT_raw_pt <- PT_raw |>
    dplyr::filter(!operador %in% c("TT", "SL"))

} else {
  # ---- FALLBACK: Recibo B de TT como proxy TT+SL (comportamento anterior) -----
  message("AVISO: ficheiro Oracle TT/SL não encontrado — a usar Recibo B de TT como TT+SL (SL excluído do PT).")
  message("  Para separar correctamente, exportar query 2b de query_SL_TT.sql para INPUT_DIR.")
  tt_sl_pt  <- NULL
  PT_raw_pt <- PT_raw |> dplyr::filter(operador != "SL")
}

# Agregar PT por ticket_code e operador_final
# — quando Oracle activo: PT_raw_pt já não tem TT/SL; tt_sl_pt tem os valores repartidos
# — quando fallback: PT_raw_pt tem TT (=TT+SL) sem SL
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
  dplyr::filter(!operador %in% c("SC"))   # Scotturb

# Juntar TT e SL separados (apenas quando ficheiro Oracle disponível)
if (usar_oracle_tt_sl && !is.null(tt_sl_pt)) {
  PT_mesano <- dplyr::bind_rows(PT_mesano, tt_sl_pt)
}


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

# Converter colunas numéricas (substituir vírgula por ponto para valores decimais)
parse_num_pt <- function(x) as.numeric(gsub(",", ".", as.character(x)))

TX_raw <- TX_raw |>
  dplyr::mutate(
    ticket_operator_code = as.integer(ticket_operator_code),
    ticket_code          = as.integer(ticket_code),
    sistema_quantity     = parse_num_pt(sistema_quantity),
    sistema_total_price  = parse_num_pt(sistema_total_price),
    operador_quantity    = parse_num_pt(operador_quantity),
    operador_price       = parse_num_pt(operador_price),
    siit_qty             = parse_num_pt(siit_qty),
    siit_price           = parse_num_pt(siit_price)
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

# ---- 3. Títulos sem carregamento (Validations as Transactions) ----------------
# Títulos gratuitos/sem carregamento mensal (ex: Sub18+TP, Sub23+TP, Navegante 12).
# Não geram receita de venda de operador (receita A = 0), mas a quantidade ativa
# no sistema (sistema_quantity) conta como passe vendido para a COSP.
vat_sistema <- TX_raw |>
  dplyr::filter(grepl("validation", source, ignore.case = TRUE),
                ticket_operator_code == 31,
                ticket_code > 0) |>
  dplyr::group_by(ticket_code) |>
  dplyr::summarise(
    qty_vat = max(sistema_quantity, na.rm = TRUE),
    .groups = "drop"
  )

message(sprintf("Títulos sem carregamento (VaT): %d títulos, total = %d passes.",
                nrow(vat_sistema), sum(vat_sistema$qty_vat, na.rm = TRUE)))

# ---- Guardar outputs ---------------------------------------------------------
pt_out  <- F_PT
rx_out  <- F_RECEITAS
vat_out <- F_VAT

write.csv2(PT_mesano,              pt_out,  row.names = FALSE)
write.csv2(receitas_titulo_mesano, rx_out,  row.names = FALSE)
write.csv2(vat_sistema,            vat_out, row.names = FALSE)

message("Output gravado:")
message("  ", pt_out)
message("  ", rx_out)
message("  ", vat_out)

# ---- Verificações básicas ----------------------------------------------------
cat("\n--- Verificação: totais PT por operador ---\n")
if (usar_oracle_tt_sl) {
  cat("(TT e SL separados via Oracle F_VALIDATIONS — query 2b)\n")
} else {
  cat("(AVISO: TT inclui TT+SL — Recibo B de TT agrega ambos; ficheiro Oracle não encontrado)\n")
}

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
