# =============================================================================
# 08_tables.R — Exporta relatório consolidado de compensações em Excel (xlsx)
# Distribuição de Receitas Navegante — TML
#
# Gera o workbook 'tabela_transferencias_<sufixo>.xlsx' com as seguintes folhas:
#   "0 - Global"               — Tabela cruzada consolidada de transferências (TT+SL agregados)
#   "1 - Quotas"               — Quotas de distribuição por título e operador (formato wide)
#   "2 - Vendas AK"            — Resumo e detalhe de vendas A (operadores) e K (canais TML)
#   "4 - Receita B e CongNav B"— Receita bilheteira devida e congelamento por operador
#   "5 - Pag Conta COSP D"     — Parâmetros regulamentares COSP e pagamentos por operador
#   "6 - Transferencias F"     — Formato longo de transferências por métrica (TT+SL agregados)
#
# Cabeçalhos: tom dourado (gold).
# Nomes e ordenação de operadores alternativos:
#   CP, FT, TT, SL, ML, MTS, Carris, TCB, AT Cascais, AT TML - CM, BT Oeste
#   (TT+SL são agregados apenas nas folhas "0 - Global" e "6 - Transferencias F")
# =============================================================================

source(here::here("code", "config.R"))
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(openxlsx)
})

# ---- 0. Mapeamentos e Ordenação de Operadores --------------------------------
# Nomes alternativos com TT e SL separados (11 operadores)
nome_op_sep <- c(
  CP  = "CP",
  FT  = "FT",
  TT  = "TT",
  SL  = "SL",
  ML  = "ML",
  MS  = "MTS",
  CA  = "Carris",
  TB  = "TCB",
  CAP = "AT Cascais",
  CM  = "AT TML - CM",
  BQ  = "BT Oeste"
)

ordem_ops_sep <- c("CP", "FT", "TT", "SL", "ML", "MTS",
                   "Carris", "TCB", "AT Cascais", "AT TML - CM", "BT Oeste")

# Nomes alternativos com TT + SL agregados (10 operadores)
nome_op_merged <- c(
  CP  = "CP",
  FT  = "FT",
  TT  = "TT + SL",
  SL  = "TT + SL",
  ML  = "ML",
  MS  = "MTS",
  CA  = "Carris",
  TB  = "TCB",
  CAP = "AT Cascais",
  CM  = "AT TML - CM",
  BQ  = "BT Oeste"
)

ordem_ops_merged <- c("CP", "FT", "TT + SL", "ML", "MTS",
                      "Carris", "TCB", "AT Cascais", "AT TML - CM", "BT Oeste")

# Carregar operadores.csv para nomes completos
op_df <- read.csv2(file.path(LISTS_DIR, "operadores.csv"), stringsAsFactors = FALSE, dec = ".")
nomes_completos <- op_df |>
  dplyr::select(ENTITY_ABBREVIATION, ENTITY_NAME) |>
  dplyr::distinct() |>
  tibble::deframe()

# Títulos de transporte
titulos_df <- read.csv2(file.path(LISTS_DIR, "titulos.csv"), stringsAsFactors = FALSE, dec = ".")
titulos_df$ticket_code <- as.integer(titulos_df$ticket_code)
titulos_df$pvp         <- as.numeric(titulos_df$pvp)

# ---- 1. Carregar Dados de Output ---------------------------------------------
# 1.1 Transferências
transf_raw <- read.csv2(F_TRANSFERENCIAS, stringsAsFactors = FALSE, dec = ",")
if ("receita_B" %in% names(transf_raw) && !"B" %in% names(transf_raw)) transf_raw$B <- transf_raw$receita_B
if ("cosp_D" %in% names(transf_raw) && !"D" %in% names(transf_raw)) transf_raw$D <- transf_raw$cosp_D
if ("congelamento_B" %in% names(transf_raw) && !"congelamento" %in% names(transf_raw)) transf_raw$congelamento <- transf_raw$congelamento_B

num_cols_tr <- c("B", "congelamento", "receita_A", "D", "F_transferencia", "total_transferir")
transf_raw[num_cols_tr] <- lapply(transf_raw[num_cols_tr], function(x) as.numeric(gsub(",", ".", x)))

# 1.2 Quotas
quotas_raw <- read.csv2(F_QUOTAS, stringsAsFactors = FALSE, dec = ",")
quotas_raw$ticket_code <- as.integer(quotas_raw$ticket_code)
quotas_raw$quota       <- as.numeric(gsub(",", ".", quotas_raw$quota))

# 1.3 Receita Titulo Distribuir (RTD)
rtd_raw <- read.csv2(F_RTD, stringsAsFactors = FALSE, dec = ",")
num_cols_rtd <- c("pvp", "receita_A_total", "qty_A_total", "qty_K", "receita_K", "qty_vat", "qty_total", "receita_distribuir")
for (col in intersect(num_cols_rtd, names(rtd_raw))) {
  rtd_raw[[col]] <- as.numeric(gsub(",", ".", rtd_raw[[col]]))
}
rtd_raw$ticket_code <- as.integer(rtd_raw$ticket_code)

# 1.4 Vendas A por operador
vendas_a_raw <- if (file.exists(F_VENDAS_A)) {
  read.csv2(F_VENDAS_A, stringsAsFactors = FALSE, dec = ",") |>
    mutate(receita_A = as.numeric(gsub(",", ".", receita_A)),
           qty_A     = as.numeric(gsub(",", ".", qty_A)))
} else {
  transf_raw |> select(operador, receita_A) |> mutate(qty_A = 0)
}

# 1.5 Vendas K por canal (PV / ATM)
vendas_k_raw <- if (file.exists(F_VENDAS_K)) {
  df_vk <- read.csv2(F_VENDAS_K, stringsAsFactors = FALSE, dec = ",")
  for (c in c("pvp", "qty_K_pv", "receita_K_pv", "qty_K_atm", "receita_K_atm", "qty_K", "receita_K")) {
    if (c %in% names(df_vk)) df_vk[[c]] <- as.numeric(gsub(",", ".", df_vk[[c]]))
  }
  df_vk$ticket_code <- as.integer(df_vk$ticket_code)
  df_vk
} else {
  NULL
}

# 1.6 Receita B e Congelamento
cong_raw <- read.csv2(F_CONGELAMENTO, stringsAsFactors = FALSE, dec = ",")
cong_raw$receita_B      <- as.numeric(gsub(",", ".", cong_raw$receita_B))
cong_raw$congelamento_B <- as.numeric(gsub(",", ".", cong_raw$congelamento_B))

# 1.7 COSP D por operador
cosp_raw <- read.csv2(F_D_OPERADOR, stringsAsFactors = FALSE, dec = ",")
cosp_raw$cosp_D <- as.numeric(gsub(",", ".", cosp_raw$cosp_D))

# Total K de canais partilhados
total_K_val <- sum(rtd_raw$receita_K, na.rm = TRUE)

