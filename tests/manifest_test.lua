-- Checks plugin.json against what the code carries by hand: the version string must match Constants.VERSION, and
-- the manifest must keep the shape the client and Mod.io require (a digits-and-dots version, dependencies as an
-- object, a contact email). The client does not expose the manifest to Lua, so this is the only guard.
local T = require("harness")
local Constants = require("src/constants")

local function readManifest()
    local path = T.PLUGIN_ROOT .. "/plugin.json"
    local file = assert(io.open(path, "r"), "cannot open " .. path)
    local text = file:read("a")
    file:close()
    return text
end

local manifest = readManifest()

T.section("manifest: version")
local version = manifest:match('"version"%s*:%s*"([^"]*)"')
T.equal(version, Constants.VERSION, "plugin.json version matches Constants.VERSION")
T.check(version ~= nil and version:match("^%d+%.%d+%.%d+$") ~= nil,
    "version is digits and dots only, as Mod.io requires")

T.section("manifest: shape")
T.check(manifest:match('"requiredDependencies"%s*:%s*{') ~= nil, "requiredDependencies is an object, not an array")
T.check(manifest:match('"contactEmailAddress"%s*:%s*"[^"]+@[^"]+"') ~= nil, "a contact email is present")
T.check(manifest:match('"requiredPermissions"%s*:%s*%[%s*%]') ~= nil, "no required permissions, as the README promises")
