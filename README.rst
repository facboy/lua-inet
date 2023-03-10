=========================================
``inet`` - an IP address mangling library
=========================================

``inet`` is meant to make it simple and fun to do IP address calculations,
subnet math and similar IP address related arithmetics.

::

  local inet = require 'inet'

  -- get first address of the 3rd /64 in a /56
  inet('2001:db8::/56') / 64 * 3 + 1  -- returns inet('2001:db8:0:3::1/64')

  -- get last /64 in a /56
  inet('2001:db8::/56') * 1 / 64 * -1 -- returns inet('2001:db8:0:ff::/64')

All examples on this page, are tested when ``make test`` is run.

Dependencies
============

- Lua_ version 5.2, 5.3 or 5.4 beta
- LPeg_ - Parsing Expression Grammars For Lua

Install
=======

You can install lua-inet in several ways,
after all it is just a pure Lua library.

From git
--------

System-wide
~~~~~~~~~~~

::

  $ sudo -i
  # apt install lua-lpeg
  # git clone https://git.2e8.dk/lua-inet /opt/lua-inet
  # mkdir -p /usr/local/share/lua/5.3
  # ln -s /opt/lua-inet/lua/inet /usr/local/share/lua/5.3/inet

Local user
~~~~~~~~~~

Clone this repo to somewhere, then include this repo's ``lua/`` in your
``package.path``, with something like this::

  package.path = '/PATH/TO/lua/?.lua;/PATH/TO/lua/?/init.lua;'..package.path

See also the `LUA_INIT`_ environment variable.

LuaRocks
--------

If you want you can also use LuaRocks_::

  $ luarocks install inet

API
===

``inet`` module
---------------

======================= =====================================================
API                     Description
======================= =====================================================
``inet(...)``           Parse address and build ``inet4`` or ``inet6`` table
``inet.is(foo)``        is ``foo`` an ``inet*`` table?
``inet.is4(foo)``       is ``foo`` an ``inet4`` table?
``inet.is6(foo)``       is ``foo`` an ``inet6`` table?
``inet.is_set(foo)``    is ``set`` table?
``inet.set()``          get new empty ``set`` instance.
``inet.mixed_networks`` IPv6 mixed notation ``set``
``inet.version``        API version (currently ``1``)
======================= =====================================================

IPv6 mixed notation configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``inet.mixed_networks`` can be used to configure which IPv6 networks
should use mixed notation, ie. last 32 bits formatted as IPv4,
as per `RFC 5952`_ section 5.

Initially the set contains these well-known networks:

::

  inet.mixed_networks:list() -- returns {
    inet('::ffff:0:0/96'), -- RFC 5156
    inet('64:ff9b::/96'),  -- RFC 6052
  }

Common ``inet*`` API
--------------------

================== ======================================
Operator           Description
================== ======================================
``+``              Addition
``-``              Subtract
``/``              Change mask (absolute)
``^``              Change mask (relative)
``*``              Move network
``<``              is less than
``<=``             is less than or equal
``==``             equals
``>=``             is greater or equal
``>``              is greater than
``~=``             not equals
``#``              number of network bits
``:contains()``    contains
``:network()``     extract network part of address
``tostring(net)``  convert to network
``:ipstring()``    ip as string without prefix
``:cidrstring()``  format CIDR notation
``:netmask()``     generate netmask as an address
``:hostmask()``    generate hostmask as an address
``:flip()``        flip the least significant network bit
``:bits()``        return the address bits in a table
``:subnets()``     return the amount of /n subnets
``:family()``      return the address family (number)
``:full_family()`` return the address family (string)
================== ======================================


Additional ``inet6`` methods
-----------------------------

inet6 has these additional methods:

================ =====================================
Operator         Description
================ =====================================
``:ipstring4()`` string formatted in mixed notation
``:ipstring6()`` string formatted in standard notation
================ =====================================


``set`` API
-----------

