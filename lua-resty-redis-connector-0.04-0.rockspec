package = "lua-resty-redis-connector"
version = "0.04-0"
source = {
  url = "git://github.com/pintsized/lua-resty-redis-connector",
  tag = "v0.04"
}
description = {
  summary = "Connection utilities for lua-resty-redis.",
  detailed = [[
    Connection utilities for lua-resty-redis, making it easy and
    reliable to connect to Redis hosts, either directly or via Redis
    Sentinel.
  ]],
  homepage = "https://github.com/pintsized/lua-resty-redis-connector",
  license = "2-clause BSD",
  maintainer = "James Hurst <james@pintsized.co.uk>"
}
dependencies = {
  "lua >= 5.1",
}
build = {
  type = "builtin",
  modules = {
    ["resty.redis.connector"] = "lib/resty/redis/connector.lua",
    ["resty.redis.sentinel"] = "lib/resty/redis/sentinel.lua"
  }
}
