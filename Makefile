DEST_LUA  = $(DESTDIR)/usr/share/lua/5.3/inet

.PHONY: install build test
build:
install:
	install -d $(DEST_LUA)
	install -m644 lua/inet/*.lua $(DEST_LUA)
test:
	./test.lua
