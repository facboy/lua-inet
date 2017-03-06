#!/usr/bin/env lua

package.path = './?/init.lua;./lua/?.lua;./lua/?/init.lua;./?.lua;'..package.path

local test = require 'test'

test.test()
