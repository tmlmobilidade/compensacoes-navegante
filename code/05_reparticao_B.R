# =============================================================================
# 05_reparticao_B.R — Repartição de receitas por operador (B) + Congelamento
# Distribuição de Receitas Navegante — TML
#
# Calcula:
#   dist_receita_operador_titulo(i,j) = Quota(i,j) × receita_distribuir(i)
#     (arredondado ao cêntimo)
#   B(j) = sum_i[ dist_receita_operador_titulo(i,j) ]   ← receita bilheteira devida
#
#   Fator TAT = (1+TAT_2024)(1+TAT_2025)(1+TAT_2026) - 1
#   receita_compensar(i,j) = dist_receita_operador_titulo(i,j) × fator_TAT
#   Congelamento(j) = sum_i[ receita_compensar(i,j) ]
#
# Inputs:
#   OUT_DIR/quotas_mesano.csv
#   OUT_DIR/receita_titulo_distribuir_mesano.csv
#   lists/tat.csv
#
# Outputs:
#   OUT_DIR/reparticao_B_mesano.csv    (distribuição por título e operador)
#   OUT_DIR/congelamento_mesano.csv    (congelamento por operador)
# =============================================================================

source(here::here("code", "config.R"))

quotas   <- read.csv2(F_QUOTAS,
                      stringsAsFactors = FALSE)
rtd      <- read.csv2(F_RTD,
                      stringsAsFactors = FALSE)

# ---- TAT — factor cumulativo -------------------------------------------------
tat_df <- read.csv2(TAT_FILE, stringsAsFactors = FALSE, dec = ".")
tat_df$tat <- as.numeric(tat_df$tat)

# Aplicar TAT cumulativo desde 2024 até ANO_CALCULO
tat_ate_ano <- tat_df[tat_df$ano <= ANO, ]
fator_tat   <- prod(1 + tat_ate_ano$tat) - 1

cat(sprintf("Factor TAT cumulativo (até %d): %.6f (= %.4f%%)\n",
            ANO, fator_tat, fator_tat * 100))
cat("TAT por ano:\n")
print(tat_ate_ano)

# ---- Distribuição de receita por título e operador ---------------------------
quotas$ticket_code <- as.integer(quotas$ticket_code)
rtd$ticket_code    <- as.integer(rtd$ticket_code)

dist_ij <- quotas |>
  dplyr::select(operador, ticket_code, quota) |>
  dplyr::left_join(
    rtd |> dplyr::select(ticket_code, titulo_nome, receita_distribuir),
    by = "ticket_code"
  ) |>
  dplyr::mutate(
    quota              = as.numeric(quota),
    receita_distribuir = as.numeric(receita_distribuir),
    # Sem arredondamento intermédio por título (como no Excel original,
    # que mantém precisão total e só arredonda no somatório final por operador)
    dist_receita       = quota * receita_distribuir,
    # Parcela de congelamento por título e operador
    receita_compensar  = dist_receita * fator_tat
  )

# Verificação: soma das dist_receita por título deve = receita_distribuir
verif_titulos <- dist_ij |>
  dplyr::group_by(ticket_code) |>
  dplyr::summarise(
    soma_dist    = sum(dist_receita, na.rm = TRUE),
    receita_orig = mean(receita_distribuir, na.rm = TRUE),
    dif          = soma_dist - receita_orig,
    .groups = "drop"
  )

max_dif <- max(abs(verif_titulos$dif), na.rm = TRUE)
if (max_dif > 0.05) {
  warning(sprintf("Diferença máxima de distribuição por título: %.4f€ — verificar!", max_dif))
} else {
  message(sprintf("✓ Distribuição por título OK (dif. máx. = %.6f€)", max_dif))
}

# ---- B(j) — Receita bilheteira devida por operador --------------------------
B_operador <- dist_ij |>
  dplyr::group_by(operador) |>
  dplyr::summarise(
    receita_B = round(sum(dist_receita, na.rm = TRUE), 2),
    .groups = "drop"
  )

# ---- Congelamento por operador -----------------------------------------------
congelamento_operador <- dist_ij |>
  dplyr::group_by(operador) |>
  dplyr::summarise(
    congelamento_B = round(sum(receita_compensar, na.rm = TRUE), 2),
    .groups = "drop"
  )

# ---- Sumário -----------------------------------------------------------------
cat("\n--- Repartição B e Congelamento por operador ---\n")
B_operador |>
  dplyr::left_join(congelamento_operador, by = "operador") |>
  dplyr::arrange(desc(receita_B)) |>
  dplyr::mutate(
    receita_B      = scales::number(receita_B,      big.mark = ".", decimal.mark = ",", accuracy = 0.01),
    congelamento_B = scales::number(congelamento_B, big.mark = ".", decimal.mark = ",", accuracy = 0.01)
  ) |>
  print()

total_B    <- sum(B_operador$receita_B, na.rm = TRUE)
total_cong <- sum(congelamento_operador$congelamento_B, na.rm = TRUE)
total_dist <- sum(rtd$receita_distribuir, na.rm = TRUE)

cat(sprintf("\nTotal B (receita devida):    %12.2f €\n", total_B))
cat(sprintf("Total a distribuir (A+K):    %12.2f €\n", total_dist))
cat(sprintf("Total Congelamento:          %12.2f €\n", total_cong))

if (abs(total_B - total_dist) > 0.50)
  warning(sprintf("DISCREPÂNCIA B vs. distribuir: %.2f €", total_B - total_dist))

# ---- Guardar outputs ---------------------------------------------------------
rep_out  <- F_REPARTICAO_B
cong_out <- F_CONGELAMENTO

# Tabela detalhada por título × operador
write.csv2(dist_ij,               rep_out,  row.names = FALSE)
# Congelamento por operador (com receita_B para referência)
congelamento_saida <- B_operador |>
  dplyr::left_join(congelamento_operador, by = "operador")
write.csv2(congelamento_saida,    cong_out, row.names = FALSE)

message("Outputs gravados:")
message("  ", rep_out)
message("  ", cong_out)
