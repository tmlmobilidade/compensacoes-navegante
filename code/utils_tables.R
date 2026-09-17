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
#' @param notes notas de rodapé da tabela (texto, vetor ou lista compatível com tinytable::tt)
#' @param bold_total lógico; se TRUE coloca a linha que contenha "TOTAL" a negrito
#' @param fontsize numérico; escala do tamanho de letra (padrão 0.85 para ~9.35pt com texto base 11pt)
#' @param fontsize_notes numérico; escala do tamanho de letra das notas de rodapé (padrão 0.7 para ~7.7pt)
#' @param italic_notes lógico; se TRUE coloca as notas de rodapé em itálico (padrão FALSE)
#' @param ... argumentos adicionais passados a tinytable::tt()
#' @return Objeto tinytable
tml_table <- function(x, 
                      align = NULL, 
                      caption = NULL, 
                      notes = NULL,
                      bold_total = TRUE, 
                      fontsize = 0.85, 
                      fontsize_notes = 0.7, 
                      italic_notes = FALSE, 
                      ...) {
  dots <- list(...)
  if ("notes_fontsize" %in% names(dots)) {
    fontsize_notes <- dots[["notes_fontsize"]]
    dots[["notes_fontsize"]] <- NULL
  }
  if ("notes_italic" %in% names(dots)) {
    italic_notes <- dots[["notes_italic"]]
    dots[["notes_italic"]] <- NULL
  }

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
  tt_args <- c(list(x = x, caption = caption, notes = notes), dots)
  tab <- do.call(tinytable::tt, tt_args)

  if (!is.null(fontsize)) {
    tab <- style_tt(tab, fontsize = fontsize)
  }
  if (!is.null(fontsize_notes) || isTRUE(italic_notes)) {
    tab <- style_tt(
      tab,
      i = "notes",
      fontsize = fontsize_notes,
      italic = if (isTRUE(italic_notes)) TRUE else NULL
    )
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