================== =================================
API                Description
================== =================================
``set:list()``     list networks in set
``set:add()``      add network to set
``set:remove()``   remove network from set
``set:contains()`` is network contained in set?
``set:flush()``    empty the set
================== =================================


Creating
--------

There is a multitude of different ways to create ``inet*`` instances.

::

  -- IPv4
  inet('192.0.2.0')     -- returns inet('192.0.2.0/32')
  inet('192.0.2.0', 24) -- returns inet('192.0.2.0/24')
  inet({192,0,2,0}, 24) -- returns inet('192.0.2.0/24')
  inet(3221225985, 32)  -- returns inet('192.0.2.1')

  -- IPv6
  inet('2001:db8::')     -- returns inet('2001:db8::/128')
  inet('2001:db8::', 56) -- returns inet('2001:db8::/56')

  -- its possible to wrap inet instances
  inet(inet('192.0.2.0/24')) -- returns inet('192.0.2.0/24')
  inet(inet('2001:db8::'))   -- returns inet('2001:db8::')

  -- when wrapped additional mask takes precedence
  inet(inet('192.0.2.0/32'), 24)   -- returns inet('192.0.2.0/24')
  inet(inet('2001:db8::/128'), 64) -- returns inet('2001:db8::/64')

  -- various error examples
  inet('192.0.2.0/24', 32)  -- returns nil, 'multiple masks supplied'
  inet('2001:db8::/64', 56) -- returns nil, 'multiple masks supplied'
  inet('foobar')            -- returns nil, 'parse error'
  inet('foo::bar')          -- returns nil, 'parse error'
  inet('192.0.2.0', 33)     -- returns nil, 'invalid mask'
  inet('2001:db8::', 129)   -- returns nil, 'invalid mask'

Mangling
--------

All of the ``inet*`` mangling operators and methods returns a new instance, and does
not modify the original instance.

``foo + bar``
~~~~~~~~~~~~~

Addition

::

  inet('192.0.2.0') + 24    -- returns inet('192.0.2.24')
  inet('2001:db8::/64') + 5 -- returns inet('2001:db8::5/64')

  -- mixed networks special:
  inet('::ffff:0.0.0.0/96') + inet('192.0.2.24') -- returns inet('::ffff:192.0.2.24')
  inet('192.0.2.24') + inet('::ffff:0.0.0.0/96') -- returns inet('::ffff:192.0.2.24')

``foo - bar``
~~~~~~~~~~~~~

Subtraction

::

  inet('2001:db8::5/64') - 5 -- returns inet('2001:db8::/64')

  inet('192.0.2.24') - inet('192.0.2.0') -- returns 24

  inet('2001:db8::5/64') - inet('2001:db8::') -- returns 5

  -- by calling the operator method directly additional debuging info are available:
  inet('2001:db8::5/64') - inet('ffff::') -- returns nil
  inet('2001:db8::5/64'):__sub(inet('ffff::'))
  -- returns nil, 'out of range', { -57342, 3512, 0, 0, 0, 0, 0, 5 }

  -- mixed networks special:
  inet('::ffff:192.0.2.24') - inet('::ffff:0.0.0.0/96') -- returns inet('192.0.2.24')

``foo / bar``
~~~~~~~~~~~~~

Change mask (absolute)

::

  inet('2001:db8::/32') / 64  -- returns inet('2001:db8::/64')
  inet('2001:db8::1/32') / 64 -- returns inet('2001:db8::1/64')

``foo ^ bar``
~~~~~~~~~~~~~

Change mask (relative)

::

  inet('2001:db8::/64')  ^ -8 -- returns inet('2001:db8::/56')
  inet('2001:db8::2/48') ^  8 -- returns inet('2001:db8::2/56')

``foo * bar``
~~~~~~~~~~~~~

Move network

::

  inet('2001:db8::/64')   *   1 -- returns inet('2001:db8:0:1::/64')
  inet('2001:db8:1::/64') * -16 -- returns inet('2001:db8:0:fff0::/64')


