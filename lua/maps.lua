--! Defines an interface for common map manipulations for wesnoth rpgs,
--! including automatic shroud loading and saving, etc.

local events = modular.require "events"


local maps = {}


maps.settings = {
	require_map = true,
	remember_shroud = true,
	mark_visited = true,
	mark_known = true,
	shroud_sides = {1},
}
maps.defaults = {
	turns_per_day = 6,
}


local _ = wesnoth.textdomain "wesnoth-help"
maps.schedules = {
	schedules = {
		dawn = {
			id=dawn,
			name= _ "Dawn",
			image="misc/schedule-dawn.png",
			red=-20,
			green=-20,
			sound="ambient/morning.ogg",
		},
		morning = {
			id=morning,
			name= _ "Morning",
			image="misc/schedule-morning.png",
			lawful_bonus=25
		},
		afternoon = {
			id=afternoon,
			name= _ "Afternoon",
			image="misc/schedule-afternoon.png",
			lawful_bonus=25
		},
		dusk = {
			id=dusk,
			name= _ "Dusk",
			image="misc/schedule-dusk.png",
			green=-20,
			blue=-20,
			sound="ambient/night.ogg",
		},
		first_watch = {
			id=first_watch,
			name= _ "First Watch",
			image="misc/schedule-firstwatch.png",
			lawful_bonus=-25,
			red=-45,
			green=-35,
			blue=-10,
		},
		second_watch = {
			id=second_watch,
			name= _ "Second Watch",
			image="misc/schedule-secondwatch.png",
			lawful_bonus=-25,
			red=-45,
			green=-35,
			blue=-10
		},
		indoors = {
			id=indoors,
			name= _ "Indoors",
			image="misc/schedule-indoors.png",
			lighter=indoors_illum,
			{
				"illuminated_time", {
					id=indoors_illum,
					name= _ "Indoors",
					image="misc/schedule-indoors.png",
					lawful_bonus=25
				}
			}
		},
		underground = {
			id=underground,
			name= _ "Underground",
			image="misc/schedule-underground.png",
			lawful_bonus=-25,
			red=-45,
			green=-35,
			blue=-10,
			{
				"illuminated_time", {
					id=underground_illum,
					name= _ "Underground",
					image="misc/schedule-underground-illum.png",
				}
			}
		},
		deep_underground = {
			id=deep_underground,
			name= _ "Deep Underground",
			image="misc/schedule-underground.png",
			lawful_bonus=-30,
			red=-40,
			green=-45,
			blue=-15,
			{
				"illuminated_time", {
					id=deep_underground_illum,
					name= _ "Deep Underground",
					image="misc/schedule-underground-illum.png"
				}
			}
		}
	},
	from_str = function(schedule_str)
		local schedule = {}
		for time in string.gmatch(schedule_string, "[^%s,][^,]*") do
			table.insert(schedule, maps.schedules[time])
		end
		return schedule
	end,
	generate = function(turns_per_day)
		local schedule = {}
		for i=1, turns_per_day do
			local time = "second_watch"
			if i <= turns_per_day/6 then
				time = "dawn"
			elseif i <= 2*turns_per_day/6 then
				time = "morning"
			elseif i <= 3*turns_per_day/6 then
				time = "afternoon"
			elseif i <= 4*turns_per_day/6 then
				time = "dusk"
			elseif i <= 5*turns_per_day/6 then
				time = "first_watch"
			end
			table.insert(schedule, maps.schedules.schedules[time])
		end
		return schedule
	end,
	
	set = function(schedule)
		local schedule_wml = {}
		for i, time_def in ipairs(schedule) do
			table.insert(schedule_wml, {"time", time_def})
		end
		wesnoth.fire("replace_schedule", schedule_wml)
	end,
}


--! Generic map-related functions.


maps.vars = {
	get_name = function(map_id, var)
		return string.format("maps.%s.%s", map_id, var)
	end,
	get = function(map_id, var, default)
		local v = maps.vars.get_name(map_id, var)
		return wesnoth.get_variable(v) or default
	end,
	set = function(map_id, var, value)
		local v = maps.vars.get_name(map_id, var)
		wesnoth.set_variable(v, value)
	end
}


--! Shroud handling
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


--! A map class. For now there will only be one instance of it, located
--! at maps.current.
maps.map = events.tag:new("map_setup", {
	id = nil,
	--map_data = nil,
	init = function(self, cfg)
		if maps.current ~= nil then error("~wml:Only one [map_setup] tag is permitted.") end
		if cfg.id == nil then error("~wml:[map_setup] tag must specify an id.") end
		
		local o = self:get_parent().init(self, cfg)

		o.id = cfg.id
		o.turns_per_day = cfg.turns_per_day or maps.defaults.turns_per_day
		
		if cfg.schedule == nil then
			o.schedule = maps.schedules.generate(o.turns_per_day)
		else
			o.schedule = maps.schedules.from_str(cfg.schedule)
		end
		maps.schedules.set(o.schedule)
		
		maps.current = o
		return o
	end,
	
	is_known = function(self)
		return maps.vars.get(self.id, "known")
	end,
	mark_known = function(self)
		-- Marks the map as "known"
		maps.vars.set(self.id, "known", true)
	end,
	
	is_visited = function(self)
		return maps.vars.get(self.id, "visited")
	end,
	mark_visited = function(self)
		-- Marks the map as "visited"
		maps.vars.set(self.id, "visited", true)
	end,
	
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
		maps.vars.set(self.id, var, value)
	end,
	get = function(self, var, default)
		return maps.vars.get(self.id, var, default)
	end,
})


--! Event registrations
events.register("prestart", function()
	local map = maps.current
	if map then
		if maps.settings.mark_visited then map:mark_visited() end
		if maps.settings.mark_known then map:mark_known() end
		--if maps.settings.remember_shroud then map:load_shroud() end
	else
		if maps.settings.require_map then
			error("~wml:Expected [map] tag is missing.")
		end
	end
end)
local function save_shroud()
	local map = maps.current
	if map then
		if maps.settings.remember_shroud then map:save_shroud() end
	end
end
events.register("victory", save_shroud)
events.register("defeat", save_shroud)


return maps