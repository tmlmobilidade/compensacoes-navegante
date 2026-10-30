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
#' @param width vetor numérico com as larguras ou proporções das colunas (ex.: c(0.6, 0.4) ou c(60, 40)); opcional
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
                      width = NULL,
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
    return(tml_table_docx(x, align = align, notes = notes, bold_total = bold_total, width = width))
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
  if (!is.null(width) && is.numeric(width)) {
    if (length(width) > 1 && sum(width) > 1.01) {
      width <- width / sum(width)
    }
    dots[["width"]] <- width
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

  # Estilos para tabela de reporte/pagamentos (ex.: Tabela 5)
  if (nrow(x) > 0) {
    col1 <- trimws(gsub("\\*", "", as.character(x[[1]])))

    # Cores na coluna Estado (Pago -> Verde, Por pagar -> Vermelho)
    if (ncol(x) >= 3) {
      col3 <- trimws(as.character(x[[3]]))
      pago_idx <- which(col3 == "Pago")
      if (length(pago_idx) > 0) {
        tab <- style_tt(tab, i = pago_idx, j = 3, color = "#27AE60")
      }
      por_pagar_idx <- which(col3 == "Por pagar")
      if (length(por_pagar_idx) > 0) {
        tab <- style_tt(tab, i = por_pagar_idx, j = 3, color = "#C0392B")
      }
    }

    # Linha divisória após anos anteriores (ex.: Subtotal 2025)
    subtot_ant_idx <- which(grepl("^Subtotal\\s+\\d{4}\\s+solicitado e pago", col1, ignore.case = TRUE))
    if (length(subtot_ant_idx) > 0) {
      tab <- style_tt(tab, i = max(subtot_ant_idx), line = "b", line_width = 0.05)
    }

    # Linha divisória após o mês atual e destaque em negrito
    subtot_ano_idx <- which(grepl("^Subtotal\\s+\\d{4}\\s+solicitado$", col1, ignore.case = TRUE))
    if (length(subtot_ano_idx) > 0 && subtot_ano_idx[1] > 1) {
      cur_m <- subtot_ano_idx[1] - 1
      tab <- style_tt(tab, i = cur_m, j = 1:min(2, ncol(x)), bold = TRUE)
      tab <- style_tt(tab, i = cur_m, line = "b", line_width = 0.05)
    }

    # Sombreado nas linhas de comparação plurianual (ex.: Subtotal 2024-2026)
    pluri_idx <- which(grepl("^Subtotal\\s+\\d{4}-\\d{4}", col1, ignore.case = TRUE))
    if (length(pluri_idx) > 0) {
      tab <- style_tt(tab, i = pluri_idx, background = "#EAEAEA")
    }

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
tml_table_docx <- function(x, align = NULL, notes = NULL, bold_total = TRUE, width = NULL) {
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

  # Destaque em negrito das colunas 1 e 2 do mês atual na Tabela 5
  if (nr > 0) {
    col1_clean <- trimws(as.character(x[[1]]))
    subtot_ano_idx <- which(grepl("^Subtotal\\s+\\d{4}\\s+solicitado$", col1_clean, ignore.case = TRUE))
    if (length(subtot_ano_idx) > 0 && subtot_ano_idx[1] > 1) {
      cur_m <- subtot_ano_idx[1] - 1
      for (c_idx in 1:min(2, nc)) {
        val <- as.character(cells[cur_m, c_idx])
        if (nzchar(val) && val != "\u00a0") {
          cells[cur_m, c_idx] <- paste0("**", val, "**")
        }
      }
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
      if (0 %in% n$i) header[n$j] <- paste0(header[n$j], mk)
      rows <- n$i[n$i > 0]
      if (length(rows) > 0) {
        for (r in rows) {
          cells[r, n$j] <- paste0(cells[r, n$j], mk)
        }
      }
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

  if (!is.null(width) && is.numeric(width) && length(width) == nc) {
    pct <- width / sum(width)
    w   <- pmax(round(pct * 100), 3)
  } else {
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
  }
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

