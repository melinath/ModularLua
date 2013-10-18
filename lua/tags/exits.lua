--! Defines generic exits from one scenario to another, with custom
--! start locations.

local events = modular.require "events"
local helper = wesnoth.require "lua/helper.lua"

local exits = {}


exits.settings = {
	start_x_var = "start_x",
	start_y_var = "start_y",
	--! A comma-separated list of sides, like you would pass to a standard unit
	--! filter.
	sides = "1"
}


local matcher = {
	filter = nil,
	filter_location = nil,

	new = function(cls, cfg)
		local new_cls = cfg or {}
		setmetatable(new_cls, cls)
		new_cls.__index = new_cls
		return new_cls
	end,

	matches = function(self)
		local c = wesnoth.current.event_context
		local matched = true
		if self.filter_location ~= nil then
			if not wesnoth.match_location(c.x1, c.y1, filter_location) then
				matched = false
			end
		end
		if self.filter ~= nil then
			local unit = wesnoth.get_unit(c.x1, c.y1)
			if not wesnoth.match_unit(unit, self.filter) then
				matched = false
			end
		end
		return matched
	end,
}
matcher.__index = matcher


exits.handler = matcher:new({
	on_match = function(self)
		--! Hook for things which should run when this matches.
	end,
})


--! Map of exit names to exit instances for the current map.
exits.exits = {}


exits.exit = matcher:new({
	name = nil,
	start_x = nil,
	start_y = nil,

	--! Methods !--
	
	new = function(cls, cfg)
		local new_cls = cfg or {}
		setmetatable(new_cls, cls)
		new_cls.__index = new_cls

		--! Default to next scenario name for exit name.
		new_cls.name = new_cls.name or new_cls.scenario

		if new_cls.name == nil then
			error("exit requires name")
		elseif exits.exits[new_cls.name] then
			error("Multiple exits with name '" .. new_cls.name .. "'")
		end

		new_cls.handlers = {
			cancel={},
			success={},
		}
		exits.exits[new_cls.name] = new_cls

		return new_cls
	end,

	add_handler = function(self, handler_type, handler)
		table.insert(self.handlers[handler_type], 0, handler)
	end,

	on_match = function(self)
		--! Hook for things which should run when this matches.
		local c = wesnoth.current.event_context
		wesnoth.set_variable(exits.settings.start_x_var, self.start_x)
		wesnoth.set_variable(exits.settings.start_y_var, self.start_y)
		wesnoth.fire("endlevel", {
			name = "victory",
			save = true,
			carryover_report = false,
			carryover_percentage = 100,
			linger_mode = false,
			bonus = false,
			next_scenario = self.scenario,
			replay_save = false
		})
	end,
})

exits.add_handler = function(exit_name, handler_type, handler)
	local exit = exits.exits[name]
	if exit == nil then error("Exit named '" .. exit_name .. "' does not exist") end
	exit:add_handler(handler_type, handler)
end


events.register("moveto", function()
	for name, exit in pairs(exits.exits) do
		if exit:matches() then
			local matches = true
			for i, handler in ipairs(exit.handlers.cancel) do
				if handler:matches() then
					matches = false
					handler:on_match()
					break
				end
			end
			if matches then
				for i, handler in ipairs(exit.handlers.success) do
					if handler:matches() then
						handler:on_match()
						break
					end
				end
				exit:on_match()
				break
			end
		end
	end
end)


--! Exit tag
exits.exit_tag = events.tag:new("exit", {
	init = function(self, cfg)
		local o = self:get_parent().init(self, cfg)
		
		local filter = helper.get_child(cfg, "filter")
		if filter == nil then error("~wml:[exit] expects a [filter] child", 0) end
		
		local new_cfg = {
			filter = helper.literal(filter),
			name = cfg.name,
			start_x = cfg.start_x,
			start_y = cfg.start_y,
			scenario = cfg.scenario,
		}
		
		exits.exit:new(new_cfg)

		return o
	end,
})


--! Set starting position
events.register("prestart", function()
	local x = wesnoth.get_variable(exits.settings.start_x_var)
	local y = wesnoth.get_variable(exits.settings.start_y_var)

	if x ~= nil and y ~= nil then
		local units = wesnoth.get_units{side=exits.settings.sides}
		local varname = "Lua_store_unit"
		for i,u in ipairs(units) do
			wesnoth.extract_unit(u)
			wesnoth.set_variable(varname, u.__cfg)
			wesnoth.fire("unstore_unit", {
				variable = varname,
				find_vacant = true,
				check_passability = true,
				x = x,
				y = y
			})
		end
		wesnoth.set_variable(varname)
		wesnoth.scroll_to_tile(x, y)
	end

	wesnoth.set_variable(exits.settings.start_x_var)
	wesnoth.set_variable(exits.settings.start_y_var)
end)


return exits