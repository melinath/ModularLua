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


function units.get_pronouns(unit)
	gender = unit.__cfg.gender
	if gender == "male" then
		return {nom='he',acc='him',pos='his'}
	elseif gender == "female" then
		return {nom='she',acc='her',pos='hers'}
	else
		return {nom='they',acc='them',pos='theirs'}
	end
end


return units