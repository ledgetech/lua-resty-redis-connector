use Test::Nginx::Socket 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';
$ENV{TEST_NGINX_REDIS_PORT} ||= 6379;

no_long_string();
run_tests();

__DATA__

=== TEST 1: basic connect
--- http_config eval: $::HttpConfig
--- config
location /t {
    content_by_lua_block {
        local rc = require("resty.redis.connector").new({
            port = $TEST_NGINX_REDIS_PORT
        })

        local redis = assert(rc:connect(params),
            "connect should return positively")

        assert(redis:set("dog", "an animal"),
            "redis:set should return positively")

        redis:close()
    }
}
--- request
GET /t
--- no_error_log
[error]


=== TEST 2: try_hosts
--- http_config eval: $::HttpConfig
--- config
location /t {
    lua_socket_log_errors off;
    content_by_lua_block {
        local rc = require("resty.redis.connector").new({
            connect_timeout = 100,
        })

        local hosts = {
            { host = "127.0.0.1", port = 1 },
            { host = "127.0.0.1", port = 2 },
            { host = "127.0.0.1", port = $TEST_NGINX_REDIS_PORT },
        }

        local redis, err, previous_errors = rc:try_hosts(hosts)
        assert(redis and not err,
            "try_hosts should return a connection and no error")

        assert(previous_errors[1] == "connection refused",
            "previous_errors[1] should be 'connection refused'")
        assert(previous_errors[2] == "connection refused",
            "previous_errors[2] should be 'connection refused'")

        assert(redis:set("dog", "an animal"),
            "redis connection should be working")

        redis:close()

        local hosts = {
            { host = "127.0.0.1", port = 1 },
            { host = "127.0.0.1", port = 2 },
        }

        local redis, err, previous_errors = rc:try_hosts(hosts)
        assert(not redis and err == "no hosts available",
            "no available hosts should return an error")

        assert(previous_errors[1] == "connection refused",
            "previous_errors[1] should be 'connection refused'")
        assert(previous_errors[2] == "connection refused",
            "previous_errors[2] should be 'connection refused'")
    }
}
--- request
    GET /t
--- no_error_log
[error]


=== TEST 3: Test connect_to_host directly
--- http_config eval: $::HttpConfig
--- config
location /t {
    content_by_lua_block {
        local redis_connector = require "resty.redis.connector"
        local rc = redis_connector.new()

        local host = { host = "127.0.0.1", port = $TEST_NGINX_REDIS_PORT }

        local redis, err = rc:connect_to_host(host)
        if not redis then
            ngx.say("failed to connect: ", err)
            return
        end

        local res, err = redis:set("dog", "an animal")
        if not res then
            ngx.say("failed to set dog: ", err)
            return
        end

        ngx.say("set dog: ", res)

        redis:close()
    }
}
--- request
    GET /t
--- response_body
set dog: OK
--- no_error_log
[error]


=== TEST 4: Test connect options override
--- http_config eval: $::HttpConfig
--- config
location /t {
    content_by_lua_block {
        local redis_connector = require "resty.redis.connector"
        local rc = redis_connector.new()

        local host = {
            host = "127.0.0.1",
            port = $TEST_NGINX_REDIS_PORT,
            db = 1,
        }

        local redis, err = rc:connect_to_host(host)
        if not redis then
            ngx.say("failed to connect: ", err)
            return
        end

        local res, err = redis:set("dog", "an animal")
        if not res then
            ngx.say("failed to set dog: ", err)
            return
        end

        ngx.say("set dog: ", res)

        redis:select(2)
        ngx.say(redis:get("dog"))

        redis:select(1)
        ngx.say(redis:get("dog"))

        redis:close()
    }
}
--- request
    GET /t
--- response_body
set dog: OK
null
an animal
--- no_error_log
[error]


=== TEST 5: Test set_keepalive method
--- http_config eval: $::HttpConfig
--- config
location /t {
    lua_socket_log_errors Off;
    content_by_lua_block {
        local rc = require("resty.redis.connector").new()

        local redis = assert(rc:connect(),
            "rc:connect should return positively")
        local ok, err = rc:set_keepalive(redis)
        assert(not err, "set_keepalive error should be nil")

        local ok, err = redis:set("foo", "bar")
        assert(not ok, "ok should be nil")
        assert(string.find(err, "closed"), "error should contain 'closed'")

        local redis = assert(rc:connect(), "connect should return positively")
        assert(redis:subscribe("channel"), "subscribe should return positively")

        local ok, err = rc:set_keepalive(redis)
        assert(not ok, "ok should be nil")
        assert(string.find(err, "subscribed state"),
            "error should contain 'subscribed state'")

    }
}
--- request
GET /t
--- no_error_log
[error]
