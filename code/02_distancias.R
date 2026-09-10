# =============================================================================
# 02_distancias.R — Resolve as distâncias médias por título e operador
# Distribuição de Receitas Navegante — TML
#
# Hierarquia de distâncias (Regulamento 1362-C/2023, Secção VIII):
#  1. Distância dinâmica APEX (para CM e CAP) → V_REG_AVERAGE_DISTANCE_FINAL_ALL_*.csv
#  2. Para os restantes: tabelas de referência (out21 / ago21)
#     A tabela é estática por operador × título. Se valor = 0, aplica fallback.
#
# Inputs:
#   OUT_DIR/PT_{SUFIXO}.csv
#   INPUT_DIR/V_REG_AVERAGE_DISTANCE_FINAL_ALL_*.csv ou distancias_dinamicas_*.csv (distâncias APEX)
#   lists/distanciasref_{out21|ago21}_incompleto.csv (referência estática)
#   lists/operadores.csv
#   lists/titulos.csv
#
# Output:
#   OUT_DIR/distancias_{SUFIXO}.csv   (ticket_code × operador → distancia_km)
# =============================================================================

source(here::here("code", "config.R"))

# ---- Carregar dados de suporte -----------------------------------------------
operadores <- read.csv2(file.path(LISTS_DIR, "operadores.csv"),
                        stringsAsFactors = FALSE, dec = ".")
titulos    <- read.csv2(file.path(LISTS_DIR, "titulos.csv"),
                        stringsAsFactors = FALSE, dec = ".")
PT_mesano  <- read.csv2(F_PT,
                        stringsAsFactors = FALSE)

# ---- 1. Distâncias dinâmicas APEX (CM e CAP) ---------------------------------
# Ficheiro exportado do Oracle PDBDWPROD (procurar em INPUT_DIR ou REPLICATE_DIR)
apex_files <- list.files(
  c(INPUT_DIR, REPLICATE_DIR),
  pattern = "(V_REG_AVERAGE_DISTANCE_FINAL_ALL|distancias_dinamicas).*\\.csv$",
  full.names = TRUE
)
apex_files <- unique(apex_files)

if (length(apex_files) == 0)
  stop("Ficheiro de distâncias APEX não encontrado em: ", INPUT_DIR)

# Usar o ficheiro mais recente (preferir V_REG se existir)
v_reg_files <- grep("V_REG_AVERAGE_DISTANCE_FINAL_ALL", apex_files, value = TRUE)
apex_file <- if (length(v_reg_files) > 0) {
  tail(sort(v_reg_files), 1)
} else {
  tail(sort(apex_files), 1)
}
message("Ficheiro APEX: ", basename(apex_file))

# Ler (separador ";" com vírgula decimal é possível — verificar)
apex_raw <- tryCatch(
  read.csv(apex_file, sep = ";", header = TRUE, stringsAsFactors = FALSE,
           fileEncoding = "UTF-8-BOM", check.names = FALSE),
  error = function(e) read.csv(apex_file, header = TRUE, stringsAsFactors = FALSE,
                               fileEncoding = "UTF-8-BOM", check.names = FALSE)
)

# Normalizar nomes
apex_raw <- apex_raw |> janitor::clean_names()
# Colunas relevantes: ticket_code_ref, entity_id, calc_final_value
stopifnot(all(c("ticket_code_ref", "entity_id", "calc_final_value") %in% names(apex_raw)))

# Filtrar mês/ano e operadores APEX
apex_dist <- apex_raw |>
  dplyr::filter(
    distribution_year  == ANO,
    distribution_month == MES,
    entity_id %in% APEX_ENTITY_IDS
  ) |>
  dplyr::select(entity_id, ticket_code = ticket_code_ref,
                distancia_km = calc_final_value) |>
  dplyr::mutate(
    distancia_km = as.numeric(distancia_km),
    ticket_code  = as.integer(ticket_code),
    entity_id    = as.integer(entity_id)
  )

# Mapear entity_id para abreviatura usada nos PT
# CM → ENTITY_ID 75; CAP → ENTITY_ID 22
apex_dist <- apex_dist |>
  dplyr::left_join(
    operadores |> dplyr::select(entity_id = ENTITY_ID,
                                entity_abbreviation = ENTITY_ABBREVIATION),
    by = "entity_id"
  ) |>
  dplyr::mutate(
    operador = dplyr::case_when(
      entity_id == 75L ~ "CM",
      entity_id == 22L ~ "CAP",
      TRUE             ~ entity_abbreviation
    )
  ) |>
  dplyr::select(operador, ticket_code, distancia_km, fonte = entity_id) |>
  dplyr::mutate(fonte = "APEX")

message(sprintf("Distâncias APEX: %d registos (%s).",
                nrow(apex_dist),
                paste(unique(apex_dist$operador), collapse = ", ")))

# ---- 2. Distâncias de referência (operadores não-APEX) -----------------------
# Ficheiro em formato wide: ticket_code por linha, operador por coluna

dist_ref_raw <- read.csv2(DIST_REF_FILE, stringsAsFactors = FALSE, dec = ".")

# Converter para long format
# Colunas: ticket_operator_code, ticket_code, CP, FT, TT, SL, ML, MTS,
#          Carris, TCB, AT Cascais, AT TML - CM, BT Oeste
dist_ref_long <- dist_ref_raw |>
  tidyr::pivot_longer(
    cols      = -c(ticket_operator_code, ticket_code),
    names_to  = "operador_ref",
    values_to = "distancia_km"
  ) |>
  dplyr::mutate(distancia_km = as.numeric(distancia_km))

