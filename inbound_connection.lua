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
    name = "In-Connection",
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

  local function split(s)
    local head, tail = split_first(s)
    if not tail then
      return head
    else
      return head, split(tail)
    end
  end

  -- Commands
  local commands = {}
  function commands.announce_self(self, arguments)
    local cli_ip = self.ip
    local cli_uuid, cli_port = split(arguments)
    if (cli_ip and cli_uuid and cli_port) then
      self.server.db:add_node{ uuid = cli_uuid, ip = cli_ip, port = cli_port}
    else
      self:debug_message("invalid input! '" .. arguments .. "'")
    end
  end

  function commands.request_node_list(self)
    for uuid, node in pairs(self.server.db.known_nodes) do
      if node.ip and node.port then
        self:send("NODE_INFO " .. uuid .. " " .. node.ip .. " " .. node.port)
      end
    end
  end

  function commands.request_known_services(self)
    local services = ""
    for service in pairs(self.server.node.services) do
      services = services .. " " .. service
    end
    self:send('KNOWN_SERVICES' .. services)
  end

  function commands.keep_alive(self, enabled)
    self.keep_alive = enabled and (enabled:lower() == "on")
  end

  function commands.service(self, arguments)
    local service_name, service_arguments = split_first(arguments)
    self.server.node.services[service_name:lower()](self, service_arguments)
  end

  -- Routine logic
  local function invalid_command(self, command)
    self:debug_message("Invalid command: '" .. command .. "'")
  end

  local function make_invalid_command_callback(command)
    return function(self, ...) return invalid_command(self, command, ...) end
  end

  function inbound_connection:routine_logic()
    while true do
      local command_name, arguments = split_first(self:receive())
      if not command_name then return end
      command_name = command_name:lower()

      local callback = commands[command_name] or make_invalid_command_callback(command_name)
      callback(self, arguments)

      if not self.keep_alive then
        return
      end
      coroutine.yield()
    end
  end
end