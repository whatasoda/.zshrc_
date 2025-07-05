local apps = {
  d = "com.microsoft.VSCode",
  s = "com.mitchellh.ghostty"
}

local function toggleAppByBundleID(bundleID)
  local app = hs.application.get(bundleID)

  if app and app:isFrontmost() then
    app:hide()
  elseif app then
    app:activate()
  else
    hs.application.launchOrFocusByBundleID(bundleID)
  end
end

local tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  local flags = event:getFlags()
  local keyCode = event:getKeyCode()

  if flags.ctrl then
    for key, bundleID in pairs(apps) do
      if keyCode == hs.keycodes.map[key] then
        toggleAppByBundleID(bundleID)
        return true
      end
    end
  end

  return false
end)

tap:start()
