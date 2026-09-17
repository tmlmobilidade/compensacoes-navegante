# =============================================================================
# render_informacao1.R — Renderiza a Informação 1 em Typst (PDF) e Word (DOCX)
# Distribuição de Receitas Navegante — TML
# =============================================================================

source(here::here("code", "config.R"))

# Criar pasta de destino: <mes_ano>_replicate/output/docs
docs_dir <- file.path(OUT_DIR, "docs")
dir.create(docs_dir, showWarnings = FALSE, recursive = TRUE)

qmd_file <- here::here("code", "informacao1.qmd")

message("-----------------------------------------------------------------")
message(sprintf("A renderizar Informacao 1 para: %s / %d", mes_nome, ANO))
message(sprintf("Pasta de saida: %s", docs_dir))
message("-----------------------------------------------------------------")

# 1. Renderizar Typst (PDF)
message("-> A gerar PDF (Typst)...")
system2("quarto", c("render", shQuote(qmd_file), "--to", "typst"))

# 2. Renderizar Word (DOCX)
message("-> A gerar Word (DOCX)...")
system2("quarto", c("render", shQuote(qmd_file), "--to", "docx"))

# 3. Copiar ficheiros para a pasta de saida docs/
pdf_src  <- here::here("code", "informacao1.pdf")
docx_src <- here::here("code", "informacao1.docx")

pdf_dest  <- file.path(docs_dir, paste0("informacao1_", SUFIXO, ".pdf"))
docx_dest <- file.path(docs_dir, paste0("informacao1_", SUFIXO, ".docx"))

if (file.exists(pdf_src)) {
  file.copy(pdf_src, pdf_dest, overwrite = TRUE)
  message(sprintf("✓ PDF copiado para:  %s", pdf_dest))
} else {
  warning("Ficheiro informacao1.pdf não encontrado.")
}

if (file.exists(docx_src)) {
  file.copy(docx_src, docx_dest, overwrite = TRUE)
  message(sprintf("✓ DOCX copiado para: %s", docx_dest))
} else {
  warning("Ficheiro informacao1.docx não encontrado.")
}

message("=================================================================")
message("Renderizacao concluida com sucesso!")
message("=================================================================")

