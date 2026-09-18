# =============================================================================
# config.R — Parâmetros globais e constantes regulamentares
# Distribuição de Receitas Navegante — TML
# =============================================================================
# Alterar ANO e MES para correr para outro mês.

ANO <- if (!is.na(Sys.getenv("ANO", unset = NA))) as.integer(Sys.getenv("ANO")) else 2026
MES <- if (!is.na(Sys.getenv("MES", unset = NA))) as.integer(Sys.getenv("MES")) else 5      # 5 = maio, 6 = junho, etc.

# ---- Caminhos base -----------------------------------------------------------
BASE_DIR <- here::here()   # raiz do projecto (onde está o code/)
LISTS_DIR  <- file.path(BASE_DIR, "lists")

# Meses em português (abreviatura minúscula) para nomes de pastas
meses_pt <- c("jan", "fev", "mar", "abr", "mai", "jun",
              "jul", "ago", "set", "out", "nov", "dez")
meses_pt_nome <- c("Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
                   "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro")

mes_str       <- sprintf("%02d", MES)
mes_abrev     <- meses_pt[MES]                      # ex: "mai"
mes_nome      <- meses_pt_nome[MES]                 # ex: "Maio"
mes_ano       <- sprintf("%02d_%s_%d", MES, mes_abrev, ANO)   # ex: "05_mai_2026"
DATA_DIR      <- file.path(BASE_DIR, mes_ano)
REPLICATE_DIR <- file.path(BASE_DIR, paste0(mes_ano, "_replicate")) # estava a usar este para output intermédio, mas ajustar para input/output final
INPUT_DIR     <- file.path(REPLICATE_DIR, "input")
OUT_DIR       <- file.path(REPLICATE_DIR, "output")

# Sufixo para nomes de ficheiros de output: paste0(mes_abrev, ano curto)
# ex: "mai26", "jun26"
SUFIXO <- paste0(mes_abrev, substr(as.character(ANO), 3, 4))