``foo:network()``
~~~~~~~~~~~~~~~~~

Reset the host bits.

::

  inet('192.0.2.4/24'):network() -- returns inet('192.0.2.0/24')


``foo:netmask()``
~~~~~~~~~~~~~~~~~

Build an IP address mask with the netmask of ``foo``.

::

  inet('192.0.2.0/24'):netmask() -- returns inet('255.255.255.0')
  inet('2001:db8::/52'):netmask() -- returns inet('ffff:ffff:ffff:f000::')
  inet('2001:db8::/56'):netmask() -- returns inet('ffff:ffff:ffff:ff00::')
  inet('2001:db8::/64'):netmask() -- returns inet('ffff:ffff:ffff:ffff::')


``foo:hostmask()``
~~~~~~~~~~~~~~~~~~

Build an IP address mask with the netmask of ``foo``.

::

  inet('192.0.2.0/24'):hostmask()   -- returns inet('0.0.0.255')
  inet('2001:db8::/64'):hostmask()  -- returns inet('::ffff:ffff:ffff:ffff')
  inet('2001:db8::/116'):hostmask() -- returns inet('::fff')
  inet('2001:db8::/112'):hostmask() -- returns inet('::ffff')


``foo:flip()``
~~~~~~~~~~~~~~

Flip the least significant network bit, to find the complimentary network.

::

  inet('192.0.2.0/26'):flip()  -- returns inet('192.0.2.64/26')
  inet('192.0.2.64/26'):flip() -- returns inet('192.0.2.0/26')
  inet('192.0.2.0/25'):flip()  -- returns inet('192.0.2.128/25')

Tests
-----

``<``, ``<=``, ``>=`` and ``>``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Compares ``inet`` instances according to the sort order.

::

  inet('192.0.2.0/26') < inet('192.0.2.64/26') -- returns true
  inet('192.0.2.0/24') < inet('192.0.2.0/26') -- returns true
  inet('192.0.2.0/26') < inet('192.0.2.1/26')  -- returns true
  inet('192.0.2.0/26') < inet('2001:db8::1/64')  -- returns true
  inet('2001:db8::1/64') < inet('192.0.2.0/26')  -- returns false

``==`` and ``~=``
~~~~~~~~~~~~~~~~~

Checks if two ``inet`` instances are of the same family, address and mask, or not.

::

  inet('192.0.2.0/24') == inet('192.0.2.0/24')  -- returns true
  inet('192.0.2.0/24') ~= inet('192.0.2.0/24')  -- returns false
  inet('192.0.2.0/24') == inet('192.0.2.0/26')  -- returns false
  inet('192.0.2.0/24') == inet('192.0.2.1/24')  -- returns false
  inet('192.0.2.0/24') == inet('2001:db8::')    -- returns false

``#foo``
~~~~~~~~

Returns the amount of significant network bits.

::

  #inet('192.0.2.0/24')  -- returns 24
  #inet('2001:db8::/48') -- returns 48

``foo:contains(bar)``
~~~~~~~~~~~~~~~~~~~~~~

``:contains()`` tests for subnet inclusion. It considers only the network parts of the two addresses, ignoring any host part, and determine whether one network part is a subnet of the other.

::

  inet('192.0.2.0/24'):contains(inet('192.0.2.64/26')) -- returns true
  inet('192.0.2.0/24'):contains(inet('192.0.2.0/26'))  -- returns true
  inet('192.0.2.0/24'):contains(inet('192.0.2.0/24'))  -- returns false
  inet('192.0.2.64/26'):contains(inet('192.0.2.0/24')) -- returns false

Text representation
-------------------

``inet6`` implements `RFC 5952`_ providing a standardized textual representation of IPv6 addresses.

``tostring(foo)``
~~~~~~~~~~~~~~~~~

