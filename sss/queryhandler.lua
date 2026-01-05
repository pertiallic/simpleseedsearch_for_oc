
local util = require("util")
local luaaliases = require("luaaliases")

local replacesub = util.replacesub
local stringsplit = util.stringsplit

local queryalias = luaaliases.queryalias

--cropdataがbakedqueryの条件を満たすかを判定する
---@param bakedquery bakedquery
---@param cropdata cropdata
---@return boolean
local function matchQuery (bakedquery, cropdata)
    return assert(load("return " .. replacesub(bakedquery, cropdata)))()
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
    bakeQuery = bakeQuery,
    queryConcat = queryConcat
}