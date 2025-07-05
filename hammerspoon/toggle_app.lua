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

-- イベントタップ定義（global にして再スタート可能に）
local tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  local flags = event:getFlags()
  local keyCode = event:getKeyCode()

  if flags:containExactly({ "ctrl" }) then
    for key, bundleID in pairs(apps) do
      if keyCode == hs.keycodes.map[string.upper(key)] then
        local ok, err = pcall(function()
          toggleAppByBundleID(bundleID)
        end)
        if not ok then
          hs.alert.show("toggle error: " .. tostring(err))
        end
        return true
      end
    end
  end

  return false
end)

tap:start()

hs.hotkey.bind({ "ctrl" }, "D", function()
  hs.alert.show("🔄 Reloading Hammerspoon config")
  hs.reload()
end)

hs.hotkey.bind({ "ctrl" }, "S", function()
  hs.alert.show("🔄 Reloading Hammerspoon config")
  hs.reload()
end)
