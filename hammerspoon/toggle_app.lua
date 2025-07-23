local IDE_APP_ID = "com.todesktop.230313mzl4w4u92"
local TERMINAL_APP_ID = "com.mitchellh.ghostty"
local CALENDAR_APP_NAME = "Notion Calendar"

local function switchAppByBundleID(bundleID, toggle)
  local app = hs.application.get(bundleID)
  if app and app:isFrontmost() then
    if toggle then
      app:hide()
    end
  elseif app then
    app:activate()
  else
    hs.application.launchOrFocusByBundleID(bundleID)
  end
end

local function hideAppByBundleID(bundleID)
  local app = hs.application.get(bundleID)
  if app then
    app:hide()
  end
end


local function switchAppByName(appName, toggle)
  local app = hs.application.find(appName)
  if app and app:isFrontmost() then
    if toggle then
      app:hide()
    end
  elseif app then
    app:activate()
  else
    hs.application.launchOrFocus(appName)
  end
end

local function showIDE()
  switchAppByBundleID(IDE_APP_ID, false)
  hs.eventtap.keyStroke({ "ctrl", "shift", "command" }, "w")
end

local function toggleIDE()
  switchAppByBundleID(IDE_APP_ID, true)
end

local function toggleTerminal()
  switchAppByBundleID(TERMINAL_APP_ID, true)
end

local function hideIDEAndTerminal()
  hideAppByBundleID(IDE_APP_ID)
  hideAppByBundleID(TERMINAL_APP_ID)
end

local function toggleCalendar()
  switchAppByName(CALENDAR_APP_NAME, true)
end

local function moveTabToLeft()
  if hs.application.frontmostApplication():bundleID() == IDE_APP_ID then
    hs.eventtap.keyStroke({ "control", "shift", "command", "option" }, "left")
  end

  hs.eventtap.keyStroke({ "control", "shift" }, "tab")
end

local function moveTabToRight()
  if hs.application.frontmostApplication():bundleID() == IDE_APP_ID then
    hs.eventtap.keyStroke({ "control", "shift", "command", "option" }, "right")
  end

  hs.eventtap.keyStroke({ "control" }, "tab")
end

-- イベントタップ定義（global にして再スタート可能に）
local tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  local flags = event:getFlags()
  local keyCode = event:getKeyCode()

  if flags:containExactly({ "ctrl" }) and keyCode == hs.keycodes.map["A"] then
    hideIDEAndTerminal()
    return true
  end

  if flags:containExactly({ "ctrl" }) and keyCode == hs.keycodes.map["S"] then
    toggleTerminal()
    return true
  end

  if flags:containExactly({ "ctrl" }) and keyCode == hs.keycodes.map["D"] then
    toggleIDE()
    return true
  end

  if flags:containExactly({ "ctrl" }) and keyCode == hs.keycodes.map["W"] then
    showIDE()
    return true
  end

  if flags:containExactly({ "ctrl", "shift" }) and keyCode == hs.keycodes.map["Q"] then
    toggleCalendar()
    return true
  end

  return false
end)

tap:start()

hs.hotkey.bind({ "ctrl" }, "a", function()
  hs.alert.show("🔄 Reloading Hammerspoon config")
  hideIDEAndTerminal()
  hs.reload()
end)

hs.hotkey.bind({ "ctrl" }, "s", function()
  hs.alert.show("🔄 Reloading Hammerspoon config")
  toggleTerminal()
  hs.reload()
end)

hs.hotkey.bind({ "ctrl" }, "w", function()
  hs.alert.show("🔄 Reloading Hammerspoon config")
  showIDE()
  hs.reload()
end)

hs.hotkey.bind({ "ctrl" }, "d", function()
  hs.alert.show("🔄 Reloading Hammerspoon config")
  toggleIDE()
  hs.reload()
end)

hs.hotkey.bind({ "ctrl", "shift" }, "q", function()
  hs.alert.show("🔄 Reloading Hammerspoon config")
  toggleCalendar()
  hs.reload()
end)
