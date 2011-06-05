--! Defines generic time utilities for persistent cross-scenario time.
--! Time is represented in hours.

local events = modular.require "events"
local dialog = modular.require "dialog"

local time = {}

time.settings = {
	variable = 'time',
	display_string = "It is day %d",
	menu_id = "calendar",
	menu_name = "Calendar"
}

function time.display()
	local label = string.format(time.settings.display_string, time.get())
	local d = dialog.create({widget="label", label=label})
	d:display()
end

function time.get()
	return wesnoth.get_variable(time.settings.variable)
end

function time.set(val)
	wesnoth.set_variable(time.settings.variable, val)
end


events.register(function()
	local t = time.get()
	time.set(t and t + 24/maps.current.turns_per_day or 0)
end, "new turn")

events.register(function()
	local menu_item = {
		id=time.settings.menu_id,
		description=time.settings.menu_name,
		{"command", {{"lua", {code=[[
	local time = modular.require "rpg/time"
	time.display()
]]}}}}
	}
	wesnoth.fire("set_menu_item", menu_item)
end, "prestart")

return time