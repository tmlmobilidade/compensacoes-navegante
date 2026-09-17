# =============================================================================
# utils_tables.R — Funções auxiliares de formatação de tabelas (tinytable)
# Distribuição de Receitas Navegante — TML
# =============================================================================

suppressPackageStartupMessages({
  library(tinytable)
})

#' Cria e formata uma tabela com tinytable para Typst e Word (Quarto)
#'
#' Trata quebras de linha em cabeçalhos e células, escapa asteriscos isolados
#' para o Typst, aplica alinhamentos por coluna, coloca a linha TOTAL a negrito
#' e ajusta o tamanho de letra.
#'
#' @param x data.frame ou tibble
#' @param align vetor de caracteres com alinhamentos por coluna ("l", "r", "c")
#' @param caption legenda da tabela
#' @param bold_total lógico; se TRUE coloca a linha que contenha "TOTAL" a negrito
#' @param fontsize numérico; escala do tamanho de letra (padrão 0.85 para ~9.35pt com texto base 11pt)
#' @param ... argumentos adicionais passados a tinytable::tt()
#' @return Objeto tinytable
tml_table <- function(x, align = NULL, caption = NULL, bold_total = TRUE, fontsize = 0.85, ...) {
  if (is.data.frame(x)) {
    names(x) <- gsub("\n", " \\ ", names(x), fixed = TRUE)
    x[] <- lapply(x, function(col) {
      if (is.character(col)) {
        col <- gsub("\n", " \\ ", col, fixed = TRUE)
        col <- gsub("(\\w)\\*", "\\1\\\\*", col)
        col
      } else {
        col
      }
    })
  }
  tab <- tt(x, caption = caption, ...)
  if (!is.null(fontsize)) {
    tab <- style_tt(tab, fontsize = fontsize)
  }
  if (!is.null(align)) {
    for (j in seq_along(align)) {
      tab <- style_tt(tab, j = j, align = align[j])
    }
  }
  if (bold_total && nrow(x) > 0) {
    total_idx <- which(grepl("^TOTAL", x[[1]], ignore.case = TRUE))
    if (length(total_idx) > 0) {
      tab <- style_tt(tab, i = total_idx, bold = TRUE, line = "t", line_width = 0.03)
    }
  }
  tab
}

