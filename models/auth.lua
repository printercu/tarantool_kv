local s = box.schema.space.create('auth')

s:format({
  {name = 'token', type = 'string'},
})

s:create_index('primary', {
  type = 'hash',
  parts = {'token'},
})