String representation of ``foo``. If ``foo`` represents a host address, then just the address is returned, otherwise CIDR notation is used.

::

  tostring(inet('192.0.2.0/24')) -- returns '192.0.2.0/24'
  tostring(inet('192.0.2.0/32')) -- returns '192.0.2.0'

For IPv6, if the network is contained by ``inet.mixed_networks``, then mixed notation is used.

``foo:cidrstring(foo)``
~~~~~~~~~~~~~~~~~~~~~~~

Like ``tostring(foo)``, but always return the address in CIDR notation, as specified in `RFC 4632`_.

::

  inet('192.0.2.0/32'):cidrstring() -- returns '192.0.2.0/32'

``foo:ipstring()``
~~~~~~~~~~~~~~~~~~

Like ``tostring(foo)``, but always returns the only the IP address, and not the mask.

::

  inet('192.0.2.0/24'):ipstring() -- returns '192.0.2.0'

``foo:ipstring4()``
~~~~~~~~~~~~~~~~~~~

Like ``foo:ipstring()``, but always uses mixed notation.

::

  inet('2001:db8::c000:218'):ipstring()  -- returns '2001:db8::c000:218'
  inet('2001:db8::c000:218'):ipstring4() -- returns '2001:db8::192.0.2.24'

``foo:ipstring6()``
~~~~~~~~~~~~~~~~~~~

Like ``tostring(foo)``, but never uses mixed notation.

::

  inet('::ffff:192.0.2.24'):ipstring()  -- returns '::ffff:192.0.2.24'
  inet('::ffff:192.0.2.24'):ipstring6() -- returns '::ffff:c000:218'


``foo:bits(n)``
~~~~~~~~~~~~~~~

Return the IP as a table with elements of ``n`` bits each.

Valid values for ``n`` are ``1``, ``2``, ``4``, ``8``, ``16`` or ``32``.

::

  inet('192.0.2.24'):bits(32) -- returns { 3221226008 }
  inet('192.0.2.24'):bits(16) -- returns { 49152, 536 }
  inet('192.0.2.24'):bits(8) -- returns { 192, 0, 2, 24 }
  inet('192.0.2.24'):bits(4) -- returns { 12, 0, 0, 0, 0, 2, 1, 8 }
  inet('192.0.2.24'):bits(1) -- returns
    { 1, 1, 0, 0,  0, 0, 0, 0,   0, 0, 0, 0,  0, 0, 0, 0,
      0, 0, 0, 0,  0, 0, 1, 0,   0, 0, 0, 1,  1, 0, 0, 0 }

  inet('2001:db8::42/64'):bits(32) -- returns { 536939960, 0, 0, 66 }
  inet('::ffff:192.0.2.24'):bits(32) -- returns { 0, 0, 65535, 3221226008 }
  inet('2001:db8::42/64'):bits(16) -- returns { 8193, 3512, 0, 0, 0, 0, 0, 66 }
  inet('2001:db8::42/64'):bits(8) -- returns
    { 32, 1,  13, 184,  0, 0,  0, 0,  0, 0,  0, 0,  0, 0,  0, 66 }
  inet('2001:db8::42/64'):bits(4) -- returns
    { 2, 0, 0, 1,  0, 13, 11, 8,   0, 0, 0, 0,  0, 0, 0, 0,
      0, 0, 0, 0,  0,  0,  0, 0,   0, 0, 0, 0,  0, 0, 4, 2 }


``foo:subnets(n)``
~~~~~~~~~~~~~~~~~~

::

  inet('192.0.2.0/24'):subnets(26) -- returns 4
  inet('192.0.2.0/25'):subnets(26) -- returns 2
  inet('192.0.2.0/26'):subnets(26) -- returns 1
  inet('192.0.2.0/27'):subnets(26) -- returns 0.5
  inet('192.0.2.0/28'):subnets(26) -- returns 0.25

  inet('2001:db8::/48'):subnets(56) -- returns 256
  inet('2001:db8::/56'):subnets(64) -- returns 256
  inet('2001:db8::/48'):subnets(64) -- returns 65536
  inet('2001:db8::/64'):subnets(56) -- returns 0.00390625

