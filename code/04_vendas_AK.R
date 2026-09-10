# =============================================================================
# 04_vendas_AK.R — Agrega receitas de venda A (operadores) e K (PV/ATM)
# Distribuição de Receitas Navegante — TML
#
# - A: receita de venda dos operadores (já em receitas_titulo_mesano.csv)
# - K: receita de canais genéricos TML (Portal VIVA e ATM/SIBS)
#   Ficheiro: [DATA_DIR]/Recibos B/ReciboB_[MES][ANO]_Separação_PV_ATM.xlsx
#
# Calcula:
#   receita_titulo_distribuir(i) = sum_j[receita_A(i,j)] + receita_K(i)
#   receita_posse_operador(j)    = sum_i[receita_A(i,j)]
#
# Inputs:
#   OUT_DIR/receitas_titulo_mesano.csv
#   [DATA_DIR]/Recibos B/ReciboB_*_Separação_PV_ATM.xlsx
#   lists/titulos.csv
#
# Outputs:
#   OUT_DIR/vendas_AK_mesano.csv             (receita A e K por operador)
#   OUT_DIR/receita_titulo_distribuir_mesano.csv  (total a distribuir por título)
# =============================================================================

source(here::here("code", "config.R"))

receitas <- read.csv2(F_RECEITAS,
                      stringsAsFactors = FALSE)
titulos  <- read.csv2(file.path(LISTS_DIR, "titulos.csv"),
                      stringsAsFactors = FALSE, dec = ".")

# ---- Receita A (operadores) --------------------------------------------------
# Receita total por título (soma sobre todos os operadores)
receita_A_por_titulo <- receitas |>
  dplyr::group_by(ticket_code) |>
  dplyr::summarise(
    receita_A_total = sum(receita_operador, na.rm = TRUE),
    qty_A_total     = sum(qty_operador,     na.rm = TRUE),
    .groups = "drop"
  )

# Receita na posse do operador (A): soma por operador de todos os títulos
receita_posse_operador <- receitas |>
  dplyr::group_by(operador) |>
  dplyr::summarise(
    receita_A = sum(receita_operador, na.rm = TRUE),
    qty_A     = sum(qty_operador,     na.rm = TRUE),
    .groups = "drop"
  )

cat("\n--- Receita A por operador (€) ---\n")
receita_posse_operador |>
  dplyr::arrange(desc(receita_A)) |>
  dplyr::mutate(receita_A = scales::number(receita_A, big.mark = ".", decimal.mark = ",")) |>
  print()

# ---- Receita K (canais PV e ATM) --------------------------------------------
# Ficheiro com separação PV/ATM enviado pelo Dept ITS
pvatm_files <- list.files(
  file.path(DATA_DIR, "Recibos B"),
  pattern = "ReciboB_.*Separa.*PV.*ATM.*\\.(xlsx|xls)$",
  full.names = TRUE,
  ignore.case = TRUE
)

