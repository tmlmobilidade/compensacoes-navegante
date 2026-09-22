# =============================================================================
# 10_documentos.R — Renderiza relatórios e ofícios em Typst (PDF) e Word (DOCX)
# Distribuição de Receitas Navegante — TML
# =============================================================================

source(here::here("code", "config.R"))

# Criar pasta de destino docs/ se não existir
dir.create(DOCS_DIR, showWarnings = FALSE, recursive = TRUE)

# Garantir sincronização dos modelos/fundos timbrados de docs/ para code/docs/
code_docs_dir <- here::here("code", "docs")
dir.create(code_docs_dir, showWarnings = FALSE, recursive = TRUE)
for (f in c("folha_1.pdf", "folha_restantes.pdf", "folha1.png", "folhas_restantes.png")) {
  src <- here::here("docs", f)
  dst <- file.path(code_docs_dir, f)
  if (file.exists(src) && (!file.exists(dst) || file.mtime(src) > file.mtime(dst))) {
    file.copy(src, dst, overwrite = TRUE)
  }
}

# Garantir que a tabela global consolidada (passo 08) existe antes de renderizar
if (isTRUE(get0("RENDER_INFORMACAO1", ifnotfound = TRUE)) &&
    !file.exists(F_TABELA_GLOBAL) &&
    file.exists(here::here("code", "08_tables.R"))) {
  message("ℹ Ficheiro da tabela global (F_TABELA_GLOBAL) não encontrado. A executar code/08_tables.R...")
  source(here::here("code", "08_tables.R"))
}

#' Converte um PDF para Word (DOCX) usando o PDF24 Toolbox em modo flow (asposeFlow)
convert_pdf_to_docx_pdf24 <- function(pdf_file, docx_dest, mode = "asposeFlow") {
  pdf24_exe <- "C:/Program Files/PDF24/pdf24-Toolbox.exe"
  if (!file.exists(pdf24_exe)) {
    pdf24_exe <- "C:/Program Files (x86)/PDF24/pdf24-Toolbox.exe"
  }
  if (!file.exists(pdf24_exe)) {
    which_pdf24 <- Sys.which("pdf24-Toolbox.exe")
    if (nzchar(which_pdf24)) pdf24_exe <- which_pdf24
  }

  if (!file.exists(pdf24_exe)) {
    warning("PDF24 Toolbox não encontrado em C:/Program Files/PDF24/. Conversão para DOCX ignorada.")
    return(FALSE)
  }

  if (!file.exists(pdf_file)) {
    warning(sprintf("PDF de origem %s não encontrado para conversão.", pdf_file))
    return(FALSE)
  }

  temp_dir <- tempdir()
  job_file <- file.path(temp_dir, paste0("pdf24_job_", as.integer(Sys.time()), ".json"))
  res_file <- file.path(temp_dir, paste0("pdf24_res_", as.integer(Sys.time()), ".json"))

  job_data <- list(
    action = "convertPdfTo",
    fileInfos = list(list(file = normalizePath(pdf_file, winslash = "\\"))),
    outputFileType = "docx",
    conversionMode = mode
  )

  jsonlite::write_json(job_data, job_file, auto_unbox = TRUE, pretty = TRUE)
  if (file.exists(res_file)) unlink(res_file)

  message(sprintf("-> A converter PDF para Word (DOCX) via PDF24 Toolbox (modo '%s')...", mode))
  status <- system2(pdf24_exe, args = c("-processJob", shQuote(job_file), shQuote(res_file)), wait = TRUE)

  if (file.exists(res_file)) {
    res <- tryCatch(jsonlite::read_json(res_file), error = function(e) NULL)
    unlink(job_file)
    unlink(res_file)

    if (!is.null(res$state) && res$state == "done" && length(res$outputFiles) > 0) {
      out_temp <- res$outputFiles[[1]]$file
      if (file.exists(out_temp)) {
        file.copy(out_temp, docx_dest, overwrite = TRUE)
        unlink(out_temp)
        message(sprintf("✓ DOCX guardado em: %s", docx_dest))
        return(TRUE)
      }
    }
  }
  warning("Falha na conversão de PDF para DOCX pelo PDF24 Toolbox.")
  return(FALSE)
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

  # 1. Renderizar Typst (PDF)
  message("-> A gerar PDF (Typst)...")
  status_pdf <- system2("quarto", c("render", shQuote(qmd_file), "--to", "typst"))
  pdf_src <- here::here("code", paste0(base_name, ".pdf"))
  if (status_pdf == 0 && file.exists(pdf_src)) {
    file.copy(pdf_src, pdf_dest, overwrite = TRUE)
    message(sprintf("✓ PDF guardado em:  %s", pdf_dest))
  } else {
    warning(sprintf("Falha ao gerar %s.pdf.", base_name))
    return(FALSE)
  }

  # 2. Converter PDF gerado para Word (DOCX) via PDF24 CLI, se ativado em config.R
  if (!is.null(docx_dest) && isTRUE(get0("RENDER_DOCX", ifnotfound = FALSE))) {
    mode_chosen <- get0("DOCX_MODE", ifnotfound = "asposeFlow")
    convert_pdf_to_docx_pdf24(pdf_dest, docx_dest, mode = mode_chosen)
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
    docx_dest = F_DOC_METODOLOGIA_DOCX
  )
} else {
  message("ℹ Metodologia: ignorada (RENDER_METODOLOGIA = FALSE em config.R).")
}

# 3. Ofício 1 (a disponibilizar brevemente)
if (isTRUE(RENDER_OFICIO1)) {
  render_qmd_doc(
    qmd_name  = "oficio1.qmd",
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

