# =============================================================================
# 07_transferencias_F.R — Calcula as transferências finais por operador
# Distribuição de Receitas Navegante — TML
#
# Por operador j:
#   A(j)   = receita na posse do operador (vendas próprias)
#   B(j)   = receita bilheteira devida (distribuição por quota)
#   D(j)   = COSP (Compensação de Obrigação de Serviço Público)
#   Cong(j) = Congelamento Navegante (TAT)
#
#   F(j) = B(j) + D(j) - A(j)           ← transferência TML → operador
#   Total_transferir(j) = F(j) + Cong(j)
#
# Notas:
#   - Se Total_transferir < 0: operador tem excedente (devolve à TML ou a
#     membro do mesmo grupo económico — normalmente TST→Fertagus)
#   - Cascais (CAP): não pagar mensalmente; aguardar acerto anual
#   - COSP e Congelamento são pagos via programa "Incentiva"
#     (só após TML receber do Estado)
#
# Inputs:
#   OUT_DIR/2_vendas_AK_mesano.csv
#   OUT_DIR/4_receitaB_congelamento_mesano.csv
#   OUT_DIR/5_cosp_operador_mesano.csv
#   lists/operadores.csv
#
# Output:
#   OUT_DIR/6_transferencias_mesano.csv
# =============================================================================

source(here::here("code", "config.R"))

vendas_A   <- read.csv2(F_VENDAS_A,
                      stringsAsFactors = FALSE)
cong       <- read.csv2(F_CONGELAMENTO,
                        stringsAsFactors = FALSE)
D_op       <- read.csv2(F_D_OPERADOR,
                        stringsAsFactors = FALSE)
operadores <- read.csv2(file.path(LISTS_DIR, "operadores.csv"),
                        stringsAsFactors = FALSE, dec = ".")

# Nomes completos dos operadores para o relatório final
op_nomes <- operadores |>
  dplyr::select(ENTITY_ABBREVIATION, ENTITY_NAME) |>
  dplyr::rename(operador = ENTITY_ABBREVIATION, nome_operador = ENTITY_NAME)

# ---- Juntar A, B, D, Cong por operador ---------------------------------------
# receita_B está em 4_receitaB_congelamento_mesano.csv (coluna receita_B)
transferencias <- cong |>
  dplyr::select(operador, receita_B, congelamento_B) |>
  dplyr::full_join(
    vendas_A |> dplyr::select(operador, receita_A),
    by = "operador"
  ) |>
  dplyr::full_join(D_op, by = "operador") |>
  dplyr::mutate(
    receita_B      = as.numeric(receita_B),
    congelamento_B = as.numeric(congelamento_B),
    receita_A      = as.numeric(receita_A),
    cosp_D         = as.numeric(cosp_D),
    # Substituir NA por 0 (operador sem vendas próprias ou sem COSP)
    receita_A      = tidyr::replace_na(receita_A, 0),
    cosp_D         = tidyr::replace_na(cosp_D, 0),
    congelamento_B = tidyr::replace_na(congelamento_B, 0),
    # Calcular transferência
    F_transferencia  = receita_B + cosp_D - receita_A,
    total_transferir = F_transferencia + congelamento_B
  )

# ---- Notas por operador ------------------------------------------------------
transferencias <- transferencias |>
  dplyr::mutate(
    nota = dplyr::case_when(
      operador == "CAP" ~
        "Cascais: sem pagamento mensal — aguardar acerto anual (gratuitidade municipal)",
      total_transferir < 0 ~
        glue::glue("Excedente de {scales::number(abs(total_transferir), big.mark='.', decimal.mark=',')}€ — devolução à TML ou a Fertagus (TST)"),
      cosp_D > 0 | congelamento_B > 0 ~
        "COSP e Congelamento pagos via Incentiva (após recebimento do Estado)",
      TRUE ~ ""
    ),
    pagamento_imediato = dplyr::case_when(
      operador == "CAP"     ~ 0,
      total_transferir < 0  ~ 0,    # devolução — tratar separadamente
      TRUE                  ~ F_transferencia
    ),
    pagamento_incentiva = dplyr::case_when(
      operador == "CAP"     ~ 0,
      total_transferir < 0  ~ 0,
      TRUE                  ~ congelamento_B + cosp_D
    )
  )

