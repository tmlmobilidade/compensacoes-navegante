-- docx_styles.lua — Filtro Pandoc executado APÓS o Quarto (`- quarto`, depois `- docx_styles.lua`)
--
-- 1. Desembrulha tabelas com legenda no Word:
--    Elimina a moldura exterior inserida pelo Quarto.
--
-- 2. Linha TOTAL nas tabelas:
--    Adiciona borda superior preta (`<w:top w:val="single" w:sz="8" w:space="0" w:color="000000"/>`)
--    às células da linha de TOTAL.
--
-- 3. Legendas centradas:
--    Centraliza as legendas de tabelas e figuras geradas pelo Quarto/Pandoc.
--
-- 4. Listas com marcas (bullet points) sem indentação extra:
--    Aplica numPr oficial da TML (numId 4) com indentação compacta (360 dxa).

if not FORMAT:match("docx") then
  return {}
end

function Table(tbl)
  -- 1. Desenvelopar o contentor exterior do Quarto
  if #tbl.head.rows == 0 and #tbl.colspecs == 1 and tbl.colspecs[1][1] == pandoc.AlignCenter then
    local body = tbl.bodies[1]
    if body and #body.body == 1 and #body.body[1].cells == 1 then
      return body.body[1].cells[1].contents
    end
  end

  -- 2. Processar corpos: linha TOTAL (borda superior) e linha de variação 'vs' (borda superior e inferior)
  for _, body in ipairs(tbl.bodies) do
    for _, row in ipairs(body.body) do
      local is_total = false
      local is_var = false
      for _, cell in ipairs(row.cells) do
        local txt = pandoc.utils.stringify(cell)
        if txt:match("^TOTAL") then
          is_total = true
          break
        elseif txt:match("%s+vs%s+") then
          is_var = true
          break
        end
      end
      if is_total then
        for _, cell in ipairs(row.cells) do
          local raw_tc = pandoc.RawBlock(
            "openxml",
            '<w:tcPr><w:tcBorders><w:top w:val="single" w:sz="8" w:space="0" w:color="000000"/></w:tcBorders></w:tcPr>'
          )
          cell.contents:insert(1, raw_tc)
        end
      elseif is_var then
        for _, cell in ipairs(row.cells) do
          local raw_tc = pandoc.RawBlock(
            "openxml",
            '<w:tcPr><w:tcBorders><w:top w:val="single" w:sz="8" w:space="0" w:color="000000"/><w:bottom w:val="single" w:sz="8" w:space="0" w:color="000000"/></w:tcBorders></w:tcPr>'
          )
          cell.contents:insert(1, raw_tc)
        end
      end
    end
  end

  return tbl
end

function Para(p)
  -- 3. Centrar legendas do Quarto (ImageCaption / TableCaption)
  for _, inl in ipairs(p.content) do
    if inl.t == "RawInline" and inl.format == "openxml" then
      if inl.text:match("ImageCaption") or inl.text:match("TableCaption") then
        inl.text = inl.text:gsub('<w:jc w:val="left"/>', '<w:jc w:val="center"/>')
      end
    end
  end
  return p
end

function BulletList(bl)
  -- 4. Bullet points sem indentação excessiva à esquerda
  -- Usa o estilo PargrafodaLista / numId 4 oficial do template TML com margem compacta
  local out = pandoc.List()
  local raw_p = pandoc.RawInline(
    "openxml",
    '<w:pPr><w:pStyle w:val="PargrafodaLista"/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="4"/></w:numPr><w:ind w:left="360" w:hanging="360"/></w:pPr>'
  )
  for _, item in ipairs(bl.content) do
    for _, block in ipairs(item) do
      if block.t == "Para" or block.t == "Plain" then
        local inlines = pandoc.List({ raw_p })
        for _, inl in ipairs(block.content) do
          inlines:insert(inl)
        end
        out:insert(pandoc.Para(inlines))
      else
        out:insert(block)
      end
    end
  end
  return out
end
