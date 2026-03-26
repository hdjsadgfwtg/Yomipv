--[[ Player notification system              ]]
--[[ User-facing OSD notification interface. ]]

local mp = require("mp")
local options = require("options")

local Player = {}

-- Default notification duration in seconds
local DEFAULT_DURATION = 2

-- Notification type to icon mapping
local ICONS = {
	info = "ℹ",
	warn = "⚠",
	error = "✖",
	success = "✓",
}

-- Display OSD notification (info, warn, error, success)
function Player.notify(message, type, duration)
	if not message or message == "" then
		return
	end

	type = type or "info"
	duration = duration or DEFAULT_DURATION

    -- Skip non-critical messages if disabled
    if not options.osd_messages and (type == "info" or type == "success") then
        return
    end

	local icon = ICONS[type] or ""
	local display_text = icon ~= "" and (icon .. " " .. message) or message

	mp.osd_message(display_text, duration)
end

-- Clear active OSD message state
function Player.clear_osd()
	mp.osd_message("", 0)
end

-- Display persistent OSD message (no auto-hide)
function Player.show_persistent(message)
	if not message or message == "" then
		return
	end
	mp.osd_message(message, 999999)
end

return Player
