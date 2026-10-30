if not FORMAT:match("docx") then
  return {}
end

local pass1 = {
  Table = function(tbl)
    -- 1. Desenvelopar o contentor exterior do Quarto
    if #tbl.head.rows == 0 and #tbl.colspecs == 1 and tbl.colspecs[1][1] == pandoc.AlignCenter then
      local body = tbl.bodies[1]
      if body and #body.body == 1 and #body.body[1].cells == 1 then
        return body.body[1].cells[1].contents
      end
    end

    -- 2. Processar corpos: linha TOTAL, subtotais, sombreados e cores
    for _, body in ipairs(tbl.bodies) do
      local num_rows = #body.body
      for row_idx, row in ipairs(body.body) do
        local txt1 = pandoc.utils.stringify(row.cells[1])
        local next_txt1 = (row_idx < num_rows) and pandoc.utils.stringify(body.body[row_idx + 1].cells[1]) or ""

        local is_total = txt1:match("^TOTAL")
        local is_var   = txt1:match("%s+vs%s+")

        -- Tabela 5: Linha horizontal abaixo do ano anterior (antes dos meses)
        local is_subtot_ant = txt1:match("^Subtotal%s+%d+%s+solicitado e pago") and (next_txt1:match("^%a%a%a/%d%d") or next_txt1:match("^%*%*%a%a%a/%d%d"))

        -- Tabela 5: Linha horizontal abaixo do mês atual (antes de Subtotal 2026 solicitado)
        local is_mes_atual_border = next_txt1:match("^Subtotal%s+%d+%s+solicitado$")

        -- Tabela 5: Sombreado nas linhas plurianuais (Subtotal 2024-2026)
        local is_plurianual = txt1:match("^Subtotal%s+%d+%-%d+")

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
        elseif is_subtot_ant or is_mes_atual_border then
          for _, cell in ipairs(row.cells) do
            local raw_tc = pandoc.RawBlock(
              "openxml",
              '<w:tcPr><w:tcBorders><w:bottom w:val="single" w:sz="8" w:space="0" w:color="000000"/></w:tcBorders></w:tcPr>'
            )
            cell.contents:insert(1, raw_tc)
          end
        elseif is_plurianual then
          for _, cell in ipairs(row.cells) do
            local raw_tc = pandoc.RawBlock(
              "openxml",
              '<w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="EAEAEA"/></w:tcPr>'
            )
            cell.contents:insert(1, raw_tc)
          end
        end

        -- Cores na coluna Estado (Pago -> Verde #27AE60, Por pagar -> Vermelho #C0392B)
        for _, cell in ipairs(row.cells) do
          local ctxt = pandoc.utils.stringify(cell):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
          if ctxt == "Pago" then
            local raw_r = pandoc.RawInline("openxml", '<w:r><w:rPr><w:color w:val="27AE60"/></w:rPr><w:t>Pago</w:t></w:r>')
            cell.contents = { pandoc.Plain({ raw_r }) }
          elseif ctxt == "Por pagar" then
            local raw_r = pandoc.RawInline("openxml", '<w:r><w:rPr><w:color w:val="C0392B"/></w:rPr><w:t>Por pagar</w:t></w:r>')
            cell.contents = { pandoc.Plain({ raw_r }) }
          end
        end
      end
    end
    return tbl
  end,

  Para = function(p)
    -- 3. Centrar legendas do Quarto
    for _, inl in ipairs(p.content) do
      if inl.t == "RawInline" and inl.format == "openxml" then
        if inl.text:match("ImageCaption") or inl.text:match("TableCaption") then
          inl.text = inl.text:gsub('<w:jc w:val="left"/>', '<w:jc w:val="center"/>')
        end
      end
    end
    return p
  end,

  BlockQuote = function(bq)
    -- 5. Citações (Blockquotes): itálico, cinzento escuro (#404040), indentação e barra à esquerda
    local out = pandoc.List()
    local num_blocks = #bq.content
    for blk_idx, blk in ipairs(bq.content) do
      if blk.t == "BulletList" then
        local num_items = #blk.content
        for item_idx, item in ipairs(blk.content) do
          local is_last = (blk_idx == num_blocks and item_idx == num_items)
          local spacing = is_last and '<w:spacing w:before="40" w:after="240" w:line="260" w:lineRule="auto"/>'
                                  or '<w:spacing w:before="40" w:after="40" w:line="260" w:lineRule="auto"/>'
          for _, subblk in ipairs(item) do
            if subblk.t == "Para" or subblk.t == "Plain" then
              local raw_p = pandoc.RawInline(
                "openxml",
                '<w:pPr><w:pStyle w:val="BlockText"/><w:pBdr><w:left w:val="single" w:sz="12" w:space="12" w:color="B0B0B0"/></w:pBdr>' .. spacing .. '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="4"/></w:numPr><w:ind w:left="920" w:hanging="360" w:right="360"/><w:rPr><w:i/><w:iCs/><w:color w:val="404040"/></w:rPr></w:pPr>'
              )
              local inlines = pandoc.List({ raw_p })
              for _, inl in ipairs(subblk.content) do
                inlines:insert(inl)
              end
              out:insert(pandoc.Para(inlines))
            else
              out:insert(subblk)
            end
          end
        end
      elseif blk.t == "Para" or blk.t == "Plain" then
        local is_last = (blk_idx == num_blocks)
        local spacing = is_last and '<w:spacing w:before="80" w:after="240" w:line="260" w:lineRule="auto"/>'
                                or '<w:spacing w:before="80" w:after="80" w:line="260" w:lineRule="auto"/>'
        local raw_p = pandoc.RawInline(
          "openxml",
          '<w:pPr><w:pStyle w:val="BlockText"/><w:pBdr><w:left w:val="single" w:sz="12" w:space="12" w:color="B0B0B0"/></w:pBdr>' .. spacing .. '<w:ind w:left="720" w:right="360"/><w:rPr><w:i/><w:iCs/><w:color w:val="404040"/></w:rPr></w:pPr>'
        )
        local inlines = pandoc.List({ raw_p })
        for _, inl in ipairs(blk.content) do
          inlines:insert(inl)
        end
        out:insert(pandoc.Para(inlines))
      else
        out:insert(blk)
      end
    end
    return out
  end
}

local pass2 = {
  BulletList = function(bl)
    -- 4. Listas com marcas (bullet points) normais sem indentação excessiva
    local out = pandoc.List()
    local raw_p = pandoc.RawInline(
      "openxml",
      '<w:pPr><w:pStyle w:val="TMLLista"/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="4"/></w:numPr><w:ind w:left="360" w:hanging="360"/></w:pPr>'
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
}

return { pass1, pass2 }
