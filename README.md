# lua-resty-redis-connector

Connection utilities for lua-resty-redis

## Synopsis

```lua
local redis_connector = require "resty.redis.connector"
local rc = redis_connector.new()
rc:set_connect_timeout(1000)
rc:set_read_timeout(200)
rc:set_connect_options(...)

-- Simple redis connection, to database 1
local redis, err = rc:connect{ 
    host = "127.0.0.1",
    port = 6379,
    db = 1,
    password = "mysecret",
}

-- Connect using a Unix socket.
local redis, err = rc:connect{
    path = "/tmp/redis.sock",
    db = 2,
}

-- Connect via Sentinel, to the master
local redis, err = rc:connect{
    mastername = "mymaster",
    role = "master",
    db = 3,
    password = "mysecret",
    sentinels = {
        { host = "127.0.0.1", 26379 },
        { host = "192.168.1.1", 26379 },
    },
}


-- Simple connection using a connection string.
local redis, err = rc:connect{ url = "redis://PASSWORD@127.0.0.1:6379/1" }

-- Connect via Sentinel to the master with the mastername "mymaster", and select database 3.
local redis, err = rc:connect{
    url = "sentinel://PASSWORD@mymaster:m/3",
    sentinels = {
        { host = "127.0.0.1", 26379 },
        { host = "192.168.1.1", 26379 },
    }
}


-- Connect to a slave with the mastername "mymaster", and selecte database 2.
local redis, err = rc:connect{
    url = "redis://PASSWORD@mymaster:s/2",
    sentinels = {
        { host = "127.0.0.1", 26379 },
        { host = "192.168.1.1", 26379 },
    }
}

rc:connect{ url = "redis://PASSWORD@mymaster:s/2", sentinels = { host = "127.0.0.1", port = 26379 } }

rc:connect{ 
    cluster_startup_nodes = { 
        { host = "127.0.0.1", port = 6379 },
    }
}

-- Attempt connection to the master with the mastername "mymaster". If it
-- cannot be reached, try each slave until one connects. Then select database 2.
local redis, err = rc:connect{
    url = "sentinel://PASSWORD@mymaster:ms/2",
    sentinels = {
        { host = "127.0.0.1", port = 26379 },
        { host = "192.168.1.1", port = 26379 },
    }
}


```
