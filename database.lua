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

  local function new_node()
    local node = {}
    function node:services_string()
      local services = ""
      for service in pairs(self.services) do
        services = services .. " " .. service
      end
      return services
    end
    node.__index = node

    local result = { services = {} }
    setmetatable(result, node)
    return result
  end

  function database:add_node(uuid, ip, port, services)
    assert(uuid, "add_node must receive at least an uuid")

    local new_node = self.known_nodes[uuid] or new_node()
    self.known_nodes[uuid] = new_node

    new_node.uuid = uuid
    new_node.ip = ip
    new_node.port = port
    new_node.connection_errors = 0
    new_node.last_time = os.time()

    -- Check services
    if services then
      local rest, service = services
      while true do
        service, rest = rest:match("^%s*([^ ]+)(.*)$")
        if not service then break end
        new_node.services[service] = new_node.services[service] or true -- don't overwrite any values already there
      end
    end

    return new_node
  end

  function database:update_time(uuid)
    self:debug_message("Update Time: '" .. uuid .. "'")
    self.known_nodes[uuid].last_time = os.time()
  end

  function database:debug_message(msg)
    print("[DB] - " .. msg)
  end
end