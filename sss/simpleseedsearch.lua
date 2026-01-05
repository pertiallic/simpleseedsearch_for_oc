--モジュール/modules

local component = require("component")
local sides = require("sides")
local config = require("config")
local serialization = require("serialization")
local luaaliases = require("luaaliases")
local util = require("util")
local shell = require("shell")
local queryhandler = require("queryhandler")
local funcs_default = require("funcs_default")
local funcs_ae2 = require("funcs_ae2")
local lang
--コンポーネント/components

local notifier
local transposer = component.transposer
--AE2モード/AE2 mode

local me_controller, me_exportbus, database
--その他/miscs

local commandsalias = luaaliases.commandalias
local queryalias = luaaliases.queryalias
local configs = {}
configs.transposer_fromside = sides[config.transposer_fromside]
configs.transposer_toside = sides[config.transposer_toside]
configs.transposer_lookside = sides[config.transposer_lookside]
configs.ae2mode = config.ae2mode
configs.alarm = config.alarm
configs.lang = config.lang
configs.maineside = sides[config.mainexportbus_side]
configs.maineacc = config.mainexportbus_acceleration
configs.subeside = sides[config.subexportbus_side]
configs.subeacc = config.subexportbus_acceleration
--関数/functions

local format = util.format
local stringsplit = util.stringsplit
local ifInArray = util.ifInArray
local notify = util.notify
local countIterLen = util.countIterLen
local bakeQuery = queryhandler.bakeQuery
local queryConcat = queryhandler.queryConcat
--デフォルトモード

local depositAll_default = funcs_default.depositAll_default
local deposit_default = funcs_default.deposit_default
local getCropStatuses_default = funcs_default.getCropStatuses_default
local getSeedsCountByQuery_default = funcs_default.getSeedsCountByQuery_default
local showContents_default = funcs_default.showContents_default
--AE2モード

local depositAll_ae2 = funcs_ae2.depositAll_ae2
local deposit_ae2 = funcs_ae2.deposit_ae2
local getCropStatuses_ae2 = funcs_ae2.getCropStatuses_ae2
local getSeedsCountByQuery_ae2 = funcs_ae2.getSeedsCountByQuery_ae2
local showContents_ae2 = funcs_ae2.showContents_ae2

local args, ops = shell.parse(...)
local queries_tbl = {}
local searching = false

--[[query:
luaでの条件に従う
<name>には名前
<gr>,<ga>,<re>にはそれぞれgrowth, gain, resistanceが代入される
例:
(string.find(<name>,"veno")) and (<gr> >= 5 or <ga> >= 5)
--]]

local alarm_component = {{"beep" , "computer"}, {"alarm", "os_alarm"}, {"chat", "chat_box"}, {"note", "note_block"}, {"none", nil}}

if configs.ae2mode == nil then configs.ae2mode = component.isAvailable("me_controller") end
if configs.alarm == nil then 
    for _, p in pairs(alarm_component) do
        if p[2] and component.isAvailable(p[2]) then
            configs.alarm = p[1]
        end
    end
end

if ops.fromside then configs.transposer_fromside = sides[ops.fromside] end
if ops.toside then configs.transposer_toside = sides[ops.toside] end
if ops.alarm then configs.alarm = ops.alarm end
if ops.ae2 then configs.ae2mode = true end
if ops.lang then configs.lang = ops.lang end

for _, p in ipairs(alarm_component) do
    if p[1] == configs.alarm and p[2] then
        notifier = component[p[2]]
    end
end

if configs.ae2mode then
    me_controller = component.me_controller
    me_exportbus = component.me_exportbus
    database = component.database
end
---@type lang
lang = require("lang."..configs.lang)

print(lang.introductiontext)

if configs.ae2mode then
    print(lang.ae2mode_enabled)
end

local langs_logging = {foundnoseed = lang.foundnoseed, searching = lang.searching, depositing = lang.depositing, depositedseed = lang.depositedseed}

