local eisuKanaToggle = 0

-- 指定した keyCode を物理キーとして送信する
local function sendKeycode(keycode)
  local event = hs.eventtap.event.newKeyEvent({}, keycode, true):post()
  hs.timer.doAfter(0.01, function()
    hs.eventtap.event.newKeyEvent({}, keycode, false):post()
  end)
end

-- F19 トグルで英数/かなを切り替え
hs.hotkey.bind({}, "f19", function()
  if eisuKanaToggle == 1 then
    eisuKanaToggle = 0
    sendKeycode(102) -- 英数
  else
    eisuKanaToggle = 1
    sendKeycode(104) -- かな
  end
end)
