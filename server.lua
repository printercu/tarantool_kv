#!/usr/bin/env tarantool

HTTP_HOST = '127.0.0.1'
HTTP_PORT = 3000
HTTP_REALM = 'app'

box.cfg {
  listen = 3301,
  wal_dir = 'tmp',
  memtx_dir = 'tmp',
}

box.once('bootstrap', function()
  dofile('./models/auth.lua')
  dofile('./models/store.lua')

  box.schema.user.grant('guest', 'read,write,execute', 'universe')
  box.space.auth:upsert({'testtoken'}, {})
end)

local function readValue(request)
  local authResponse = authorizeRequest(request)
  if authResponse ~= nil then
    return authResponse
  end
  local key = request:stash('key')
  local value = box.space.store:get(key)
  if value == nil then
    return {status = 404, body = '{"error":"Not found"}'}
  else
    return {status = 200, body = value.content}
  end
end

local function writeValue(request)
  local authResponse = authorizeRequest(request)
  if authResponse ~= nil then
    return authResponse
  end
  local key = request:stash('key')
  local content = request:read()
  box.space.store:upsert({key, content}, {{'=', 2, content}})
  return {status = 200}
end

local function deleteValue(request)
  local authResponse = authorizeRequest(request)
  if authResponse ~= nil then
    return authResponse
  end
  local key = request:stash('key')
  box.space.store:delete({key})
  return {status = 204}
end

function authorizeRequest(request)
  header = request.headers['authorization']
  if header == nil then
    return {
      status = 401,
      body = '{"error":"Unauthorized"}',
      headers = { ['WWW-Authenticate'] = 'Bearer realm=' .. HTTP_REALM }
    }
  end
  _, _, token = header:find('Bearer%s+(.+)')
  if token == nil or box.space.auth:get(token) == nil then
    return {
      status = 403,
      body = '{"error":"Forbidden"}',
    }
  end
end

local httpd = require('http.server').new(HTTP_HOST, HTTP_PORT)
httpd:route({path = '/:key', method = 'GET'}, readValue)
httpd:route({path = '/:key', method = 'POST'}, writeValue)
httpd:route({path = '/:key', method = 'DELETE'}, deleteValue)
httpd:start()
