.PHONY: build test
build:
test:
	lua5.2 ./test.lua
	lua5.3 ./test.lua
	find lua/ test/ -iname '*.lua' | xargs luacheck
