module ('etherclan', package.seeall) do

  require 'socket'
  require 'etherclan.base_connection'

  outbound_connection = {
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
    type_name = "Out-Connection",
  }
  outbound_connection.__index = outbound_connection
  setmetatable(outbound_connection, base_connection)

  function outbound_connection.create(node)
    local newclient = {
      node = node,
      socket = socket.tcp(),
      routine = coroutine.create(outbound_connection.routine_logic)
    }
    newclient.ip, newclient.port = node.ip, node.port
    newclient.name = node.uuid
    setmetatable(newclient, outbound_connection)
    local ok, err = newclient.socket:connect(node.ip, node.port)
    if not ok then
      newclient:debug_message("Error connecting: " .. err)
      return nil
    end
    return newclient
  end
  
  -- Commands
  local responses = {}
  function responses.node_info(self, arguments)
    local uuid, ip, port, services = arguments:match("^([^ ]+) ([^ ]+) ([^ ]+)(.*)$")
    if (uuid and ip and port) then
      self.server.db:add_node(uuid, ip, port, services)
    end
  end

  function outbound_connection:routine_logic()
    self:send("KEEP_ALIVE ON")
    self:send("ANNOUNCE_SELF " .. self.server.node.uuid .. " " .. self.server.port .. self.server.node:services_string())
    self:send("REQUEST_NODE_LIST")
    self:send("KEEP_ALIVE OFF")
    coroutine.yield()
    while true do
      local response = self:receive()
      if not response then return end

      local response_name, arguments = response:match("^([^ ]+) (.*)$") -- split first
      local callback = responses[response_name:lower()] or (function() end)
      callback(self, arguments)

      coroutine.yield()
    end
  end
end