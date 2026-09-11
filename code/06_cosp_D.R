# =============================================================================
# 06_cosp_D.R — COSP: Compensação de Obrigação de Serviço Público (D)
# Distribuição de Receitas Navegante — TML
#
# Regulamento 1362-C/2023:
#   VMC_2026 = VMC_2023 × ∏(1 + TAT_ano)   arredondado ao cêntimo
#   valor_medio_passe = VMC_2026 / N_PASSES_COMPENSAR
#   estimativa_passes_anuais = qty_total_mes / sazonalidade_mes
#   pct_compensar = min(1, N_PASSES_COMPENSAR / estimativa_passes_anuais)
#   passes_compensar(i) = pct_compensar × qty_titulo(i)
#   COSP(i) = passes_compensar(i) × valor_medio_passe × (1 - RETENCAO_TML)
#   COSP_dist(i,j) = COSP(i) × Quota(i,j)
#   D(j) = sum_i[ COSP_dist(i,j) ]
#
# Inputs:
#   OUT_DIR/receita_titulo_distribuir_mesano.csv
#   OUT_DIR/quotas_mesano.csv
#   lists/sazonalidade.csv
#   lists/tat.csv
#
# Output:
#   OUT_DIR/cosp_D_mesano.csv   (COSP por título e operador + D por operador)
# =============================================================================

source(here::here("code", "config.R"))

rtd      <- read.csv2(F_RTD,
                      stringsAsFactors = FALSE)
quotas   <- read.csv2(F_QUOTAS,
                      stringsAsFactors = FALSE)
saz      <- read.csv2(file.path(LISTS_DIR, "sazonalidade.csv"),
                      stringsAsFactors = FALSE, dec = ".")
tat_df   <- read.csv2(TAT_FILE, stringsAsFactors = FALSE, dec = ".")
tat_df$tat <- as.numeric(tat_df$tat)

# ---- 1. VMC atualizado -------------------------------------------------------
tat_ate_ano   <- tat_df[tat_df$ano <= ANO, ]
fator_tat_vmc <- prod(1 + tat_ate_ano$tat)   # produto completo (não subtrair 1)
VMC_ano       <- round(VMC_2023 * fator_tat_vmc, 2)

cat(sprintf("VMC 2023 (regulado):  %15.2f €\n", VMC_2023))
cat(sprintf("Factor TAT (∏):       %15.6f\n", fator_tat_vmc))
cat(sprintf("VMC %d (atualizado): %15.2f €\n", ANO, VMC_ano))

# ---- 2. Valor médio por passe ------------------------------------------------
valor_medio_passe <- VMC_ano / N_PASSES_COMPENSAR
cat(sprintf("Valor médio por passe: %13.6f €\n", valor_medio_passe))

# ---- 3. Sazonalidade e estimativa de passes anuais --------------------------
saz_mes <- saz[saz$mes == MES, "sazonalidade"]
if (length(saz_mes) == 0 || is.na(saz_mes))
  stop("Sazonalidade não encontrada para mês: ", MES)

cat(sprintf("Sazonalidade mês %d:   %13.3f\n", MES, saz_mes))

# Quantidade total de passes vendidos no sistema (SISTEMA_QUANTITY)
# Usar receita_titulo_distribuir que contém qty_total = qty_A + qty_K + qty_vat
qty_total_mes <- sum(rtd$qty_total, na.rm = TRUE)

estimativa_passes_anuais <- qty_total_mes / saz_mes
pct_compensar <- min(1, N_PASSES_COMPENSAR / estimativa_passes_anuais)

cat(sprintf("Qty passes mês:        %13d\n", round(qty_total_mes)))
cat(sprintf("Estimativa anual:      %13d\n", round(estimativa_passes_anuais)))
cat(sprintf("N passes a compensar:  %13d\n", N_PASSES_COMPENSAR))
cat(sprintf("Percentagem a comp.:   %13.4f%%\n", pct_compensar * 100))

