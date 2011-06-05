--! This particular file mostly just makes accessing other files easier :-)

local modular = {}

modular.settings = {
	debug = false
}

function modular.debug()
	modular.settings.debug = true
end

function modular.require(name, addon)
	--! Loads the file named ``name`` from the add-on ``addon`` (defaults
	--! to ModularLua. This assumes that the add-on stores its lua files in
	--! "~add-ons/<addon>/lua/<name>.lua".
	local addon = tostring(addon or "ModularLua")
	local name = tostring(name)
	if string.find(name, ".", 1, true) then error(string.format("Invalid module: %s (in %s)", name, addon)) end
	return wesnoth.require(string.format("~add-ons/%s/lua/%s.lua", addon, name))
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
				wesnoth.message("ModularLua", string.format("Tag loading failed for %s. Error was: %s", mod, rval))
			end
			tags[mod] = nil
		end
	end
	return tags
end

return modular