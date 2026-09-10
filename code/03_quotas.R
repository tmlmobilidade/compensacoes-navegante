# =============================================================================
# 03_quotas.R — Calcula PKM e Quotas de distribuição por título e operador
# Distribuição de Receitas Navegante — TML
#
# Fórmula (Regulamento 1362-C/2023):
#   PKM(i,j)   = PT(i,j) × distância(i,j)
#   Q_raw(i,j) = peso(j) × PKM(i,j)
#   Quota(i,j) = Q_raw(i,j) / sum_j[ Q_raw(i,j) ]   → soma = 1 por título i
#
# Caso especial: se sum_j[Q_raw] == 0 para um título i (todos os operadores
# têm dist=0 ou PT=0), usar a quota média do operador (média sobre outros títulos).
#
# Inputs:
#   OUT_DIR/PT_mesano.csv
#   OUT_DIR/distancias_mesano.csv
#   lists/pesos_pkm.csv
#
# Output:
#   OUT_DIR/quotas_mesano.csv   (ticket_code × operador → quota [0,1])
# =============================================================================

source(here::here("code", "config.R"))

# ---- Carregar dados ----------------------------------------------------------
PT_mesano         <- read.csv2(F_PT,
                               stringsAsFactors = FALSE)
distancias_mesano <- read.csv2(F_DISTANCIAS,
                               stringsAsFactors = FALSE)

# Pesos — ficheiro sem header; colunas: operador_nome, peso
# Nomes na tabela de pesos usam OPERATOR_NAME_NAVEGANTE (ver operadores.csv)
pesos_raw <- read.csv2(file.path(LISTS_DIR, "pesos_pkm.csv"),
                       header = FALSE, stringsAsFactors = FALSE, dec = ".")
names(pesos_raw) <- c("operador_nome_navegante", "peso")
pesos_raw$peso   <- as.numeric(pesos_raw$peso)

# Mapeamento nome_navegante → abreviatura usada nos PT
# (baseado em lists/operadores.csv campo OPERATOR_NAME_NAVEGANTE)
mapa_pesos <- c(
  "CP"          = "CP",
  "FT"          = "FT",
  "TT"          = "TT",
  "SL"          = "SL",
  "ML"          = "ML",
  "MTS"         = "MS",
  "Carris"      = "CA",
  "TCB"         = "TB",
  "AT Cascais"  = "CAP",
  "AT TML - CM" = "CM",
  "BT Oeste"    = "BQ"
)

pesos <- pesos_raw |>
  dplyr::mutate(operador = dplyr::recode(operador_nome_navegante, !!!mapa_pesos)) |>
  dplyr::select(operador, peso)

# ---- Juntar PT × Distâncias × Pesos -----------------------------------------
PT_mesano$ticket_code         <- as.integer(PT_mesano$ticket_code)
distancias_mesano$ticket_code <- as.integer(distancias_mesano$ticket_code)

pkm_base <- PT_mesano |>
  dplyr::left_join(distancias_mesano |>
                     dplyr::select(operador, ticket_code, distancia_km),
                   by = c("operador", "ticket_code")) |>
  dplyr::left_join(pesos, by = "operador") |>
  dplyr::mutate(
    distancia_km = dplyr::if_else(is.na(distancia_km), 0, as.numeric(distancia_km)),
    peso         = dplyr::if_else(is.na(peso), 0, as.numeric(peso)),
    pt_operador  = as.numeric(pt_operador)
  )

# Verificar operadores sem peso
ops_sem_peso <- pkm_base |>
  dplyr::filter(peso == 0 | is.na(peso)) |>
  dplyr::pull(operador) |>
  unique()
if (length(ops_sem_peso) > 0)
  warning("Operadores sem peso definido: ", paste(ops_sem_peso, collapse = ", "))

