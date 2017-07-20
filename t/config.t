use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * blocks() * 2;

my $pwd = cwd();

our $HttpConfig = qq{
lua_package_path "$pwd/lib/?.lua;;";

init_by_lua_block {
    require("luacov.runner").init()
}
};

$ENV{TEST_NGINX_REDIS_PORT} ||= 6379;

no_long_string();
run_tests();

__DATA__

=== TEST 1: Default config
--- http_config eval: $::HttpConfig
--- config
location /t {
    content_by_lua_block {
        local rc = require("resty.redis.connector").new()

        local redis = assert(rc:connect(), "rc:connect should return postively")
        assert(redis:set("foo", "bar"), "redis:set should return positvely")
        assert(redis:get("foo") == "bar", "get(foo) should return bar")
        redis:close()
    }
}
--- request
GET /t
--- no_error_log
[error]


=== TEST 2: Defaults via new
--- http_config eval: $::HttpConfig
--- config
location /t {
    content_by_lua_block {
        local config = {
            connect_timeout = 500,
            port = 6380,
            db = 6,
        }
        local rc = require("resty.redis.connector").new(config)

        assert(config ~= rc.config, "config should not equal rc.config")
        assert(rc.config.connect_timeout == 500, "connect_timeout should be 500")
        assert(rc.config.db == 6, "db should be 6")
        assert(rc.config.role == "master", "role should be master")
    }
}
--- request
GET /t
--- no_error_log
[error]


=== TEST 3: Config via connect still overrides
--- http_config eval: $::HttpConfig
--- config
location /t {
    content_by_lua_block {
        local rc = require("resty.redis.connector").new({
            connect_timeout = 500,
            port = 6380,
            db = 6,
            keepalive_poolsize = 10,
        })

        assert(config ~= rc.config, "config should not equal rc.config")
        assert(rc.config.connect_timeout == 500, "connect_timeout should be 500")
        assert(rc.config.db == 6, "db should be 6")
        assert(rc.config.role == "master", "role should be master")
        assert(rc.config.keepalive_poolsize == 10,
            "keepalive_poolsize should be 10")

        local redis = assert(rc:connect({ port = 6379 }),
            "rc:connect should return positively")
    }
}
--- request
GET /t
--- no_error_log
[error]


=== TEST 4: Unknown config errors, all config does not error
--- http_config eval: $::HttpConfig
--- config
location /t {
    content_by_lua_block {
        local rc, err = require("resty.redis.connector").new({
            connect_timeout = 500,
            port = 6380,
            db = 6,
            foo = "bar",
        })

        assert(rc == nil, "rc should be nil")
        assert(string.find(err, "field foo does not exist"),
            "err should contain error")

        -- Provide all options, without errors

        assert(require("resty.redis.connector").new({
            connect_timeout = 100,
            read_timeout = 1000,
            connection_options = { pool = "<host>::<port>" },
            keepalive_timeout = 60000,
            keepalive_poolsize = 30,

            host = "127.0.0.1",
            port = 6379,
            path = "",
            password = "",
            db = 0,

            url = "",

            master_name = "mymaster",
            role = "master",
            sentinels = {},
        }), "new should return positively")

        -- Provide all options via connect, without errors

        local rc = require("resty.redis.connector").new()

        assert(rc:connect({
            connect_timeout = 100,
            read_timeout = 1000,
            connection_options = { pool = "<host>::<port>" },
            keepalive_timeout = 60000,
            keepalive_poolsize = 30,

            host = "127.0.0.1",
            port = 6379,
            path = "",
            password = "",
            db = 0,

            url = "",

            master_name = "mymaster",
            role = "master",
            sentinels = {},
        }), "rc:connect should return positively")
    }
}
--- request
GET /t
--- no_error_log
[error]
