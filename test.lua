#!/usr/bin/env lem

package.path = './?/init.lua;'..package.path..';./lua/?.lua;./lua/?/init.lua;./?.lua'
package.cpath = package.cpath..';./lua/?.so'

local test = require 'test'

test.test()
