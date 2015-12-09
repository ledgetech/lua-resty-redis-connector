local redis = require "resty.redis"
redis.add_commands("sentinel")
local sentinel = require "resty.redis.sentinel"


local ipairs, setmetatable, pcall = ipairs, setmetatable, pcall
local ngx_null = ngx.null
local ngx_log = ngx.log
local ngx_DEBUG = ngx.DEBUG
local ngx_ERR = ngx.ERR
local ngx_re_match = ngx.re.match
local tbl_insert = table.insert
local tbl_remove = table.remove
local tbl_sort = table.sort

local ok, tbl_new = pcall(require, "table.new")
if not ok then
    tbl_new = function (narr, nrec) return {} end
end


local _M = {
    _VERSION = '0.03',
}

local mt = { __index = _M }


local DEFAULTS = {
    host = "127.0.0.1",
    port = 6379,
    path = nil, -- /tmp/redis.sock
    password = nil,
    db = 0,
    master_name = "mymaster",
    role = "master", -- master | slave | any (tries master first, failover to a slave)
    sentinels = nil,
    cluster_startup_nodes = {},
}


function _M.new()
    return setmetatable({
        connect_timeout = 100,
        read_timeout = 1000,
        connection_options = nil, -- pool, etc
    }, mt)
end


function _M.set_connect_timeout(self, timeout)
    self.connect_timeout = timeout
end


function _M.set_read_timeout(self, timeout)
    self.read_timeout = timeout
end


function _M.set_connection_options(self, options)
    self.connection_options = options
end


local function parse_dsn(params)
    local url = params.url
    if url then
        local url_pattern = [[^(?:(redis|sentinel)://)(?:([^@]*)@)?([^:/]+)(?::(\d+|[msa]+))/?(.*)$]]
        local m, err = ngx_re_match(url, url_pattern, "")
        if not m then
            ngx_log(ngx_ERR, "could not parse DSN: ", err)
        else
            local fields
            if m[1] == "redis" then
                fields = { "password", "host", "port", "db" }
            elseif m[1] == "sentinel" then
                fields = { "password", "master_name", "role", "db" }
            end
            
            -- password may not be present
            if #m < 5 then tbl_remove(fields, 1) end

            local roles = { m = "master", s = "slave", a = "any" }
            
            for i,v in ipairs(fields) do
                params[v] = m[i + 1]
                if v == "role" then
                    params[v] = roles[params[v]]
                end
            end
        end
    end
end


function _M.connect(self, params)
    -- If we have nothing, assume default host connection options apply
    if not params or type(params) ~= "table" then
        params = {}
    end

    if params.url then 
        parse_dsn(params) 
    end

    if params.sentinels then
        setmetatable(params, { __index = DEFAULTS } )
        return self:connect_via_sentinel(params)
    elseif params.startup_cluster_nodes then
        setmetatable(params, { __index = DEFAULTS } )
        -- TODO: Implement cluster
        return nil, "Redis Cluster not yet implemented"
    else
        setmetatable(params, { __index = DEFAULTS } )
        return self:connect_to_host(params)
    end
end


local function sort_by_localhost(a, b)
    if a.host == "127.0.0.1" then
        return true
    else
        return false
    end
end


function _M.connect_via_sentinel(self, params)
    local sentinels = params.sentinels
    local master_name = params.master_name
    local role = params.role
    local db = params.db
    local password = params.password

    local sentnl, err, previous_errors = self:try_hosts(sentinels)
    if not sentnl then
        return nil, err, previous_errors
    end

    if role == "master" or role == "any" then
        local master, err = sentinel.get_master(sentnl, master_name)
        if master then
            master.db = db
            master.password = password

            local redis, err = self:connect_to_host(master)
            if redis then
                sentnl:set_keepalive()
                return redis, err
            else
                if role == "master" then
                    return nil, err
                end
            end
        end
    end

    -- We either wanted a slave, or are failing over to a slave "any"
    local slaves, err = sentinel.get_slaves(sentnl, master_name)
    sentnl:set_keepalive()

    if not slaves then
        return nil, err
    end

    -- Put any slaves on 127.0.0.1 at the front
    tbl_sort(slaves, sort_by_localhost)

    if db or password then
        for i,slave in ipairs(slaves) do
            slave.db = db
            slave.password = password
        end
    end

    local slave, err, previous_errors = self:try_hosts(slaves)
    if not slave then
        return nil, err, previous_errors
    else
        return slave
    end
end


-- In case of errors, returns "nil, err, previous_errors" where err is
-- the last error received, and previous_errors is a table of the previous errors.
function _M.try_hosts(self, hosts)
    local errors = tbl_new(#hosts, 0)
    
    for i, host in ipairs(hosts) do
        local r
        r, errors[i] = self:connect_to_host(host)
        if r then
            return r, tbl_remove(errors), errors
        end
    end
    return nil, tbl_remove(errors), errors
end


function _M.connect_to_host(self, host)
    local r = redis.new()
    r:set_timeout(self.connect_timeout)

    local ok, err
    local socket = host.socket
    if socket then
        if self.connection_options then
            ok, err = r:connect(socket, self.connection_options)
        else
            ok, err = r:connect(socket)
        end
    else
        if self.connection_options then
            ok, err = r:connect(host.host, host.port, self.connection_options)
        else
            ok, err = r:connect(host.host, host.port)
        end
    end

    if not ok then
        ngx_log(ngx_ERR, err, " for ", host.host, ":", host.port)
        return nil, err
    else
        r:set_timeout(self, self.read_timeout)

        local password = host.password
        if password then
            local res, err = r:auth(password)
            if err then
                ngx_log(ngx_ERR, err)
                return res, err
            end
        end

        r:select(host.db)
        return r, nil
    end
end


return _M
