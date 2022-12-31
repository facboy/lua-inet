local versions = {
    ['Lua 5.2'] = 'bit32',
    ['LuaJIT'] = 'inet.bitops.luajit',
}

local version = _VERSION
if _VERSION == 'Lua 5.1' then
    --[[
    from https://stackoverflow.com/questions/20335340/how-can-i-detect-at-runtime-if-i-am-running-luajit-or-puc-lua-5-1
    this seems less flaky than the other suggestion (which seems to work by checking for a
    difference in how the LuaJIT implementation represents tables)
    ]]--
    if type(jit) == 'table' then
        local jit_version = jit.version
        if type(jit_version) == 'string' and jit_version:sub(1, 6) == 'LuaJIT' then
            version = 'LuaJIT'
        end
    end
end

local library = versions[version] or 'inet.bitops.native'
return assert(require(library))
