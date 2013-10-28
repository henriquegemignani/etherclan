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
  function commands.announce_self(self, cli_uuid, cli_port)
    local cli_ip = self.ip
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
    self:send('KNOWN_SERVICES ')
  end

  function commands.keep_alive(self, enabled)
    self.keep_alive = enabled and (enabled:lower() == "on")
  end

  -- Routine logic
  local function invalid_command(self, command)
    self:debug_message("Invalid command: '" .. command .. "'")
  end

  local function make_invalid_command_callback(command)
    return function(self, ...) return invalid_command(self, command, ...) end
  end

  function inbound_connection:routine_logic()
    repeat
      local command_name, arguments = split_first(self:receive())
      command_name = command_name:lower()

      local callback = commands[command_name] or make_invalid_command_callback(command_name)
      callback(self, split(arguments))

      coroutine.yield()
    until not self.keep_alive
  end
end