``foo:family(n)``
~~~~~~~~~~~~~~~~~

::

  inet('192.0.2.0/24'):family()  -- returns 4
  inet('2001:db8::/64'):family() -- returns 6

``foo:full_family(n)``
~~~~~~~~~~~~~~~~~~~~~~

::

  inet('192.0.2.0/24'):full_family()  -- returns 'ipv4'
  inet('2001:db8::/64'):full_family() -- returns 'ipv6'

Sets
----

::

  local foo = inet.set()

``set:list()``
~~~~~~~~~~~~~~

List networks in set.

::

  foo:list() -- returns {}

``set:add(foo)``
~~~~~~~~~~~~~~~~

Add network to set.

::

  foo:add(inet('2001:db8::/48')) -- returns true
  foo:list() -- returns { inet('2001:db8::/48') }
  foo:add(inet('2001:db8:1::/48')) -- returns true
  foo:list() -- returns { inet('2001:db8::/47') }
  foo:add(inet('192.0.2.0/24')) -- returns nil, 'invalid family'

``set:remove(foo)``
~~~~~~~~~~~~~~~~~~~

Remove network from set.

::

  foo:remove(inet('2001:db8:1::/48')) -- returns true
  foo:remove(inet('2001:db8:1::/48')) -- returns false
  foo:list() -- returns { inet('2001:db8::/48') }

  foo:remove(inet('2001:db8:0:4200::/56')) -- returns true
  foo:list() -- returns {
    inet('2001:db8::/50'),
    inet('2001:db8:0:4000::/55'),
    inet('2001:db8:0:4300::/56'),
    inet('2001:db8:0:4400::/54'),
    inet('2001:db8:0:4800::/53'),
    inet('2001:db8:0:5000::/52'),
    inet('2001:db8:0:6000::/51'),
    inet('2001:db8:0:8000::/49'),
  }

  foo:add(inet('2001:db8:0:4200::/56')) -- returns true
  foo:list() -- returns { inet('2001:db8::/48') }

``set:contains(foo)``
~~~~~~~~~~~~~~~~~~~~~

If the network is contained or equal to a network in the set, then
the matching network will be returned, otherwise false is.

::

  foo:contains(inet('2001:db8::'))           -- returns inet('2001:db8::/48')
  foo:contains(inet('2001:db8::/32'))        -- returns false
  foo:contains(inet('2001:db8::/48'))        -- returns inet('2001:db8::/48')
  foo:contains(inet('2001:db8:1:2:3:4:5:6')) -- returns false

``set:flush()``
~~~~~~~~~~~~~~~

Empties the set.

::

  foo:flush() -- returns true
  foo:list()  -- returns {}

History
=======

* ``inet`` was brewed in Labitat_ in late 2014.
* Since then it has been battle-tested in production at the danish ISP Fiberby_.
* In July 2019 ``inet`` was finally polished up and released to the world.

License
=======

This project is licensed under `GNU Lesser General Public License version 3`_ or later.

.. _Labitat: https://labitat.dk/
.. _Fiberby: https://peeringdb.com/asn/42541
.. _Lua: http://www.lua.org/
.. _LPeg: http://www.inf.puc-rio.br/~roberto/lpeg/
.. _LuaRocks: https://luarocks.org/modules/asbjorn/inet
.. _LUA_INIT: http://www.lua.org/manual/5.3/manual.html#pdf-LUA_INIT
.. _RFC 4632: https://tools.ietf.org/html/rfc4632
.. _RFC 5952: https://tools.ietf.org/html/rfc5952
.. _GNU Lesser General Public License version 3: https://www.gnu.org/licenses/lgpl-3.0.en.html
