module ('etherclan', package.seeall) do

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
  }
  inbound_connection.__index = inbound_connection

  function inbound_connection.create(sock)
    local newclient = {
      socket = sock,
      routine = coroutine.create(inbound_connection.routine_logic)
    }
    newclient.ip, newclient.port = sock:getpeername()
    setmetatable(newclient, inbound_connection)

    return newclient
  end

  function inbound_connection:continue()
    self:debug_message "Continue"
    assert(coroutine.resume(self.routine, self))
    if coroutine.status(self.routine) == 'dead' then
      self:finish()
    end
  end

  function inbound_connection:finish()
    self:debug_message "Finish"
    self.socket:close()
    if self.server then
      self.server:remove_inbound_connection(self)
    end
  end

  function inbound_connection:send(msg)
    self:debug_message("Sending: '" .. msg .. "'")
    self.socket:send(msg .. '\n')
  end

  function inbound_connection:receive()
    return self.socket:receive()
  end

  function inbound_connection:debug_message(str)
    print("[Client Connection @ " .. self.ip .. " -- " .. self.port .. "] " .. str)
  end

  -- Utils
  local function split_first(s)
    local head, tail = s:match("^([^ ]+) (.*)$")
    if not head then
      return s
    end
    return head, tail
  end

  local function split(s)
    if not s then return nil end
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
      self:debug_message("invalid input! '" .. arguments .. "': " .. cli_uuid .. " --- " .. cli_port)
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

  -- Routine logic
  local function invalid_command(self, command)
    self:debug_message("Invalid command: '" .. command .. "'")
  end

  local function make_invalid_command_callback(command)
    return function(self, ...) return invalid_command(self, command, ...) end
  end

  function inbound_connection:routine_logic()
    local command_name, arguments = split_first(self:receive())
    command_name = command_name:lower()

    local callback = commands[command_name] or make_invalid_command_callback(command_name)
    callback(self, split(arguments))
  end
end