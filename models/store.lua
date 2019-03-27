local s = box.schema.space.create('store')

s:format({
  {name = 'id', type = 'string'},
  {name = 'content', type = 'string'},
})

s:create_index('primary', {
  type = 'hash',
  parts = {'id'},
})