# ---- 2. Paleta de Cores e Estilos --------------------------------------------
cor_gold_dark   <- "#FFC000"  # DarkGoldenrod — cabeçalho principal
cor_gold_sub    <- "#FFE699"  # Metallic Gold — subcabeçalhos
cor_gold_light  <- "#FFF2CC"  # Fundo para totais e destaques
cor_op_col      <- "#FAF6EC"  # Fundo suave para colunas de identificação
cor_alt_row     <- "#FCFBF7"  # Linhas alternadas muito subtis
cor_white       <- "#FFFFFF"
cor_border      <- "#e5b32b"  # Dourado para bordas
cor_border_soft <- "#D9D9D9"  # Cinzento suave para grelha
cor_neg         <- "#FFC7CE"  # Fundo para excedentes negativos
cor_zero        <- "#C6EFCE"  # Fundo para linhas a zero (MTS)

wb <- createWorkbook()

# Estilos base
st_title <- createStyle(
  fontSize = 13, textDecoration = "bold",
  halign = "left", valign = "center",
  fgFill = cor_gold_dark, fontColour = "#FFFFFF"
)

st_header_gold <- createStyle(
  fgFill = cor_gold_dark, fontColour = "#FFFFFF",
  halign = "center", valign = "center",
  textDecoration = "bold", border = "TopBottomLeftRight",
  borderColour = cor_border, wrapText = TRUE, fontSize = 9
)

st_header_op <- createStyle(
  fgFill = cor_gold_dark, fontColour = "#FFFFFF",
  halign = "left", valign = "center",
  textDecoration = "bold", border = "TopBottomLeftRight",
  borderColour = cor_border, fontSize = 9
)

st_sub_header <- createStyle(
  fgFill = cor_gold_sub, fontColour = "#FFFFFF",
  halign = "center", valign = "center",
  textDecoration = "bold", border = "TopBottomLeftRight",
  borderColour = cor_border, fontSize = 9
)

st_total_lbl <- createStyle(
  fgFill = cor_gold_light, textDecoration = "bold",
  halign = "left", border = "TopBottomLeftRight",
  borderColour = cor_border, fontSize = 9
)

st_total_num <- createStyle(
  fgFill = cor_gold_light, textDecoration = "bold",
  numFmt = "#,##0.00", halign = "right",
  border = "TopBottomLeftRight", borderColour = cor_border, fontSize = 9
)

st_total_int <- createStyle(
  fgFill = cor_gold_light, textDecoration = "bold",
  numFmt = "#,##0", halign = "right",
  border = "TopBottomLeftRight", borderColour = cor_border, fontSize = 9
)

st_total_pct <- createStyle(
  fgFill = cor_gold_light, textDecoration = "bold",
  numFmt = "0.0000%", halign = "right",
  border = "TopBottomLeftRight", borderColour = cor_border, fontSize = 9
)

st_param_lbl <- createStyle(
  fgFill = cor_op_col, textDecoration = "bold",
  halign = "left", border = "TopBottomLeftRight",
  borderColour = cor_border_soft, fontSize = 9
)

st_param_val <- createStyle(
  halign = "right", border = "TopBottomLeftRight",
  borderColour = cor_border_soft, fontSize = 9
)


# =============================================================================
# FOLHA 0: "0 - Global" (Tabela cruzada consolidada com TT+SL fundidos)
# =============================================================================
addWorksheet(wb, "0 - Global", tabColour = cor_gold_dark)
ws_g <- "0 - Global"

