-- Processor companion for emoji_u17.
-- 1. Pressing 1-9/0/Space/Return on a v+category hint jumps to that category.
-- 2. Normal candidate navigation and numeric selection are left to key_binder/selector.

local processor = {}

local kAccepted = 1
local kNoop = 2

local CATEGORY_ORDER = {
  "guoqi", "biaoqing", "ren", "dongwu", "zhiwu", "shiwu", "lvxing", "jiaotong",
  "huodong", "wuti", "yifu", "fuhao", "jiantou", "xingzuo", "shuzi", "zujian"
}

local function startswith(s, prefix)
  return string.sub(s, 1, #prefix) == prefix
end

local function split(s, sep)
  local t = {}
  if not s or s == "" then return t end
  sep = sep or ","
  local pattern = "([^" .. sep .. "]+)"
  for item in string.gmatch(s, pattern) do
    table.insert(t, item)
  end
  return t
end

local function user_dir()
  if rime_api and rime_api.get_user_data_dir then
    return rime_api.get_user_data_dir()
  end
  return "."
end

local function load_categories(env)
  env.cat_alias = {}
  env.cat_codes = {}
  local path = user_dir() .. "/emoji_u17_categories.tsv"
  local f = io.open(path, "r")
  if not f then return end
  for line in f:lines() do
    if line ~= "" and not startswith(line, "#") then
      local code, targets = string.match(line, "^([^\t]+)\t([^\t]+)")
      if code and targets then
        env.cat_alias[code] = split(targets, ",")
        table.insert(env.cat_codes, code)
      end
    end
  end
  f:close()
end

local function matching_category_codes(env, prefix)
  if not env.cat_alias then load_categories(env) end
  local codes = {}

  -- Keep v mode to a curated, Chinese category list.
  for _, code in ipairs(CATEGORY_ORDER) do
    if env.cat_alias[code] and (prefix == "" or startswith(code, prefix)) then
      table.insert(codes, code)
    end
  end

  return codes
end

local function selection_index(repr)
  if repr == "space" or repr == "Return" then return 1 end
  if repr == "1" then return 1 end
  if repr == "2" then return 2 end
  if repr == "3" then return 3 end
  if repr == "4" then return 4 end
  if repr == "5" then return 5 end
  if repr == "6" then return 6 end
  if repr == "7" then return 7 end
  if repr == "8" then return 8 end
  if repr == "9" then return 9 end
  if repr == "0" then return 10 end
  return nil
end

local function replace_input(context, text)
  local ok = pcall(function()
    context.input = text
    context.caret_pos = #text
  end)
  if ok then return end

  -- Fallback for older builds where input assignment is unavailable.
  context:clear()
  for i = 1, #text do
    context:push_input(string.sub(text, i, i))
  end
end

function processor.init(env)
  load_categories(env)
end

function processor.func(key, env)
  local context = env.engine.context
  local input = context.input or ""
  if input == "" then return kNoop end

  input = string.lower(input)
  if not startswith(input, "v") then return kNoop end

  local repr = key:repr()
  local code_prefix = string.sub(input, 2)

  if env.last_input ~= input then
    env.last_input = input
    env.cat_page = 0
  end

  -- Once the full category code is entered, vguoqi/vshiwu should behave like a
  -- normal emoji list. Numeric selection and paging must be handled by Rime.
  if env.cat_alias and env.cat_alias[code_prefix] then
    return kNoop
  end

  local matches = matching_category_codes(env, code_prefix)
  local page_size = 10
  local max_page = math.max(0, math.ceil(#matches / page_size) - 1)

  -- Track the visible category page so selecting 1 after PageDown/+ maps to the
  -- first item on that page, not the first item of page 1.
  if repr == "equal" or repr == "plus" or repr == "KP_Add" or repr == "bracketright" or repr == "Page_Down" then
    env.cat_page = math.min(max_page, (env.cat_page or 0) + 1)
    return kNoop
  end
  if repr == "minus" or repr == "KP_Subtract" or repr == "bracketleft" or repr == "Page_Up" then
    env.cat_page = math.max(0, (env.cat_page or 0) - 1)
    return kNoop
  end

  local idx = selection_index(repr)
  if not idx then return kNoop end

  local absolute_idx = (env.cat_page or 0) * page_size + idx
  local code = matches[absolute_idx]
  if code then
    replace_input(context, "v" .. code)
    return kAccepted
  end

  return kNoop
end

return processor
