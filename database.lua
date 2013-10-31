module ('etherclan', package.seeall) do

  database = {
    -- class methods
    create = nil,

    -- methods
    add_node = nil,

    -- attributes
    known_nodes = nil
  }
  database.__index = database

  function database.create()
    local newdb = {
      known_nodes = {},
    }
    setmetatable(newdb, database)
    return newdb
  end

  known_nodes = {}

  function database:add_node(node_or_uuid, ip, port)
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
    self:debug_message("Add Node: '" .. node.uuid .. "'")
    self.known_nodes[node.uuid] = node
    self.known_nodes[node.uuid].connection_errors = 0
    self.known_nodes[node.uuid].last_time = os.time()
    node.services = node.services or {}
  end

  function database:update_time(uuid)
    self:debug_message("Update Time: '" .. uuid .. "'")
    self.known_nodes[uuid].last_time = os.time()
  end

  function database:debug_message(msg)
    print("[DB] - " .. msg)
  end
end