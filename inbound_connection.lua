module ('etherclan', package.seeall) do

  require 'etherclan.base_connection'

  inbound_connection = {
    -- class methods
    create = nil,

    -- methods
    continue = nil,
    finish = nil,
    routine_logic = nil,

    -- attributes
    socket = nil,
    routine = nil,
    server = nil,

    -- static members
    type_name = "In-Connection",
  }
  inbound_connection.__index = inbound_connection
  setmetatable(inbound_connection, base_connection)

  function inbound_connection.create(sock)
    local newclient = {
      socket = sock,
      routine = coroutine.create(inbound_connection.routine_logic)
    }
    newclient.ip, newclient.port = sock:getpeername()
    setmetatable(newclient, inbound_connection)

    return newclient
  end

  -- Utils
  local function split_first(s)
    if not s then return nil end
    local head, tail = s:match("^([^ ]+) (.*)$")
    if not head then
      return s
    end
    return head, tail
  end

  -- Commands
  local commands = {}
  function commands.announce_self(self, arguments)
    local uuid, port, services = arguments:match("^([^ ]+) ([^ ]+)(.*)$")
    local ip = self.ip
    if (uuid and ip and port) then
      self.server.db:add_node(uuid, ip, port, services)
    end
  end

  function commands.request_node_list(self)
    for uuid, node in pairs(self.server.db.known_nodes) do
      if node.ip and node.port then
        self:send("NODE_INFO " .. uuid .. " " .. node.ip .. " " .. node.port .. node:services_string())
      end
    end
  end

  function commands.keep_alive(self, enabled)
    self.keep_alive = enabled and (enabled:lower() == "on")
  end

  function commands.service(self, arguments)
    local service_name, service_arguments = split_first(arguments)
    local service_handler = self.server.node.services[service_name:lower()]
    if service_handler then
      service_handler(self, service_arguments)
    else
      self:debug_message("Unknown service requested: '" .. service_name .. "'")
    end
  end

  function inbound_connection:routine_logic()
    self.remote_uuid = self:receive()
    self.name = self.remote_uuid
    while true do
      local command_name, arguments = split_first(self:receive())
      if not command_name then return end

      local callback = commands[command_name:lower()] or (function() end)
      callback(self, arguments)

      if not self.keep_alive then
        return
      end
      coroutine.yield()
    end
  end
end