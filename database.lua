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
    local uuid
    if type(node_or_uuid) == 'table' then
      uuid = node_or_uuid.uuid
      ip = node_or_uuid.ip
      port = node_or_uuid.port
    else
      uuid = node_or_uuid
    end
    assert(uuid, "add_node must receive at least an uuid")

    local new_node = self.known_nodes[uuid] or { services = {} }

    self.known_nodes[uuid] = new_node

    new_node.uuid = uuid
    new_node.ip = ip
    new_node.port = port
    new_node.connection_errors = 0
    new_node.last_time = os.time()
  end

  function database:update_time(uuid)
    self:debug_message("Update Time: '" .. uuid .. "'")
    self.known_nodes[uuid].last_time = os.time()
  end

  function database:debug_message(msg)
    print("[DB] - " .. msg)
  end
end