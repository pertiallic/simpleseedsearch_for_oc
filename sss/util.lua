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
--ある値が配列中にあるかを調べる
---@param elem any
---@param arr any[]
---@return boolean
local function ifInArray (elem, arr)
    for _, v in pairs(arr) do
        if v == elem then return true end
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

return {
    trim = trim,
    stringsplit = stringsplit,
    format = format,
    replacesub = replacesub,
    ifInArray = ifInArray,
    generateProgressBar = generateProgressBar,
    drawProgressBar = drawProgressBar,
}