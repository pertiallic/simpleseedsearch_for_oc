local serialization = require("serialization")
local util = require("util")
local queryhandler = require("queryhandler")

local drawProgressBar = util.drawProgressBar
local bakeQuery = queryhandler.bakeQuery
local matchQuery = queryhandler.matchQuery
local queryConcat = queryhandler.queryConcat

--datasからbakedqueryとマッチするもののリストを`return`する <br>
--`return`するリストは {`slot`, `size`}
---@param bakedquery bakedquery
---@param datas_default data_defaultiter
---@param datasize integer
---@param lang_searching string
---@param m? integer
---@return slotdata_default[]
local function querySearch_default (bakedquery, datas_default, datasize, lang_searching, m)
    m = m or -1
    local found = {}
    local count = 0
    drawProgressBar(30, 0, datasize, lang_searching, false)
    local i = 1
    for data in datas_default do
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
        ::continue::
        drawProgressBar(30, i, datasize, lang_searching)
        i = i + 1
    end
    print("")
    table.sort(found, function (a, b) return a["slot"] > b["slot"] end)
    return found
end
--`data_default`のイテレーターとインベントリの大きさ(=イテレーターの大きさ)を返す
---@param transposerproxy any
---@param side integer
---@return data_defaultiter
---@return integer
local function getCropStatuses_default (transposerproxy, side)
    local i = 0
    local iter = transposerproxy.getAllStacks(side)
    return (function ()
        local d = iter()
        i = i + 1
        if d then return {slot = i, size = d["size"], cropdata = d["crop"]} end
    end), transposerproxy.getInventorySize(side)
end
--`slotdatas_default`に入っている種の数を返す
---@param slotdatas_default slotdata_default[]
---@return integer
local function countSeeds_default (slotdatas_default)
    local c = 0
    for _, data in pairs(slotdatas_default) do
        c = c + data["size"]
    end
    return c
end
--`querylist`と`datas`から条件を満たす種の数を返す
---@param querylist querylist
---@param datas_default data_defaultiter
---@param lang_searching string
---@return integer
local function getSeedsCountByQuery_default (querylist, datas_default, datasize, lang_searching)
    return countSeeds_default(querySearch_default(bakeQuery(queryConcat(querylist)),datas_default, datasize, lang_searching, -1))
end
--1スタック分だけ搬出する
---@param transosperproxy any
---@param fromside integer
---@param toside integer
---@param size integer
---@param slot integer
---@param searchstart? integer
---@return integer
---@return integer
local function depositOneStack_default (transosperproxy, fromside, toside, size, slot, searchstart)
    searchstart = searchstart or 1
    local tosize = transosperproxy.getInventorySize(toside)
    for i = searchstart, tosize do
        local stack = transosperproxy.getStackInSlot(toside, i)
        if stack == nil then
            return transosperproxy.transferItem(fromside, toside, size, slot, i), i
        end
    end
    return 0, 0
end
--クエリ、データなどからアイテムを搬出する <br>
---@param bakedquery bakedquery
---@param transposerproxy any
---@param fromside integer
---@param toside integer 
---@param langs {foundnoseed:string, searching:string, depositing: string, depositedseed:string}
---@param datas_default? data_defaultiter
---@param datasize? integer
---@param m? integer
---@return true
local function deposit_default (bakedquery, transposerproxy, fromside, toside, langs, datas_default, datasize, m)
    if datas_default == nil then datas_default, datasize = getCropStatuses_default(transposerproxy, fromside) end
    m = m or -1
    ---@diagnostic disable-next-line
    local depositQueue = querySearch_default(bakedquery, datas_default, datasize, langs.searching,m)
    local c = 0
    if #depositQueue == 0 then
        print(langs.foundnoseed)
        return true
    end
    drawProgressBar(30, 0, #depositQueue, langs.depositing, false)
    local j = 1
    for i, data in pairs(depositQueue) do
        local slot = data["slot"]
        local size = data["size"]
        if size == nil then goto continue end
        if size > 0 then
            local transferred
            transferred, j = depositOneStack_default(transposerproxy, fromside, toside, size, slot, j)
            c = c + transferred
        end
        ::continue::
        drawProgressBar(30, i, #depositQueue, langs.depositing)
    end
    print("")
    print(string.format(langs.depositedseed, c))
    return true
end
--全部のアイテムを搬出する
---@param transposerproxy any
---@param fromside integer
---@param toside integer
---@param langs {foundnoseed:string, searching:string, depositing: string, depositedseed:string}
---@return true
local function depositAll_default (transposerproxy, fromside, toside, langs)
    return deposit_default(" (true)", transposerproxy, fromside, toside, langs)
end
--内容をすべて出力する
---@param transposerproxy any
---@param fromside integer
local function showContents_default(transposerproxy, fromside)
    for data in getCropStatuses_default(transposerproxy, fromside) do
        print(serialization.serialize(data))
    end
end

return {
    getCropStatuses_default = getCropStatuses_default,
    countSeeds_default = countSeeds_default,
    getSeedsCountByQuery_default = getSeedsCountByQuery_default,
    depositOneStack_default = depositOneStack_default,
    deposit_default = deposit_default,
    depositAll_default = depositAll_default,
    showContents_default = showContents_default,
}