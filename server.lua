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
  local key = request:stash('key')
  local value = box.space.store:get(key)
  if value == nil then
    return jsonResponse(404, '{"error":"Not found"}')
  else
    -- TODO: change to jsonResponse when writeValue validates for valid json
    return {status = 200, body = value.content}
  end
end

-- TODO: validate for json content. Try request:json()
local function writeValue(request)
  local key = request:stash('key')
  local content = request:read()
  box.space.store:upsert({key, content}, {{'=', 2, content}})
  return jsonResponse(200, '{}')
end

local function deleteValue(request)
  local key = request:stash('key')
  box.space.store:delete({key})
  return {status = 204}
end

local function withAuthorization(callback)
  return function(request)
    header = request.headers['authorization']
    if header == nil then
      return jsonResponse(401, '{"error":"Unauthorized"}', {
        ['WWW-Authenticate'] = 'Bearer realm=' .. HTTP_REALM
      })
    end
    _, _, token = header:find('Bearer%s+(.+)')
    if token == nil or box.space.auth:get(token) == nil then
      return jsonResponse(403, '{"error":"Forbidden"}')
    end
    return callback(request)
  end
end

function jsonResponse(status, body, headers)
  local responseHeaders = {['Content-Type'] = 'application/json'}
  if headers then
    for k, v in pairs(headers) do responseHeaders[k] = v end
  end
  return {status = status, body = body, headers = responseHeaders}
end

local httpd = require('http.server').new(HTTP_HOST, HTTP_PORT)
httpd:route({path = '/:key', method = 'GET'}, withAuthorization(readValue))
httpd:route({path = '/:key', method = 'POST'}, withAuthorization(writeValue))
httpd:route({path = '/:key', method = 'DELETE'}, withAuthorization(deleteValue))
httpd:start()
