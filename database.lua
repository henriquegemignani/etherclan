module ('etherclan', package.seeall) do

  database = {

  }
  database.__index = database

  function database.create()
    local newdb = {
    }
    setmetatable(newdb, database)
    return newdb
  end

  known_nodes = {}

  function add_node(node_or_uuid, ip, port)
    local node
    if type(node_or_uuid) ~= 'table' then
      node = {
        uuid = node_or_uuid,
        ip = ip,
        port = port,
      }
    else
      node = node_or_uuid
    end
    assert(node.uuid, "add_node must receive at least an uuid")
    known_nodes[node.uuid] = node
  end
end