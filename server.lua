module ('etherclan', package.seeall) do
  local socket = require("socket")

  require 'etherclan.inbound_connection'

  local function tableremove(t, val)
    for i, s in ipairs(t) do
      if s == val then
        table.remove(t, i)
        return
      end
    end
  end

  server = {
    -- class methods
    create = nil,

    -- methods
    step = nil,
    start = nil,

    -- attributes
    search_period = 100,
    pending_search_time = 10,
    db = nil,
    sock = nil,
    timeout = nil,
    port = 0,
    connections = nil,
    socket_table = nil,
  }
  server.__index = server

  function server.create(db, timeout, port)
    local newserver = { 
      db = db,
      timeout = timeout and timeout * 0.5 or nil,
      port = port or 0
      pending_search_time = server.pending_search_time,

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
    self.sock:settimeout(self.timeout, 't')
    self.sock:listen(3)
    self.ip, self.port = self.sock:getsockname()

    self:debug_message("Server Start with timeout " .. self.timeout)
  end

  function server:step()
    self:debug_message "Accept"
    local inbound_sock = self.sock:accept()
    if inbound_sock then
      self:create_inbound_connection(inbound_sock)
    end

    self.pending_search_time = self.pending_search_time - 1
    if self.pending_search_time <= 0 then
      self.pending_search_time = self.search_period
    end

    self:debug_message "Select"
    local read = socket.select(self.connections, nil, self.timeout)
    for _, sock in ipairs(read) do
      self.socket_table[sock]:continue()
    end
  end

  function server:close()
    self.sock:close()
  end

  function server:create_inbound_connection(sock)
    self:debug_message "Create Inbound Connection"
    local inbound = inbound_connection.create(sock)
    self:add_connection(inbound)
  end

  function server:create_outbound_connection(sock)
    self:debug_message "Create Outbound Connection"
    error "NYI"
    local outbound = nil
    self:add_connection(outbound)
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
    self.socket_table[inbound.socket] = nil
  end

  function server:debug_message(str)
    print("[Server @ " .. self.ip .. " -- " .. self.port .. "] " .. str)
  end
end