--! This particular file mostly just makes accessing other files easier :-)

modular = {}

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
	if not wesnoth.have_file(path) then error("Can't require path; does not exist: " .. path) end
	return wesnoth.require(path)
end

function modular.dofile(name, addon)
	--! Shortcut for wesnoth.dofile "~add-ons/<addon>/lua/<name>.lua".
	--! ``addon`` defaults to "ModularLua".
	local path = modular.build_path(name, addon)
	if not wesnoth.have_file(path) then error("Can't dofile path; does not exist: " .. path) end
	return wesnoth.require(path)
end

function modular.message(str)
	wesnoth.message("ModularLua", str)
end

return modular