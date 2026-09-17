function RawInline(el)
  if el.format == "html" and (el.text == "<br>" or el.text == "<br/>" or el.text == "<br />") then
    return pandoc.LineBreak()
  end
end

