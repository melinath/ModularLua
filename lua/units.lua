--! Functions for the trials and travails of dealing with units.
local helper = wesnoth.require "lua/helper.lua"

local units = {}

function units.has_advance(unit, advance_id)
	local mods = helper.get_child(unit.__cfg, "modifications")
	for i=1,#mods do
		if mods[i][1] == "advance" then
			if mods[i][2].id == advance_id then return true end
		end
	end
	return false
end


return units