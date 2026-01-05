local shell = require("shell")
local url = "https://raw.githubusercontent.com/pertiallic/simpleseedsearch_for_oc/main/sss"
local sss_scripts = {
    "clearall",
    "config",
    "funcs_default",
    "funcs_ae2",
    "init",
    "luaaliases",
    "queryhandler",
    "simpleseedsearch",
    "util",
}
local lang = {
    "en",
    "ja"
}
shell.execute("md sss")
for _,s in ipairs(sss_scripts) do
    shell.execute(string.format("wget %s/%s.lua", url, s))
    shell.execute(string.format("mv %s.lua sss/%s.lua", s, s))
end
shell.execute("md sss/lang")
for _,l in ipairs(lang) do
    shell.execute(string.format("wget %s/lang/%s.lua", url, l))
    shell.execute(string.format("mv %s.lua sss/lang/%s.lua", l, l))
end
shell.setAlias("sss", "simpleseedsearch.lua")