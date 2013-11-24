module ('etherclan', package.seeall) do

  local socket = require("socket")
  local uuid4  = require("etherclan.uuid4")

  require 'etherclan.inbound_connection'
  require 'etherclan.outbound_connection'

  local function tableremove(t, val)
    for i, s in ipairs(t) do
      if s == val then
        table.remove(t, i)
        return
      end
    end
  end

  commands = {
    announce_self = 1,
    request_node_list = 2,
    keep_alive = 3,
    service = 4,
  }

  server = {
    -- class methods
    create = nil,

    -- methods
    step = nil,
    start = nil,

    -- attributes
    db = nil,
    sock = nil,
    timeout = nil,
    port = 0,
    connections = nil,
    socket_table = nil,
  }
  server.__index = server

  function server.create(db, timeout, port, input_node)
    local newserver = { 
      db = db,
      timeout = timeout or 1.0,
      port = port or 0,
      node = db:add_node(input_node and input_node.uuid or uuid4.getUUID()),

      connections = {},
      socket_table = {},
    }
    setmetatable(newserver, server)

    return newserver
  end

  function server:start()
    self.sock = socket.tcp()
    if not self.sock:bind("*", self.port) then
      self.sock = socket.tcp()
      assert(self.sock:bind("*", 0))
    end
    self.ip, self.port = self.sock:getsockname()

    self.sock:settimeout(self.timeout * 0.25, 't') -- accept timeout
    self.sock:listen(3)

    -- Debug message at end so we have the ip and port
    self:debug_message("Server Start with timeout " .. self.timeout)
  end

  function server:step()
    self:accept_new_in_connections()
    self:handle_active_connections()
  end

  function server:close()
    self.sock:close()
  end

  function server:accept_new_in_connections()
    --self:debug_message "Accept"
    -- Get a new inbound connection socket
    local inbound_sock = self.sock:accept()
    if inbound_sock then -- nil when timeout happens
      self:create_inbound_connection(inbound_sock)
    end
  end

  function server:create_new_out_connections()
    -- Create new connections!
    self:debug_message "Search"
    for _, node in pairs(self.db.known_nodes) do
      if node.uuid ~= self.node.uuid then
        self:create_outbound_connection(node)
      end
    end
  end

  function server:handle_active_connections()
    --self:debug_message "Select"
    local read = socket.select(self.connections, nil, self.timeout)
    for _, sock in ipairs(read) do
      self.socket_table[sock]:continue()
    end
  end

  function server:create_inbound_connection(sock)
    self:debug_message "Create Inbound Connection"
    local inbound = inbound_connection.create(sock)
    self:add_connection(inbound)
  end

  function server:create_outbound_connection(node)
    self:debug_message "Create Outbound Connection"
    local outbound = outbound_connection.create(node)
    if outbound then
      self:add_connection(outbound)
      outbound:continue()
    else
      node.connection_errors = node.connection_errors + 1
    end
  end

  function server:add_connection(connection)
    table.insert(self.connections, connection.socket)
    self.socket_table[connection.socket] = connection
    connection.server = self
  end

  function server:remove_connection(connection)
    self:debug_message "Remove Connection"

    assert(connection.server == self)
    connection.server = nil
    tableremove(self.connections, connection.socket)
    self.socket_table[connection.socket] = nil
  end

  function server:debug_message(str)
    print("[Server @ " .. self.ip .. " -- " .. self.port .. "] " .. str)
  end

  function server:send_message(uuid, command, ...)
    local result

    local target = self.db.known_nodes[uuid]
    if not target then 
      server:debug_message("Sending message to unknown UUID: '" .. uuid .. "'")
      return
    end

    local s = socket.tcp()
    s:settimeout(0.5)
    if s:connect(target.ip, target.port) then
      s:settimeout(1)
      s:send(self.node.uuid)

      if command == commands.service then
        local service_name, argument, has_response = ...
        s:send('SERVICE ' .. service_name .. ' ' .. argument .. '\n')
        if has_response then
          result = s:receive()
        end
      else
        error("etherclan.server:send_message -- unknown/unsupported command")
      end
      s:close()
    else
      self:debug_message "Connection failure!"
    end

    return result
  end
end