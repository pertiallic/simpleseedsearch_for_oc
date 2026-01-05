local unicode = require("unicode")
local term = require("term")
--前と後ろの空白文字を消す
---@param s string
---@return string
local function trim (s)
   return select(1, s:gsub("^%s*(.-)%s*$", "%1"))
end
--Source - https://stackoverflow.com/questions/1426954/split-string-in-lua<br>
--Posted by user973713, modified by community. See post 'Timeline' for change history<br>
--Retrieved 2025-12-25, License - CC BY-SA 4.0<br>
--名前を`stringsplit`にして、空白文字で区切るようにした
---@param inputstr string
---@return string[]
local function stringsplit (inputstr)
  local t = {}
  for str in string.gmatch(inputstr, "([^%s]+)") do
    table.insert(t, str)
  end
  return t
end
--前後の空白文字を削除してすべての文字を小文字にする
---@param s string
---@return string
local function format (s)
    return unicode.lower(trim(s))
end
--"\<name\>"などを`cropdata`で置き換える
---@param s string
---@param cropdata cropdata
---@return string
local function replacesub (s, cropdata)
    return select(1,s:gsub("<name>", string.format("%q", format(cropdata["name"]) or "")):
             gsub("<gr>", tostring(cropdata["growth"] or 0)):
             gsub("<ga>", tostring(cropdata["gain"] or 0)):
             gsub("<re>", tostring(cropdata["resistance"] or 0)))
end
--二つの値が一致するか調べる(table対応)
---@param a any
---@param b any
---@return boolean
local function tblEqual (a, b)
  if type(a) ~= type(b) then
    return false
  end
  if type(a) ~= "table" then
    return a == b  
  end
  for k, v in pairs(a) do
    if b[k] == nil then
      return false
    end
  end
  for k, v  in pairs(b) do
    if a[k] == nil then
      return false
    end
    if not tblEqual(a[k],v) then
      return false
    end
  end
  return true
end
--ある値が配列中にあるかを調べる
---@param elem any
---@param arr any[]
---@return boolean
local function ifInArray (elem, arr)
    for _, v in pairs(arr) do
        if tblEqual(v,elem) then return true end
    end
    return false
end
--プログレスバーを生成する
---@param width integer
---@param progress integer
---@param complete integer
---@return string
local function generateProgressBar (width, progress, complete)
    local tmp = "["
    local numprog = math.ceil(progress * width / complete - 0.5)
    tmp = tmp .. string.rep("=", numprog)
    tmp = tmp .. string.rep(" ", width - numprog)
    return tmp .. "]"
end
--プログレスバーを描画する
---@param width integer
---@param progress integer
---@param complete integer
---@param before string
---@param written? boolean
local function drawProgressBar (width, progress, complete, before, written)
    if written == nil then
        written = true
    end
    term.clearLine()
    io.write(before .. generateProgressBar(width, progress, complete) .. " " .. progress .. "/" .. complete)
end
--通知する
---@param proxy any
---@param mode string
---@param message? string
---@param pitch? integer
---@param time? number
local function notify (proxy, mode, message, pitch, time)
    if mode == "note" then
        proxy.trigger(pitch)
    elseif mode == "chat" then
        proxy.say(message)
    elseif mode == "alarm" then
        proxy.activate()
        ---@diagnostic disable-next-line:undefined-field
        os.sleep(time)
        proxy.deactivate()
    elseif mode == "beep" then
        proxy.beep("-")
    end
end
--イテレーターの大きさを返す
---@param iter fun():any
---@return integer
local function countIterLen(iter)
    local c = 0
    for _ in iter do
        c = c + 1
    end
    return c
end

return {
    trim = trim,
    stringsplit = stringsplit,
    format = format,
    replacesub = replacesub,
    tblEqual = tblEqual,
    ifInArray = ifInArray,
    generateProgressBar = generateProgressBar,
    drawProgressBar = drawProgressBar,
    notify = notify,
    countIterLen = countIterLen
}