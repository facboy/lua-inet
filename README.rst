=========================================
``inet`` - an IP address mangling library
=========================================

``inet`` is meant to make it fun to do IP address calculations.

::

  local inet = require 'inet'

  -- get first address of the 3rd /64 in a /56
  inet('2001:db8::/56') / 64 * 3 + 1  -- returns inet('2001:db8:0:3::1/64')

  -- get last /64 in a /56
  inet('2001:db8::/56') * 1 / 64 * -1 -- returns inet('2001:db8:0:ff::/64')


Dependencies
============

- Lua_ version 5.2 or 5.3
- LPeg_ - Parsing Expression Grammars For Lua

API
===

``inet`` module
---------------

======================= =====================================================
API                     Description
======================= =====================================================
``inet(...)``           Parse address and build ``inet4`` or ``inet6`` table
``inet.is(foo)``        is ``foo`` an ``inet*`` table
``inet.is4(foo)``       is ``foo`` an ``inet4`` table
``inet.is6(foo)``       is ``foo`` an ``inet6`` table
``inet.set4()``         get new empty IPv4 set
``inet.set6()``         get new empty IPv6 set
``inet.mixed_networks`` IPv6 mixed notation set
``inet.version``        API version (currently ``1``)
======================= =====================================================

IPv6 mixed notation configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``inet.mixed_networks`` can be used to configure which IPv6 networks
should use mixed notation, ie. last 32 bits formatted as IPv4,
as per `RFC 5952`_ section 5.

Initially the set only contains the well-known ``::ffff:0.0.0.0/96`` network.

Common ``inet*`` API
--------------------

================= ======================================
Operator          Description
================= ======================================
``+``             Addition
``-``             Subtract
``/``             Change mask (absolute)
``^``             Change mask (relative)
``*``             Move network
``<``             is less than
``<=``            is less than or equal
``==``            equals
``>=``            is greater or equal
``>``             is greater than
``~=``            not equals
``#``             number of network bits
``:contains()``   contains
``:network()``    extract network part of address
``tostring(net)`` convert to network
``:ipstring()``   ip as string without prefix
``:cidrstring()`` format CIDR notation
``:netmask()``    generate netmask as address
``:flip()``       flip the least significant network bit
================= ======================================


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

  inet('2001:db8::/64') + 5 -- returns inet('2001:db8::5/64')

  --inet('::ffff:0.0.0.0/96') + inet('192.0.2.24') -- returns inet('192.0.2.24')

``foo - bar``
~~~~~~~~~~~~~

Subtract

::

  inet('2001:db8::5/64') - 5 -- returns inet('2001:db8::/64')

  --inet('2001:db8::5/64') - inet('2001:db8::') -- returns 5

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

Like ``tostring(foo)``, but always just return the IP address.

::

  inet('192.0.2.0/24'):ipstring() -- returns '192.0.2.0'

``foo:ipstring4()``
~~~~~~~~~~~~~~~~~~~

Like ``foo:ipstring()``, but always uses mixed notation.

``foo:ipstring6()``
~~~~~~~~~~~~~~~~~~~

Like ``tostring(foo)``, but never uses mixed notation.

Sets
----

``set:list()``
~~~~~~~~~~~~~~

list networks in set

``set:add(foo)``
~~~~~~~~~~~~~~~~

add network to set

``set:remove(foo)``
~~~~~~~~~~~~~~~~~~~

remove network from set

``set:contains(foo)``
~~~~~~~~~~~~~~~~~~~~~

is network contained in set?

``set:flush()``
~~~~~~~~~~~~~~~

Empties the set.

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
.. _RFC 4632: https://tools.ietf.org/html/rfc4632
.. _RFC 5952: https://tools.ietf.org/html/rfc5952
.. _GNU Lesser General Public License version 3: https://www.gnu.org/licenses/lgpl-3.0.en.html