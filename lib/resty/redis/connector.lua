local redis = require "resty.redis"
redis.add_commands("sentinel")
local sentinel = require "resty.redis.sentinel"


local ipairs, type, setmetatable = ipairs, type, setmetatable
local ngx_null = ngx.null
local ngx_log = ngx.log
local ngx_DEBUG = ngx.DEBUG
local ngx_ERR = ngx.ERR
local tbl_insert = table.insert
local tbl_remove = table.remove

local ok, tbl_new = pcall(require, "table.new")
if not ok then
    tbl_new = function (narr, nrec) return {} end
end


local _M = {
    _VERSION = '0.01',
}

local mt = { __index = _M }


local DEFAULTS = {
    host = "127.0.0.1",
    port = 6379,
    path = nil,
    password = nil,
    db = 0,
    master_name = "mymaster",
    role = "master", -- master | slave | any (tries master first, failover to a slave)
    sentinels = nil, {
        { host = "127.0.0.1", port = 6379 }
    },
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


function _M.set_connect_options(self, options)
    self.connection_options = options
end


function _M.connect(self, params)
    -- If we have nothing, assume default host connection options apply
    if not params then
        params = {}
    end
    
    if params.url then
        -- interpret DSN string
    end

    if params.sentinels then
        setmetatable(params, { __index = DEFAULTS } )
        return self:connect_via_sentinel(params.sentinels, params.master_name, params.role)
    elseif params.startup_cluster_nodes then
        setmetatable(params, { __index = DEFAULTS } )
        -- TODO: Implement cluster
        return nil, "Redis Cluster not yet implemented"
    else
        setmetatable(params, { __index = DEFAULTS } )
        return self:connect_to_host(params)
    end
end


function _M.connect_via_sentinel(self, sentinels, master_name, role)
    local sentnl, err, previous_errors = self:try_hosts(sentinels)
    if not sentnl then
        return nil, err, previous_errors
    end

    if role == "master" or role == "any" then
        local master, err = sentinel.get_master(sentnl, master_name)
        if master then
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
        r:select(host.db)
        return r, nil
    end
end


return _M
