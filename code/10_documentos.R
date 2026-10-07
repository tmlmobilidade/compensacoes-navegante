# =============================================================================
# 10_documentos.R — Renderiza relatórios e ofícios em Typst (PDF) e Word (DOCX)
# Distribuição de Receitas Navegante — TML
# =============================================================================

source(here::here("code", "config.R"))

# Criar pasta de destino docs/ se não existir
dir.create(DOCS_DIR, showWarnings = FALSE, recursive = TRUE)


# Garantir que a tabela global consolidada (passo 08) existe antes de renderizar
if (isTRUE(get0("RENDER_INFORMACAO1", ifnotfound = TRUE)) &&
    !file.exists(F_TABELA_GLOBAL) &&
    file.exists(here::here("code", "08_tables.R"))) {
  message("ℹ Ficheiro da tabela global (F_TABELA_GLOBAL) não encontrado. A executar code/08_tables.R...")
  source(here::here("code", "08_tables.R"))
}


#' Renderiza um documento Quarto (.qmd) para Typst (PDF) e converte para Word (DOCX)
#' e guarda na pasta de destino DOCS_DIR
render_qmd_doc <- function(qmd_name, pdf_dest, docx_dest = NULL) {
  qmd_file <- here::here("code", qmd_name)
  if (!file.exists(qmd_file)) {
    warning(sprintf("Ficheiro %s não encontrado em code/.", qmd_name))
    return(FALSE)
  }
  base_name <- sub("\\.qmd$", "", qmd_name)
  message("-----------------------------------------------------------------")
  message(sprintf("A renderizar %s para: %s / %d", qmd_name, mes_nome, ANO))
  message(sprintf("Pasta de saída: %s", DOCS_DIR))
  message("-----------------------------------------------------------------")

  # 1. Garantir reference-doc atualizado
  if (file.exists(here::here("code", "templates", "build_reference_doc.R"))) {
    tryCatch({
      source(here::here("code", "templates", "build_reference_doc.R"))
      build_reference_doc()
    }, error = function(e) invisible(NULL))
  }

  # 2. Renderizar Typst (PDF) se configurado
  if (!is.null(pdf_dest) && isTRUE(get0("RENDER_PDF", ifnotfound = TRUE))) {
    message("-> A gerar PDF (Typst)...")
    status_pdf <- system2("quarto", c("render", shQuote(qmd_file), "--to", "typst"))
    pdf_src <- here::here("code", paste0(base_name, ".pdf"))
    if (status_pdf == 0 && file.exists(pdf_src)) {
      file.copy(pdf_src, pdf_dest, overwrite = TRUE)
      message(sprintf("✓ PDF guardado em:  %s", pdf_dest))
    } else {
      warning(sprintf("Falha ao gerar %s.pdf.", base_name))
    }
  }

  # 3. Gerar Word (DOCX) diretamente via Quarto
  if (!is.null(docx_dest) && isTRUE(get0("RENDER_DOCX", ifnotfound = FALSE))) {
    lines_qmd <- readLines(qmd_file, n = 30, warn = FALSE)
    has_docx_format <- any(grepl("^\\s*docx:", lines_qmd))

    if (has_docx_format) {
      message("-> A gerar Word (DOCX) diretamente via Quarto...")
      status_docx <- system2("quarto", c("render", shQuote(qmd_file), "--to", "docx"))
      docx_src <- here::here("code", paste0(base_name, ".docx"))
      if (status_docx == 0 && file.exists(docx_src)) {
        file.copy(docx_src, docx_dest, overwrite = TRUE)
        message(sprintf("✓ DOCX guardado em: %s", docx_dest))
      } else {
        warning(sprintf("Falha ao gerar %s.docx.", base_name))
      }
    } else {
      message(sprintf("ℹ %s não tem formato docx configurado no YAML. Ignorado.", qmd_name))
    }
  }
  TRUE
}


# 1. Informação 1
if (isTRUE(RENDER_INFORMACAO1)) {
  render_qmd_doc(
    qmd_name  = "informacao1.qmd",
    pdf_dest  = F_DOC_INFO1_PDF,
    docx_dest = F_DOC_INFO1_DOCX
  )
} else {
  message("ℹ Informação 1: ignorada (RENDER_INFORMACAO1 = FALSE em config.R).")
}

# 2. Metodologia
if (isTRUE(RENDER_METODOLOGIA)) {
  render_qmd_doc(
    qmd_name  = "metodologia.qmd",
    pdf_dest  = F_DOC_METODOLOGIA_PDF,
    docx_dest = NULL # apenas em PDF conforme requisitos
  )
} else {
  message("ℹ Metodologia: ignorada (RENDER_METODOLOGIA = FALSE em config.R).")
}

# 3. Ofício 1 (a disponibilizar brevemente)
if (isTRUE(RENDER_OFICIO1)) {
  render_qmd_doc(
    qmd_name  = "oficio1.qmd", # com as tabelas no fim dos items numerados
    pdf_dest  = F_DOC_OFICIO1_PDF,
    docx_dest = F_DOC_OFICIO1_DOCX
  )
}

# 3. Ofício 2 (a disponibilizar brevemente)
if (isTRUE(RENDER_OFICIO2)) {
  render_qmd_doc(
    qmd_name  = "oficio2.qmd",
    pdf_dest  = F_DOC_OFICIO2_PDF,
    docx_dest = F_DOC_OFICIO2_DOCX
  )
}

message("=================================================================")
message("Fase de documentos concluída!")
message("=================================================================")

