module ('etherclan', package.seeall) do

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
    name = "In-Connection",
  }
  outbound_connection.__index = outbound_connection
  setmetatable(outbound_connection, base_connection)

  function outbound_connection.create(sock)
    local newclient = {
      socket = sock,
      routine = coroutine.create(outbound_connection.routine_logic)
    }
    newclient.ip, newclient.port = sock:getpeername()
    setmetatable(newclient, outbound_connection)

    return newclient
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
  local responses = {}
  function responses.node_info(self, arguments)
    local uuid, ip, port = split(arguments)
    if (uuid and ip and port) then
      self.server.db:add_node{ uuid = uuid, ip = ip, port = port}
    end
  end

  function responses.known_services(self, arguments)
    local service, rest = split_first(arguments)
    while service ~= nil do
      print("known service: " .. service)
      service, rest = split_first(rest)
    end
  end

  -- Routine logic
  local function invalid_response(self, name)
    self:debug_message("Invalid response: '" .. name .. "'")
  end

  local function make_invalid_response_callback(name)
    return function(self, ...) return invalid_response(self, name, ...) end
  end

  function outbound_connection:routine_logic()
    self:send("KEEP_ALIVE ON")
    self:send("ANNOUNCE_SELF " .. self.server.uuid .. " " .. self.server.port)
    self:send("REQUEST_KNOWN_SERVICES")
    self:send("KEEP_ALIVE OFF")
    coroutine.yield()
    while true do
      local response = self:receive()
      if not response then return end

      local response_name, arguments = split_first(response)
      local callback = responses[response_name] or make_invalid_response_callback(response_name)
      callback(self, arguments)

      coroutine.yield()
    end
  end
end