# ---- Calcular PKM e Quota_raw ------------------------------------------------
pkm_base <- pkm_base |>
  dplyr::mutate(
    pkm       = pt_operador * distancia_km,
    quota_raw = peso * pkm
  )

# ---- Normalizar quotas (soma = 1 por título) ---------------------------------
quotas_norm <- pkm_base |>
  dplyr::group_by(ticket_code) |>
  dplyr::mutate(
    soma_quota_raw = sum(quota_raw, na.rm = TRUE)
  ) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    quota = dplyr::if_else(soma_quota_raw > 0,
                           quota_raw / soma_quota_raw,
                           NA_real_)   # assinalar: precisa de quota média
  )

# ---- Caso especial: títulos sem PKM (dist=0 para todos ou PT=0 para todos) ---
# Usar a quota média do operador (média ponderada das quotas noutros títulos)
quota_media_op <- quotas_norm |>
  dplyr::filter(!is.na(quota)) |>
  dplyr::group_by(operador) |>
  dplyr::summarise(quota_media = mean(quota, na.rm = TRUE), .groups = "drop")

titulos_sem_pkm <- quotas_norm |>
  dplyr::filter(soma_quota_raw == 0) |>
  dplyr::pull(ticket_code) |>
  unique()

if (length(titulos_sem_pkm) > 0) {
  message(sprintf(
    "Títulos sem PKM (usar quota média): %d — ticket_codes: %s",
    length(titulos_sem_pkm),
    paste(titulos_sem_pkm, collapse = ", ")
  ))
}

quotas_norm <- quotas_norm |>
  dplyr::left_join(quota_media_op, by = "operador") |>
  dplyr::mutate(
    quota = dplyr::if_else(is.na(quota),
                           quota_media / sum(quota_media_op$quota_media),
                           quota),
    quota_fonte = dplyr::if_else(soma_quota_raw == 0, "quota_media", "pkm")
  ) |>
  dplyr::select(-quota_media)

# Re-normalizar após substituição (garantir soma = 1)
quotas_norm <- quotas_norm |>
  dplyr::group_by(ticket_code) |>
  dplyr::mutate(
    quota = quota / sum(quota, na.rm = TRUE)
  ) |>
  dplyr::ungroup()

# ---- Verificação: soma das quotas por título ----------------------------------
verificacao <- quotas_norm |>
  dplyr::group_by(ticket_code) |>
  dplyr::summarise(soma_quota = round(sum(quota, na.rm = TRUE), 6), .groups = "drop")

n_erros <- sum(abs(verificacao$soma_quota - 1) > 0.0001, na.rm = TRUE)
if (n_erros > 0) {
  warning(sprintf("%d título(s) com soma de quotas ≠ 1!", n_erros))
  print(verificacao |> dplyr::filter(abs(soma_quota - 1) > 0.0001))
} else {
  message("✓ Verificação: soma das quotas = 1 para todos os títulos.")
}

# ---- Output ------------------------------------------------------------------
quotas_mesano <- quotas_norm |>
  dplyr::select(
    operador, ticket_code,
    pt_operador, distancia_km, peso,
    pkm, quota_raw, quota, quota_fonte
  ) |>
  dplyr::arrange(ticket_code, operador)

quota_out <- F_QUOTAS
write.csv2(quotas_mesano, quota_out, row.names = FALSE)
message("Output gravado: ", quota_out)

cat("\n--- Quotas por operador (média sobre títulos) ---\n")
quotas_mesano |>
  dplyr::group_by(operador) |>
  dplyr::summarise(
    n_titulos    = dplyr::n(),
    quota_media  = round(mean(quota, na.rm = TRUE) * 100, 2),
    pkm_total    = round(sum(pkm, na.rm = TRUE) / 1e6, 2),
    .groups = "drop"
  ) |>
  dplyr::arrange(desc(quota_media)) |>
  dplyr::rename(`Quota média (%)` = quota_media,
                `PKM total (M)` = pkm_total) |>
  print()
