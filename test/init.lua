local utils = require 'lem.utils'

local updatenow = utils.updatenow
local pack = table.pack
local unpack = table.unpack
local format = string.format

local master

local function test_assert(v, msg, ...)
	if not v then
		error(msg or 'assertion failed!', 2)
	end
	master.assert_cnt = master.assert_cnt + 1
	return v, msg, ...
end

local function msg_handler(msg)
	local trace = debug.traceback(msg, 4)
	return trace
	--return string.match(trace, '^(.-)\n[^\n]-tester_cut_traceback_here')
end

local test = {}
test.__index = test

function test:enter()
	self.prev_test = master.activetest
	master.activetest = self
	self.real_assert = assert
	_ENV.assert = test_assert
end

function test:leave()
	master.activetest = self.prev_test
	self.prev_test = nil
	_ENV.assert = self.real_assert
	self.real_assert = nil
end

function test:depend(t)
	if type(t) == 'string' then
		t = require('test.'..t)
	end
	table.insert(self.dependencies, t)
end

local function tester_cut_traceback_here(self)
	local deps = self.dependencies
	for i=1,#deps do
		local dep = deps[i]
		dep:run()
	end
	if self.test then
		self:test()
	end
end

local function tester(...)
	-- hack due to the first function called by xpcall
	-- not being refered to by name in tracebacks
	local ret, msg = tester_cut_traceback_here(...)
	return ret, msg
end

function test:run()
	if master == nil then
		self:setmaster()
	end
	if master.have_run[self] then
		return self.passed -- TODO return previous result
	end
	self:enter()
	local t1, t2
	t1 = updatenow()
	local ret, msg = xpcall(tester, msg_handler, self)
	t2 = updatenow()
	self.runtime = t2 - t1
	self:leave()
	if not ret then
		self.error_msg = msg
	end
	master.have_run[self] = true
	self.passed = ret
	master.run = master.run + 1
	if ret then
		master.passed = master.passed + 1
	else
		table.insert(master.failed, self)
	end
	return ret
end

function test:setmaster()
	assert(master == nil, 'master already set')
	master = {
		test = self,
		assert_cnt = 0,
		have_run = {},
		passed = 0,
		run = 0,
		failed = {},
	}
end

function test:reset()
	if self ~= master.test then
		error('you can only run reset on current master task')
	end
	master = nil
end

local function new_test(func)
	local src = debug.getinfo(func or 2, 'S').short_src
	return setmetatable({
		test = func,
		dependencies = {},
		source = src,
	}, test)
end

function test:stats()
	if self ~= master.test then
		error('you can only run stats on current master task')
	end
	local run, passed, asserts = master.run, master.passed, master.assert_cnt
	if run == passed then
		print(format('%d/%d  All tests passed, %d assertions in %.3fs',
			run, passed, asserts, master.test.runtime))
	else
		print(format('%d/%d  %d failed', run, passed, run-passed))
	end
end

function test:failed()
	if self ~= master.test then
		error('you can only run stats on current master task')
	end
	for i=1,#master.failed do
		local t = master.failed[i]
		print(t.error_msg)
	end
end

local function assert_fail(cb, ...)
	local ret = pack(pcall(cb, ...))
	if ret[1] then assert(false, 'doomed function succeeded') end
	return unpack(ret)
end

local M = {}

function M.test()
	local index = require 'test.all'
	index:run()
	index:stats()
	index:failed()
end

M.new = new_test
M.fail = assert_fail

return M
