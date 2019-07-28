local versions = {
	['Lua 5.2'] = 'bit32',
}

local library = versions[_VERSION] or 'inet.bitops.native'
return assert(require(library))
