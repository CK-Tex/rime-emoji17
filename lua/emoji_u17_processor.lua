-- Processor companion for emoji_u17.
-- 1. Pressing 1-9/0/Space/Return on a v+category hint jumps to that category.
-- 2. Clicking a v+category hint with mouse also jumps to that category.
-- 3. Normal candidate navigation and numeric selection are left to key_binder/selector.

local processor = {}

local kAccepted = 1
local kNoop = 2

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

local function category_title(code, title)
  if CATEGORY_TITLE[code] then return CATEGORY_TITLE[code] end
  if title and title ~= "" and title ~= code then return title end
  return code
end

local function load_categories(env)
  env.cat_alias = {}
  env.cat_codes = {}
  env.cat_title = {}
  env.category_text_to_code = {}

  local path = user_dir() .. "/emoji_u17_categories.tsv"
  local f = io.open(path, "r")
  if not f then return end
  for line in f:lines() do
    if line ~= "" and not startswith(line, "#") then
      local code, targets, title = string.match(line, "^([^\t]+)\t([^\t]+)\t?(.*)$")
      if code and targets then
        local display_title = category_title(code, title)
        env.cat_alias[code] = split(targets, ",")
        env.cat_title[code] = display_title
        table.insert(env.cat_codes, code)
      end
    end
  end
  f:close()

  -- Only the curated category hints are clickable jump targets.
  -- This mirrors emoji_u17.lua's CATEGORY_ORDER and avoids duplicate raw Unicode subgroup names.
  for _, code in ipairs(CATEGORY_ORDER) do
    local title = env.cat_title[code]
    if title and not env.category_text_to_code[title] then
      env.category_text_to_code[title] = code
    end
  end
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

local function category_code_from_selected_candidate(ctx, env)
  local cand = ctx:get_selected_candidate()
  if not cand or cand.type ~= "emoji_category" then return nil end

  if env.category_text_to_code and env.category_text_to_code[cand.text] then
    return env.category_text_to_code[cand.text]
  end

  -- Fallback: use current selected index on the visible category list.
  local input = string.lower(ctx.input or "")
  if not startswith(input, "v") then return nil end
  local matches = matching_category_codes(env, string.sub(input, 2))
  local ok, code = pcall(function()
    local comp = ctx.composition
    if comp:empty() then return nil end
    local seg = comp:back()
    return matches[(seg.selected_index or 0) + 1]
  end)
  if ok then return code end
  return nil
end

local function connect_notifier_first(notifier, fn)
  -- Newer librime-lua supports notifier groups. group 0 runs before default callbacks.
  -- That is needed for commit_notifier so the category title is replaced before Engine::OnCommit reads it.
  local ok, conn = pcall(function() return notifier:connect(fn, 0) end)
  if ok then return conn end
  return notifier:connect(fn)
end

function processor.init(env)
  load_categories(env)

  env.commit_conn = connect_notifier_first(env.engine.context.commit_notifier, function(ctx)
    local input = string.lower(ctx.input or "")
    if input == "" or not startswith(input, "v") then return end

    local code_prefix = string.sub(input, 2)
    if env.cat_alias and env.cat_alias[code_prefix] then return end

    local code = category_code_from_selected_candidate(ctx, env)
    if not code then return end

    local cand = ctx:get_selected_candidate()
    if cand and cand.type == "emoji_category" then
      -- Mouse click commits the candidate's text. Make that commit empty, then restore input below.
      cand.text = ""
      env.pending_category_input = "v" .. code
    end
  end)

  env.update_conn = env.engine.context.update_notifier:connect(function(ctx)
    local target = env.pending_category_input
    if not target or target == "" then return end
    env.pending_category_input = nil
    replace_input(ctx, target)
  end)
end

function processor.fini(env)
  if env.commit_conn then env.commit_conn:disconnect() end
  if env.update_conn then env.update_conn:disconnect() end
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