# ---- 4. COSP por título ------------------------------------------------------
rtd$ticket_code    <- as.integer(rtd$ticket_code)
quotas$ticket_code <- as.integer(quotas$ticket_code)

# Quantidade total por título (vendas A + K + VaT)
qty_titulo <- rtd |>
  dplyr::mutate(
    qty_total_i = as.numeric(qty_total)
  ) |>
  dplyr::select(ticket_code, titulo_nome, qty_total_i)

cosp_titulo <- qty_titulo |>
  dplyr::mutate(
    passes_compensar_i = round(pct_compensar * qty_total_i, 0),
    COSP_i             = passes_compensar_i * valor_medio_passe * (1 - RETENCAO_TML)
  )

cat(sprintf("\nTotal passes a compensar no mês: %d\n", sum(cosp_titulo$passes_compensar_i, na.rm = TRUE)))
cat(sprintf("COSP total (antes de distribuir): %.2f €\n",
            sum(cosp_titulo$COSP_i, na.rm = TRUE)))

# ---- 5. Distribuição COSP por título e operador ------------------------------
cosp_dist <- quotas |>
  dplyr::select(operador, ticket_code, quota) |>
  dplyr::mutate(quota = as.numeric(quota)) |>
  dplyr::left_join(cosp_titulo |> dplyr::select(ticket_code, COSP_i),
                   by = "ticket_code") |>
  dplyr::mutate(
    COSP_ij = quota * COSP_i
  )

# ---- 6. D(j) — COSP por operador --------------------------------------------
D_operador <- cosp_dist |>
  dplyr::group_by(operador) |>
  dplyr::summarise(D = round(sum(COSP_ij, na.rm = TRUE), 2), .groups = "drop")

cat("\n--- COSP (D) por operador ---\n")
D_operador |>
  dplyr::arrange(desc(D)) |>
  dplyr::mutate(D = scales::number(D, big.mark = " ", decimal.mark = ",", accuracy = 0.01)) |>
  print()

cat(sprintf("\nTotal D (COSP):  %.2f €\n", sum(D_operador$D, na.rm = TRUE)))

# ---- Guardar output ----------------------------------------------------------
# Tabela completa com detalhes
cosp_output <- cosp_dist |>
  dplyr::left_join(cosp_titulo |> dplyr::select(ticket_code, titulo_nome,
                                                  qty_total_i, passes_compensar_i),
                   by = "ticket_code") |>
  dplyr::select(operador, ticket_code, titulo_nome, qty_total_i,
                passes_compensar_i, COSP_i, quota, COSP_ij) |>
  dplyr::arrange(ticket_code, operador)

# Adicionar totais D por operador ao CSV de saída
cosp_D_out <- F_COSP_D
write.csv2(cosp_output, cosp_D_out, row.names = FALSE)

# Também guardar o sumário D por operador
D_out <- F_D_OPERADOR
write.csv2(D_operador, D_out, row.names = FALSE)

message("Outputs gravados:")
message("  ", cosp_D_out)
message("  ", D_out)

# Parâmetros COSP para auditoria
cat("\n--- Parâmetros COSP (para verificação) ---\n")
cat(sprintf("  VMC 2023:              %15.2f €\n", VMC_2023))
cat(sprintf("  VMC %d:              %15.2f €\n", ANO, VMC_ano))
cat(sprintf("  N passes compensar:    %15d\n",   N_PASSES_COMPENSAR))
cat(sprintf("  Valor médio passe:     %15.6f €\n", valor_medio_passe))
cat(sprintf("  Sazonalidade mês %d:   %15.3f\n",   MES, saz_mes))
cat(sprintf("  Qty passes mês:        %15d\n",   round(qty_total_mes)))
cat(sprintf("  Estimativa anual:      %15d\n",   round(estimativa_passes_anuais)))
cat(sprintf("  %% a compensar:         %15.4f%%\n", pct_compensar * 100))
cat(sprintf("  Retenção TML:          %15.1f%%\n", RETENCAO_TML * 100))