# Criar pastas de input e output se não existirem
dir.create(INPUT_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(OUT_DIR,   showWarnings = FALSE, recursive = TRUE)

# ---- Nomes de ficheiros de output (centralizados) ----------------------------
# Todos os ficheiros intermédios e finais usam SUFIXO no nome.
# Alterar MES/ANO em cima actualiza automaticamente todos os caminhos.
F_PT            <- file.path(OUT_DIR, paste0("1a_PT_",                        SUFIXO, ".csv"))
F_PT_CM         <- file.path(OUT_DIR, paste0("1b_PT_CM_",                    SUFIXO, ".csv"))
F_RECEITAS      <- file.path(OUT_DIR, paste0("1c_receitas_titulo_",          SUFIXO, ".csv"))
F_DISTANCIAS    <- file.path(OUT_DIR, paste0("1e_distancias_",               SUFIXO, ".csv"))
F_QUOTAS        <- file.path(OUT_DIR, paste0("1_quotas_",                    SUFIXO, ".csv"))
F_VENDAS_A      <- file.path(OUT_DIR, paste0("2_vendas_A_",                  SUFIXO, ".csv"))
F_VENDAS_K      <- file.path(OUT_DIR, paste0("2_vendas_K_",                  SUFIXO, ".csv"))
F_VENDAS_AK     <- F_VENDAS_A   # alias de compatibilidade
F_RTD           <- file.path(OUT_DIR, paste0("4a_receita_titulo_distribuir_", SUFIXO, ".csv"))
F_REPARTICAO_B  <- file.path(OUT_DIR, paste0("4b_reparticao_B_",             SUFIXO, ".csv"))
F_CONGELAMENTO  <- file.path(OUT_DIR, paste0("4_receitaB_congelamento_",     SUFIXO, ".csv"))
F_COSP_D        <- file.path(OUT_DIR, paste0("5a_cosp_",                     SUFIXO, ".csv"))
F_D_OPERADOR    <- file.path(OUT_DIR, paste0("5_cosp_operador_",             SUFIXO, ".csv"))
F_VAT           <- file.path(OUT_DIR, paste0("1d_validacoes_",               SUFIXO, ".csv"))
F_TRANSFERENCIAS <- file.path(OUT_DIR, paste0("6_transferencias_",           SUFIXO, ".csv"))
F_TABELA_XLSX   <- file.path(OUT_DIR, paste0("Anexo_calculos_",              SUFIXO, ".xlsx"))

# ---- Função auxiliar para selecção de ficheiros recentes ---------------------
#' Seleciona o ficheiro mais recente que corresponda a um padrão.
#' Regras:
#' 1. Usar o ficheiro mais recente pelo timestamp de data no nome (YYYYMMDD...);
#' 2. Se houver mais do que um ficheiro com a mesma data mais recente, preferir o que diz "_update" (ou "update");
#' 3. Desempate final pelo timestamp completo mais recente (ou mtime).
selecionar_ficheiro_recente <- function(diretorias, pattern_pref, pattern_fallback = NULL) {
  files <- list.files(diretorias, pattern = pattern_pref, ignore.case = TRUE, full.names = TRUE)
  if (length(files) == 0 && !is.null(pattern_fallback)) {
    files <- list.files(diretorias, pattern = pattern_fallback, ignore.case = TRUE, full.names = TRUE)
  }
  files <- unique(files)
  if (length(files) == 0) return(NULL)
  if (length(files) == 1) return(files[1])

  info <- lapply(files, function(p) {
    fname <- basename(p)
    # Extrair sequência de 8 a 14 dígitos (ex: 202609171208 ou 20260911_1613 ou 20260911)
    m <- regmatches(fname, gregexpr("\\b20\\d{6,12}\\b|\\d{8,14}", fname))[[1]]
    has_update <- grepl("update", fname, ignore.case = TRUE)
    if (length(m) > 0) {
      digs <- gsub("[^0-9]", "", tail(m, 1))
      date_8 <- as.numeric(substr(digs, 1, 8))
      ts_full <- as.numeric(substr(paste0(digs, "00000000000000"), 1, 14))
      has_ts <- TRUE
    } else {
      # Fallback: mtime do ficheiro se não houver timestamp no nome
      fi <- suppressWarnings(file.info(p))
      mtime <- if (!is.na(fi$mtime[1])) fi$mtime[1] else as.POSIXct("1970-01-01")
      date_8 <- as.numeric(format(mtime, "%Y%m%d"))
      ts_full <- as.numeric(format(mtime, "%Y%m%d%H%M%S"))
      has_ts <- FALSE
    }
    data.frame(path = p, fname = fname, date_8 = date_8, ts_full = ts_full,
               has_update = has_update, has_ts = has_ts,
               mtime = as.numeric(file.info(p)$mtime),
               stringsAsFactors = FALSE)
  })
  df <- do.call(rbind, info)

  # Regra 1: Filtrar para a data mais recente no nome (date_8)
  max_date <- max(df$date_8)
  candidatos <- df[df$date_8 == max_date, ]

  # Regra 2: Se houver mais do que um com a mesma data mais recente,
  # dar prioridade ao que diz "_update"
  if (nrow(candidatos) > 1) {
    candidatos_up <- candidatos[candidatos$has_update, ]
    if (nrow(candidatos_up) > 0) {
      candidatos <- candidatos_up
    }
  }

  # Desempate por timestamp completo mais recente, mtime e nome de ficheiro
  candidatos <- candidatos[order(candidatos$ts_full, candidatos$mtime, candidatos$fname, decreasing = TRUE), ]
  candidatos$path[1]
}

# Ficheiro Oracle com distâncias APEX (CM e CAP)
# Padrão: ficheiro com AVERAGE_DISTANCE no nome (ignora distancias_dinamicas)
F_APEX_DISTANCIAS <- selecionar_ficheiro_recente(
  c(INPUT_DIR, REPLICATE_DIR),
  pattern_pref = "AVERAGE_DISTANCE.*\\.csv$"
)

# Ficheiro Oracle com validações TT (entity 5) e SL (entity 8) — query 2b de query_SL_TT.sql
# Exportado de PDBDWPROD: DW_PROC.F_VALIDATIONS com ENTITY_ID IN (5,8), TICKET_OPERATOR_CODE=31
# Padrão: tt_sl_*(timestamp).csv (ou fallback validacoes_TT_SL / TICKET_OPERATOR)
TT_ENTITY_ID <- 5L    # Tâmega e Tua
SL_ENTITY_ID <- 8L    # Soflusa / Barreiro
SL_RUN_CODE  <- 7L    # RUN_CODE do ferry Soflusa/Barreiro — identifica validações SL
                      # (RUN_CODE != 7 → TT; metodologia da colega via georreferenciação)

F_TT_SL_VALIDACOES <- selecionar_ficheiro_recente(
  c(INPUT_DIR, REPLICATE_DIR),
  pattern_pref     = "tt_sl.*\\.csv$",
  pattern_fallback = "(validacoes_TT_SL|TICKET_OPERATOR).*\\.csv$"
)

# Ficheiro Oracle com validações do Portal VIVA (fiscais móveis Carris Metropolitana, entity 23) — query 2c
# Padrão: entity23_*(timestamp).csv (ou fallback CM_viva / PV_CM)
F_CM_VIVA_VALIDACOES <- selecionar_ficheiro_recente(
  c(INPUT_DIR, REPLICATE_DIR),
  pattern_pref     = "entity_?23.*\\.csv$",
  pattern_fallback = "(CM_viva|PV_CM).*\\.csv$"
)




# ---- Épocas ------------------------------------------------------------------
# Meses de verão: junho (6), julho (7), agosto (8)
MESES_VERAO <- c(6L, 7L, 8L)
eh_verao    <- MES %in% MESES_VERAO

# Ficheiro de distâncias de referência (estático, regulamento 1362-C/2023)
DIST_REF_FILE <- if (eh_verao) {
  file.path(LISTS_DIR, "distanciasref_ago21_incompleto.csv")
} else {
  file.path(LISTS_DIR, "distanciasref_out21_incompleto.csv")
}

# ---- Operadores APEX (distâncias dinâmicas disponíveis) ----------------------
# CM (Carris Metropolitana): ENTITY_ID = 75
# CAP (Cascais Próxima):     ENTITY_ID = 22
APEX_ENTITY_IDS <- c(75L, 22L)

# Sub-operadores da CM nos Recibos B (A1, A2, A3, A4 → agregados como CM)
CM_SUBOPS <- c("A1", "A2", "A3", "A4")
CM_ENTITY_ID <- 75L

# Operadores a excluir dos cálculos
# Scotturb (SC, entity 11) e validadores móveis fiscais (PV, entity 23)
EXCLUIR_ENTITY_IDS <- c(11L, 23L)

# ---- Constantes regulamentares -----------------------------------------------
# Valor Máximo de Compensação COSP regulado para 2023 (€)
VMC_2023 <- 112562432.41

# Número máximo de passes a compensar por ano
N_PASSES_COMPENSAR <- 8472279L

# Retenção da TML sobre o valor a compensar mensalmente
RETENCAO_TML <- 0.025

# ---- TAT — Taxa de Atualização Tarifária -------------------------------------
# Valores confirmados pela AMT (calculados em final de outubro de cada ano):
#   2024 = 0.0643 (~6.43%)
#   2025 = 0.0202 (~2.02%)
#   2026 = 0.0228 (~2.28%)
# (o tat.csv foi corrigido — os anos 2024 e 2026 estavam trocados na versão original)
TAT_FILE <- file.path(LISTS_DIR, "tat.csv")

# Função auxiliar: calcula o factor cumulativo TAT até ao ano corrente
get_fator_tat <- function(ano_calc = ANO) {
  tat <- read.csv2(TAT_FILE, header = TRUE, stringsAsFactors = FALSE,
                   dec = ".")
  # Garantir tipos corretos (sep=; dec=.)
  tat$tat <- as.numeric(tat$tat)
  tat_ate_ano <- tat[tat$ano <= ano_calc, ]
  prod(1 + tat_ate_ano$tat) - 1
}

# ---- Separador dos CSVs dos Recibos B ----------------------------------------
RECIBOS_SEP <- ";"
RECIBOS_DEC <- "."

message(sprintf("Config carregado: %s/%d | Verão: %s | Output: %s",
                mes_nome, ANO, eh_verao, OUT_DIR))
