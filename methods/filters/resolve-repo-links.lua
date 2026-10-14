-- Pandoc Lua filter to resolve relative paths (../code/, ../lists/, etc.)
-- to full GitHub repository URLs when rendering the Quarto book.

local repo_base = "https://github.com/tmlmobilidade/compensacoes-navegante"
local branch = "main"

local patterns = {
  "^%.%./(code/.*)$",
  "^(code/.*)$",
  "^%.%./(lists/.*)$",
  "^(lists/.*)$",
  "^%.%./(data/.*)$",
  "^(data/.*)$",
  "^%.%./(README%.md.*)$",
  "^(README%.md.*)$"
}

function Link(el)
  local target = el.target
  if not target then return el end

  for _, pat in ipairs(patterns) do
    local match = target:match(pat)
    if match then
      -- If it's a directory (ends with / or is just 'lists/' or 'code/'), GitHub uses /tree/
      -- If it's a file, GitHub uses /blob/
      local action = "blob"
      if match:sub(-1) == "/" then
        action = "tree"
      end
      el.target = string.format("%s/%s/%s/%s", repo_base, action, branch, match)
      break
    end
  end

  return el
end