# ---- Juntar nomes -----------------------------------------------------------
transferencias <- transferencias |>
  dplyr::left_join(op_nomes, by = "operador") |>
  dplyr::relocate(operador, nome_operador, .before = everything())

# ---- Sumário -----------------------------------------------------------------
mes_nome <- c("Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
              "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro")[MES]
cat("\n=== TRANSFERÊNCIAS FINAIS —", mes_nome, ANO, "===\n\n")
transferencias |>
  dplyr::select(operador, nome_operador, receita_A, receita_B, cosp_D, congelamento_B,
                F_transferencia, total_transferir, nota) |>
  dplyr::arrange(desc(abs(total_transferir))) |>
  dplyr::mutate(dplyr::across(where(is.numeric), ~ round(.x, 2))) |>
  print()

# Totais de verificação
cat(sprintf("\n--- Totais ---\n"))
cat(sprintf("  Sum(A):               %12.2f €\n", sum(transferencias$receita_A, na.rm = TRUE)))
cat(sprintf("  Sum(B):               %12.2f €\n", sum(transferencias$receita_B, na.rm = TRUE)))
cat(sprintf("  Sum(D):               %12.2f €\n", sum(transferencias$cosp_D, na.rm = TRUE)))
cat(sprintf("  Sum(Congelamento):    %12.2f €\n", sum(transferencias$congelamento_B, na.rm = TRUE)))
cat(sprintf("  Sum(F):               %12.2f €\n", sum(transferencias$F_transferencia, na.rm = TRUE)))
cat(sprintf("  Sum(Total transferir):%12.2f €\n", sum(transferencias$total_transferir, na.rm = TRUE)))

# Verificação: Sum(A + K) deve = Sum(B)  [B distribui A + K]
# Carregar receita K para o total
rtd_check <- tryCatch(
  read.csv2(F_RTD,
            stringsAsFactors = FALSE),
  error = function(e) NULL
)
total_K_check <- if (!is.null(rtd_check)) sum(as.numeric(rtd_check$receita_K), na.rm = TRUE) else 0
total_A_mais_K <- sum(transferencias$receita_A, na.rm = TRUE) + total_K_check

dif_AB <- sum(transferencias$receita_B, na.rm = TRUE) - total_A_mais_K
if (abs(dif_AB) > 1) {
  warning(sprintf("DISCREPÂNCIA Sum(A+K) vs Sum(B): %.2f €", dif_AB))
} else {
  message(sprintf("✓ Sum(A+K) ≈ Sum(B) (dif = %.2f €)", dif_AB))
}

# ---- Guardar output ----------------------------------------------------------
transf_out <- F_TRANSFERENCIAS
write.csv2(transferencias, transf_out, row.names = FALSE)
message("\nOutput gravado: ", transf_out)

# ---- Tabela resumo bonita (para copiar) --------------------------------------
cat("\n--- Tabela resumo (valores em €, arredondados ao cêntimo) ---\n")
transferencias |>
  dplyr::filter(operador != "CAP" | receita_B > 0) |>
  dplyr::select(Operador = operador,
                `A (na posse)` = receita_A,
                `B (devida)`   = receita_B,
                `D (COSP)`     = cosp_D,
                `Congel.`      = congelamento_B,
                `F (transf.)`  = F_transferencia,
                `Total`        = total_transferir) |>
  dplyr::mutate(dplyr::across(where(is.numeric), ~ tidyr::replace_na(.x, 0))) |>
  dplyr::mutate(dplyr::across(where(is.numeric), ~ round(.x, 2))) |>
  tibble::as_tibble() |>
  print(n = Inf)

