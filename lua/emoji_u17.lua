-- Standalone Emoji 17 translator for Rime.
-- Files expected in the Rime user data directory:
--   emoji_u17.tsv
--   emoji_u17_categories.tsv

local translator = {}

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

local function split_tab(line)
  local fields = {}
  local start = 1
  while true do
    local pos = string.find(line, "\t", start, true)
    if not pos then
      table.insert(fields, string.sub(line, start))
      break
    end
    table.insert(fields, string.sub(line, start, pos - 1))
    start = pos + 1
  end
  return fields
end

local function startswith(s, prefix)
  return string.sub(s, 1, #prefix) == prefix
end

local function add_unique(list, seen, value)
  if value and value ~= "" and not seen[value] then
    seen[value] = true
    table.insert(list, value)
  end
end

local function push_index(env, code, id)
  if not code or code == "" then return end
  env.exact[code] = env.exact[code] or {}
  table.insert(env.exact[code], id)
  local max_len = math.min(#code, 24)
  for i = 1, max_len do
    local p = string.sub(code, 1, i)
    env.prefix[p] = env.prefix[p] or {}
    table.insert(env.prefix[p], id)
  end
end

local function user_dir()
  if rime_api and rime_api.get_user_data_dir then
    return rime_api.get_user_data_dir()
  end
  return "."
end

local CATEGORY_TITLE = {
  biaoqing = "表情", xiaolian = "笑脸", qinggan = "情感",
  ren = "人物", renwu = "人物", shenti = "身体", zujian = "组件", bujian = "部件",
  dongwu = "动物", ziran = "自然", zhiwu = "植物", hua = "花",
  shiwu = "食物", yinliao = "饮料", chi = "吃", shuiguo = "水果",
  lvxing = "旅行", didian = "地点", jiaotong = "交通", che = "车",
  huodong = "活动", yundong = "运动", youxi = "游戏",
  wuti = "物体", dongxi = "东西", yifu = "衣服",
  fuhao = "符号", jiantou = "箭头", xingzuo = "星座", shuzi = "数字",
  guoqi = "国旗", qizhi = "旗帜", guojia = "国家旗帜",
  biaoqingqinggan = "表情情感", smileysemotion = "表情情感",
  renwushenti = "人物身体", peoplebody = "人物身体",
  animalsnature = "动物自然", fooddrink = "食物饮料", travelplaces = "旅行地点",
  activities = "活动", objects = "物品", symbols = "符号", flags = "旗帜国旗",
  component = "组件",
}

local CATEGORY_ORDER = {
  "guoqi", "biaoqing", "ren", "dongwu", "zhiwu", "shiwu", "lvxing", "jiaotong",
  "huodong", "wuti", "yifu", "fuhao", "jiantou", "xingzuo", "shuzi", "zujian"
}

local function category_title(code, title)
  if CATEGORY_TITLE[code] then return CATEGORY_TITLE[code] end
  if title and title ~= "" and title ~= code then return title end
  return code
end

local function read_data(env)
  env.entries = {}
  env.exact = {}
  env.prefix = {}
  env.categories = {}
  env.cat_alias = {}
  env.cat_title = {}
  env.cat_codes = {}

  local base = user_dir()
  local data_path = base .. "/emoji_u17.tsv"
  local f = io.open(data_path, "r")
  if not f then
    return false, "找不到 emoji_u17.tsv"
  end

  for line in f:lines() do
    if not startswith(line, "#") and line ~= "" then
      local cols = split_tab(line)
      local emoji = cols[1] or ""
      local name = cols[2] or ""
      local group = cols[3] or ""
      local subgroup = cols[4] or ""
      local version = cols[5] or ""
      local codes = cols[6] or ""
      local terms = cols[7] or ""
      if emoji ~= "" then
        local id = #env.entries + 1
        local e = {
          text = emoji,
          name = name,
          group = group,
          subgroup = subgroup,
          version = version,
          codes = split(codes, ","),
          terms = terms,
        }
        table.insert(env.entries, e)
        for _, code in ipairs(e.codes) do
          push_index(env, code, id)
        end
        env.categories["group:" .. group] = env.categories["group:" .. group] or {}
        table.insert(env.categories["group:" .. group], id)
        env.categories["subgroup:" .. subgroup] = env.categories["subgroup:" .. subgroup] or {}
        table.insert(env.categories["subgroup:" .. subgroup], id)
      end
    end
  end
  f:close()

  local cat_path = base .. "/emoji_u17_categories.tsv"
  local cf = io.open(cat_path, "r")
  if cf then
    for line in cf:lines() do
      if not startswith(line, "#") and line ~= "" then
        local code, targets, title = string.match(line, "^([^\t]+)\t([^\t]+)\t?(.*)$")
        if code and targets then
          env.cat_alias[code] = split(targets, ",")
          env.cat_title[code] = category_title(code, title)
          table.insert(env.cat_codes, code)
        end
      end
    end
    cf:close()
  end

  env.loaded = true
  return true, nil
end

local function append_split_parts(parts, seen, text, sep, limit)
  if not text or text == "" then return end
  local n = 0
  for _, item in ipairs(split(text, sep)) do
    item = string.gsub(item, "^%s+", "")
    item = string.gsub(item, "%s+$", "")
    if item ~= "" and not seen[item] then
      seen[item] = true
      table.insert(parts, item)
      n = n + 1
      if limit and n >= limit then return end
    end
  end
end

local function code_hint(e, input)
  local matches = {}
  local seen = {}
  if input and input ~= "" then
    for _, code in ipairs(e.codes) do
      if startswith(code, input) then
        add_unique(matches, seen, code)
        if #matches >= 3 then break end
      end
    end
  end
  if #matches == 0 then
    for _, code in ipairs(e.codes) do
      add_unique(matches, seen, code)
      if #matches >= 3 then break end
    end
  end
  return matches
end

local function top_terms_comment(e)
  local parts = {}
  local seen = {}
  append_split_parts(parts, seen, e.terms, "|", 1)

  if #parts == 0 then return "" end
  return " " .. table.concat(parts, " / ")
end

local function entry_comment(e, input, v_mode)
  -- Normal keyword mode stays compact: emoji only, no right-side comment.
  -- v+category mode shows only the two most useful Simplified Chinese hints.
  if v_mode then
    return top_terms_comment(e)
  end
  return ""
end

local function yield_entry(env, id, input, seg, exact, v_mode)
  local e = env.entries[id]
  if not e then return end
  local c = Candidate("emoji", seg.start, seg._end, e.text, entry_comment(e, input, v_mode))
  if exact then
    c.quality = 1000 - id / 100000
  else
    c.quality = 500 - id / 100000
  end
  yield(c)
end

local function collect_category_ids(env, code)
  local targets = env.cat_alias and env.cat_alias[code]
  if not targets then return nil end
  local seen = {}
  local ids = {}
  for _, target in ipairs(targets) do
    local list = env.categories[target] or {}
    for _, id in ipairs(list) do
      add_unique(ids, seen, id)
    end
  end
  return ids
end

local function yield_category_entries(env, seg, code)
  local ids = collect_category_ids(env, code)
  if not ids then return false end
  for _, id in ipairs(ids) do
    local e = env.entries[id]
    local c = Candidate("emoji", seg.start, seg._end, e.text, entry_comment(e, nil, true))
    c.quality = 850 - id / 100000
    yield(c)
  end
  return true
end

local function yield_category_candidate(env, seg, code, rank)
  local title = env.cat_title[code] or code
  local c = Candidate("emoji_category", seg.start, seg._end, title, "")
  c.quality = 1200 - rank / 1000
  yield(c)
end

local function matching_category_codes(env, prefix)
  local codes = {}

  -- Only expose the curated Chinese category set in v mode.
  -- The raw Unicode subgroup names are intentionally hidden because they are too
  -- numerous and make the candidate bar messy.
  for _, code in ipairs(CATEGORY_ORDER) do
    if env.cat_alias[code] and (prefix == "" or startswith(code, prefix)) then
      table.insert(codes, code)
    end
  end

  return codes
end

local function yield_category_suggestions(env, seg, prefix)
  local codes = matching_category_codes(env, prefix)
  for rank, code in ipairs(codes) do
    yield_category_candidate(env, seg, code, rank)
  end
  return #codes > 0
end

local function same_category_targets(env, codes)
  if #codes == 0 then return false end
  local first = table.concat(env.cat_alias[codes[1]] or {}, ",")
  if first == "" then return false end
  for i = 2, #codes do
    if table.concat(env.cat_alias[codes[i]] or {}, ",") ~= first then
      return false
    end
  end
  return true
end

function translator.init(env)
  read_data(env)
end

function translator.fini(env)
end

function translator.func(input, seg, env)
  if not env.loaded then
    local ok, err = read_data(env)
    if not ok then
      if input == "emoji" then
        yield(Candidate("emoji", seg.start, seg._end, "emoji_u17.tsv", " " .. (err or "数据未加载")))
      end
      return
    end
  end

  if input == nil or input == "" then return end
  input = string.lower(input)

  -- v + category. v shows category hints; vguoqi shows all flags.
  if startswith(input, "v") then
    local code = string.sub(input, 2)
    if code == "" then
      yield_category_suggestions(env, seg, "")
      return
    end
    if env.cat_alias[code] then
      yield_category_entries(env, seg, code)
      return
    end

    local matches = matching_category_codes(env, code)
    if #matches > 0 then
      for rank, cat_code in ipairs(matches) do
        yield_category_candidate(env, seg, cat_code, rank)
      end
      -- If the prefix has narrowed down to one category, or multiple aliases of
      -- the same category, immediately show that category's emoji entries below
      -- the category hint. This makes inputs like "vbiao" useful even before
      -- typing the full "vbiaoqing".
      if #matches == 1 or same_category_targets(env, matches) then
        yield_category_entries(env, seg, matches[1])
      end
      return
    end
  end

  local emitted = {}
  local exact = env.exact[input]
  if exact then
    for _, id in ipairs(exact) do
      if not emitted[id] then
        emitted[id] = true
        yield_entry(env, id, input, seg, true)
      end
    end
  end

  local pref = env.prefix[input]
  if pref then
    local n = 0
    for _, id in ipairs(pref) do
      if not emitted[id] then
        emitted[id] = true
        yield_entry(env, id, input, seg, false)
        n = n + 1
        if n >= 200 then break end
      end
    end
  end
end

return translator
