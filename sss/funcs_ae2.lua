local serialization = require("serialization")
local util = require("util")
local queryhandler = require("queryhandler")
local event = require("event")
local thread = require("thread")
local funcs_default = require("funcs_default")

local drawProgressBar = util.drawProgressBar
local countIterLen = util.countIterLen
local tblEqual = util.tblEqual
local bakeQuery = queryhandler.bakeQuery
local matchQuery = queryhandler.matchQuery
local queryConcat = queryhandler.queryConcat
local depositOneStack_default = funcs_default.depositOneStack_default

local batch = {1, 8, 32, 64, 96}
local importqueue = {}
--stackdata_ae2がstackcountを除いて一致するか調べる
---@param a stackdata_ae2
---@param b stackdata_ae2
---@return boolean
local function isDataEqual(a,b)
    return a.label == b.label and a.size == b.size
end
--aがstackcountを除いてdatasのどこにあるか調べる
---@param a stackdata_ae2
---@param datas stackdata_ae2[]
---@return any
local function getDataIndex(a,datas)
    for k, d in pairs(datas) do
        if isDataEqual(a,d) then
            return k
        end
    end
    return nil
end

--datasからbakedqueryとマッチするもののリストを`return`する <br>
--`return`するリストは {`label`, `size`}
---@param bakedquery bakedquery
---@param datas_ae2 data_ae2iter
---@param datasize integer
---@param lang_searching string
---@return stackdata_ae2[]
---@return integer
local function querySearch_ae2 (bakedquery, datas_ae2, datasize, lang_searching)
    local found = {}
    drawProgressBar(30, 0, datasize, lang_searching, false)
    local i = 1
    local c = 0
    for data in datas_ae2 do
        local label = data["label"]
        local size = data["size"]
        local cropdata = data["cropdata"]
        local tmp = {label = label, size = size, stackcount = 1, matchstack = 0}
        local ind = getDataIndex(tmp, found)
        if cropdata == nil then
            goto continue
        end
        if ind == nil then
            table.insert(found, tmp)
        else
            found[ind].stackcount = found[ind].stackcount + 1 
        end
        if matchQuery(bakedquery, cropdata) then
            found[ind or #found].matchstack = found[ind or #found].matchstack + 1
        end
        ::continue::
        drawProgressBar(30, i, datasize, lang_searching)
        i = i + 1
    end
    for j = #found, 1, -1 do
        if found[j].matchstack == 0 then
            table.remove(found,j)
        else
            c = c + found[j].stackcount
        end
    end
    print("")
    return found, c
end
--`data_ae2`のイテレーターを返す
---@param mecproxy any
---@return data_ae2iter
local function getCropStatuses_ae2 (mecproxy)
    local iter = mecproxy.allItems()
    return (function ()
        local d = iter()
        if d then return {label = d["label"], size = d["size"], cropdata = d["crop"]} end
    end)
end
--`stackdatas_ae2`に入っている種の数を返す
---@param stackdatas_ae2 stackdata_ae2[]
---@return integer
local function countSeeds_ae2 (stackdatas_ae2)
    local c = 0
    for _, data in pairs(stackdatas_ae2) do
        c = c + data.size * data.matchstack
    end
    return c
end
--`querylist`と`datas`から条件を満たす種の数を返す
---@param querylist querylist
---@param datas_ae2 data_ae2iter
---@param datasize integer
---@param lang_searching string
---@return integer
local function getSeedsCountByQuery_ae2 (querylist, datas_ae2, datasize, lang_searching)
    return countSeeds_ae2(querySearch_ae2(bakeQuery(queryConcat(querylist)),datas_ae2, datasize, lang_searching))
end
--1回分だけ搬出する
---@param ebusproxy any
---@param ebusside integer
---@param canseeinventory any
---@param invside integer
---@param searchstart? integer
---@return boolean
---@return integer
local function depositOneStack_ae2 (ebusproxy, ebusside, canseeinventory, invside, searchstart)
    searchstart = searchstart or 1
    local invsize = canseeinventory.getInventorySize(invside)
    for i=invsize, searchstart, -1 do
        if canseeinventory.getSlotStackSize(invside, i) == 0 then
            return ebusproxy.exportIntoSlot(ebusside, i), i
        end 
    end
    return false, -1
end
--スレッド用
---@param tpproxy any
---@param tpfromside integer
---@param tptoside integer
---@return nil
local function importfunc (tpproxy, tpfromside, tptoside)
    event.pull("sss_startdepositing")
    while true do
        ::continue::
        if #importqueue == 0 then
            event.pull("sss_endqueue")
        end
        if importqueue[1] == "end" then
            importqueue = {}
            break
        end
        if importqueue[1] == nil then
            table.remove(importqueue, 1)
            goto continue
        end
        local d = tpproxy.getStackInSlot(tpfromside, 1)
        local cropdata = d.crop
        local c, result = pcall(depositOneStack_default, tpproxy, tpfromside, tptoside, d.size, 1)
        local i = 0
        if c then
            i = result
        end
        if i == d.size and tblEqual(cropdata, importqueue[1]) then
            table.remove(importqueue, 1)
        end
    end
end
--クエリ、データなどからアイテムを搬出する <br>
---@param bakedquery bakedquery
---@param mecproxy any
---@param ebusproxy any
---@param mainebusside integer
---@param subebusside integer
---@param mainebusacc integer
---@param subebusacc integer
---@param tpproxy any
---@param tpfromside integer
---@param tptoside integer
---@param tplookside integer
---@param dbproxy any
---@param langs {foundnoseed:string, searching:string, depositing: string, depositedseed:string}
---@param m? integer
---@return true
local function deposit_ae2 (bakedquery, mecproxy, ebusproxy, mainebusside, subebusside, mainebusacc, subebusacc, tpproxy, tpfromside, tptoside, tplookside, dbproxy, langs, m)
    local importthread = thread.create(importfunc, tpproxy, tpfromside, tptoside)
    local datas_ae2 = getCropStatuses_ae2(mecproxy)
    local datasize = countIterLen(mecproxy.allItems())
    m = m or -1
    local mainebusbatch = batch[mainebusacc + 1]
    local subebusbatch = batch[subebusacc + 1]
    local depositQueue, stackcount = querySearch_ae2(bakedquery, datas_ae2, datasize, langs.searching)
    if #depositQueue == 0 then
        print(langs.foundnoseed)
        return true
    end
    drawProgressBar(30, 0, stackcount, langs.depositing, false)
    local processedstack = 0
    local i = 1
    local c = 0
    dbproxy.clear(1)
    event.push("sss_startdepositing")
    local lastnotmatch
    while #depositQueue ~= 0 do
        local data, label, size, stackdata, cropdata, ebusside, ebusbatch, tpside, ifmatched, s, maini
        maini = i
        data = depositQueue[1]
        label = data.label
        size = data.size
        mecproxy.store({label = label, size = size}, dbproxy.address, 1, 1)
        stackdata = dbproxy.get(1)
        if stackdata == nil then
            table.remove(depositQueue, 1)
            goto continue
        end
        cropdata = stackdata.crop
        if cropdata == nil then goto continue end
        ifmatched = matchQuery(bakedquery, cropdata)
        if ifmatched then
            i = maini
            ebusside = mainebusside
            ebusbatch = mainebusbatch
            tpside = tplookside
        else
            i = 1
            lastnotmatch = cropdata
            ebusside = subebusside
            ebusbatch = subebusbatch
            tpside = tpfromside
        end
        ebusproxy.setExportConfiguration(ebusside, 1, dbproxy.address, 1)
        dbproxy.clear(1)
        s = true
        for j=1, math.ceil(size / ebusbatch) do
            s,i = depositOneStack_ae2(ebusproxy, ebusside, tpproxy, tpside, i)
            if not s then
                break
            end
            if ifmatched then
                c = c + math.min(size - ebusbatch * (j - 1), ebusbatch)
                maini = i
            end
            if m ~= -1 and c >= m then
                break
            end
        end
        depositQueue[1].stackcount = depositQueue[1].stackcount - 1
        if depositQueue[1].stackcount <= 0 or not s then
            table.remove(depositQueue, 1)
            table.insert(importqueue, lastnotmatch)
            lastnotmatch = nil
            event.push("sss_endqueue")
        end
        ::continue::
        processedstack = processedstack + 1
        drawProgressBar(30, processedstack, stackcount, langs.depositing)
        if m ~= -1 and c >= m then
            break
        end
    end
    table.insert(importqueue, "end")
    event.push("sss_endqueue")
    print("")
    print(string.format(langs.depositedseed, c))
    thread.waitForAll({importthread})
    return true
end
--全部のアイテムを搬出する
---@param mecproxy any
---@param ebusproxy any
---@param mainebusside integer
---@param subebusside integer
---@param mainebusacc integer
---@param subebusacc integer
---@param tpproxy any
---@param tpfromside integer
---@param tptoside integer
---@param tplookside integer
---@param dbproxy any
---@param langs {foundnoseed:string, searching:string, depositing: string, depositedseed:string}
---@return true
local function depositAll_ae2 (mecproxy, ebusproxy, mainebusside, subebusside, mainebusacc, subebusacc, tpproxy, tpfromside, tptoside, tplookside, dbproxy, langs)
    return deposit_ae2("(true)", mecproxy, ebusproxy, mainebusside, subebusside, mainebusacc, subebusacc, tpproxy, tpfromside, tptoside, tplookside, dbproxy, langs)
end
--内容をすべて出力する
---@param mecproxy any
local function showContents_ae2(mecproxy)
    for data in getCropStatuses_ae2(mecproxy) do
        print(serialization.serialize(data))
    end
end

return {
    getCropStatuses_ae2 = getCropStatuses_ae2,
    countSeeds_ae2 = countSeeds_ae2,
    getSeedsCountByQuery_ae2 = getSeedsCountByQuery_ae2,
    depositOneStack_ae2 = depositOneStack_ae2,
    deposit_ae2 = deposit_ae2,
    depositAll_ae2 = depositAll_ae2,
    showContents_ae2 = showContents_ae2,
    querySearch_ae2 = querySearch_ae2
}