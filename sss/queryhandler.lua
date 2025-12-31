
local util = require("util")
local luaaliases = require("luaaliases")

local replacesub = util.replacesub
local stringsplit = util.stringsplit
local drawProgressBar = util.drawProgressBar

local queryalias = luaaliases.queryalias

--cropdataがbakedqueryの条件を満たすかを判定する
---@param bakedquery bakedquery
---@param cropdata cropdata
---@return boolean
local function matchQuery (bakedquery, cropdata)
    return assert(load("return " .. replacesub(bakedquery, cropdata)))()
end
--datasからbakedqueryとマッチするもののリストを`return`する<br>
--`return`するリストは {`slot`, `size`}<br>
--デフォルトモード
---@param bakedquery bakedquery
---@param datas_default data_default[]
---@param m? integer
---@return {slot:integer, size:integer}[]
local function querySearch_default (bakedquery, datas_default, m)
    m = m or -1
    local found = {}
    local count = 0
    drawProgressBar(30, 0, #datas_default, "Searching: ", false)
    for i, data in pairs(datas_default) do
        local slot = data["slot"]
        local size = data["size"]
        local cropdata = data["cropdata"]
        if cropdata == nil then
            goto continue
        end
        if size > 0 and matchQuery(bakedquery, cropdata) then
            if (size + count < m) or (m == -1) then
                count = count + size
                table.insert(found, {slot = slot, size = size})
            else
                table.insert(found, {slot = slot, size = m - count})
                break
            end
        end
        drawProgressBar(30, i, #datas_default, "Searching:")
        ::continue::
    end
    print("")
    table.sort(found, function (a, b) return a["slot"] > b["slot"] end)
    return found
end
--rawquery文字列をbakedquery文字列に変換する <br>
--name \<something\> -> string.find("\<name\>" ,\<something\>) <br>
--growth -> "\<gr\>" <br>
--gain -> "\<ga\>" <br>
--resistance -> "\<re\>"
---@param rawquery rawquery
---@return bakedquery
local function bakeQuery (rawquery)
    local rawquerylist = stringsplit(rawquery:gsub("%(" ," ( "):gsub("%)"," ) "))
    local nameplace = {}
    local querylist = {}
    for i, token in pairs(rawquerylist) do
        table.insert(querylist, queryalias[token] or token)
        if querylist[i] == "name" then
            table.insert(nameplace, i)
        end
    end
    for _, place in pairs(nameplace) do
        querylist[place] = "string.find(<name>,"
        querylist[place + 1] = string.format("%q", rawquerylist[place + 1])..")"
    end
    return select(1,table.concat(querylist, " "):gsub("growth","<gr>"):gsub("gain","<ga>"):gsub("resistance","<re>"))
end
--list/tableになっているクエリを結合する <br>
--`return`はrawquery
---@param queryl querylist
---@return rawquery
local function queryConcat (queryl)
    return "("..table.concat(queryl,") and (")..")"
end

return {
    matchQuery = matchQuery,
    querySearch_default =  querySearch_default,
    bakeQuery = bakeQuery,
    queryConcat = queryConcat
}