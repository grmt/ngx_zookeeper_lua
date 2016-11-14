local zoo = require 'ngx.zookeeper'
local system = require "system"

local timeout = zoo.timeout()

local _M = {
  _VERSION = '1.0.0',

  errors = {
      ZOO_TIMEOUT = "TIMEOUT"
  },

  flags = {
      ZOO_EPHEMERAL = bit.lshift(1, 0),
      ZOO_SEQUENCE = bit.lshift(1, 1)
  }
}

local function timeto()
  return ngx.now() * 1000 + timeout
end

local function sleep(sec)
  local ok = pcall(ngx.sleep, sec)
  if not ok then
    ngx.log(ngx.WARN, "blocking sleep function is used")
    system.sleep(sec)
  end
end

function _M.get(znode)
  local ok, sc = zoo.aget(znode)

  if not ok then
    return ok, nil, sc, nil
  end

  local time_limit = timeto()
  local completed, value, err, stat

  while not completed and ngx.now() * 1000 < time_limit
  do
    sleep(0.001)
    completed, value, err, stat = zoo.check_completition(sc)
  end

  if not completed then
    zoo.forgot(sc)
    err = _M.errors.ZOO_TIMEOUT
  end

  return completed and not err, value, err, stat
end

function _M.childrens(znode)
  local ok, sc = zoo.achildrens(znode)

  if not ok then
    return ok, nil, sc
  end

  local time_limit = timeto()
  local completed, childs, err

  while not completed and ngx.now() * 1000 < time_limit
  do
    sleep(0.001)
    completed, childs, err = zoo.check_completition(sc)
  end

  if not completed then
    zoo.forgot(sc)
    err = _M.errors.ZOO_TIMEOUT
  end

  ok = completed and not err

  if ok and not childs then
    childs = {}
  end

  return ok, childs, err
end

function _M.set(znode, value, version)
  if not version then
    version = -1
  end

  local ok, sc = zoo.aset(znode, value, version)

  if not ok then
    return ok, nil, sc, nil
  end

  local time_limit = timeto()
  local completed, err, stat

  while not completed and ngx.now() * 1000 < time_limit
  do
    sleep(0.001)
    completed, _, err, stat = zoo.check_completition(sc)
  end

  if not completed then
    zoo.forgot(sc)
    err = _M.errors.ZOO_TIMEOUT
  end

  return completed and not err, err, stat
end

function _M.create(znode, value, flags)
  if not value then
    value = ""
  end

  if not flags then
    flags = 0
  end

  local ok, sc = zoo.acreate(znode, value, flags)

  if not ok then
    return ok, nil, sc
  end

  local time_limit = timeto()
  local completed, result, err

  while not completed and ngx.now() * 1000 < time_limit
  do
    sleep(0.001)
    completed, result, err = zoo.check_completition(sc)
  end

  if not completed then
    zoo.forgot(sc)
    err = _M.errors.ZOO_TIMEOUT
  end

  return completed and not err, result, err
end

function _M.delete(znode)
  local ok, sc = zoo.adelete(znode)

  if not ok then
    return ok, sc
  end

  local time_limit = timeto()
  local completed, err

  while not completed and ngx.now() * 1000 < time_limit
  do
    sleep(0.001)
    completed, _, err = zoo.check_completition(sc)
  end

  if not completed then
    zoo.forgot(sc)
    err = _M.errors.ZOO_TIMEOUT
  end

  return completed and not err, err
end

function _M.connected()
  return zoo.connected()
end

return _M
