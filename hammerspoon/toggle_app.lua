local function toggleApp(appName)
  local app = hs.application.get(appName)
  local frontApp = hs.application.frontmostApplication()

  if app then
    if app:isFrontmost() then
      app:hide()
    else
      app:activate()
    end
  else
    hs.application.launchOrFocus(appName)
  end
end

local keymap = {
  [hs.keycodes.map.f] = "Code",
  [hs.keycodes.map.s] = "Ghostty",
}

local tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  local flags = event:getFlags()
  local keyCode = event:getKeyCode()

  if flags.ctrl and keymap[keyCode] then
    toggleApp(keymap[keyCode])
    return true
  end

  return false
end)

tap:start()