while true do
    if searching then
        io.write(lang.query)
    end
    io.write(">>>")
    local inputarray = stringsplit(format(io.read()))
    if #inputarray == 0 then
        goto continue
    end
    inputarray[1] = commandsalias[inputarray[1]] or inputarray[1]
    if searching then
        inputarray[1] = queryalias[inputarray[1]] or inputarray[1]
    end
    if inputarray[1] == "quit" then
        if searching then
            queries_tbl = {}
            searching = false
        else
            break
        end
    elseif inputarray[1] == "help" then
        if searching then
            print(lang.queryhelptext)
        else
            print(lang.helptext)
        end
    elseif inputarray[1] == "deposit" then
        local c, err, query, m
        if configs.ae2mode then
            if searching then
                m = math.tointeger(inputarray[2]) or -1
                query = bakeQuery(queryConcat(queries_tbl))
            else
                m = -1
                query = bakeQuery(table.concat(inputarray, " ", 2))
            end
            c, err = pcall(deposit_ae2, query, me_controller, me_exportbus, configs.maineside, configs.subeside, configs.maineacc, configs.subeacc, transposer, configs.transposer_fromside, configs.transposer_toside, configs.transposer_lookside, database, langs_logging, m)
        else
            if searching then
                m = math.tointeger(inputarray[2]) or -1
                query = bakeQuery(queryConcat(queries_tbl))
            else
                m = -1
                query = bakeQuery(table.concat(inputarray, " ", 2))
            end
            c, err = pcall(deposit_default, query, transposer, configs.transposer_fromside, configs.transposer_toside, langs_logging, m)
        end
        if not c then
            print(lang.error_message..err)
            print(lang.invalid_query..query)
        else 
            notify(notifier, configs.alarm, lang.finishdepositing, 14, 1)
        end
        if searching then
            queries_tbl = {}
            searching = false
        end
    elseif inputarray[1] == "depositall" then
        local c, err
        if configs.ae2mode then
            c, err = pcall(depositAll_ae2, me_controller, me_exportbus, configs.maineside, configs.subeside, configs.maineacc, configs.subeacc, transposer, configs.transposer_fromside, configs.transposer_toside, configs.transposer_lookside, database, langs_logging)
        else
            c, err = pcall(depositAll_default, transposer, configs.transposer_fromside, configs.transposer_toside, langs_logging)
        end
        if not c then
            print(lang.error_message..err)
        else 
            notify(notifier, configs.alarm, lang.finishdepositing, 14, 1)
        end
    elseif inputarray[1] == "search" then
        if searching then
            print(lang.alreadysearching)
        else
            searching = true
        end
    elseif inputarray[1] == "showcontents" then
        if configs.ae2mode then
            showContents_ae2(me_controller)
        else
            showContents_default(transposer, configs.transposer_fromside)
        end
    elseif inputarray[1] == "showconfig" then
        print(serialization.serialize(configs))
    elseif searching and ifInArray(inputarray[1], {"name", "growth", "gain", "resistance"}) then
        table.insert(queries_tbl,table.concat(inputarray," "))
        if configs.ae2mode then
            local cropdata = getCropStatuses_ae2(me_controller)
            local datasize = countIterLen(me_controller.allItems())
            print(string.format(lang.foundseed, getSeedsCountByQuery_ae2(queries_tbl, cropdata, datasize, lang.searching)))
        else
            local cropdata, datasize = getCropStatuses_default(transposer, configs.transposer_fromside)
            print(string.format(lang.foundseed, getSeedsCountByQuery_default(queries_tbl, cropdata, datasize, lang.searching)))
        end
    elseif searching and inputarray[1] == "delete" then
        local delpos = inputarray[2] or 1
        if #queries_tbl - delpos < 0 then 
            print(lang.outofindex)
            goto continue
        end
        table.remove(queries_tbl, #queries_tbl - delpos + 1)
        if #queries_tbl ~= 0  then
            if configs.ae2mode then
                local cropdata = getCropStatuses_ae2(me_controller)
                local datasize = countIterLen(me_controller.allItems())
                print(string.format(lang.foundseed, getSeedsCountByQuery_ae2(queries_tbl, cropdata, datasize, lang.searching)))
            else
                local cropdata, datasize = getCropStatuses_default(transposer, configs.transposer_fromside)
                print(string.format(lang.foundseed, getSeedsCountByQuery_default(queries_tbl, cropdata, datasize, lang.searching)))
        end
        else
            print(lang.noquery)
        end
    elseif searching and inputarray[1] == "showquery" then
        print(bakeQuery(queryConcat(queries_tbl)))
    else
        print(lang.unknowncommand)
    end
    ::continue::
end