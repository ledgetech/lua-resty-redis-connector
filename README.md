# lua-resty-redis-connector

Connection utilities for [lua-resty-redis](https://github.com/openresty/lua-resty-redis), making
it easy and reliable to connect to Redis hosts, either directly or via 
[Redis Sentinel](http://redis.io/topics/sentinel).


## Synopsis

```lua
local redis_connector = require "resty.redis.connector"
local rc = redis_connector.new()

local redis, err = rc:connect{ url = "redis://PASSWORD@127.0.0.1:6379/2" }
if not redis then
    ngx.log(ngx.ERR, err)
end
```

## DSN format

The [connect](#connect) method accepts a single table of named arguments. If the `url` field is
present then it will be parsed, overriding values supplied in the parameters table.

The format for connecting directly to Redis is:

`redis://PASSWORD@HOST:PORT/DB`

The `PASSWORD` and `DB` fields are optional, all other components are required.

When connecting via Redis Sentinel, the format is as follows:

`sentinel://PASSWORD@MASTER_NAME:ROLE/DB`

Again, `PASSWORD` and `DB` are optional. `ROLE` must be any of `m`, `s` or `a`, meaning:

* `m`: master
* `s`: slave
* `a`: any (first tries the master, but will failover to a slave if required)


## Parameters

The [connect](#connect) method expects the following field values, either by falling back to
defaults, populating the fields by parsing the DSN, or being specified directly.

The defaults are as follows:


```lua
{
    host = "127.0.0.1",
    port = "6379",
    path = nil, -- unix socket path, e.g. /tmp/redis.sock
    password = "",
    db = 0,
    master_name = "mymaster",
    role = "master", -- master | slave | any
    sentinels = nil,
}
```

Note that if `sentinel://` is supplied as the `url` parameter, a table of `sentinels` must also 
be supplied. e.g.

```lua
local redis, err = rc:connect{
    url = "sentinel://mymaster:a/2",
    sentinels = {
        { host = "127.0.0.1", port = 26379" },
    }
}
```


## API

* [new](#new)
* [set_connect_timeout](#set_connect_timeout)
* [set_read_timeout](#set_read_timeout)
* [set_connection_options](#set_connection_options)
* [connect](#connect)


### new

`syntax: rc = redis_connector.new()`

Creates the Redis Connector object. In case of failures, returns `nil` and a string describing the error.


### set_connect_timeout

`syntax: rc:set_connect_timeout(100)`

Sets the cosocket connection timeout, in ms.



### set_read_timeout

`syntax: rc:set_read_timeout(500)`

Sets the cosocket read timeout, in ms.


### set_connection_options

`syntax: rc:set_connection_options({ pool = params.host .. ":" .. params.port .. "/" .. params.db })`

Sets the connection options table, as supplied to [tcpsock:connect](https://github.com/openresty/lua-nginx-module#tcpsockconnect)
method.


### connect

`syntax: redis, err = rc:connect(params)`

Attempts to create a connection, according to the [params](#parameters) supplied.


## TODO

* Redis Cluster support.


# Author

James Hurst <james@pintsized.co.uk>


# Licence

This module is licensed under the 2-clause BSD license.

Copyright (c) 2013, James Hurst <james@pintsized.co.uk>

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
