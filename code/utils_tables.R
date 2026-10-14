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
                      alignv = NULL,
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

  # Word (DOCX): tabela Markdown processada pelo Pandoc + filtro docx_styles.lua
  if (is_docx_output()) {
    return(tml_table_docx(x, align = align, notes = notes, bold_total = bold_total))
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
  if (!is.null(alignv)) {
    tab <- style_tt(tab, alignv = alignv)
  }
  tab
}

#' TRUE quando o Quarto/Pandoc está a produzir um DOCX
is_docx_output <- function() {
  fmt <- tryCatch(knitr::pandoc_to(), error = function(e) NULL)
  !is.null(fmt) && length(fmt) == 1 && grepl("^docx", fmt)
}

#' Tabela Markdown (pipe table) para DOCX, com notas e estilos Word
#'
#' - quebras de linha ("\n") passam a <br> (convertido em quebra de linha Word
#'   pelo filtro linebreaks.lua);
#' - larguras relativas das colunas derivadas do conteúdo;
#' - linha TOTAL a negrito;
#' - notas: texto simples (vetor) ou list(a = list(i, j, text)) com marcador
#'   sobrescrito na célula (i = 0 é o cabeçalho);
#' - o estilo de letra das células é aplicado por docx_styles.lua
#' Tabela Markdown (pipe table) para DOCX, com notas e estilos Word
#'
#' - quebras de linha ("\n") passam a <br> (convertido em quebra de linha Word
#'   pelo filtro linebreaks.lua);
#' - células vazias ou NA são preenchidas com espaço não-quebrável ("\u00a0") para
#'   garantir que herdam sempre o estilo Compact e não docDefaults/Normal;
#' - larguras relativas das colunas derivadas do conteúdo limpo de tags;
#' - linha TOTAL a negrito com borda preta superior pelo filtro docx_styles.lua;
#' - notas: texto simples (vetor) ou list(a = list(i, j, text)) com marcador
#'   sobrescrito na célula (i = 0 é o cabeçalho);
#' - o estilo de letra das células é aplicado pelo estilo Compact do Word (Calibri 8.5 pt).
tml_table_docx <- function(x, align = NULL, notes = NULL, bold_total = TRUE) {
  x <- as.data.frame(x, stringsAsFactors = FALSE, check.names = FALSE)
  esc <- function(s) {
    s <- as.character(s)
    s[is.na(s) | trimws(s) == ""] <- "\u00a0"
    s <- gsub("|", "\\|", s, fixed = TRUE)
    s <- gsub("[", "\\[", s, fixed = TRUE)
    s <- gsub("]", "\\]", s, fixed = TRUE)
    gsub("\n", "<br>", s, fixed = TRUE)
  }
  header <- esc(names(x))
  cells  <- lapply(x, esc)
  cells  <- as.data.frame(cells, stringsAsFactors = FALSE, check.names = FALSE)
  nr <- nrow(cells); nc <- ncol(cells)

  if (bold_total && nr > 0) {
    tot <- which(grepl("^TOTAL", x[[1]], ignore.case = TRUE))
    for (r in tot) {
      v <- unlist(cells[r, ], use.names = FALSE)
      cells[r, ] <- as.list(ifelse(nzchar(v) & v != "\u00a0", paste0("**", v, "**"), "\u00a0"))
    }
  }

  # Notas
  note_lines <- character()
  if (is.character(notes)) {
    note_lines <- notes
  } else if (is.list(notes)) {
    for (key in names(notes)) {
      n <- notes[[key]]
      mk <- paste0("^", key, "^")
      if (n$i == 0) header[n$j] <- paste0(header[n$j], mk) else cells[n$i, n$j] <- paste0(cells[n$i, n$j], mk)
      note_lines <- c(note_lines, paste0(mk, " ", n$text))
    }
  }

  clean_str <- function(s) {
    s <- gsub("\\[\\]\\{[^}]*\\}", "", s)
    s <- gsub("\\*\\*", "", s)
    s <- gsub("\\^[^\\^]*\\^", "", s)
    s
  }
  maxw_vec <- function(v) {
    v_clean <- clean_str(as.character(v))
    parts <- unlist(strsplit(v_clean, "<br>", fixed = TRUE))
    max(nchar(trimws(parts)), 1, na.rm = TRUE)
  }
  w <- vapply(seq_len(nc), function(j) {
    has_eur <- any(grepl("€", cells[[j]], fixed = TRUE))
    has_pct <- any(grepl("%", cells[[j]], fixed = TRUE))
    cell_w  <- maxw_vec(cells[[j]])
    hdr_parts <- unlist(strsplit(clean_str(header[j]), "<br>", fixed = TRUE))
    hdr_words <- unlist(strsplit(hdr_parts, "\\s+"))
    hdr_w   <- max(nchar(trimws(hdr_words)), 1, na.rm = TRUE)
    
    col_w   <- max(cell_w, hdr_w)
    min_col <- if (j == 1) 16 else if (has_eur) 19 else if (has_pct) 13 else 8
    max(col_w, min_col)
  }, numeric(1))
  al <- if (is.null(align)) rep("l", nc) else rep_len(align, nc)
  sep <- vapply(seq_len(nc), function(j) {
    d <- strrep("-", w[j])
    switch(al[j], r = paste0(d, ":"), c = paste0(":", d, ":"), paste0(":", d))
  }, character(1))

  row_md <- function(v) paste0("| ", paste(v, collapse = " | "), " |")
  md <- c(row_md(header), paste0("|", paste(sep, collapse = "|"), "|"),
          vapply(seq_len(nr), function(r) row_md(unlist(cells[r, ], use.names = FALSE)), character(1)))

  if (length(note_lines)) {
    md <- c(md, "", paste0('::: {custom-style="Tabela Nota"}'), paste(note_lines, collapse = "\n\n"), ":::")
  }
  knitr::asis_output(paste0("\n", paste(md, collapse = "\n"), "\n"))
}

