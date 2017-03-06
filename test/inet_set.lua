local inet = require 'inet'
local inet_set = require 'inet.set'
local test = require 'test'

function agg_set(a, b)
	inet_set.aggregate(a)
	assert(#a == #b, 'wrong set size')
	for i=1,#a do
		--print(a[i], b[i])
		assert(a[i] == b[i], 'unexpected network')
	end
end


return test.new(function()
	local ip = inet('10.0.0.0/24')

	agg_set({
		inet('10.0.0.0/24'),
		inet('10.0.1.0/24'),
	}, {
		inet('10.0.0.0/23'),
	})

	agg_set({
		inet('10.0.1.0/24'),
		inet('10.0.2.0/24'),
	}, {
		inet('10.0.1.0/24'),
		inet('10.0.2.0/24'),
	})

	agg_set({
		inet('10.0.1.0/24'),
		inet('10.0.2.0/24'),
		inet('10.0.3.0/24'),
		inet('10.0.4.0/24'),
	}, {
		inet('10.0.1.0/24'),
		inet('10.0.2.0/23'),
		inet('10.0.4.0/24'),
	})

	agg_set({
		inet('10.0.2.1/24'),
		inet('10.0.4.0/24'),
		inet('10.0.1.0/24'),
		inet('10.0.3.0/24'),
	}, {
		inet('10.0.2.0/23'),
		inet('10.0.4.0/24'),
		inet('10.0.1.0/24'),
	})

	agg_set({
		inet('10.0.1.1/24'),
		inet('10.0.3.2/24'),
		inet('10.0.2.3/24'),
		inet('10.0.4.4/24'),
	}, {
		inet('10.0.1.0/24'),
		inet('10.0.2.0/23'),
		inet('10.0.4.0/24'),
	})

	agg_set({
		inet('::/32'),
		inet('0:1::/32'),
	}, {
		inet('::/31'),
	})
end)
