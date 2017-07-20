# lua-resty-redis-connector

Connection utilities for [lua-resty-redis](https://github.com/openresty/lua-resty-redis), making it easy and reliable to connect to Redis hosts, either directly or via [Redis Sentinel](http://redis.io/topics/sentinel).


## Synopsis

Quick and simple authenticated connection on localhost to DB 2:

```lua
local redis, err = require("resty.redis.connector").new({
    url = "redis://PASSWORD@127.0.0.1:6379/2",
}):connect()
```

More verbose configuration, with timeouts and a default password:

```lua
local rc = require("resty.redis.connector").new({
    connect_timeout = 50,
    read_timeout = 5000,
    keepalive_timeout = 30000,
    password = "mypass",
})

local redis, err = rc:connect({
    url = "redis://127.0.0.1:6379/2",
})

-- ...

local ok, err = rc:set_keepalive(redis)  -- uses keepalive params
```

Keep all config in a table, to easily create / close connections as needed:

```lua
local rc = require("resty.redis.connector").new({
    connect_timeout = 50,
    read_timeout = 5000,
    keepalive_timeout = 30000,
    
    host = "127.0.0.1",
    port = 6379,
    db = 2,
    password = "mypass",
})

local redis, err = rc:connect()

-- ...

local ok, err = rc:set_keepalive(redis)
```

`connect` can be used to override defaults given in `new`


```lua
local rc = require("resty.redis.connector").new({
    host = "127.0.0.1",
    port = 6379,
    db = 2,
})

local redis, err = rc:connect({
    db = 5,
})
```


## DSN format

If the `params.url` field is present then it will be parsed, overriding values supplied in the parameters table.

### Direct Redis connections

The format for connecting directly to Redis is:

`redis://PASSWORD@HOST:PORT/DB`

The `PASSWORD` and `DB` fields are optional, all other components are required.

### Connections via Redis Sentinel

When connecting via Redis Sentinel, the format is as follows:

`sentinel://PASSWORD@MASTER_NAME:ROLE/DB`

Again, `PASSWORD` and `DB` are optional. `ROLE` must be any of `m`, `s` or `a`, meaning:

* `m`: master
* `s`: slave
* `a`: any (first tries the master, but will failover to a slave if required)

A table of `sentinels` must also be supplied. e.g.

```lua
local redis, err = rc:connect{
    url = "sentinel://mymaster:a/2",
    sentinels = {
        { host = "127.0.0.1", port = 26379" },
    }
}
```


## Default Parameters


```lua
{
    connect_timeout = 100,
    read_timeout = 1000,
    connection_options = {}, -- pool, etc
    keepalive_timeout = 60000,
    keepalive_poolsize = 30,
    
    host = "127.0.0.1",
    port = "6379",
    path = "",  -- unix socket path, e.g. /tmp/redis.sock
    password = "",
    db = 0,
    
    master_name = "mymaster",
    role = "master",  -- master | slave | any
    sentinels = {},
}
```


## API

* [new](#new)
* [connect](#connect)
* [Utilities](#utilities)
    * [connect_via_sentinel](#connect_via_sentinel)
    * [try_hosts](#try_hosts)
    * [connect_to_host](#connect_to_host)
    * [sentinel.get_master](#sentinelget_master)
    * [sentinel.get_slaves](#sentinelget_slaves)


### new

`syntax: rc = redis_connector.new()`

Creates the Redis Connector object. In case of failures, returns `nil` and a string describing the error.


### connect

`syntax: redis, err = rc:connect(params)`

Attempts to create a connection, according to the [params](#parameters) supplied. If a connection cannot be made, returns `nil` and a string describing the reason.


## Utilities

The following methods are not typically needed, but may be useful if a custom interface is required.


### connect_via_sentinel

`syntax: redis, err = rc:connect_via_sentinel(params)`

Returns a Redis connection by first accessing a sentinel as supplied by the `params.sentinels` table,
and querying this with the `params.master_name` and `params.role`.


### try_hosts

`syntax: redis, err = rc:try_hosts(hosts)`

Tries the hosts supplied in order and returns the first successful connection.


### connect_to_host

`syntax: redis, err = rc:connect_to_host(host)`

Attempts to connect to the supplied `host`.


### sentinel.get_master

`syntax: master, err = sentinel.get_master(sentinel, master_name)`

Given a connected Sentinel instance and a master name, will return the current master Redis instance.


### sentinel.get_slaves

`syntax: slaves, err = sentinel.get_slaves(sentinel, master_name)`

Given a connected Sentinel instance and a master name, will return a list of registered slave Redis instances.


# Author

James Hurst <james@pintsized.co.uk>


# Licence

This module is licensed under the 2-clause BSD license.

Copyright (c) James Hurst <james@pintsized.co.uk>

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
