# =============================================================================
# 08_tables.R — Exporta tabela de transferências em formato Excel (xlsx)
# Distribuição de Receitas Navegante — TML
#
# Lê:  OUT_DIR/6_transferencias_mesano.csv
# Cria: OUT_DIR/tabela_transferencias_mesano.xlsx
#   Folha 1 ("Tabela 6 - Transf (F)"): formato longo (por linha de métrica)
#   Folha 2 ("Folha2"):                 tabela cruzada tipo exemplo docs/table_example.xlsx
# =============================================================================

source(here::here("code", "config.R"))
suppressPackageStartupMessages({
  library(dplyr)
  library(openxlsx)
})

# ---- 1. Ler dados ------------------------------------------------------------
transf <- read.csv2(F_TRANSFERENCIAS, stringsAsFactors = FALSE, dec = ",")

# Garantir tipos numéricos
num_cols <- c("receita_B", "congelamento_B", "receita_A", "cosp_D",
              "F_transferencia", "total_transferir",
              "pagamento_imediato", "pagamento_incentiva")
transf[num_cols] <- lapply(transf[num_cols], as.numeric)

# ---- 2. Mapear operadores para nomes curtos da tabela exemplo ----------------
# Mapeamento: código → nome de exibição na tabela
#   TT e SL são fundidos numa linha "TT + SL"
#   MS → MTS, CA → Carris, TB → TCB, CAP → AT Cascais,
#   CM → AT TML - CM, BQ → BT Oeste, FT → FT, CP → CP, ML → ML
nome_tabela <- c(
  CP  = "CP",
  FT  = "FT",
  TT  = "TT + SL",   # TT e SL agregados
  SL  = "TT + SL",
  ML  = "ML",
  MS  = "MTS",
  CA  = "Carris",
  TB  = "TCB",
  CAP = "AT Cascais",
  CM  = "AT TML - CM",
  BQ  = "BT Oeste"
)

transf <- transf |>
  mutate(nome_tab = nome_tabela[operador])

