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
REPLICATE_DIR <- file.path(BASE_DIR, paste0(mes_ano, "_replicate"))
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
F_PT            <- file.path(OUT_DIR, paste0("PT_",                         SUFIXO, ".csv"))
F_PT_CM         <- file.path(OUT_DIR, paste0("PT_CM_agregado_",             SUFIXO, ".csv"))
F_RECEITAS      <- file.path(OUT_DIR, paste0("receitas_titulo_",            SUFIXO, ".csv"))
F_DISTANCIAS    <- file.path(OUT_DIR, paste0("distancias_",                 SUFIXO, ".csv"))
F_QUOTAS        <- file.path(OUT_DIR, paste0("quotas_",                     SUFIXO, ".csv"))
F_VENDAS_AK     <- file.path(OUT_DIR, paste0("vendas_AK_",                  SUFIXO, ".csv"))
F_RTD           <- file.path(OUT_DIR, paste0("receita_titulo_distribuir_",  SUFIXO, ".csv"))
F_REPARTICAO_B  <- file.path(OUT_DIR, paste0("reparticao_B_",              SUFIXO, ".csv"))
F_CONGELAMENTO  <- file.path(OUT_DIR, paste0("congelamento_",               SUFIXO, ".csv"))
F_COSP_D        <- file.path(OUT_DIR, paste0("cosp_D_",                     SUFIXO, ".csv"))
F_D_OPERADOR    <- file.path(OUT_DIR, paste0("D_operador_",                 SUFIXO, ".csv"))
F_TRANSFERENCIAS <- file.path(OUT_DIR, paste0("transferencias_F_",          SUFIXO, ".csv"))

# Ficheiro Oracle com validações TT (entity 5) e SL (entity 8) — query 2b de query_SL_TT.sql
# Exportado de PDBDWPROD: DW_PROC.F_VALIDATIONS com ENTITY_ID IN (5,8), TICKET_OPERATOR_CODE=31
# Identificado por conter "TICKET_OPERATOR" (nome padrão da query 2b exportada) ou "TT_SL"
TT_ENTITY_ID <- 5L    # Tâmega e Tua
SL_ENTITY_ID <- 8L    # Soflusa / Barreiro
SL_RUN_CODE  <- 7L    # RUN_CODE do ferry Soflusa/Barreiro — identifica validações SL
                      # (RUN_CODE != 7 → TT; metodologia da colega via georreferenciação)

F_TT_SL_VALIDACOES <- {
  candidates <- list.files(INPUT_DIR,
    pattern = "(TICKET_OPERATOR|validacoes_TT_SL|TT_SL).*\\.csv$",
    ignore.case = TRUE,
    full.names = TRUE)
  if (length(candidates) > 0) tail(sort(candidates), 1) else NULL
}




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
N_PASSES_COMPENSAR <- 8472289L

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
