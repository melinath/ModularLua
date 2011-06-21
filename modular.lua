--! This particular file mostly just makes accessing other files easier :-)

local modular = {}

modular.settings = {
	debug = false
}

function modular.debug()
	modular.settings.debug = true
end

function modular.build_path(name, addon)
	--! Returns the path to a lua file within a given add-on, assuming a
	--! structure like "~add-ons/<addon>/lua/<name>.lua". ``addon`` defaults
	--! to "ModularLua".
	local addon = tostring(addon or "ModularLua")
	local name = tostring(name)
	if string.find(name, ".", 1, true) then error(string.format("Invalid module: %s (in %s)", name, addon)) end
	return string.format("~add-ons/%s/lua/%s.lua", addon, name)
end

function modular.require(name, addon)
	--! Shortcut for wesnoth.require "~add-ons/<addon>/lua/<name>.lua".
	--! ``addon`` defaults to "ModularLua".
	local path = modular.build_path(name, addon)
	return wesnoth.require(path)
end

function modular.dofile(name, addon)
	--! Shortcut for wesnoth.dofile "~add-ons/<addon>/lua/<name>.lua".
	--! ``addon`` defaults to "ModularLua".
	local path = modular.build_path(name, addon)
	return wesnoth.require(path)
end

function modular.require_tags(...)
	-- Loads the given tag libraries. Reports failures, but doesn't halt.
	local tags = {}
	for i=1,#arg do
		local mod = tostring(arg[i])
		local success, rval = pcall(modular.require, string.format("tags/%s", mod))
		if success then
			tags[mod] = rval
		else
			if modular.settings.debug then
				modular.message(string.format("Tag loading failed for %s. Error was: %s", mod, rval))
			end
			tags[mod] = nil
		end
	end
	return tags
end

function modular.message(str)
	wesnoth.message("ModularLua", str)
end

return modular