# Agregar TT + SL (somar os numéricos; nota: ignorar, será NA)
transf_tab <- transf |>
  filter(!is.na(nome_tab)) |>
  group_by(nome_tab) |>
  summarise(
    receita_A        = sum(receita_A,        na.rm = TRUE),
    receita_B        = sum(receita_B,        na.rm = TRUE),
    congelamento_B   = sum(congelamento_B,   na.rm = TRUE),
    receita_A_grp    = sum(receita_A,        na.rm = TRUE),
    cosp_D           = sum(cosp_D,           na.rm = TRUE),
    F_transferencia  = sum(F_transferencia,  na.rm = TRUE),
    total_transferir = sum(total_transferir, na.rm = TRUE),
    pagamento_imediato  = sum(pagamento_imediato,  na.rm = TRUE),
    pagamento_incentiva = sum(pagamento_incentiva, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    # saldo_C = A - B  (saldo de receitas: positivo → tem excedente)
    saldo_C  = receita_A - receita_B,
    # SG = saldo_C - D  (saldo global: negativo → operador é credor)
    SG = saldo_C - cosp_D,
    # F = -SG = B + D - A  (confirmação)
    # F_transferencia já calculado; SG = -F_transferencia
    # % do total
    total_todos = sum(total_transferir[total_transferir > 0], na.rm = TRUE),
    pct = if_else(total_todos > 0, total_transferir / total_todos, 0)
  )

# Ordem dos operadores (igual ao exemplo)
ordem_ops <- c("CP", "FT", "TT + SL", "ML", "MTS",
                "Carris", "TCB", "AT Cascais", "AT TML - CM", "BT Oeste")

transf_tab <- transf_tab |>
  mutate(nome_tab = factor(nome_tab, levels = ordem_ops)) |>
  arrange(nome_tab) |>
  mutate(nome_tab = as.character(nome_tab))

# Linha TOTAL
total_row <- transf_tab |>
  summarise(
    nome_tab         = "TOTAL",
    receita_A        = sum(receita_A),
    receita_B        = sum(receita_B),
    congelamento_B   = sum(congelamento_B),
    cosp_D           = sum(cosp_D),
    F_transferencia  = sum(F_transferencia),
    total_transferir = sum(total_transferir),
    pagamento_imediato  = sum(pagamento_imediato),
    pagamento_incentiva = sum(pagamento_incentiva),
    saldo_C          = sum(saldo_C),
    SG               = sum(SG),
    total_todos      = NA_real_,
    pct              = sum(pct)
  )

transf_tab_full <- bind_rows(transf_tab, total_row)

# ---- 3. Montar data.frame para Folha 2 (14 colunas como no exemplo) ---------
# Colunas (igual ao exemplo):
#  1. Operador
#  2. Receita na posse [A]
#  3. Receita devida [B]
#  4. Saldo de Receitas [C = A - B]
#  5. Pagamentos por conta COSP Tarifária [D]
#  6. Saldo Global de Receitas [SG]
#  7. Transferências [F = -SG]
#  8. Compensação congelamento passes Navegante [CongNav[B]]
#  9. [F + CongNav[B]]
# 10. Transferência entre operadores (€)
# 11. TOTAL a transferir pela TML (€)
# 12. % do montante total a transferir a cada Operador
# 13. Parcela proveniente das verbas dos canais de receita partilhada
# 14. Parcela proveniente das verbas do Incentiva +TP

# Transferência entre operadores: MTS tem excedente → vai para FT (TST group)
mts_row <- transf_tab_full |> filter(nome_tab == "MTS")
excedente_mts <- if (nrow(mts_row) > 0 && mts_row$total_transferir < 0)
  abs(mts_row$total_transferir) else 0

folha2 <- transf_tab_full |>
  mutate(
    transf_entre_ops = case_when(
      nome_tab == "FT"    ~ excedente_mts,   # FT recebe o excedente do MTS
      nome_tab == "MTS"   ~ -excedente_mts,  # MTS devolve
      nome_tab == "TOTAL" ~ 0,               # Saldo de transferências entre ops anula-se
      TRUE                ~ NA_real_
    ),
    # TOTAL a transferir corrigido: total_transferir - transf_entre_ops (se existir)
    total_tml = case_when(
      nome_tab == "MTS"    ~ 0,      # excedente = 0 a transferir pela TML
      nome_tab == "TOTAL"  ~ NA_real_,
      total_transferir < 0 ~ 0,      # excedentes negativos → 0
      TRUE ~ total_transferir - replace(transf_entre_ops, is.na(transf_entre_ops), 0)
    )
  )

# Preencher total_tml na linha TOTAL com a soma exata dos operadores
soma_total_tml <- sum(folha2$total_tml[folha2$nome_tab != "TOTAL"], na.rm = TRUE)
folha2$total_tml[folha2$nome_tab == "TOTAL"] <- soma_total_tml

# Ler total de receita K (canais de receita partilhada: Portal VIVA + SIBS/ATM)
total_K <- if (file.exists(F_VENDAS_K)) {
  v_k <- read.csv2(F_VENDAS_K, stringsAsFactors = FALSE)
  sum(as.numeric(v_k$receita_K), na.rm = TRUE)
} else if (file.exists(F_RTD)) {
  rtd <- read.csv2(F_RTD, stringsAsFactors = FALSE)
  sum(as.numeric(rtd$receita_K), na.rm = TRUE)
} else {
  0
}

folha2 <- folha2 |>
  # % recalculada sobre total_tml
  mutate(
    pct2 = case_when(
      nome_tab == "TOTAL" ~ 1.0,
      soma_total_tml > 0  ~ total_tml / soma_total_tml,
      TRUE                ~ 0
    ),
    # Parcela canais partilhados: percentagem × soma total de K
    parcela_partilhada = case_when(
      nome_tab == "TOTAL" ~ total_K,
      total_tml <= 0      ~ 0,
      TRUE                ~ round(pct2 * total_K, 3)
    ),
    # Parcela Incentiva +TP: restante do valor a transferir pela TML
    parcela_incentiva  = case_when(
      nome_tab == "TOTAL" ~ round(total_tml - total_K, 3),
      total_tml <= 0      ~ 0,
      TRUE                ~ round(total_tml - parcela_partilhada, 3)
    )
  )

# Seleccionar e renomear colunas finais
folha2_out <- folha2 |>
  select(
    `Operador`                                                         = nome_tab,
    `Receita na posse [A]`                                             = receita_A,
    `Receita devida [B]`                                               = receita_B,
    `Saldo de Receitas [C = A - B]`                                    = saldo_C,
    `Pagamentos por conta COSP Tarifária [D]`                          = cosp_D,
    `Saldo Global de Receitas [SG]`                                    = SG,
    `Transferências [F = -SG]`                                         = F_transferencia,
    `Compensação congelamento passes Navegante [CongNav[B]]`           = congelamento_B,
    `[F + CongNav[B]]`                                                 = total_transferir,
    `Transferência entre operadores (€)`                               = transf_entre_ops,
    `TOTAL a transferir pela TML (€)`                                  = total_tml,
    `% do montante total a transferir a cada Operador`                 = pct2,
    `Parcela proveniente das verbas dos canais de receita partilhada`  = parcela_partilhada,
    `Parcela proveniente das verbas do Incentiva +TP`                  = parcela_incentiva
  )

# ---- 4. Montar Folha 1 (formato longo, igual ao sheet 1 do exemplo) ---------
# Métricas em linhas, operadores em colunas
metricas <- c(
  "Receita na posse do operador [A]",
  "Receita bilheteira devida ao operador [B]",
  "Pagamento por conta COSP devida ao operador [D]",
  "Transferência [F]",
  "Congelamento Navegante [CongNavB]",
  "Total a transferir",
  "Transferência entre operadores",
  "Total a transferir corrigido"
)

# Construir colunas: Ano | Mês | Métrica | operador1 | ... | TOTAL
ops_ordem_folha1 <- setdiff(ordem_ops, character(0))

# Dados wide por métrica
make_wide <- function(metrica, valores_fn) {
  row_vals <- sapply(ops_ordem_folha1, function(op) {
    r <- folha2[folha2$nome_tab == op, ]
    if (nrow(r) == 0) return(NA_real_)
    valores_fn(r)
  })
  total_val <- valores_fn(folha2[folha2$nome_tab == "TOTAL", ])
  c(ANO, MES, metrica, row_vals, total_val)
}

folha1_rows <- list(
  make_wide("Receita na posse do operador [A]",     function(r) r$receita_A),
  make_wide("Receita bilheteira devida ao operador [B]", function(r) r$receita_B),
  make_wide("Pagamento por conta COSP devida ao operador [D]", function(r) r$cosp_D),
  make_wide("Transferência [F]",                    function(r) r$F_transferencia),
  make_wide("Congelamento Navegante [CongNavB]",     function(r) r$congelamento_B),
  make_wide("Total a transferir",                    function(r) r$total_transferir),
  make_wide("Transferência entre operadores",
            function(r) {
              v <- r$transf_entre_ops
              if (length(v) == 0 || is.na(v)) NA_real_ else v
            }),
  make_wide("Total a transferir corrigido",          function(r) r$total_tml)
)

folha1_df <- as.data.frame(
  do.call(rbind, folha1_rows),
  stringsAsFactors = FALSE
)
colnames(folha1_df) <- c("Ano", "Mês", "Métrica", ops_ordem_folha1, "TOTAL")

# Converter colunas numéricas
num_cols_f1 <- c(ops_ordem_folha1, "TOTAL")
folha1_df[num_cols_f1] <- lapply(folha1_df[num_cols_f1], as.numeric)

# ---- 5. Estilos e construção do workbook ------------------------------------
wb <- createWorkbook()

# --- Paleta de cores (inspirada no exemplo) ---
# openxlsx requer # nos códigos hex para fgFill e fontColour,
# mas borderColour NÃO aceita # — usar formato diferente por parâmetro
cor_header      <- "#FFC000"  # dourado para cabeçalho (fgFill)
cor_header_txt  <- "#292929"  # texto preto (fontColour)
cor_total       <- "#FFF2CC"  # dourado claro para linha TOTAL
cor_operador    <- "#f8f4e6"  # amarelo muito claro para coluna Operador
cor_alt_row     <- "#fbfbfc"  # cinzento para linhas alternadas
cor_neg         <- "#FFC7CE"  # vermelho claro para valores negativos
cor_pos_zero    <- "#C6EFCE"  # verde claro para MTS (transferir = 0)
cor_border      <- "#e4e3e3"  # cinzento leve para bordas

# Estilos gerais
st_header <- createStyle(
  fgFill = cor_header, fontColour = cor_header_txt,
  halign = "center", valign = "center",
  textDecoration = "bold", border = "TopBottomLeftRight",
  borderColour = cor_border, wrapText = TRUE, fontSize = 9
)
st_header_op <- createStyle(
  fgFill = cor_header, fontColour = cor_header_txt,
  halign = "left", valign = "center",
  textDecoration = "bold", border = "TopBottomLeftRight",
  borderColour = cor_border, fontSize = 10
)
st_euro <- createStyle(
  numFmt = "#,##0.00", halign = "right", border = "LeftRight",
  borderColour = cor_border, fontSize = 9
)
st_pct <- createStyle(
  numFmt = "0.000%", halign = "right", border = "LeftRight",
  borderColour = cor_border, fontSize = 9
)
st_op <- createStyle(
  fgFill = cor_operador, textDecoration = "bold",
  halign = "left", border = "LeftRight",
  borderColour = cor_border, fontSize = 9
)
st_total_lbl <- createStyle(
  fgFill = cor_total, textDecoration = "bold",
  halign = "left", border = "TopBottomLeftRight",
  borderColour = cor_border, fontSize = 9
)
st_total_num <- createStyle(
  fgFill = cor_total, textDecoration = "bold",
  numFmt = "#,##0.00", halign = "right",
  border = "TopBottomLeftRight", borderColour = cor_border, fontSize = 9
)
st_total_pct <- createStyle(
  fgFill = cor_total, textDecoration = "bold",
  numFmt = "0.000%", halign = "right",
  border = "TopBottomLeftRight", borderColour = cor_border, fontSize = 9
)
st_neg <- createStyle(
  fgFill = cor_neg, numFmt = "#,##0.00", halign = "right",
  border = "LeftRight", borderColour = cor_border, fontSize = 9
)
st_zero <- createStyle(
  fgFill = cor_pos_zero, numFmt = "#,##0.00", halign = "right",
  border = "LeftRight", borderColour = cor_border, fontSize = 9
)
st_alt <- createStyle(
  fgFill = cor_alt_row, numFmt = "#,##0.00", halign = "right",
  border = "LeftRight", borderColour = cor_border, fontSize = 9
)
st_alt_op <- createStyle(
  fgFill = cor_alt_row, textDecoration = "bold",
  halign = "left", border = "LeftRight",
  borderColour = cor_border, fontSize = 9
)

# ============================================================
# FOLHA 2
# ============================================================
addWorksheet(wb, "Folha2")
ws2 <- "Folha2"

# Linha de título (merged)
mergeCells(wb, ws2, rows = 1, cols = 1:14)
writeData(wb, ws2, x = paste0("     Tabela 6 - Transferências — ", mes_nome, " ", ANO),
          startRow = 1, startCol = 1)
addStyle(wb, ws2,
  createStyle(fontSize = 13, textDecoration = "bold",
              halign = "center", valign = "center",
              fgFill = cor_header, fontColour = cor_header_txt),
  rows = 1, cols = 1:14, gridExpand = TRUE)
setRowHeights(wb, ws2, rows = 1, heights = 24)

# Cabeçalhos (linha 2)
writeData(wb, ws2,
  x = as.data.frame(t(names(folha2_out))),
  startRow = 2, startCol = 1, colNames = FALSE)
addStyle(wb, ws2, st_header,    rows = 2, cols = 2:14, gridExpand = TRUE)
addStyle(wb, ws2, st_header_op, rows = 2, cols = 1,    gridExpand = TRUE)
setRowHeights(wb, ws2, rows = 2, heights = 60)

# Dados (linhas 3 a 12 = 10 operadores + TOTAL)
n_rows <- nrow(folha2_out)  # = 11 (10 ops + TOTAL)

writeData(wb, ws2, x = folha2_out,
          startRow = 3, startCol = 1, colNames = FALSE)

# Aplicar estilos linha a linha
for (i in seq_len(n_rows)) {
  excel_row <- i + 2   # linha Excel (começa em 3)
  op_nome   <- folha2_out$Operador[i]
  is_total  <- op_nome == "TOTAL"
  is_even   <- (i %% 2 == 0)

  # Valores negativos ou zero para MTS
  val_total <- folha2_out$`TOTAL a transferir pela TML (€)`[i]
  is_neg    <- !is_total && !is.na(val_total) && val_total < 0
  is_zero_t <- !is_total && !is.na(val_total) && val_total == 0

  if (is_total) {
    addStyle(wb, ws2, st_total_lbl, rows = excel_row, cols = 1)
    addStyle(wb, ws2, st_total_num, rows = excel_row, cols = c(2:9, 11, 13:14), gridExpand = TRUE)
    addStyle(wb, ws2, createStyle(
      fgFill = cor_total, textDecoration = "bold",
      numFmt = "#,##0.00", halign = "right",
      border = "TopBottomLeftRight", borderColour = cor_border, fontSize = 9),
      rows = excel_row, cols = 10)
    addStyle(wb, ws2, st_total_pct, rows = excel_row, cols = 12)
  } else if (is_neg || is_zero_t) {
    # Linha com excedente (negativo) ou zero
    st_fill_n <- if (is_neg) st_neg else st_zero
    addStyle(wb, ws2,
      createStyle(fgFill = if (is_neg) cor_neg else cor_pos_zero,
                  textDecoration = "bold", halign = "left",
                  border = "LeftRight", borderColour = cor_border, fontSize = 9),
      rows = excel_row, cols = 1)
    addStyle(wb, ws2, st_fill_n, rows = excel_row, cols = c(2:9, 11, 13:14), gridExpand = TRUE)
    addStyle(wb, ws2, st_fill_n, rows = excel_row, cols = 10)
    addStyle(wb, ws2,
      createStyle(fgFill = if (is_neg) cor_neg else cor_pos_zero,
                  numFmt = "0.000%", halign = "right",
                  border = "LeftRight", borderColour = cor_border, fontSize = 9),
      rows = excel_row, cols = 12)
  } else {
    # Linhas normais (alternadas)
    fg <- if (is_even) cor_alt_row else "#FFFFFF"
    st_n <- createStyle(fgFill = fg, numFmt = "#,##0.00", halign = "right",
                        border = "LeftRight", borderColour = cor_border, fontSize = 9)
    st_o <- createStyle(fgFill = fg, textDecoration = "bold", halign = "left",
                        border = "LeftRight", borderColour = cor_border, fontSize = 9)
    st_p <- createStyle(fgFill = fg, numFmt = "0.000%", halign = "right",
                        border = "LeftRight", borderColour = cor_border, fontSize = 9)
    addStyle(wb, ws2, st_o, rows = excel_row, cols = 1)
    addStyle(wb, ws2, st_n, rows = excel_row, cols = c(2:9, 11, 13:14), gridExpand = TRUE)
    addStyle(wb, ws2, st_n, rows = excel_row, cols = 10)
    addStyle(wb, ws2, st_p, rows = excel_row, cols = 12)
  }
}

# Bordas externas na tabela de dados
addStyle(wb, ws2,
  createStyle(border = "Bottom", borderColour = cor_border),
  rows = n_rows + 2, cols = 1:14, gridExpand = TRUE, stack = TRUE)

# Larguras de colunas
setColWidths(wb, ws2, cols = 1,      widths = 14)   # Operador
setColWidths(wb, ws2, cols = 2:9,    widths = 14)   # valores principais
setColWidths(wb, ws2, cols = 10,     widths = 16)   # transf entre ops
setColWidths(wb, ws2, cols = 11,     widths = 16)   # TOTAL TML
setColWidths(wb, ws2, cols = 12,     widths = 10)   # %
setColWidths(wb, ws2, cols = 13:14,  widths = 18)   # parcelas

# Congelar painel (linha cabeçalho)
freezePane(wb, ws2, firstActiveRow = 3)

# ============================================================
# FOLHA 1 (formato longo)
# ============================================================
addWorksheet(wb, "Tabela 6 - Transf (F)")
ws1 <- "Tabela 6 - Transf (F)"

# Título
n_cols_f1 <- ncol(folha1_df)
mergeCells(wb, ws1, rows = 1, cols = 1:n_cols_f1)
writeData(wb, ws1,
  x = paste0("     Tabela 6 - Transferências — ", mes_nome, " ", ANO),
  startRow = 1, startCol = 1)
addStyle(wb, ws1,
  createStyle(fontSize = 13, textDecoration = "bold",
              halign = "center", valign = "center",
              fgFill = cor_header, fontColour = cor_header_txt),
  rows = 1, cols = 1:n_cols_f1, gridExpand = TRUE)
setRowHeights(wb, ws1, rows = 1, heights = 24)

# Cabeçalho (linha 2)
# Linha com "Ano" + "Mês" + espaço + operadores + "TOTAL"
# Subheader de totais (linhas 3–4 como no exemplo com 13.657.120 / 20.868.102 / 7.210.982)
header_labels <- c("Ano", "Mês", "",
                   ops_ordem_folha1,
                   "TOTAL",
                   "Receita A (canal direto)",
                   "Receita K (partilhada)")

# Só as colunas do folha1_df
writeData(wb, ws1,
  x = as.data.frame(t(colnames(folha1_df))),
  startRow = 2, startCol = 1, colNames = FALSE)
addStyle(wb, ws1, st_header, rows = 2, cols = 1:n_cols_f1, gridExpand = TRUE)
setRowHeights(wb, ws1, rows = 2, heights = 36)

# Dados
writeData(wb, ws1, x = folha1_df,
          startRow = 3, startCol = 1, colNames = FALSE)

n_rows_f1 <- nrow(folha1_df)
num_start_col <- 4  # colunas 4.. são numéricas (Ano, Mês, Métrica são texto)

for (i in seq_len(n_rows_f1)) {
  excel_row <- i + 2
  is_even   <- (i %% 2 == 0)
  fg <- if (is_even) cor_alt_row else "#FFFFFF"
  addStyle(wb, ws1,
    createStyle(fgFill = fg, halign = "center", fontSize = 9,
                border = "LeftRight", borderColour = cor_border),
    rows = excel_row, cols = 1:2)
  addStyle(wb, ws1,
    createStyle(fgFill = fg, halign = "left", textDecoration = "bold",
                fontSize = 9, border = "LeftRight", borderColour = cor_border),
    rows = excel_row, cols = 3)
  addStyle(wb, ws1,
    createStyle(fgFill = fg, numFmt = "#,##0.00", halign = "right",
                fontSize = 9, border = "LeftRight", borderColour = cor_border),
    rows = excel_row, cols = num_start_col:n_cols_f1, gridExpand = TRUE)
}

setColWidths(wb, ws1, cols = 1,             widths = 6)
setColWidths(wb, ws1, cols = 2,             widths = 5)
setColWidths(wb, ws1, cols = 3,             widths = 36)
setColWidths(wb, ws1, cols = num_start_col:n_cols_f1, widths = 14)
freezePane(wb, ws1, firstActiveRow = 3, firstActiveCol = 4)

# ---- 6. Guardar ficheiro -----------------------------------------------------
F_TABELA_XLSX <- file.path(OUT_DIR, paste0("tabela_transferencias_", SUFIXO, ".xlsx"))
saveWorkbook(wb, F_TABELA_XLSX, overwrite = TRUE)
message("Tabela exportada: ", F_TABELA_XLSX)
