# =============================================================================
# build_reference_doc.R — Gera o reference-doc do Pandoc/Quarto para DOCX
# Distribuição de Receitas Navegante — TML
#
# Lê code/templates/TML_Informacao_template.docx (modelo oficial TML)
# e garante que TODOS os estilos esperados pelo Pandoc estão definidos
# com as regras tipográficas exatas da TML:
#  - docDefaults: Greycliff CF Light, 11 pt (sz=22), justificado, entrelinhamento 1.2
#  - Normal / BodyText / FirstParagraph: Greycliff CF Light, 11 pt, justificado
#  - Heading1 / Heading2 / Heading3 / Title: Greycliff CF, preto, numeração do Word
#  - Table / Compact / TabelaTexto: Greycliff CF Light, 8.5 pt (sz=17)
#  - TabelaTextoPequeno: Greycliff CF Light, 7.5 pt (sz=15)
#  - TabelaNota: Greycliff CF Light, 7.5 pt (sz=15), cor cinzenta #595959
#  - BlocoPequeno / BlocoDireita: 9 pt (sz=18)
#
# Resultado: code/templates/TML_Informacao_pandoc.docx
# =============================================================================

build_reference_doc <- function(
    template = here::here("code", "templates", "TML_Informacao_template.docx"),
    output   = here::here("code", "templates", "TML_Informacao_pandoc.docx"),
    force    = TRUE) {

  if (!file.exists(template)) stop("Modelo não encontrado: ", template)
  if (!force && file.exists(output) &&
      file.mtime(output) >= file.mtime(template) &&
      file.mtime(output) >= file.mtime(here::here("code", "build_reference_doc.R"))) {
    return(invisible(output))
  }

  tmp <- file.path(tempdir(), paste0("refdoc_", as.integer(Sys.time())))
  unlink(tmp, recursive = TRUE)
  dir.create(tmp, recursive = TRUE)
  utils::unzip(template, exdir = tmp)

  styles_file <- file.path(tmp, "word", "styles.xml")
  styles <- paste(readLines(styles_file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  # 1. Atualizar docDefaults para Greycliff CF Light 11 pt, justificado
  docdef_old <- '<w:docDefaults>.*?</w:docDefaults>'
  docdef_new <- paste0(
    '<w:docDefaults>',
    '<w:rPrDefault><w:rPr>',
    '<w:rFonts w:ascii="Greycliff CF Light" w:hAnsi="Greycliff CF Light" w:eastAsia="Greycliff CF Light" w:cs="Greycliff CF Light"/>',
    '<w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="pt-PT"/>',
    '</w:rPr></w:rPrDefault>',
    '<w:pPrDefault><w:pPr>',
    '<w:spacing w:before="120" w:after="240" w:line="288" w:lineRule="auto"/>',
    '<w:ind w:right="-7"/><w:jc w:val="both"/>',
    '</w:pPr></w:pPrDefault>',
    '</w:docDefaults>'
  )
  styles <- sub(docdef_old, docdef_new, styles)

  # Helper para gerar estilos de parágrafo
  make_style <- function(id, name, based = "Normal", ppr = "", rpr = "", custom = "1") {
    custom_attr <- if (nzchar(custom)) sprintf(' w:customStyle="%s"', custom) else ''
    sprintf(
      '<w:style w:type="paragraph"%s w:styleId="%s"><w:name w:val="%s"/><w:basedOn w:val="%s"/><w:qFormat/><w:pPr>%s</w:pPr><w:rPr>%s</w:rPr></w:style>',
      custom_attr, id, name, based, ppr, rpr
    )
  }

  # Propriedades de parágrafo e texto
  p_body <- '<w:spacing w:before="120" w:after="240" w:line="288" w:lineRule="auto"/><w:ind w:right="-7"/><w:jc w:val="both"/>'
  r_body <- '<w:rFonts w:ascii="Greycliff CF Light" w:hAnsi="Greycliff CF Light"/><w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="pt-PT"/>'

  p_compact_list  <- '<w:spacing w:before="40" w:after="40" w:line="260" w:lineRule="auto"/><w:ind w:right="-7"/><w:jc w:val="both"/>'
  p_compact       <- '<w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/><w:ind w:right="0"/><w:jc w:val="left"/>'
  p_compact_small <- '<w:spacing w:before="0" w:after="0" w:line="180" w:lineRule="exact"/><w:ind w:right="0"/><w:jc w:val="left"/>'
  r_tbl_text      <- '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="17"/><w:szCs w:val="17"/><w:lang w:val="pt-PT"/>'
  r_tbl_small     <- '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="17"/><w:szCs w:val="17"/><w:lang w:val="pt-PT"/>'

  p_tbl_note <- '<w:spacing w:before="60" w:after="180" w:line="240" w:lineRule="auto"/><w:ind w:right="0"/><w:jc w:val="left"/>'
  r_tbl_note <- '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="15"/><w:szCs w:val="15"/><w:color w:val="595959"/>'

  p_caption <- '<w:keepNext/><w:spacing w:before="140" w:after="80" w:line="240" w:lineRule="auto"/><w:jc w:val="center"/>'
  r_caption <- '<w:rFonts w:ascii="Greycliff CF" w:hAnsi="Greycliff CF"/><w:b/><w:bCs/><w:sz w:val="18"/><w:szCs w:val="18"/>'

  p_bloco_dir <- '<w:keepLines/><w:spacing w:before="120" w:after="240" w:line="240" w:lineRule="auto"/><w:ind w:left="4536"/><w:jc w:val="left"/>'
  r_bloco_dir <- '<w:rFonts w:ascii="Greycliff CF Light" w:hAnsi="Greycliff CF Light" w:cs="Greycliff CF Light"/><w:sz w:val="18"/><w:szCs w:val="18"/>'

  p_bloco_peq  <- '<w:spacing w:before="0" w:after="30" w:line="240" w:lineRule="auto"/><w:jc w:val="left"/>'
  p_linha_desp <- '<w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="000000"/></w:pBdr><w:spacing w:before="600" w:after="120"/>'

  # Headings oficiais TML (Greycliff CF, preto, numeração do Word)
  # Heading 1: 14 pt (sz="28"), negrito, espaçamento antes 431, depois 120
  # Heading 2: 12 pt (sz="24"), negrito, mais espaço antes (300) e menos depois (100)
  # Heading 3: 11 pt (sz="22"), semibold, espaçamento antes 160, depois 80
  h1_def <- paste0(
    '<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="Heading 1"/><w:basedOn w:val="Ttulo1"/><w:next w:val="BodyText"/><w:qFormat/>',
    '<w:pPr><w:keepNext/><w:keepLines/><w:numPr><w:numId w:val="5"/></w:numPr><w:spacing w:before="431" w:after="120" w:line="354" w:lineRule="exact"/><w:ind w:left="426"/><w:outlineLvl w:val="0"/></w:pPr>',
    '<w:rPr><w:rFonts w:ascii="Greycliff CF" w:hAnsi="Greycliff CF"/><w:b/><w:bCs/><w:color w:val="000000"/><w:spacing w:val="-1"/><w:sz w:val="28"/><w:szCs w:val="32"/></w:rPr></w:style>'
  )
  h2_def <- paste0(
    '<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="Heading 2"/><w:basedOn w:val="Ttulo2"/><w:next w:val="BodyText"/><w:qFormat/>',
    '<w:pPr><w:keepNext/><w:keepLines/><w:numPr><w:ilvl w:val="1"/><w:numId w:val="5"/></w:numPr><w:spacing w:before="300" w:after="100"/><w:ind w:left="567" w:hanging="567"/><w:outlineLvl w:val="1"/></w:pPr>',
    '<w:rPr><w:rFonts w:ascii="Greycliff CF" w:hAnsi="Greycliff CF"/><w:b/><w:bCs/><w:sz w:val="24"/><w:szCs w:val="28"/></w:rPr></w:style>'
  )
  h3_def <- paste0(
    '<w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="Heading 3"/><w:basedOn w:val="Ttulo3"/><w:next w:val="BodyText"/><w:qFormat/>',
    '<w:pPr><w:keepNext/><w:keepLines/><w:numPr><w:ilvl w:val="2"/><w:numId w:val="5"/></w:numPr><w:spacing w:before="200" w:after="80"/><w:ind w:left="567" w:hanging="567"/><w:outlineLvl w:val="2"/></w:pPr>',
    '<w:rPr><w:rFonts w:ascii="Greycliff CF" w:hAnsi="Greycliff CF"/><w:b/><w:bCs/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr></w:style>'
  )
  title_def <- paste0(
    '<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Ttulo"/><w:next w:val="Normal"/><w:qFormat/>',
    '<w:pPr><w:jc w:val="right"/></w:pPr>',
    '<w:rPr><w:rFonts w:ascii="Greycliff CF" w:hAnsi="Greycliff CF"/><w:sz w:val="24"/><w:szCs w:val="24"/><w:lang w:val="pt-PT"/></w:rPr></w:style>'
  )

  # Atualizar também os estilos nativos do template Ttulo2 e Ttulo3
  styles <- gsub(
    '(<w:style [^>]*w:styleId="Ttulo2"[^>]*>.*?<w:sz )w:val="28"',
    '\\1w:val="24"',
    styles
  )
  styles <- gsub(
    '(<w:style [^>]*w:styleId="Ttulo3"[^>]*>.*?<w:sz )w:val="24"',
    '\\1w:val="22"',
    styles
  )

  # Estilo de tabela oficial (grelha TML com 8.5 pt Calibri, sem linhas cinzentas horizontais intermediárias)
  table_def <- paste0(
    '<w:style w:type="table" w:default="1" w:styleId="Table"><w:name w:val="Table"/><w:basedOn w:val="Tabelanormal"/><w:uiPriority w:val="59"/>',
    '<w:pPr><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/><w:jc w:val="left"/></w:pPr>',
    '<w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="17"/><w:szCs w:val="17"/><w:lang w:val="pt-PT"/></w:rPr>',
    '<w:tblPr><w:tblBorders>',
    '<w:top w:val="single" w:sz="8" w:space="0" w:color="000000"/>',
    '<w:bottom w:val="single" w:sz="8" w:space="0" w:color="000000"/>',
    '<w:insideH w:val="none"/>',
    '</w:tblBorders><w:tblCellMar><w:top w:w="65" w:type="dxa"/><w:left w:w="70" w:type="dxa"/><w:bottom w:w="65" w:type="dxa"/><w:right w:w="70" w:type="dxa"/></w:tblCellMar></w:tblPr>',
    '<w:tblStylePr w:type="firstRow"><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:b/><w:bCs/><w:sz w:val="17"/><w:szCs w:val="17"/></w:rPr><w:tcPr><w:tcBorders><w:bottom w:val="single" w:sz="8" w:space="0" w:color="000000"/></w:tcBorders><w:vAlign w:val="bottom"/></w:tcPr></w:tblStylePr>',
    '</w:style>'
  )

  # Estilos para código inline e blocos de código
  # Consolas ou Cascadia Mono, 9.5 pt (sz=19), cor cinzenta/azulada elegante (#1F497D)
  verbatim_def <- paste0(
    '<w:style w:type="character" w:customStyle="1" w:styleId="VerbatimChar">',
    '<w:name w:val="Verbatim Char"/><w:basedOn w:val="NormalCar"/><w:qFormat/>',
    '<w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/>',
    '<w:color w:val="1F497D"/><w:sz w:val="19"/><w:szCs w:val="19"/>',
    '</w:rPr></w:style>'
  )
  sourcecode_def <- paste0(
    '<w:style w:type="paragraph" w:customStyle="1" w:styleId="SourceCode">',
    '<w:name w:val="Source Code"/><w:basedOn w:val="Normal"/><w:qFormat/>',
    '<w:pPr><w:spacing w:before="60" w:after="60" w:line="240" w:lineRule="auto"/><w:jc w:val="left"/></w:pPr>',
    '<w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/>',
    '<w:color w:val="1F497D"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr></w:style>'
  )

  extra_styles <- list(
    BodyText           = make_style("BodyText", "Body Text", based = "Normal", ppr = p_body, rpr = r_body),
    FirstParagraph     = make_style("FirstParagraph", "First Paragraph", based = "Normal", ppr = p_body, rpr = r_body),
    Compact            = make_style("Compact", "Compact", based = "Normal", ppr = p_compact_list, rpr = r_body),
    TableCaption       = make_style("TableCaption", "Table Caption", based = "Normal", ppr = p_caption, rpr = r_caption),
    ImageCaption       = make_style("ImageCaption", "Image Caption", based = "Normal", ppr = p_caption, rpr = r_caption),
    Caption            = make_style("Caption", "Caption", based = "Normal", ppr = p_caption, rpr = r_caption),
    TabelaTexto        = make_style("TabelaTexto", "Tabela Texto", based = "Normal", ppr = p_compact, rpr = r_tbl_text),
    TabelaTextoPequeno = make_style("TabelaTextoPequeno", "Tabela Texto Pequeno", based = "Normal", ppr = p_compact_small, rpr = r_tbl_small),
    TabelaNota         = make_style("TabelaNota", "Tabela Nota", based = "Normal", ppr = p_tbl_note, rpr = r_tbl_note),
    BlocoPequeno       = make_style("BlocoPequeno", "Bloco Pequeno", based = "Normal", ppr = p_bloco_peq, rpr = r_bloco_dir),
    BlocoDireita       = make_style("BlocoDireita", "Bloco Direita", based = "Normal", ppr = p_bloco_dir, rpr = r_bloco_dir),
    LinhaDespacho      = make_style("LinhaDespacho", "Linha Despacho", based = "Normal", ppr = p_linha_desp),
    Heading1           = h1_def,
    Heading2           = h2_def,
    Heading3           = h3_def,
    Title              = title_def,
    Table              = table_def,
    VerbatimChar       = verbatim_def,
    SourceCode         = sourcecode_def
  )

  for (id in names(extra_styles)) {
    pattern <- sprintf('<w:style [^>]*w:styleId="%s"[^>]*>.*?</w:style>', id)
    if (grepl(pattern, styles)) {
      styles <- sub(pattern, extra_styles[[id]], styles)
    } else {
      styles <- sub("</w:styles>", paste0(extra_styles[[id]], "</w:styles>"), styles, fixed = TRUE)
    }
  }

  writeLines(styles, styles_file, useBytes = TRUE)

  # Comprimir mantendo a hierarquia completa de pastas (word/, _rels/, etc.)
  if (file.exists(output)) unlink(output)
  old_wd <- setwd(tmp)
  on.exit(setwd(old_wd), add = TRUE)
  zip::zip(zipfile = normalizePath(output, mustWork = FALSE), files = dir(all.files = TRUE, no.. = TRUE))
  setwd(old_wd)
  unlink(tmp, recursive = TRUE)

  message("✓ reference-doc gerado com sucesso: ", output)
  invisible(output)
}

if (sys.nframe() == 0) build_reference_doc(force = TRUE)
