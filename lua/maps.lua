--! Defines an interface for common map manipulations for wesnoth rpgs,
--! including automatic shroud loading and saving, knowledge of map existence,
--! exits from one map to another, village capture handling..

local helper = wesnoth.require "lua/helper.lua"

local events = modular.require "events"
local scenario = modular.require "scenario"
local utils = modular.require "utils"


local maps = {}


maps.settings = {
	no_map = false,
	remember_shroud = true,
	mark_visited = true,
	mark_known = true,
	shroud_sides = {1},
	-- current map id
	map = nil,
	start_x_var = "start_x",
	start_y_var = "start_y",
	--! A comma-separated list of sides, like you would pass to a standard unit
	--! filter.
	exit_sides = "1",

	-- Set to nil to disable capture handling.
	no_capture_sides = {[1] = true},
}

-- Holds an instance of the current map. Shortcut.
maps.current = nil

-- take map from setup (required unless no_map = true in setup)
local function map_setup_handler(setup)
	if not setup.no_map and not setup.map then
		error("Map id required in setup (or set no_map=true).")
	end
	maps.settings.no_map = setup.no_map or maps.settings.no_map
	maps.settings.map = setup.map
	maps.current = maps.map:init({id=maps.settings.map})

	maps.settings.no_capture_sides = setup.no_capture_sides or maps.settings.no_capture_sides
end
table.insert(scenario.setup_handlers, map_setup_handler)


-- Map class. Currently just provides shortcuts to getting/setting information
-- about the map.
maps.map = utils.class:subclass({
	-- Map id. Used for getting/storing variables about the map.
	id = nil,

	-- map_data = nil,
	
	-- Whether the player knows that the map exists.
	is_known = function(self) return self:get("known") end,
	mark_known = function(self) self:set("known", true) end,
	
	-- Whether the player has actually been to the map.
	is_visited = function(self) return self:get("visited") end,
	mark_visited = function(self) self:set("visited", true) end,
	
	load_shroud = function(self)
		if maps.settings.remember_shroud then
			for i, side in ipairs(maps.settings.shroud_sides) do
				local shroud_data = self:get(string.format("shroud%d", side))
				if shroud_data ~= nil then
					local cfg = maps.shroud.data_to_filter(shroud_data)
					cfg['side'] = side
					wesnoth.fire("remove_shroud", cfg)
				end
			end
		end
	end,
	save_shroud = function(self)
		if maps.settings.remember_shroud then
			for i, side_number in ipairs(maps.settings.shroud_sides) do
				local side = wesnoth.sides[side_number]
				local shroud_data = side.__cfg.shroud_data
				if shroud_data ~= "" then
					self:set(string.format("shroud%d", side_number), shroud_data)
				end
			end
		end
	end,
	
	set = function(self, var, value)
		wesnoth.set_variable(string.format("maps.%s.%s", self.id, var), value)
	end,
	get = function(self, var)
		return wesnoth.get_variable(string.format("maps.%s.%s", self.id, var))
	end,
})


-- At prestart, mark the current map as visited & known, and load shroud data
-- if there is any.
events.register("prestart", function()
	if maps.current then
		if maps.settings.mark_visited then maps.current:mark_visited() end
		if maps.settings.mark_known then maps.current:mark_known() end
		if maps.settings.remember_shroud then maps.current:load_shroud() end
	end
end)

-- At the end of the scenario, save the shroud data for next time.
local function save_shroud()
	if maps.current then
		if maps.settings.remember_shroud then maps.current:save_shroud() end
	end
end
events.register("victory", save_shroud)
events.register("defeat", save_shroud)


--! Shroud handling !--
maps.shroud = {
	data_to_filter = function(shroud_data)
		--! Converts shroud data to a standard location filter.
		if shroud_data == "" then return {} end
		local width, height, border = wesnoth.get_map_size()

		local x = 1 - border
		local locs_x, locs_y = {}, {}
		for row in string.gmatch(shroud_data, "|(%d*)") do
			local y = 1 - border
			for hex in string.gmatch(row, "%d") do
				if hex == "1" then
					table.insert(locs_x, x)
					table.insert(locs_y, y)
				end
				--! Shroud data is rotated 90 degrees from the map, so moving
				--! across the row is actually an increase along the y axis.
				y = y + 1
			end
			x = x + 1
		end

		return {
			x = table.concat(locs_x, ","),
			y = table.concat(locs_y, ",")
		}
	end
}


--! Exits & starting positions !--

maps.exit_handler = utils.matcher:subclass({
	on_match = function(self)
		--! Hook for things which should run when this matches.
	end,
})


--! Map of exit names to exit instances for the current map.
maps.exits = {}


maps.exit = utils.matcher:subclass({
	name = nil,
	start_x = nil,
	start_y = nil,

	--! Methods !--
	
	init = function(cls, cfg)
		local instance = utils.matcher.init(cls, cfg)

		--! Default to next scenario name for exit name.
		instance.name = instance.name or instance.scenario

		if instance.name == nil then
			error("exit requires name")
		elseif maps.exits[instance.name] then
			error("Multiple exits with name '" .. instance.name .. "'")
		end

		instance.handlers = {
			cancel={},
			success={},
		}
		maps.exits[instance.name] = instance

		return instance
	end,

	add_handler = function(self, handler_type, handler)
		table.insert(self.handlers[handler_type], 1, handler)
	end,

	on_match = function(self)
		--! Hook for things which should run when this matches.
		local c = wesnoth.current.event_context
		wesnoth.set_variable(maps.settings.start_x_var, self.start_x)
		wesnoth.set_variable(maps.settings.start_y_var, self.start_y)
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

maps.add_exit_handler = function(exit_name, handler_type, handler)
	local exit = maps.exits[exit_name]
	if exit == nil then error("Exit named '" .. exit_name .. "' does not exist") end
	exit:add_handler(handler_type, handler)
end


events.register("moveto", function()
	for name, exit in pairs(maps.exits) do
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


--! Exit tag class
scenario.tag:subclass({
	name = "exit",
	init = function(cls, cfg)
		local instance = scenario.tag.init(cls, cfg)

		local filter = helper.get_child(instance.wml, "filter")
		if filter == nil then error("~wml:[exit] expects a [filter] child", 0) end
		
		maps.exit:init({
			filter = helper.literal(filter),
			name = instance.wml.name,
			start_x = instance.wml.start_x,
			start_y = instance.wml.start_y,
			scenario = instance.wml.scenario,
		})

		return instance
	end,
})


--! Set starting position
events.register("prestart", function()
	local x = wesnoth.get_variable(maps.settings.start_x_var)
	local y = wesnoth.get_variable(maps.settings.start_y_var)

	if x ~= nil and y ~= nil then
		local units = wesnoth.get_units{side=maps.settings.exit_sides}
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

	wesnoth.set_variable(maps.settings.start_x_var)
	wesnoth.set_variable(maps.settings.start_y_var)
end)


--! Village captures !--
-- Currently very basic support; lets you define a side as being unable to
-- capture. Any villages they *do* capture are set ownerless.

events.register("capture", function()
	local c = wesnoth.current.event_context
	local unit = wesnoth.get_unit(c.x1, c.y1)

	if maps.settings.no_capture_sides[unit.side] then
		wesnoth.set_village_owner(c.x1, c.y1, nil)
	end
end)


return maps