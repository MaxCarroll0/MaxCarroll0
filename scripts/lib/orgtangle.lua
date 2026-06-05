-- scripts/lib/orgtangle.lua: split .org literate files into per-language line counts (babel src blocks vs prose).

local orgtangle = {}

-- org-babel language token -> tokei/Linguist name (so it classifies and colours correctly).
local TOKEN = {
  ["emacs-lisp"] = "Emacs Lisp",
  ["elisp"] = "Emacs Lisp",
  ["lisp"] = "Common Lisp",
  ["common-lisp"] = "Common Lisp",
  ["scheme"] = "Scheme",
  ["python"] = "Python",
  ["py"] = "Python",
  ["sh"] = "Shell",
  ["bash"] = "Shell",
  ["shell"] = "Shell",
  ["js"] = "JavaScript",
  ["javascript"] = "JavaScript",
  ["typescript"] = "TypeScript",
  ["c"] = "C",
  ["cpp"] = "C++",
  ["c++"] = "C++",
  ["rust"] = "Rust",
  ["lua"] = "Lua",
  ["haskell"] = "Haskell",
  ["ocaml"] = "OCaml",
  ["nix"] = "Nix",
  ["latex"] = "TeX",
  ["org"] = "Org",
}

local function canon(tok)
  tok = tok:lower()
  return TOKEN[tok] or tok
end

-- One file's text -> { totals = {lang -> nonblank lines}, line_lang = {lineNo -> lang} }.
local function parse(text)
  local totals, line_lang = {}, {}
  local in_src, cur, ln = false, "Org", 0
  for line in (text .. "\n"):gmatch("(.-)\n") do
    ln = ln + 1
    local begin_lang = line:lower():match("^%s*#%+begin_src%s+([%w_+-]+)")
    local is_end = line:lower():match("^%s*#%+end_src")
    local lang
    if begin_lang then
      line_lang[ln], lang = "Org", "Org"
      in_src, cur = true, canon(begin_lang)
    elseif is_end then
      line_lang[ln], lang = "Org", "Org"
      in_src, cur = false, "Org"
    else
      lang = in_src and cur or "Org"
      line_lang[ln] = lang
    end
    if line:match("%S") then
      totals[lang] = (totals[lang] or 0) + 1
    end
  end
  return { totals = totals, line_lang = line_lang }
end

-- Scan every .org file in `file_lang`; aggregate totals and keep a per-file line->lang map for blame.
function orgtangle.scan(dir, file_lang)
  local totals, lines = {}, {}
  for file, lang in pairs(file_lang) do
    if lang == "Org" then
      local fh = io.open(dir .. "/" .. file, "r")
      if fh then
        local p = parse(fh:read("a") or "")
        fh:close()
        lines[file] = p.line_lang
        for l, n in pairs(p.totals) do
          totals[l] = (totals[l] or 0) + n
        end
      end
    end
  end
  return { totals = totals, lines = lines }
end

return orgtangle