# Mapear para TT + SL
transf_g <- transf_raw |>
  mutate(nome_tab = nome_op_merged[operador]) |>
  filter(!is.na(nome_tab)) |>
  group_by(nome_tab) |>
  summarise(
    receita_A        = sum(receita_A,        na.rm = TRUE),
    B                = sum(B,                na.rm = TRUE),
    congelamento     = sum(congelamento,     na.rm = TRUE),
    D                = sum(D,                na.rm = TRUE),
    F_transferencia  = sum(F_transferencia,  na.rm = TRUE),
    total_transferir = sum(total_transferir, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    C  = receita_A - B,
    SG = C - D
  )

# Ordenar operadores
transf_g <- transf_g |>
  mutate(nome_tab = factor(nome_tab, levels = ordem_ops_merged)) |>
  arrange(nome_tab) |>
  mutate(nome_tab = as.character(nome_tab))

# Excedente MTS (caso MTS tenha total_transferir < 0)
mts_row <- transf_g |> filter(nome_tab == "MTS")
excedente_mts <- if (nrow(mts_row) > 0 && mts_row$total_transferir < 0) abs(mts_row$total_transferir) else 0

# Linha a linha com Transferência entre operadores corrigida:
#   FT recebe excedente de MTS -> TML transfere menos a FT (-excedente)
#   MTS salda excedente via FT -> +excedente, total a transferir TML = 0
transf_g_calc <- transf_g |>
  mutate(
    transf_entre_ops = case_when(
      nome_tab == "FT"  ~ -excedente_mts,
      nome_tab == "MTS" ~  excedente_mts,
      TRUE              ~ NA_real_
    ),
    total_tml = total_transferir + coalesce(transf_entre_ops, 0)
  )

# Total da coluna TOTAL a transferir pela TML
soma_total_tml <- sum(transf_g_calc$total_tml, na.rm = TRUE)

# Percentagens e Parcelas
transf_g_calc <- transf_g_calc |>
  mutate(
    pct = if (soma_total_tml > 0) total_tml / soma_total_tml else 0,
    parcela_partilhada = if_else(nome_tab == "MTS", 0, pct * total_K_val),
    parcela_incentiva  = if_else(nome_tab == "MTS", 0, total_tml - parcela_partilhada)
  )

# Linha TOTAL
total_row_g <- tibble(
  nome_tab           = "TOTAL",
  receita_A          = sum(transf_g_calc$receita_A),
  B                  = sum(transf_g_calc$B),
  C                  = sum(transf_g_calc$C),
  D                  = sum(transf_g_calc$D),
  SG                 = sum(transf_g_calc$SG),
  F_transferencia    = sum(transf_g_calc$F_transferencia),
  congelamento       = sum(transf_g_calc$congelamento),
  total_transferir   = sum(transf_g_calc$total_transferir),
  transf_entre_ops   = 0.0,
  total_tml          = sum(transf_g_calc$total_tml),
  pct                = sum(transf_g_calc$pct),
  parcela_partilhada = sum(transf_g_calc$parcela_partilhada),
  parcela_incentiva  = sum(transf_g_calc$parcela_incentiva)
)

tabela_global <- bind_rows(
  transf_g_calc |> select(
    nome_tab, receita_A, B, C, D, SG, F_transferencia, congelamento,
    total_transferir, transf_entre_ops, total_tml, pct,
    parcela_partilhada, parcela_incentiva
  ),
  total_row_g
)

# Nomes de exibição
names_global <- c(
  "Operador",
  "Receita na posse [A]",
  "Receita devida [B]",
  "Saldo de Receitas [C = A - B]",
  "Pagamentos por conta COSP Tarifária [D]",
  "Saldo Global de Receitas [SG]",
  "Transferências [F = -SG]",
  "Compensação congelamento passes Navegante [CongNav[B]]",
  "[F + CongNav[B]]",
  "Transferência entre operadores (€)",
  "TOTAL a transferir pela TML (€)",
  "% do montante total a transferir a cada Operador",
  "Parcela proveniente das verbas dos canais de receita partilhada",
  "Parcela proveniente das verbas do Incentiva +TP"
)

# Escrever título e cabeçalhos
mergeCells(wb, ws_g, rows = 1, cols = 1:14)
writeData(wb, ws_g, x = paste0("     Tabela 0 - Síntese Global de Transferências — ", mes_nome, " ", ANO),
          startRow = 1, startCol = 1)
addStyle(wb, ws_g, st_title, rows = 1, cols = 1:14, gridExpand = TRUE)
setRowHeights(wb, ws_g, rows = 1, heights = 26)

writeData(wb, ws_g, x = as.data.frame(t(names_global)), startRow = 2, startCol = 1, colNames = FALSE)
addStyle(wb, ws_g, st_header_op,   rows = 2, cols = 1)
addStyle(wb, ws_g, st_header_gold, rows = 2, cols = 2:14, gridExpand = TRUE)
setRowHeights(wb, ws_g, rows = 2, heights = 55)

# Escrever dados
writeData(wb, ws_g, x = tabela_global, startRow = 3, startCol = 1, colNames = FALSE)

n_g <- nrow(tabela_global)
for (i in seq_len(n_g)) {
  rw <- i + 2
  op_nm <- tabela_global$nome_tab[i]
  is_tot <- (op_nm == "TOTAL")
  is_evn <- (i %% 2 == 0)
  val_k  <- tabela_global$total_tml[i]
  is_mts <- (op_nm == "MTS")

  if (is_tot) {
    addStyle(wb, ws_g, st_total_lbl, rows = rw, cols = 1)
    addStyle(wb, ws_g, st_total_num, rows = rw, cols = c(2:9, 11, 13:14), gridExpand = TRUE)
    addStyle(wb, ws_g, st_total_num, rows = rw, cols = 10)
    addStyle(wb, ws_g, st_total_pct, rows = rw, cols = 12)
  } else if (is_mts) {
    addStyle(wb, ws_g, createStyle(fgFill = cor_zero, textDecoration = "bold", halign = "left",
                                   border = "LeftRight", borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = 1)
    addStyle(wb, ws_g, createStyle(fgFill = cor_zero, numFmt = "#,##0.00", halign = "right",
                                   border = "LeftRight", borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = c(2:11, 13:14), gridExpand = TRUE)
    addStyle(wb, ws_g, createStyle(fgFill = cor_zero, numFmt = "0.0000%", halign = "right",
                                   border = "LeftRight", borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = 12)
  } else {
    fg <- if (is_evn) cor_alt_row else cor_white
    addStyle(wb, ws_g, createStyle(fgFill = fg, textDecoration = "bold", halign = "left",
                                   border = "LeftRight", borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = 1)
    addStyle(wb, ws_g, createStyle(fgFill = fg, numFmt = "#,##0.00", halign = "right",
                                   border = "LeftRight", borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = c(2:11, 13:14), gridExpand = TRUE)
    addStyle(wb, ws_g, createStyle(fgFill = fg, numFmt = "0.0000%", halign = "right",
                                   border = "LeftRight", borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = 12)
  }
}

setColWidths(wb, ws_g, cols = 1,     widths = 14)
setColWidths(wb, ws_g, cols = 2:9,   widths = 14)
setColWidths(wb, ws_g, cols = 10,    widths = 16)
setColWidths(wb, ws_g, cols = 11,    widths = 16)
setColWidths(wb, ws_g, cols = 12,    widths = 11)
setColWidths(wb, ws_g, cols = 13:14, widths = 18)
freezePane(wb, ws_g, firstActiveRow = 3)


# =============================================================================
# FOLHA 1: "1 - Quotas" (Quotas em formato wide por operador)
# =============================================================================
addWorksheet(wb, "1 - Quotas")
ws_q <- "1 - Quotas"

# Mapear operador nos dados de quota para nome alternativo (11 operadores separados)
quotas_wide <- quotas_raw |>
  mutate(nome_op = nome_op_sep[operador]) |>
  filter(!is.na(nome_op)) |>
  select(ticket_code, nome_op, quota) |>
  pivot_wider(names_from = nome_op, values_from = quota, values_fill = 0)

# Garantir que todas as 11 colunas existem na ordem certa
for (op in ordem_ops_sep) {
  if (!op %in% names(quotas_wide)) quotas_wide[[op]] <- 0
}

quotas_wide <- titulos_df |>
  select(ticket_code, titulo_nome, pvp) |>
  left_join(quotas_wide, by = "ticket_code") |>
  mutate(across(all_of(ordem_ops_sep), ~ replace_na(.x, 0))) |>
  arrange(ticket_code)

# Coluna Total Quota (soma das quotas)
quotas_wide$total_quota <- rowSums(quotas_wide[, ordem_ops_sep], na.rm = TRUE)

# Reordenar colunas
quotas_out <- quotas_wide |>
  select(ticket_code, titulo_nome, pvp, all_of(ordem_ops_sep), total_quota)

# Título
n_q_cols <- ncol(quotas_out)
mergeCells(wb, ws_q, rows = 1, cols = 1:n_q_cols)
writeData(wb, ws_q, x = paste0("     Tabela 1 - Quotas de Repartição por Título e Operador — ", mes_nome, " ", ANO),
          startRow = 1, startCol = 1)
addStyle(wb, ws_q, st_title, rows = 1, cols = 1:n_q_cols, gridExpand = TRUE)
setRowHeights(wb, ws_q, rows = 1, heights = 26)

# Cabeçalhos
names_quotas <- c("Código", "Designação do Título", "PVP (€)", ordem_ops_sep, "Total Quota")
writeData(wb, ws_q, x = as.data.frame(t(names_quotas)), startRow = 2, startCol = 1, colNames = FALSE)
addStyle(wb, ws_q, st_header_gold, rows = 2, cols = 1:n_q_cols, gridExpand = TRUE)
setRowHeights(wb, ws_q, rows = 2, heights = 32)

# Dados
writeData(wb, ws_q, x = quotas_out, startRow = 3, startCol = 1, colNames = FALSE)

n_q_rows <- nrow(quotas_out)
for (i in seq_len(n_q_rows)) {
  rw <- i + 2
  fg <- if (i %% 2 == 0) cor_alt_row else cor_white
  addStyle(wb, ws_q, createStyle(fgFill = fg, halign = "center", border = "LeftRight",
                                 borderColour = cor_border_soft, fontSize = 9),
           rows = rw, cols = 1)
  addStyle(wb, ws_q, createStyle(fgFill = fg, halign = "left", border = "LeftRight",
                                 borderColour = cor_border_soft, fontSize = 9),
           rows = rw, cols = 2)
  addStyle(wb, ws_q, createStyle(fgFill = fg, numFmt = "#,##0.00", halign = "right",
                                 border = "LeftRight", borderColour = cor_border_soft, fontSize = 9),
           rows = rw, cols = 3)
  addStyle(wb, ws_q, createStyle(fgFill = fg, numFmt = "0.0000%", halign = "right",
                                 border = "LeftRight", borderColour = cor_border_soft, fontSize = 9),
           rows = rw, cols = 4:n_q_cols, gridExpand = TRUE)
}

setColWidths(wb, ws_q, cols = 1, widths = 8)
setColWidths(wb, ws_q, cols = 2, widths = 34)
setColWidths(wb, ws_q, cols = 3, widths = 10)
setColWidths(wb, ws_q, cols = 4:n_q_cols, widths = 12)
freezePane(wb, ws_q, firstActiveRow = 3, firstActiveCol = 3)


# =============================================================================
# FOLHA 2: "2 - Vendas AK" (Vendas A e K consolidadas)
# =============================================================================
addWorksheet(wb, "2 - Vendas AK")
ws_ak <- "2 - Vendas AK"

# Preparar dados de resumo por operador (Vendas A)
vendas_a_resumo <- tibble(operador_cod = names(nome_op_sep), nome_op = unname(nome_op_sep)) |>
  left_join(vendas_a_raw |> select(operador, receita_A, qty_A), by = c("operador_cod" = "operador")) |>
  mutate(
    receita_A = replace_na(receita_A, 0),
    qty_A     = replace_na(qty_A, 0)
  ) |>
  mutate(nome_op = factor(nome_op, levels = ordem_ops_sep)) |>
  arrange(nome_op) |>
  mutate(nome_op = as.character(nome_op))

total_rec_a <- sum(vendas_a_resumo$receita_A)
total_qty_a <- sum(vendas_a_resumo$qty_A)

vendas_a_resumo <- vendas_a_resumo |>
  mutate(pct_a = if (total_rec_a > 0) receita_A / total_rec_a else 0)

vendas_a_tab <- bind_rows(
  vendas_a_resumo |> select(Operador = nome_op, `Quantidade (A)` = qty_A, `Receita A (€)` = receita_A, `% Vendas A` = pct_a),
  tibble(Operador = "TOTAL Vendas A", `Quantidade (A)` = total_qty_a, `Receita A (€)` = total_rec_a, `% Vendas A` = 1.0)
)

# Resumo Vendas K por canal (PV / ATM)
qty_k_pv_tot  <- if (!is.null(vendas_k_raw)) sum(vendas_k_raw$qty_K_pv, na.rm = TRUE) else 0
rec_k_pv_tot  <- if (!is.null(vendas_k_raw)) sum(vendas_k_raw$receita_K_pv, na.rm = TRUE) else 0
qty_k_atm_tot <- if (!is.null(vendas_k_raw)) sum(vendas_k_raw$qty_K_atm, na.rm = TRUE) else 0
rec_k_atm_tot <- if (!is.null(vendas_k_raw)) sum(vendas_k_raw$receita_K_atm, na.rm = TRUE) else 0
qty_k_tot     <- qty_k_pv_tot + qty_k_atm_tot
rec_k_tot     <- rec_k_pv_tot + rec_k_atm_tot

vendas_k_tab <- tibble(
  Canal = c("Portal VIVA", "Caixas Multibanco / ATM", "TOTAL Vendas K"),
  Quantidade = c(qty_k_pv_tot, qty_k_atm_tot, qty_k_tot),
  `Receita (€)` = c(rec_k_pv_tot, rec_k_atm_tot, rec_k_tot),
  `% Vendas K` = c(
    if_else(rec_k_tot > 0, rec_k_pv_tot / rec_k_tot, 0),
    if_else(rec_k_tot > 0, rec_k_atm_tot / rec_k_tot, 0),
    1.0
  )
)

# Tabela detalhada por título (todos os títulos)
detalhe_ak <- rtd_raw |>
  select(
    ticket_code, titulo_nome, pvp,
    qty_A_total, receita_A_total,
    qty_K, receita_K,
    qty_total, receita_distribuir
  ) |>
  arrange(ticket_code)

detalhe_totais <- tibble(
  ticket_code        = NA_integer_,
  titulo_nome        = "TOTAL",
  pvp                = NA_real_,
  qty_A_total        = sum(detalhe_ak$qty_A_total, na.rm = TRUE),
  receita_A_total    = sum(detalhe_ak$receita_A_total, na.rm = TRUE),
  qty_K              = sum(detalhe_ak$qty_K, na.rm = TRUE),
  receita_K          = sum(detalhe_ak$receita_K, na.rm = TRUE),
  qty_total          = sum(detalhe_ak$qty_total, na.rm = TRUE),
  receita_distribuir = sum(detalhe_ak$receita_distribuir, na.rm = TRUE)
)

detalhe_ak_full <- bind_rows(detalhe_ak, detalhe_totais)

# --- Escrever Folha 2 ---
mergeCells(wb, ws_ak, rows = 1, cols = 1:9)
writeData(wb, ws_ak, x = paste0("     Tabela 2 - Vendas Navegante: Operadores (A) e Canais Partilhados TML (K) — ", mes_nome, " ", ANO),
          startRow = 1, startCol = 1)
addStyle(wb, ws_ak, st_title, rows = 1, cols = 1:9, gridExpand = TRUE)
setRowHeights(wb, ws_ak, rows = 1, heights = 26)

# Secção 2.1: Resumos lado a lado
# Título Bloco A (cols 1-4)
mergeCells(wb, ws_ak, rows = 3, cols = 1:4)
writeData(wb, ws_ak, x = "Resumo: Vendas A por Operador (Bilheteira Própria)", startRow = 3, startCol = 1)
addStyle(wb, ws_ak, st_sub_header, rows = 3, cols = 1:4, gridExpand = TRUE)

writeData(wb, ws_ak, x = as.data.frame(t(names(vendas_a_tab))), startRow = 4, startCol = 1, colNames = FALSE)
addStyle(wb, ws_ak, st_header_gold, rows = 4, cols = 1:4, gridExpand = TRUE)
writeData(wb, ws_ak, x = vendas_a_tab, startRow = 5, startCol = 1, colNames = FALSE)

n_va <- nrow(vendas_a_tab)
for (i in seq_len(n_va)) {
  rw <- i + 4
  is_tot <- (i == n_va)
  fg <- if (is_tot) cor_gold_light else if (i %% 2 == 0) cor_alt_row else cor_white
  txt_dec <- if (is_tot) "bold" else NULL
  addStyle(wb, ws_ak, createStyle(fgFill = fg, textDecoration = txt_dec, halign = "left",
                                  border = "TopBottomLeftRight", borderColour = cor_border_soft, fontSize = 9),
           rows = rw, cols = 1)
  addStyle(wb, ws_ak, createStyle(fgFill = fg, textDecoration = txt_dec, numFmt = "#,##0", halign = "right",
                                  border = "TopBottomLeftRight", borderColour = cor_border_soft, fontSize = 9),
           rows = rw, cols = 2)
  addStyle(wb, ws_ak, createStyle(fgFill = fg, textDecoration = txt_dec, numFmt = "#,##0.00", halign = "right",
                                  border = "TopBottomLeftRight", borderColour = cor_border_soft, fontSize = 9),
           rows = rw, cols = 3)
  addStyle(wb, ws_ak, createStyle(fgFill = fg, textDecoration = txt_dec, numFmt = "0.00%", halign = "right",
                                  border = "TopBottomLeftRight", borderColour = cor_border_soft, fontSize = 9),
           rows = rw, cols = 4)
}

# Título Bloco K (cols 6-9)
mergeCells(wb, ws_ak, rows = 3, cols = 6:9)
writeData(wb, ws_ak, x = "Resumo: Vendas K por Canal Partilhado (TML)", startRow = 3, startCol = 6)
addStyle(wb, ws_ak, st_sub_header, rows = 3, cols = 6:9, gridExpand = TRUE)

writeData(wb, ws_ak, x = as.data.frame(t(names(vendas_k_tab))), startRow = 4, startCol = 6, colNames = FALSE)
addStyle(wb, ws_ak, st_header_gold, rows = 4, cols = 6:9, gridExpand = TRUE)
writeData(wb, ws_ak, x = vendas_k_tab, startRow = 5, startCol = 6, colNames = FALSE)

n_vk <- nrow(vendas_k_tab)
for (i in seq_len(n_vk)) {
  rw <- i + 4
  is_tot <- (i == n_vk)
  fg <- if (is_tot) cor_gold_light else if (i %% 2 == 0) cor_alt_row else cor_white
  txt_dec <- if (is_tot) "bold" else NULL
  addStyle(wb, ws_ak, createStyle(fgFill = fg, textDecoration = txt_dec, halign = "left",
                                  border = "TopBottomLeftRight", borderColour = cor_border_soft, fontSize = 9),
           rows = rw, cols = 6)
  addStyle(wb, ws_ak, createStyle(fgFill = fg, textDecoration = txt_dec, numFmt = "#,##0", halign = "right",
                                  border = "TopBottomLeftRight", borderColour = cor_border_soft, fontSize = 9),
           rows = rw, cols = 7)
  addStyle(wb, ws_ak, createStyle(fgFill = fg, textDecoration = txt_dec, numFmt = "#,##0.00", halign = "right",
                                  border = "TopBottomLeftRight", borderColour = cor_border_soft, fontSize = 9),
           rows = rw, cols = 8)
  addStyle(wb, ws_ak, createStyle(fgFill = fg, textDecoration = txt_dec, numFmt = "0.00%", halign = "right",
                                  border = "TopBottomLeftRight", borderColour = cor_border_soft, fontSize = 9),
           rows = rw, cols = 9)
}

# Caixa Total Consolidado (linhas 9-11, cols 6-9)
rw_cons <- 9
mergeCells(wb, ws_ak, rows = rw_cons, cols = 6:9)
writeData(wb, ws_ak, x = "TOTAL CONSOLIDADO (Vendas A + Vendas K)", startRow = rw_cons, startCol = 6)
addStyle(wb, ws_ak, st_sub_header, rows = rw_cons, cols = 6:9, gridExpand = TRUE)

writeData(wb, ws_ak, x = as.data.frame(t(c("Métrica", "Quantidade Total", "Receita Total (€)", "% do Total"))),
          startRow = rw_cons + 1, startCol = 6, colNames = FALSE)
addStyle(wb, ws_ak, st_header_gold, rows = rw_cons + 1, cols = 6:9, gridExpand = TRUE)

writeData(wb, ws_ak, x = as.data.frame(t(c("Vendas A + K", total_qty_a + qty_k_tot, total_rec_a + rec_k_tot, 1.0))),
          startRow = rw_cons + 2, startCol = 6, colNames = FALSE)
addStyle(wb, ws_ak, st_total_lbl, rows = rw_cons + 2, cols = 6)
addStyle(wb, ws_ak, st_total_int, rows = rw_cons + 2, cols = 7)
addStyle(wb, ws_ak, st_total_num, rows = rw_cons + 2, cols = 8)
addStyle(wb, ws_ak, st_total_pct, rows = rw_cons + 2, cols = 9)

# Secção 2.2: Tabela Detalhada por Título (linha 19)
row_det <- 18
mergeCells(wb, ws_ak, rows = row_det, cols = 1:9)
writeData(wb, ws_ak, x = "Detalhe por Título: Quantidades e Valores de Vendas A e K", startRow = row_det, startCol = 1)
addStyle(wb, ws_ak, st_sub_header, rows = row_det, cols = 1:9, gridExpand = TRUE)
setRowHeights(wb, ws_ak, rows = row_det, heights = 22)

names_det <- c("Código", "Designação do Título", "PVP (€)",
               "Qtd Vendas A", "Receita Vendas A (€)",
               "Qtd Vendas K", "Receita Vendas K (€)",
               "Qtd Total Vendida", "Receita Total a Distribuir (€)")
writeData(wb, ws_ak, x = as.data.frame(t(names_det)), startRow = row_det + 1, startCol = 1, colNames = FALSE)
addStyle(wb, ws_ak, st_header_gold, rows = row_det + 1, cols = 1:9, gridExpand = TRUE)
setRowHeights(wb, ws_ak, rows = row_det + 1, heights = 32)

writeData(wb, ws_ak, x = detalhe_ak_full, startRow = row_det + 2, startCol = 1, colNames = FALSE)

n_det <- nrow(detalhe_ak_full)
for (i in seq_len(n_det)) {
  rw <- row_det + 1 + i
  is_tot <- (i == n_det)
  fg <- if (is_tot) cor_gold_light else if (i %% 2 == 0) cor_alt_row else cor_white
  txt_dec <- if (is_tot) "bold" else NULL

  if (is_tot) {
    addStyle(wb, ws_ak, st_total_lbl, rows = rw, cols = 1:2, gridExpand = TRUE)
    addStyle(wb, ws_ak, st_total_lbl, rows = rw, cols = 3)
    addStyle(wb, ws_ak, st_total_int, rows = rw, cols = c(4, 6, 8), gridExpand = TRUE)
    addStyle(wb, ws_ak, st_total_num, rows = rw, cols = c(5, 7, 9), gridExpand = TRUE)
  } else {
    addStyle(wb, ws_ak, createStyle(fgFill = fg, halign = "center", border = "LeftRight",
                                   borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = 1)
    addStyle(wb, ws_ak, createStyle(fgFill = fg, halign = "left", border = "LeftRight",
                                   borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = 2)
    addStyle(wb, ws_ak, createStyle(fgFill = fg, numFmt = "#,##0.00", halign = "right",
                                   border = "LeftRight", borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = 3)
    addStyle(wb, ws_ak, createStyle(fgFill = fg, numFmt = "#,##0", halign = "right",
                                   border = "LeftRight", borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = c(4, 6, 8), gridExpand = TRUE)
    addStyle(wb, ws_ak, createStyle(fgFill = fg, numFmt = "#,##0.00", halign = "right",
                                   border = "LeftRight", borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = c(5, 7, 9), gridExpand = TRUE)
  }
}

setColWidths(wb, ws_ak, cols = 1, widths = 8)
setColWidths(wb, ws_ak, cols = 2, widths = 32)
setColWidths(wb, ws_ak, cols = 3, widths = 10)
setColWidths(wb, ws_ak, cols = c(4, 6, 8), widths = 14)
setColWidths(wb, ws_ak, cols = c(5, 7, 9), widths = 18)


# =============================================================================
# FOLHA 4: "4 - Receita B e CongNav B" (Receita devida e congelamento por operador)
# =============================================================================
addWorksheet(wb, "4 - Receita B e CongNav B")
ws_b <- "4 - Receita B e CongNav B"

# Dados por operador (11 operadores separados)
df_b_op <- tibble(operador_cod = names(nome_op_sep), operador = unname(nome_op_sep)) |>
  left_join(cong_raw |> select(operador, receita_B, congelamento_B), by = c("operador_cod" = "operador")) |>
  mutate(
    receita_B      = replace_na(receita_B, 0),
    congelamento_B = replace_na(congelamento_B, 0),
    total_b_cong   = receita_B + congelamento_B
  ) |>
  mutate(operador = factor(operador, levels = ordem_ops_sep)) |>
  arrange(operador) |>
  mutate(operador = as.character(operador))

tot_rec_b  <- sum(df_b_op$receita_B)
tot_cong_b <- sum(df_b_op$congelamento_B)
tot_b_all  <- sum(df_b_op$total_b_cong)

df_b_op <- df_b_op |>
  mutate(
    pct_b     = if (tot_rec_b > 0) receita_B / tot_rec_b else 0,
    pct_cong  = if (tot_cong_b > 0) congelamento_B / tot_cong_b else 0,
    pct_total = if (tot_b_all > 0) total_b_cong / tot_b_all else 0,
    nome_completo = nomes_completos[operador_cod]
  )

tab_b_full <- bind_rows(
  df_b_op |> select(
    Código = operador_cod,
    Operador = operador,
    `Nome Completo` = nome_completo,
    `Receita Devida [B] (€)` = receita_B,
    `% Receita B` = pct_b,
    `Congelamento [CongNav B] (€)` = congelamento_B,
    `% Congelamento` = pct_cong,
    `Total Devido [B + CongNav B] (€)` = total_b_cong,
    `% Total Devido` = pct_total
  ),
  tibble(
    Código = "",
    Operador = "TOTAL",
    `Nome Completo` = "",
    `Receita Devida [B] (€)` = tot_rec_b,
    `% Receita B` = 1.0,
    `Congelamento [CongNav B] (€)` = tot_cong_b,
    `% Congelamento` = 1.0,
    `Total Devido [B + CongNav B] (€)` = tot_b_all,
    `% Total Devido` = 1.0
  )
)

# Título
mergeCells(wb, ws_b, rows = 1, cols = 1:9)
writeData(wb, ws_b, x = paste0("     Tabela 4 - Receita Bilheteira Devida [B] e Congelamento Navegante [CongNav B] — ", mes_nome, " ", ANO),
          startRow = 1, startCol = 1)
addStyle(wb, ws_b, st_title, rows = 1, cols = 1:9, gridExpand = TRUE)
setRowHeights(wb, ws_b, rows = 1, heights = 26)

# Cabeçalhos
writeData(wb, ws_b, x = as.data.frame(t(names(tab_b_full))), startRow = 2, startCol = 1, colNames = FALSE)
addStyle(wb, ws_b, st_header_gold, rows = 2, cols = 1:9, gridExpand = TRUE)
setRowHeights(wb, ws_b, rows = 2, heights = 35)

writeData(wb, ws_b, x = tab_b_full, startRow = 3, startCol = 1, colNames = FALSE)

n_b_rows <- nrow(tab_b_full)
for (i in seq_len(n_b_rows)) {
  rw <- i + 2
  is_tot <- (i == n_b_rows)
  fg <- if (is_tot) cor_gold_light else if (i %% 2 == 0) cor_alt_row else cor_white
  txt_dec <- if (is_tot) "bold" else NULL

  if (is_tot) {
    addStyle(wb, ws_b, st_total_lbl, rows = rw, cols = 1:3, gridExpand = TRUE)
    addStyle(wb, ws_b, st_total_num, rows = rw, cols = c(4, 6, 8), gridExpand = TRUE)
    addStyle(wb, ws_b, st_total_pct, rows = rw, cols = c(5, 7, 9), gridExpand = TRUE)
  } else {
    addStyle(wb, ws_b, createStyle(fgFill = fg, halign = "center", border = "LeftRight",
                                   borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = 1)
    addStyle(wb, ws_b, createStyle(fgFill = fg, textDecoration = "bold", halign = "left",
                                   border = "LeftRight", borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = 2)
    addStyle(wb, ws_b, createStyle(fgFill = fg, halign = "left", border = "LeftRight",
                                   borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = 3)
    addStyle(wb, ws_b, createStyle(fgFill = fg, numFmt = "#,##0.00", halign = "right",
                                   border = "LeftRight", borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = c(4, 6, 8), gridExpand = TRUE)
    addStyle(wb, ws_b, createStyle(fgFill = fg, numFmt = "0.0000%", halign = "right",
                                   border = "LeftRight", borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = c(5, 7, 9), gridExpand = TRUE)
  }
}

setColWidths(wb, ws_b, cols = 1, widths = 8)
setColWidths(wb, ws_b, cols = 2, widths = 14)
setColWidths(wb, ws_b, cols = 3, widths = 32)
setColWidths(wb, ws_b, cols = c(4, 6, 8), widths = 20)
setColWidths(wb, ws_b, cols = c(5, 7, 9), widths = 14)


# =============================================================================
# FOLHA 5: "5 - Pag Conta COSP D" (Parâmetros regulamentares e COSP por operador)
# =============================================================================
addWorksheet(wb, "5 - Pag Conta COSP D")
ws_cosp <- "5 - Pag Conta COSP D"

# Parâmetros de cálculo COSP
saz_df <- read.csv2(file.path(LISTS_DIR, "sazonalidade.csv"), stringsAsFactors = FALSE, dec = ".")
tat_df <- read.csv2(TAT_FILE, stringsAsFactors = FALSE, dec = ".")
tat_df$tat <- as.numeric(tat_df$tat)

tat_ate_ano   <- tat_df[tat_df$ano <= ANO, ]
fator_tat_vmc <- prod(1 + tat_ate_ano$tat)
VMC_ano       <- round(VMC_2023 * fator_tat_vmc, 2)
valor_medio_passe <- VMC_ano / N_PASSES_COMPENSAR

saz_mes <- saz_df[saz_df$mes == MES, "sazonalidade"]
if (length(saz_mes) == 0 || is.na(saz_mes)) saz_mes <- 0.086

qty_total_mes <- sum(rtd_raw$qty_total, na.rm = TRUE)
estimativa_passes_anuais <- qty_total_mes / saz_mes
pct_compensar <- min(1, N_PASSES_COMPENSAR / estimativa_passes_anuais)

# Passes a compensar e COSP total do mês
passes_comp_mes <- round(pct_compensar * qty_total_mes, 0)
cosp_total_mes  <- sum(cosp_raw$cosp_D, na.rm = TRUE)
retencao_val_mes <- (cosp_total_mes / (1 - RETENCAO_TML)) * RETENCAO_TML

# Tabela de Parâmetros
params_df <- tibble(
  Parâmetro = c(
    "Ano de Referência",
    "Mês de Referência",
    "Valor Máximo de Compensação 2023 (VMC 2023)",
    "Fator Cumulativo TAT [prod(1+TAT)]",
    paste0("VMC Atualizado ", ANO),
    "Número Máximo Anual de Passes a Compensar (N_PASSES)",
    "Preço Médio Regulamentar por Passe",
    "Taxa de Retenção TML",
    "Fator de Sazonalidade do Mês",
    "Total de Passes Vendidos no Mês (SISTEMA_QUANTITY)",
    "Estimativa de Passes Anuais (Qty Mês / Sazonalidade)",
    "Percentagem de Passes a Compensar [min(1, N / Est)]",
    "Total de Passes a Compensar no Mês",
    "Montante COSP Líquido Total a Distribuir [D]",
    "Montante de Retenção TML (2,5%)"
  ),
  Valor = c(
    as.character(ANO),
    paste0(mes_nome, " (mês ", sprintf("%02d", MES), ")"),
    scales::number(VMC_2023, accuracy = 0.01, big.mark = ".", decimal.mark = ",", suffix = " €"),
    scales::number(fator_tat_vmc, accuracy = 0.000001, decimal.mark = ","),
    scales::number(VMC_ano, accuracy = 0.01, big.mark = ".", decimal.mark = ",", suffix = " €"),
    scales::number(N_PASSES_COMPENSAR, accuracy = 1, big.mark = ".", decimal.mark = ","),
    scales::number(valor_medio_passe, accuracy = 0.000001, decimal.mark = ",", suffix = " €"),
    scales::percent(RETENCAO_TML, accuracy = 0.01, decimal.mark = ","),
    scales::number(saz_mes, accuracy = 0.001, decimal.mark = ","),
    scales::number(round(qty_total_mes), accuracy = 1, big.mark = ".", decimal.mark = ","),
    scales::number(round(estimativa_passes_anuais), accuracy = 1, big.mark = ".", decimal.mark = ","),
    scales::percent(pct_compensar, accuracy = 0.0001, decimal.mark = ","),
    scales::number(round(passes_comp_mes), accuracy = 1, big.mark = ".", decimal.mark = ","),
    scales::number(cosp_total_mes, accuracy = 0.01, big.mark = ".", decimal.mark = ",", suffix = " €"),
    scales::number(retencao_val_mes, accuracy = 0.01, big.mark = ".", decimal.mark = ",", suffix = " €")
  )
)

# Tabela de COSP por operador (11 operadores separados)
df_cosp_op <- tibble(operador_cod = names(nome_op_sep), operador = unname(nome_op_sep)) |>
  left_join(cosp_raw |> select(operador, cosp_D), by = c("operador_cod" = "operador")) |>
  mutate(cosp_D = replace_na(cosp_D, 0)) |>
  mutate(operador = factor(operador, levels = ordem_ops_sep)) |>
  arrange(operador) |>
  mutate(operador = as.character(operador))

tot_cosp <- sum(df_cosp_op$cosp_D)

df_cosp_op <- df_cosp_op |>
  mutate(
    pct_cosp = if (tot_cosp > 0) cosp_D / tot_cosp else 0,
    nome_completo = nomes_completos[operador_cod]
  )

tab_cosp_full <- bind_rows(
  df_cosp_op |> select(
    Código = operador_cod,
    Operador = operador,
    `Nome Completo` = nome_completo,
    `Pagamento COSP Devido [D] (€)` = cosp_D,
    `% do COSP Total` = pct_cosp
  ),
  tibble(
    Código = "",
    Operador = "TOTAL",
    `Nome Completo` = "",
    `Pagamento COSP Devido [D] (€)` = tot_cosp,
    `% do COSP Total` = 1.0
  )
)

# --- Escrever Folha 5 ---
mergeCells(wb, ws_cosp, rows = 1, cols = 1:5)
writeData(wb, ws_cosp, x = paste0("     Tabela 5 - Pagamentos por Conta COSP (D) e Parâmetros Regulamentares — ", mes_nome, " ", ANO),
          startRow = 1, startCol = 1)
addStyle(wb, ws_cosp, st_title, rows = 1, cols = 1:5, gridExpand = TRUE)
setRowHeights(wb, ws_cosp, rows = 1, heights = 26)

# Painel de Parâmetros
mergeCells(wb, ws_cosp, rows = 3, cols = 1:3)
writeData(wb, ws_cosp, x = "Parâmetros Regulamentares e de Cálculo COSP (Regulamento 1362-C/2023)", startRow = 3, startCol = 1)
addStyle(wb, ws_cosp, st_sub_header, rows = 3, cols = 1:3, gridExpand = TRUE)

writeData(wb, ws_cosp, x = as.data.frame(t(c("Parâmetro", "Valor Regulamentado / Calculado"))),
          startRow = 4, startCol = 1, colNames = FALSE)
addStyle(wb, ws_cosp, st_header_gold, rows = 4, cols = 1:3, gridExpand = TRUE)

# Escrever linhas de parâmetros
for (p in seq_len(nrow(params_df))) {
  rw <- p + 4
  mergeCells(wb, ws_cosp, rows = rw, cols = 1:2)
  writeData(wb, ws_cosp, x = params_df$Parâmetro[p], startRow = rw, startCol = 1)
  writeData(wb, ws_cosp, x = params_df$Valor[p],     startRow = rw, startCol = 3)
  addStyle(wb, ws_cosp, st_param_lbl, rows = rw, cols = 1:2, gridExpand = TRUE)
  addStyle(wb, ws_cosp, st_param_val, rows = rw, cols = 3)
}

# Tabela por Operador (linha 22)
rw_tab_cosp <- nrow(params_df) + 6
mergeCells(wb, ws_cosp, rows = rw_tab_cosp, cols = 1:5)
writeData(wb, ws_cosp, x = "Repartição dos Pagamentos por Conta COSP [D] por Operador", startRow = rw_tab_cosp, startCol = 1)
addStyle(wb, ws_cosp, st_sub_header, rows = rw_tab_cosp, cols = 1:5, gridExpand = TRUE)

writeData(wb, ws_cosp, x = as.data.frame(t(names(tab_cosp_full))), startRow = rw_tab_cosp + 1, startCol = 1, colNames = FALSE)
addStyle(wb, ws_cosp, st_header_gold, rows = rw_tab_cosp + 1, cols = 1:5, gridExpand = TRUE)
setRowHeights(wb, ws_cosp, rows = rw_tab_cosp + 1, heights = 32)

writeData(wb, ws_cosp, x = tab_cosp_full, startRow = rw_tab_cosp + 2, startCol = 1, colNames = FALSE)

n_cop <- nrow(tab_cosp_full)
for (i in seq_len(n_cop)) {
  rw <- rw_tab_cosp + 1 + i
  is_tot <- (i == n_cop)
  fg <- if (is_tot) cor_gold_light else if (i %% 2 == 0) cor_alt_row else cor_white
  txt_dec <- if (is_tot) "bold" else NULL

  if (is_tot) {
    addStyle(wb, ws_cosp, st_total_lbl, rows = rw, cols = 1:3, gridExpand = TRUE)
    addStyle(wb, ws_cosp, st_total_num, rows = rw, cols = 4)
    addStyle(wb, ws_cosp, st_total_pct, rows = rw, cols = 5)
  } else {
    addStyle(wb, ws_cosp, createStyle(fgFill = fg, halign = "center", border = "LeftRight",
                                      borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = 1)
    addStyle(wb, ws_cosp, createStyle(fgFill = fg, textDecoration = "bold", halign = "left",
                                      border = "LeftRight", borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = 2)
    addStyle(wb, ws_cosp, createStyle(fgFill = fg, halign = "left", border = "LeftRight",
                                      borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = 3)
    addStyle(wb, ws_cosp, createStyle(fgFill = fg, numFmt = "#,##0.00", halign = "right",
                                      border = "LeftRight", borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = 4)
    addStyle(wb, ws_cosp, createStyle(fgFill = fg, numFmt = "0.0000%", halign = "right",
                                      border = "LeftRight", borderColour = cor_border_soft, fontSize = 9),
             rows = rw, cols = 5)
  }
}

setColWidths(wb, ws_cosp, cols = 1, widths = 8)
setColWidths(wb, ws_cosp, cols = 2, widths = 14)
setColWidths(wb, ws_cosp, cols = 3, widths = 32)
setColWidths(wb, ws_cosp, cols = 4, widths = 22)
setColWidths(wb, ws_cosp, cols = 5, widths = 15)


# =============================================================================
# FOLHA 6: "6 - Transferencias F" (Formato longo com TT+SL fundidos)
# =============================================================================
addWorksheet(wb, "6 - Transferencias F")
ws_f <- "6 - Transferencias F"

# Construir linhas em formato longo
# Função auxiliar para extrair linha de operador
make_wide_f <- function(metrica, val_fn) {
  row_vals <- sapply(ordem_ops_merged, function(op) {
    r <- tabela_global |> filter(nome_tab == op)
    if (nrow(r) == 0) NA_real_ else val_fn(r)
  })
  tot_r <- tabela_global |> filter(nome_tab == "TOTAL")
  tot_val <- if (nrow(tot_r) == 0) NA_real_ else val_fn(tot_r)
  c(ANO, MES, metrica, row_vals, tot_val)
}

folha6_rows <- list(
  make_wide_f("Receita na posse do operador [A]",             function(r) r$receita_A),
  make_wide_f("Receita bilheteira devida ao operador [B]",     function(r) r$B),
  make_wide_f("Pagamento por conta COSP devida ao operador [D]", function(r) r$D),
  make_wide_f("Transferência [F = B + D - A]",                function(r) r$F_transferencia),
  make_wide_f("Congelamento Navegante [CongNavB]",            function(r) r$congelamento),
  make_wide_f("Total a transferir [F + CongNavB]",            function(r) r$total_transferir),
  make_wide_f("Transferência entre operadores",               function(r) r$transf_entre_ops),
  make_wide_f("Total a transferir corrigido",                 function(r) r$total_tml)
)

folha6_df <- as.data.frame(do.call(rbind, folha6_rows), stringsAsFactors = FALSE)
colnames(folha6_df) <- c("Ano", "Mês", "Métrica", ordem_ops_merged, "TOTAL")

num_cols_f6 <- c(ordem_ops_merged, "TOTAL")
folha6_df[num_cols_f6] <- lapply(folha6_df[num_cols_f6], as.numeric)

n_cols_f6 <- ncol(folha6_df)

# Título
mergeCells(wb, ws_f, rows = 1, cols = 1:n_cols_f6)
writeData(wb, ws_f, x = paste0("     Tabela 6 - Transferências Mensais TML por Métrica e Operador — ", mes_nome, " ", ANO),
          startRow = 1, startCol = 1)
addStyle(wb, ws_f, st_title, rows = 1, cols = 1:n_cols_f6, gridExpand = TRUE)
setRowHeights(wb, ws_f, rows = 1, heights = 26)

# Cabeçalhos
writeData(wb, ws_f, x = as.data.frame(t(colnames(folha6_df))), startRow = 2, startCol = 1, colNames = FALSE)
addStyle(wb, ws_f, st_header_gold, rows = 2, cols = 1:n_cols_f6, gridExpand = TRUE)
setRowHeights(wb, ws_f, rows = 2, heights = 35)

# Dados
writeData(wb, ws_f, x = folha6_df, startRow = 3, startCol = 1, colNames = FALSE)

n_rows_f6 <- nrow(folha6_df)
for (i in seq_len(n_rows_f6)) {
  rw <- i + 2
  fg <- if (i %% 2 == 0) cor_alt_row else cor_white
  txt_dec <- if (i %in% c(6, 8)) "bold" else NULL

  addStyle(wb, ws_f, createStyle(fgFill = fg, halign = "center", border = "LeftRight",
                                 borderColour = cor_border_soft, fontSize = 9),
           rows = rw, cols = 1:2)
  addStyle(wb, ws_f, createStyle(fgFill = fg, halign = "left", textDecoration = txt_dec,
                                 border = "LeftRight", borderColour = cor_border_soft, fontSize = 9),
           rows = rw, cols = 3)
  addStyle(wb, ws_f, createStyle(fgFill = fg, textDecoration = txt_dec, numFmt = "#,##0.00", halign = "right",
                                 border = "LeftRight", borderColour = cor_border_soft, fontSize = 9),
           rows = rw, cols = 4:n_cols_f6, gridExpand = TRUE)
}

setColWidths(wb, ws_f, cols = 1, widths = 6)
setColWidths(wb, ws_f, cols = 2, widths = 6)
setColWidths(wb, ws_f, cols = 3, widths = 36)
setColWidths(wb, ws_f, cols = 4:n_cols_f6, widths = 14)
freezePane(wb, ws_f, firstActiveRow = 3, firstActiveCol = 4)


# ---- 7. Guardar Workbook -----------------------------------------------------
saveWorkbook(wb, F_TABELA_XLSX, overwrite = TRUE)
message("=================================================================")
message("Workbook consolidado exportado com sucesso:")
message("  Ficheiro: ", F_TABELA_XLSX)
message("  Folhas:   ", paste(names(wb), collapse = ", "))
message("=================================================================")
