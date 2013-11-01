module ('etherclan', package.seeall) do

  base_connection = {
    -- methods
    continue = nil,
    finish = nil,
    send = nil,
    receive = nil,
    debug_message = nil,
    routine_logic = nil,

    -- attributes
    socket = nil,
    routine = nil,
    server = nil,
    type_name = "Base-Connection",
  }
  base_connection.__index = base_connection

  function base_connection:continue()
    --self:debug_message "Continue"
    assert(coroutine.resume(self.routine, self))
    if coroutine.status(self.routine) == 'dead' then
      self:finish()
    end
  end

  function base_connection:finish()
    self:debug_message "Finish"
    self.socket:close()
    if self.server then
      self.server:remove_connection(self)
    end
  end

  function base_connection:send(msg)
    self:debug_message("Sending: '" .. msg .. "'")
    self.socket:send(msg .. '\n')
  end

  function base_connection:receive()
    local data = self.socket:receive()
    if data then
      self:debug_message("Received: '" .. data .. "'")
    end
    return data   
  end

  function base_connection:debug_message(str)
    self.name = self.name or ((self.ip or "{UNK IP}") .. (self.port or "{UNK PORT}"))
    print("[" .. self.type_name .. " @ " .. self.name .. "] " .. str)
  end
end