if (length(pvatm_files) == 0) {
  warning("Ficheiro PV/ATM não encontrado. Receita K assumida = 0.")
  receita_K <- tibble::tibble(ticket_code = integer(), receita_K = numeric(),
                              qty_K = integer())
} else {
  pvatm_file <- pvatm_files[1]
  message("Ficheiro PV/ATM: ", basename(pvatm_file))

  # Estrutura do ficheiro (verificada em maio 2026):
  # Row 1: "Proveniente de PV" / "Proveniente de ATM"  (header de grupo)
  # Row 2: ENTITY_ID | TICKET_OPERATOR_CODE | TICKET_CODE | TICKET_NAME | SUM(QTY) | ...
  # Colunas 1-5: PV (ENTITY_ID=23, Portal VIVA)
  # Colunas 7-11: ATM/SIBS (ENTITY_ID=30, SIBS)

  pvatm_raw <- readxl::read_excel(pvatm_file, sheet = 1, skip = 1,
                                  col_names = FALSE)

  # Extrair colunas PV (cols 1-5) e ATM (cols 7-11)
  pv_df <- pvatm_raw |>
    dplyr::select(
      entity_id  = 1,
      tok_op_code = 2,
      ticket_code = 3,
      ticket_name = 4,
      qty_K_pv   = 5
    ) |>
    dplyr::filter(!is.na(ticket_code) & !is.na(entity_id)) |>
    dplyr::mutate(
      ticket_code = as.integer(ticket_code),
      qty_K_pv    = as.numeric(qty_K_pv)
    )

  atm_df <- pvatm_raw |>
    dplyr::select(
      entity_id    = 7,
      tok_op_code  = 8,
      ticket_code  = 9,
      ticket_name  = 10,
      qty_K_atm    = 11
    ) |>
    dplyr::filter(!is.na(ticket_code) & !is.na(entity_id)) |>
    dplyr::mutate(
      ticket_code = as.integer(ticket_code),
      qty_K_atm   = as.numeric(qty_K_atm)
    )

  # Juntar PV + ATM por ticket_code
  receita_K_qty <- pv_df |>
    dplyr::full_join(atm_df |> dplyr::select(ticket_code, qty_K_atm),
                     by = "ticket_code") |>
    dplyr::mutate(
      qty_K_pv  = tidyr::replace_na(qty_K_pv, 0),
      qty_K_atm = tidyr::replace_na(qty_K_atm, 0),
      qty_K     = qty_K_pv + qty_K_atm
    )

  # Calcular receita K = qty_K × pvp do título
  receita_K <- receita_K_qty |>
    dplyr::left_join(titulos |> dplyr::select(ticket_code, pvp),
                     by = "ticket_code") |>
    dplyr::mutate(
      pvp       = as.numeric(pvp),
      receita_K = qty_K * pvp
    ) |>
    dplyr::select(ticket_code, qty_K, qty_K_pv, qty_K_atm, receita_K)

  message(sprintf("Receita K: %d títulos, total = %.2f €",
                  nrow(receita_K), sum(receita_K$receita_K, na.rm = TRUE)))
}

# ---- Receita total a distribuir por título -----------------------------------
receita_titulo_distribuir <- receita_A_por_titulo |>
  dplyr::left_join(receita_K |> dplyr::select(ticket_code, qty_K, receita_K),
                   by = "ticket_code") |>
  dplyr::mutate(
    receita_K          = tidyr::replace_na(receita_K, 0),
    qty_K              = tidyr::replace_na(qty_K, 0),
    receita_distribuir = receita_A_total + receita_K
  ) |>
  dplyr::left_join(titulos |> dplyr::select(ticket_code, titulo_nome, pvp),
                   by = "ticket_code") |>
  dplyr::arrange(ticket_code)

# ---- Verificação: total A = total K + A?
total_A <- sum(receita_posse_operador$receita_A, na.rm = TRUE)
total_K <- sum(receita_K$receita_K, na.rm = TRUE)
total_distribuir <- sum(receita_titulo_distribuir$receita_distribuir, na.rm = TRUE)

cat(sprintf("\n--- Totais de receita ---\n"))
cat(sprintf("  Receita A (operadores):  %12.2f €\n", total_A))
cat(sprintf("  Receita K (PV + ATM):    %12.2f €\n", total_K))
cat(sprintf("  Total a distribuir:      %12.2f €\n", total_distribuir))
cat(sprintf("  Verificação A+K:         %12.2f €\n", total_A + total_K))

if (abs(total_distribuir - (total_A + total_K)) > 0.01)
  warning("DISCREPÂNCIA: total_distribuir ≠ A + K!")

# ---- Guardar outputs ---------------------------------------------------------
# Vendas A (por operador)
vendas_AK <- receita_posse_operador |>
  dplyr::left_join(
    receita_K |>
      dplyr::summarise(receita_K_total = sum(receita_K, na.rm = TRUE),
                       qty_K_total = sum(qty_K, na.rm = TRUE)) |>
      dplyr::mutate(operador = "K_PV_ATM"),
    by = "operador"
  )
# (receita K fica associada ao "operador" K_PV_ATM para referência;
#  a distribuição real é feita por título em receita_titulo_distribuir)

ak_out   <- F_VENDAS_AK
rtd_out  <- F_RTD

write.csv2(receita_posse_operador,    ak_out,  row.names = FALSE)
write.csv2(receita_titulo_distribuir, rtd_out, row.names = FALSE)

message("Outputs gravados:")
message("  ", ak_out)
message("  ", rtd_out)
