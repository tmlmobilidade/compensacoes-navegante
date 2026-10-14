function RawInline(el)
  if el.format == "html" and (el.text == "<br>" or el.text == "<br/>" or el.text == "<br />") then
    return pandoc.LineBreak()
  end
end

-- Deteta se o documento é externo através de metadados no cabeçalho YAML
-- (ex: doc-tipo: externo, tipo: externo, ou doc-externo: true)
function Pandoc(doc)
  local is_ext = false
  if doc.meta["doc-tipo"] and pandoc.utils.stringify(doc.meta["doc-tipo"]) == "externo" then
    is_ext = true
  elseif doc.meta["tipo"] and pandoc.utils.stringify(doc.meta["tipo"]) == "externo" then
    is_ext = true
  elseif doc.meta["doc-externo"] and pandoc.utils.stringify(doc.meta["doc-externo"]) == "true" then
    is_ext = true
  end

  if is_ext then
    table.insert(doc.blocks, 1, pandoc.RawBlock("typst", '#metadata("externo") <doc-externo>'))
  end
  return doc
end

