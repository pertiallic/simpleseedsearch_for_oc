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
local lang
--コンポーネント/components
--デフォルト(AE2を使わないやつ)/default(non AE2)

local transposer
--AE2モード/AE2 mode

local me_controller, me_exportbus, database, modem
--その他/miscs

local commandsalias = luaaliases.commandalias
local queryalias = luaaliases.queryalias
local configs = {}
configs.fromside = sides[config.fromside]
configs.toside = sides[config.toside]
configs.ae2mode = config.ae2mode
configs.alarm = config.alarm
configs.lang = config.lang
--関数/functions

local format = util.format
local stringsplit = util.stringsplit
local ifInArray = util.ifInArray
local bakeQuery = queryhandler.bakeQuery
local queryConcat = queryhandler.queryConcat
--デフォルトモード

local depositAll_default = funcs_default.depositAll_default
local deposit_default = funcs_default.deposit_default
local getCropStatuses_default = funcs_default.getCropStatuses_default
local getSeedsCountByQuery_default = funcs_default.getSeedsCountByQuery_default
local showContents_default = funcs_default.showContents_default

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

if config.ae2mode == nil then configs.ae2mode = component.isAvailable("me_controller") end

if ops.fromside then configs.fromside = sides[ops.fromside] end
if ops.toside then configs.toside = sides[ops.toside] end
if ops.alarm then configs.alarm = ops.alarm end
if ops.ae2 then configs.ae2mode = true end
if ops.lang then configs.lang = ops.lang end

if configs.ae2mode then
    me_controller = component.me_controller
    me_exportbus = component.me_exportbus
    database = component.database
    modem = component.modem
else
    transposer = component.transposer
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
        local c, err, query
        if searching then
            local m =  math.tointeger(inputarray[2]) or -1
            query = bakeQuery(queryConcat(queries_tbl))
            c, err = pcall(deposit_default, query, transposer, configs.fromside, configs.toside, langs_logging, nil, nil, m)
        else
            query = bakeQuery(table.concat(inputarray, " ", 2))
            c, err = pcall(deposit_default, query, transposer, configs.fromside, configs.toside, langs_logging)
        end
            if not c then
                print(lang.error_message..err)
                print(lang.invalid_query..query)
            end
        if searching then
            queries_tbl = {}
            searching = false
        end
    elseif inputarray[1] == "depositall" then
        local c,err = pcall(depositAll_default, transposer, configs.fromside, configs.toside, langs_logging)
        if not c then
            print(lang.error_message..err)
        end
    elseif inputarray[1] == "search" then
        if searching then
            print(lang.alreadysearching)
        else
            searching = true
        end
    elseif inputarray[1] == "showcontents" then
        showContents_default(transposer, configs.fromside)
    elseif inputarray[1] == "showconfig" then
        print(serialization.serialize(configs))
    elseif searching and ifInArray(inputarray[1], {"name", "growth", "gain", "resistance"}) then
        table.insert(queries_tbl,table.concat(inputarray," "))
        local cropdata, datasize = getCropStatuses_default(transposer, configs.fromside)
        print(string.format(lang.foundseed, getSeedsCountByQuery_default(queries_tbl, cropdata, datasize, lang.searching)))
    elseif searching and inputarray[1] == "delete" then
        local delpos = inputarray[2] or 1
        if #queries_tbl - delpos < 0 then 
            print(lang.outofindex)
            goto continue
        end
        table.remove(queries_tbl, #queries_tbl - delpos + 1)
        if #queries_tbl ~= 0  then
            local cropdata, datasize = getCropStatuses_default(transposer, configs.fromside)
            print(string.format(lang.foundseed, getSeedsCountByQuery_default(queries_tbl, cropdata, datasize, lang.searching)))
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