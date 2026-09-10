# =============================================================================
# 99_run_all.R — Script mestre: corre todos os passos em sequência
# Distribuição de Receitas Navegante — TML
#
# Uso:
#   Rscript code/99_run_all.R          # usa ANO/MES do config.R
#   ANO=2026 MES=6 Rscript code/99_run_all.R   # ou definir antes
#
# Sequência:
#   00. Setup de pacotes
#   01. Agrega Recibos B (PT + transações)
#   02. Resolve distâncias médias
#   03. Calcula quotas (PKM)
#   04. Agrega vendas A (operadores) + K (PV/ATM)
#   05. Repartição receita B + Congelamento TAT
#   06. COSP (D)
#   07. Transferências finais (F)
# =============================================================================

t_inicio <- proc.time()

# Permitir override de ANO e MES via variáveis de ambiente
if (!is.na(Sys.getenv("ANO", unset = NA))) {
  ano_env <- suppressWarnings(as.integer(Sys.getenv("ANO")))
  if (!is.na(ano_env)) ANO <<- ano_env
}
if (!is.na(Sys.getenv("MES", unset = NA))) {
  mes_env <- suppressWarnings(as.integer(Sys.getenv("MES")))
  if (!is.na(mes_env)) MES <<- mes_env
}

# ---- Utilitário: correr um passo com tratamento de erro ----------------------
run_step <- function(script_name, descricao) {
  cat(sprintf("\n%s\n", strrep("=", 70)))
  cat(sprintf("PASSO: %s — %s\n", script_name, descricao))
  cat(sprintf("%s\n", strrep("=", 70)))

  t0 <- proc.time()
  tryCatch({
    source(here::here("code", script_name))
    elapsed <- (proc.time() - t0)[["elapsed"]]
    cat(sprintf("\n✓ %s concluído em %.1fs\n", script_name, elapsed))
    TRUE
  }, error = function(e) {
    cat(sprintf("\n✗ ERRO em %s:\n  %s\n", script_name, conditionMessage(e)))
    FALSE
  }, warning = function(w) {
    cat(sprintf("\n⚠ AVISO em %s:\n  %s\n", script_name, conditionMessage(w)))
    # Continuar mesmo com aviso
    source(here::here("code", script_name))
    TRUE
  })
}

# ---- Setup -------------------------------------------------------------------
library(here)
source(here::here("code", "00_setup.R"))
source(here::here("code", "config.R"))

cat(sprintf("\n%s\n", strrep("#", 70)))
cat(sprintf("# DISTRIBUIÇÃO RECEITAS NAVEGANTE — %s %d\n",
            toupper(month.name[MES]), ANO))
cat(sprintf("# Output: %s\n", OUT_DIR))
cat(sprintf("%s\n\n", strrep("#", 70)))

# ---- Executar passos ---------------------------------------------------------
resultados <- list(
  "01_recibos_b.R"     = run_step("01_recibos_b.R",     "Agrega Recibos B"),
  "02_distancias.R"    = run_step("02_distancias.R",    "Distâncias médias"),
  "03_quotas.R"        = run_step("03_quotas.R",        "Quotas PKM"),
  "04_vendas_AK.R"     = run_step("04_vendas_AK.R",     "Vendas A + K"),
  "05_reparticao_B.R"  = run_step("05_reparticao_B.R",  "Repartição B + Congelamento"),
  "06_cosp_D.R"        = run_step("06_cosp_D.R",        "COSP (D)"),
  "07_transferencias_F.R" = run_step("07_transferencias_F.R", "Transferências (F)")
)

# ---- Sumário final -----------------------------------------------------------
t_total <- (proc.time() - t_inicio)[["elapsed"]]

cat(sprintf("\n%s\n", strrep("=", 70)))
cat(sprintf("SUMÁRIO FINAL — %s %d\n", month.name[MES], ANO))
cat(sprintf("%s\n", strrep("=", 70)))

n_ok  <- sum(unlist(resultados), na.rm = TRUE)
n_err <- length(resultados) - n_ok

cat(sprintf("Passos concluídos: %d/%d\n", n_ok, length(resultados)))
if (n_err > 0) {
  cat(sprintf("Passos com ERRO:   %d\n", n_err))
  erros <- names(resultados)[!unlist(resultados)]
  cat(sprintf("  → %s\n", paste(erros, collapse = ", ")))
}

cat(sprintf("Tempo total:       %.1fs\n", t_total))
cat(sprintf("Output em:         %s\n", OUT_DIR))

# ---- Ficheiros gerados -------------------------------------------------------
if (n_ok == length(resultados)) {
  cat("\nFicheiros gerados:\n")
  ficheiros_out <- list.files(OUT_DIR, pattern = "\\.csv$", full.names = FALSE)
  for (f in sort(ficheiros_out)) {
    fsize <- file.size(file.path(OUT_DIR, f))
    cat(sprintf("  %-50s %6.1f KB\n", f, fsize / 1024))
  }

  # Mostrar tabela final de transferências
  transf_file <- F_TRANSFERENCIAS
  if (file.exists(transf_file)) {
    cat(sprintf("\n%s\n", strrep("-", 70)))
    cat("TABELA FINAL DE TRANSFERÊNCIAS:\n")
    cat(sprintf("%s\n", strrep("-", 70)))
    transf <- read.csv2(transf_file, stringsAsFactors = FALSE)
    transf |>
      dplyr::select(Operador = operador,
                    Nome = nome_operador,
                    `A (posse)` = receita_A,
                    `B (devida)` = B,
                    `D (COSP)` = D,
                    `Congel.` = congelamento,
                    `F (transf.)` = F_transferencia,
                    `Total` = total_transferir) |>
      dplyr::mutate(dplyr::across(where(is.numeric), ~ tidyr::replace_na(.x, 0))) |>
      dplyr::mutate(dplyr::across(where(is.numeric), ~ round(.x, 2))) |>
      tibble::as_tibble() |>
      print(n = Inf)
  }
}

cat(sprintf("\n%s\n", strrep("=", 70)))
if (n_err == 0) {
  cat("✓ Pipeline completo sem erros.\n")
} else {
  cat("✗ Pipeline concluído COM ERROS — verificar output acima.\n")
}
cat(sprintf("%s\n", strrep("=", 70)))
