# =============================================================================
# build_reference_doc.R — Gera o reference-doc do Pandoc/Quarto para DOCX
# Distribuição de Receitas Navegante — TML
#
# Lê code/templates/TML_Informacao_template.docx (modelo oficial TML)
# e garante que TODOS os estilos esperados pelo Pandoc estão definidos
# com as regras tipográficas exatas da TML e isolados (via TMLBase / TMLTitulo1..3)
# para não sofrerem conflitos de estilo ao copiar-colar para documentos file-doc:
#  - docDefaults / TMLBase: Greycliff CF Light, 11 pt (sz=22), justificado, entrelinhamento 1.2
#  - TMLCorpo / BodyText / FirstParagraph: Greycliff CF Light, 11 pt, justificado
#  - TMLTitulo1..3 / Heading1..3 / Title: Greycliff CF, preto, numeração do Word
#  - Table / TMLCompacto / TabelaTexto: Calibri, 8.5 pt (sz=17)
#  - TabelaTextoPequeno: Calibri, 8.5 pt (sz=17)
#  - TabelaNota: Calibri, 7.5 pt (sz=15), cor cinzenta #595959
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
      file.mtime(output) >= file.mtime(here::here("code", "templates", "build_reference_doc.R"))) {
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
    '<w:color w:val="000000"/><w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="pt-PT"/>',
    '</w:rPr></w:rPrDefault>',
    '<w:pPrDefault><w:pPr>',
    '<w:spacing w:before="120" w:after="240" w:line="288" w:lineRule="auto"/>',
    '<w:ind w:left="0" w:right="-7"/><w:jc w:val="both"/>',
    '</w:pPr></w:pPrDefault>',
    '</w:docDefaults>'
  )
  styles <- sub(docdef_old, docdef_new, styles)

  # Helper para gerar estilos de parágrafo (por defeito baseados em TMLBase e não em Normal,
  # evitando herdar Cambria 10pt ou alinhamento à esquerda quando colado num documento file-doc)
  make_style <- function(id, name, based = "TMLBase", ppr = "", rpr = "", custom = "1") {
    custom_attr <- if (nzchar(custom)) sprintf(' w:customStyle="%s"', custom) else ''
    based_tag   <- if (nzchar(based)) sprintf('<w:basedOn w:val="%s"/>', based) else ''
    sprintf(
      '<w:style w:type="paragraph"%s w:styleId="%s"><w:name w:val="%s"/>%s<w:qFormat/><w:pPr>%s</w:pPr><w:rPr>%s</w:rPr></w:style>',
      custom_attr, id, name, based_tag, ppr, rpr
    )
  }

  # Propriedades de parágrafo e texto
  p_body <- '<w:spacing w:before="120" w:after="240" w:line="288" w:lineRule="auto"/><w:ind w:left="0" w:right="-7"/><w:jc w:val="both"/>'
  r_body <- '<w:rFonts w:ascii="Greycliff CF Light" w:hAnsi="Greycliff CF Light" w:eastAsia="Greycliff CF Light" w:cs="Greycliff CF Light"/><w:color w:val="000000"/><w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="pt-PT"/>'

  p_compact_list  <- '<w:spacing w:before="40" w:after="40" w:line="260" w:lineRule="auto"/><w:ind w:right="-7"/><w:jc w:val="both"/>'
  p_tml_lista     <- '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="4"/></w:numPr><w:spacing w:before="40" w:after="40" w:line="260" w:lineRule="auto"/><w:ind w:left="360" w:hanging="360" w:right="-7"/><w:jc w:val="both"/>'
  p_compact       <- '<w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/><w:ind w:left="0" w:right="0"/><w:jc w:val="left"/>'
  p_compact_small <- '<w:spacing w:before="0" w:after="0" w:line="180" w:lineRule="exact"/><w:ind w:left="0" w:right="0"/><w:jc w:val="left"/>'
  r_tbl_text      <- '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:color w:val="000000"/><w:sz w:val="17"/><w:szCs w:val="17"/><w:lang w:val="pt-PT"/>'
  r_tbl_small     <- '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:color w:val="000000"/><w:sz w:val="17"/><w:szCs w:val="17"/><w:lang w:val="pt-PT"/>'

  p_tbl_note <- '<w:spacing w:before="60" w:after="0" w:line="240" w:lineRule="auto"/><w:ind w:left="0" w:right="0"/><w:jc w:val="left"/>'
  r_tbl_note <- '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="15"/><w:szCs w:val="15"/><w:color w:val="595959"/>'

  p_caption <- '<w:keepNext/><w:spacing w:before="140" w:after="80" w:line="240" w:lineRule="auto"/><w:ind w:left="0" w:right="0"/><w:jc w:val="center"/>'
  r_caption <- '<w:rFonts w:ascii="Greycliff CF" w:hAnsi="Greycliff CF" w:cs="Greycliff CF"/><w:color w:val="000000"/><w:sz w:val="18"/><w:szCs w:val="18"/>'

  p_bloco_dir <- '<w:keepLines/><w:spacing w:before="120" w:after="240" w:line="240" w:lineRule="auto"/><w:ind w:left="4536"/><w:jc w:val="left"/>'
  r_bloco_dir <- '<w:rFonts w:ascii="Greycliff CF Light" w:hAnsi="Greycliff CF Light" w:cs="Greycliff CF Light"/><w:color w:val="000000"/><w:sz w:val="18"/><w:szCs w:val="18"/>'

  p_bloco_peq  <- '<w:spacing w:before="0" w:after="30" w:line="240" w:lineRule="auto"/><w:ind w:left="0" w:right="0"/><w:jc w:val="left"/>'
  p_linha_desp <- '<w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="000000"/></w:pBdr><w:spacing w:before="600" w:after="120"/>'

  p_block_text <- '<w:pBdr><w:left w:val="single" w:sz="12" w:space="12" w:color="B0B0B0"/></w:pBdr><w:spacing w:before="120" w:after="240" w:line="260" w:lineRule="auto"/><w:ind w:left="720" w:right="360"/><w:jc w:val="both"/>'
  r_block_text <- '<w:rFonts w:ascii="Greycliff CF Light" w:hAnsi="Greycliff CF Light" w:cs="Greycliff CF Light"/><w:color w:val="404040"/><w:sz w:val="21"/><w:szCs w:val="21"/><w:lang w:val="pt-PT"/>'

  # Headings oficiais TML (Greycliff CF, preto, numeração do Word)
  # Além de Heading1..3, criamos TMLTitulo1..3 (customStyle="1", baseados em TMLBase)
  # para não colidirem com os estilos Heading/Título azuis do file-doc ao copiar-colar.
  h1_ppr <- '<w:pPr><w:keepNext/><w:keepLines/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="5"/></w:numPr><w:spacing w:before="431" w:after="120" w:line="354" w:lineRule="exact"/><w:ind w:left="426" w:hanging="426"/><w:outlineLvl w:val="0"/></w:pPr>'
  h1_rpr <- '<w:rPr><w:rFonts w:ascii="Greycliff CF" w:hAnsi="Greycliff CF" w:cs="Greycliff CF"/><w:b/><w:bCs/><w:color w:val="000000"/><w:spacing w:val="-1"/><w:sz w:val="28"/><w:szCs w:val="32"/></w:rPr>'

  h2_ppr <- '<w:pPr><w:keepNext/><w:keepLines/><w:numPr><w:ilvl w:val="1"/><w:numId w:val="5"/></w:numPr><w:spacing w:before="300" w:after="100"/><w:ind w:left="567" w:hanging="567"/><w:outlineLvl w:val="1"/></w:pPr>'
  h2_rpr <- '<w:rPr><w:rFonts w:ascii="Greycliff CF" w:hAnsi="Greycliff CF" w:cs="Greycliff CF"/><w:b/><w:bCs/><w:color w:val="000000"/><w:sz w:val="24"/><w:szCs w:val="28"/></w:rPr>'

  h3_ppr <- '<w:pPr><w:keepNext/><w:keepLines/><w:numPr><w:ilvl w:val="2"/><w:numId w:val="5"/></w:numPr><w:spacing w:before="200" w:after="80"/><w:ind w:left="567" w:hanging="567"/><w:outlineLvl w:val="2"/></w:pPr>'
  h3_rpr <- '<w:rPr><w:rFonts w:ascii="Greycliff CF" w:hAnsi="Greycliff CF" w:cs="Greycliff CF"/><w:b/><w:bCs/><w:color w:val="000000"/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>'

  h1_def     <- paste0('<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="Heading 1"/><w:basedOn w:val="TMLBase"/><w:next w:val="TMLCorpo"/><w:qFormat/>', h1_ppr, h1_rpr, '</w:style>')
  h2_def     <- paste0('<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="Heading 2"/><w:basedOn w:val="TMLBase"/><w:next w:val="TMLCorpo"/><w:qFormat/>', h2_ppr, h2_rpr, '</w:style>')
  h3_def     <- paste0('<w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="Heading 3"/><w:basedOn w:val="TMLBase"/><w:next w:val="TMLCorpo"/><w:qFormat/>', h3_ppr, h3_rpr, '</w:style>')
  tml_h1_def <- paste0('<w:style w:type="paragraph" w:customStyle="1" w:styleId="TMLTitulo1"><w:name w:val="TML Titulo 1"/><w:basedOn w:val="TMLBase"/><w:next w:val="TMLCorpo"/><w:qFormat/>', h1_ppr, h1_rpr, '</w:style>')
  tml_h2_def <- paste0('<w:style w:type="paragraph" w:customStyle="1" w:styleId="TMLTitulo2"><w:name w:val="TML Titulo 2"/><w:basedOn w:val="TMLBase"/><w:next w:val="TMLCorpo"/><w:qFormat/>', h2_ppr, h2_rpr, '</w:style>')
  tml_h3_def <- paste0('<w:style w:type="paragraph" w:customStyle="1" w:styleId="TMLTitulo3"><w:name w:val="TML Titulo 3"/><w:basedOn w:val="TMLBase"/><w:next w:val="TMLCorpo"/><w:qFormat/>', h3_ppr, h3_rpr, '</w:style>')

  title_def <- paste0(
    '<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="TMLBase"/><w:next w:val="TMLCorpo"/><w:qFormat/>',
    '<w:pPr><w:jc w:val="right"/></w:pPr>',
    '<w:rPr><w:rFonts w:ascii="Greycliff CF" w:hAnsi="Greycliff CF" w:cs="Greycliff CF"/><w:color w:val="000000"/><w:sz w:val="24"/><w:szCs w:val="24"/><w:lang w:val="pt-PT"/></w:rPr></w:style>'
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
    '<w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:color w:val="000000"/><w:sz w:val="17"/><w:szCs w:val="17"/><w:lang w:val="pt-PT"/></w:rPr>',
    '<w:tblPr><w:jc w:val="center"/><w:tblBorders>',
    '<w:top w:val="single" w:sz="8" w:space="0" w:color="000000"/>',
    '<w:bottom w:val="single" w:sz="8" w:space="0" w:color="000000"/>',
    '<w:insideH w:val="none"/>',
    '</w:tblBorders><w:tblCellMar><w:top w:w="65" w:type="dxa"/><w:left w:w="70" w:type="dxa"/><w:bottom w:w="65" w:type="dxa"/><w:right w:w="70" w:type="dxa"/></w:tblCellMar></w:tblPr>',
    '<w:tblStylePr w:type="firstRow"><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:b/><w:bCs/><w:color w:val="000000"/><w:sz w:val="17"/><w:szCs w:val="17"/></w:rPr><w:tcPr><w:tcBorders><w:bottom w:val="single" w:sz="8" w:space="0" w:color="000000"/></w:tcBorders><w:vAlign w:val="bottom"/></w:tcPr></w:tblStylePr>',
    '</w:style>'
  )

  # Estilos para código inline e blocos de código
  verbatim_def <- paste0(
    '<w:style w:type="character" w:customStyle="1" w:styleId="VerbatimChar">',
    '<w:name w:val="Verbatim Char"/><w:basedOn w:val="NormalCar"/><w:qFormat/>',
    '<w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/>',
    '<w:color w:val="1F497D"/><w:sz w:val="19"/><w:szCs w:val="19"/>',
    '</w:rPr></w:style>'
  )
  sourcecode_def <- paste0(
    '<w:style w:type="paragraph" w:customStyle="1" w:styleId="SourceCode">',
    '<w:name w:val="Source Code"/><w:basedOn w:val="TMLBase"/><w:qFormat/>',
    '<w:pPr><w:spacing w:before="60" w:after="60" w:line="240" w:lineRule="auto"/><w:jc w:val="left"/></w:pPr>',
    '<w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/>',
    '<w:color w:val="1F497D"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr></w:style>'
  )

  extra_styles <- list(
    TMLBase            = make_style("TMLBase", "TML Base", based = "", ppr = p_body, rpr = r_body),
    TMLCorpo           = make_style("TMLCorpo", "TML Corpo", based = "TMLBase", ppr = p_body, rpr = r_body),
    TMLCompacto        = make_style("TMLCompacto", "TML Compacto", based = "TMLBase", ppr = p_compact_list, rpr = r_body),
    TMLLista           = make_style("TMLLista", "TML Lista", based = "TMLBase", ppr = p_tml_lista, rpr = r_body),
    BodyText           = make_style("BodyText", "Body Text", based = "TMLBase", ppr = p_body, rpr = r_body),
    FirstParagraph     = make_style("FirstParagraph", "First Paragraph", based = "TMLBase", ppr = p_body, rpr = r_body),
    BlockText          = make_style("BlockText", "Block Text", based = "TMLBase", ppr = p_block_text, rpr = r_block_text),
    Compact            = make_style("Compact", "Compact", based = "TMLBase", ppr = p_compact_list, rpr = r_body),
    TableCaption       = make_style("TableCaption", "Table Caption", based = "TMLBase", ppr = p_caption, rpr = r_caption),
    ImageCaption       = make_style("ImageCaption", "Image Caption", based = "TMLBase", ppr = p_caption, rpr = r_caption),
    Caption            = make_style("Caption", "Caption", based = "TMLBase", ppr = p_caption, rpr = r_caption),
    TabelaTexto        = make_style("TabelaTexto", "Tabela Texto", based = "TMLBase", ppr = p_compact, rpr = r_tbl_text),
    TabelaTextoPequeno = make_style("TabelaTextoPequeno", "Tabela Texto Pequeno", based = "TMLBase", ppr = p_compact_small, rpr = r_tbl_small),
    TabelaNota         = make_style("TabelaNota", "Tabela Nota", based = "TMLBase", ppr = p_tbl_note, rpr = r_tbl_note),
    BlocoPequeno       = make_style("BlocoPequeno", "Bloco Pequeno", based = "TMLBase", ppr = p_bloco_peq, rpr = r_bloco_dir),
    BlocoDireita       = make_style("BlocoDireita", "Bloco Direita", based = "TMLBase", ppr = p_bloco_dir, rpr = r_bloco_dir),
    LinhaDespacho      = make_style("LinhaDespacho", "Linha Despacho", based = "TMLBase", ppr = p_linha_desp, rpr = r_body),
    Heading1           = h1_def,
    Heading2           = h2_def,
    Heading3           = h3_def,
    TMLTitulo1         = tml_h1_def,
    TMLTitulo2         = tml_h2_def,
    TMLTitulo3         = tml_h3_def,
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

  # 2. Atualizar numbering.xml para associar abstractNum 9 (numId 5) a TMLTitulo1..3 com fonte Greycliff CF negrito preto
  #    e abstractNum 13 (numId 4) a TMLLista com marca Symbol e indentação 360 dxa
  num_file <- file.path(tmp, "word", "numbering.xml")
  if (file.exists(num_file)) {
    num_xml <- paste(readLines(num_file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

    # Substituir abstractNumId="9" (numeração 1. / 1.1. / 1.1.1.)
    abs9_new <- paste0(
      '<w:abstractNum w:abstractNumId="9" w15:restartNumberingAfterBreak="0">',
      '<w:nsid w:val="32761C37"/><w:multiLevelType w:val="multilevel"/><w:tmpl w:val="8CC26A3A"/>',
      '<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:pStyle w:val="TMLTitulo1"/><w:lvlText w:val="%1."/><w:lvlJc w:val="left"/>',
      '<w:pPr><w:ind w:left="426" w:hanging="426"/></w:pPr>',
      '<w:rPr><w:rFonts w:ascii="Greycliff CF" w:hAnsi="Greycliff CF" w:cs="Greycliff CF" w:hint="default"/><w:b/><w:bCs/><w:color w:val="000000"/><w:sz w:val="28"/><w:szCs w:val="32"/></w:rPr></w:lvl>',
      '<w:lvl w:ilvl="1"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:pStyle w:val="TMLTitulo2"/><w:isLgl/><w:lvlText w:val="%1.%2."/><w:lvlJc w:val="left"/>',
      '<w:pPr><w:ind w:left="567" w:hanging="567"/></w:pPr>',
      '<w:rPr><w:rFonts w:ascii="Greycliff CF" w:hAnsi="Greycliff CF" w:cs="Greycliff CF" w:hint="default"/><w:b/><w:bCs/><w:color w:val="000000"/><w:sz w:val="24"/><w:szCs w:val="28"/></w:rPr></w:lvl>',
      '<w:lvl w:ilvl="2"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:pStyle w:val="TMLTitulo3"/><w:isLgl/><w:lvlText w:val="%1.%2.%3."/><w:lvlJc w:val="left"/>',
      '<w:pPr><w:ind w:left="567" w:hanging="567"/></w:pPr>',
      '<w:rPr><w:rFonts w:ascii="Greycliff CF" w:hAnsi="Greycliff CF" w:cs="Greycliff CF" w:hint="default"/><w:b/><w:bCs/><w:color w:val="000000"/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr></w:lvl>',
      '<w:lvl w:ilvl="3"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:isLgl/><w:lvlText w:val="%1.%2.%3.%4."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="1440" w:hanging="1080"/></w:pPr><w:rPr><w:color w:val="000000"/></w:rPr></w:lvl>',
      '<w:lvl w:ilvl="4"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:isLgl/><w:lvlText w:val="%1.%2.%3.%4.%5."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="1440" w:hanging="1080"/></w:pPr><w:rPr><w:color w:val="000000"/></w:rPr></w:lvl>',
      '<w:lvl w:ilvl="5"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:isLgl/><w:lvlText w:val="%1.%2.%3.%4.%5.%6."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="1800" w:hanging="1440"/></w:pPr><w:rPr><w:color w:val="000000"/></w:rPr></w:lvl>',
      '<w:lvl w:ilvl="6"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:isLgl/><w:lvlText w:val="%1.%2.%3.%4.%5.%6.%7."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="1800" w:hanging="1440"/></w:pPr><w:rPr><w:color w:val="000000"/></w:rPr></w:lvl>',
      '<w:lvl w:ilvl="7"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:isLgl/><w:lvlText w:val="%1.%2.%3.%4.%5.%6.%7.%8."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="2160" w:hanging="1800"/></w:pPr><w:rPr><w:color w:val="000000"/></w:rPr></w:lvl>',
      '<w:lvl w:ilvl="8"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:isLgl/><w:lvlText w:val="%1.%2.%3.%4.%5.%6.%7.%8.%9."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="2160" w:hanging="1800"/></w:pPr><w:rPr><w:color w:val="000000"/></w:rPr></w:lvl>',
      '</w:abstractNum>'
    )
    num_xml <- sub('<w:abstractNum w:abstractNumId="9"[^>]*>.*?</w:abstractNum>', abs9_new, num_xml)

    # Atualizar abstractNumId="13" (numId 4 — bullet points compactos TMLLista) mantendo o caractere bullet U+2022 original
    num_xml <- sub(
      '(<w:abstractNum w:abstractNumId="13"[^>]*>.*?)<w:pStyle w:val="PargrafodaLista"/>(<w:lvlText [^>]*/>)<w:lvlJc w:val="left"/><w:pPr>.*?</w:pPr><w:rPr>.*?</w:rPr>',
      paste0(
        '\\1<w:pStyle w:val="TMLLista"/>\\2<w:lvlJc w:val="left"/>',
        '<w:pPr><w:ind w:left="360" w:hanging="360"/></w:pPr>',
        '<w:rPr><w:rFonts w:ascii="Greycliff CF Light" w:hAnsi="Greycliff CF Light" w:cs="Greycliff CF Light" w:hint="default"/><w:color w:val="000000"/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>'
      ),
      num_xml
    )

    writeLines(num_xml, num_file, useBytes = TRUE)
  }

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