# Mapeamento: nome na tabela de referência → abreviatura usada nos PT
mapa_ops_ref <- c(
  "CP"          = "CP",
  "FT"          = "FT",
  "TT"          = "TT",
  "SL"          = "SL",
  "ML"          = "ML",
  "MTS"         = "MS",    # Metro Transportes do Sul
  "Carris"      = "CA",    # Carris
  "TCB"         = "TB",    # Transportes Colectivos do Barreiro
  "AT.Cascais"  = "CAP",   # Cascais Próxima (coluna pode ter ".")
  "AT Cascais"  = "CAP",
  "AT.TML...CM" = "CM",    # Carris Metropolitana
  "AT.TML...CM" = "CM",
  "AT TML - CM" = "CM",
  "BT.Oeste"    = "BQ",    # Barraqueiro Transportes
  "BT Oeste"    = "BQ"
)

dist_ref_long <- dist_ref_long |>
  dplyr::mutate(
    operador = dplyr::recode(operador_ref, !!!mapa_ops_ref),
    fonte    = "ref_estatica"
  ) |>
  dplyr::filter(ticket_operator_code == 31) |>
  dplyr::select(operador, ticket_code, distancia_km, fonte)

# ---- 3. Combinar: APEX tem prioridade sobre referência estática --------------
# Para operadores APEX (CM, CAP): usar APEX; para os restantes: referência
operadores_apex <- unique(apex_dist$operador)   # normalmente c("CM", "CAP")

dist_ref_nao_apex <- dist_ref_long |>
  dplyr::filter(!operador %in% operadores_apex)

distancias_completa <- dplyr::bind_rows(apex_dist, dist_ref_nao_apex)

# ---- 4. Fallback para distância = 0 ou em falta (hierarquia regulamentar) ---
# As tabelas de referência têm 0 quando não existe distância disponível para
# aquele operador × título. Aplicar hierarquia:
#   1. Mesma tipologia, mesmo operador (já na tabela)
#   2. Título base, mesmo operador
#   3. Distância = 0 → manter 0 (operador não serve aquele título → sem PKM)
#
# A hierarquia mais sofisticada (prioridades 1-5 do regulamento) requer dados
# dinâmicos de meses anteriores que podem não estar disponíveis.
# Por agora: se dist = 0 → tentar título base (preco_base do mesmo operador).

titulos_base <- titulos |>
  dplyr::select(ticket_code, titulo_nome_base)

# Para cada operador × ticket_code com dist=0, procurar distância do título base
# Passo 1: obter o ticket_code "base" de cada título
titulos_codigos <- titulos |>
  dplyr::select(ticket_code) |>
  dplyr::distinct()

# Nota: a tabela de referência já usa ticket_code como chave —
# não há um campo explícito de "ticket_code base" nos dados de referência.
# A hierarquia de fallback é assinalada como NA / 0 e documentada no output.
# TODO: implementar hierarquia completa quando disponível.

distancias_mesano <- distancias_completa |>
  dplyr::filter(ticket_code > 0) |>
  dplyr::mutate(
    distancia_zero = distancia_km == 0 | is.na(distancia_km),
    distancia_km   = dplyr::if_else(is.na(distancia_km), 0, distancia_km)
  )

# Juntar com PT_mesano para garantir apenas os pares (operador, ticket_code)
# que realmente têm passageiros
PT_mesano$ticket_code <- as.integer(PT_mesano$ticket_code)
distancias_mesano$ticket_code <- as.integer(distancias_mesano$ticket_code)

distancias_mesano <- PT_mesano |>
  dplyr::select(operador, ticket_code) |>
  dplyr::distinct() |>
  dplyr::left_join(distancias_mesano, by = c("operador", "ticket_code")) |>
  dplyr::mutate(
    distancia_km = dplyr::if_else(is.na(distancia_km), 0, distancia_km),
    fonte        = dplyr::if_else(is.na(fonte), "nao_encontrada", fonte)
  )

# Avisar sobre distâncias em falta
n_falta <- sum(distancias_mesano$fonte == "nao_encontrada" |
               distancias_mesano$distancia_zero, na.rm = TRUE)
if (n_falta > 0) {
  message(sprintf(
    "AVISO: %d par(es) operador×título sem distância (dist=0 ou não encontrada).",
    n_falta))
  distancias_mesano |>
    dplyr::filter(distancia_km == 0 | fonte == "nao_encontrada") |>
    dplyr::arrange(operador, ticket_code) |>
    print()
}

message(sprintf("Distâncias finais: %d pares operador×título.", nrow(distancias_mesano)))

# ---- Guardar output ----------------------------------------------------------
dist_out <- F_DISTANCIAS
write.csv2(distancias_mesano, dist_out, row.names = FALSE)
message("Output gravado: ", dist_out)

# Sumário
cat("\n--- Distâncias médias por operador (média sobre títulos com dist>0) ---\n")
distancias_mesano |>
  dplyr::filter(distancia_km > 0) |>
  dplyr::group_by(operador, fonte) |>
  dplyr::summarise(
    n_titulos    = dplyr::n(),
    dist_media   = round(mean(distancia_km), 3),
    dist_min     = round(min(distancia_km), 3),
    dist_max     = round(max(distancia_km), 3),
    .groups = "drop"
  ) |>
  dplyr::arrange(operador) |>
  print()
