--! Provides utilities for persistent cross-scenario time (represented
--! in hours) and for handling scenario schedules.

local helper = wesnoth.require "lua/helper.lua"

local dialog = modular.require "dialog"
local events = modular.require "events"
local scenario = modular.require "scenario"

local T = helper.set_wml_tag_metatable({})

local time = {}


-- Default settings.
time.settings = {
	track_time = true,
	variable = 'time',
	display_string = "It is day %d",
	menu_id = "calendar",
	menu_name = "Calendar",
	turns_per_day = 6,
	schedule = nil
}


-- take turns_per_day and schedule (a string of time ids) from setup.
local function setup_handler(setup)
	if setup.turns_per_day then
		time.settings.turns_per_day = setup.turns_per_day
	end
	if setup.schedule then
		time.settings.schedule = setup.schedule
	end
	time.schedule.set()
end
table.insert(scenario.setup_handlers, setup_handler)


--! Schedule handling.

local _ = wesnoth.textdomain "wesnoth-help"
time.schedule = {
	defs = {
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

	from_str = function(schedule_string)
		local schedule = {}
		for id in string.gmatch(schedule_string, "[^%s,][^,]*") do
			table.insert(schedule, time.schedule.defs[id])
		end
		return schedule
	end,

	from_turns = function(turns_per_day)
		local schedule = {}
		for i=1, turns_per_day do
			local id = "second_watch"
			if i <= turns_per_day/6 then
				id = "dawn"
			elseif i <= 2*turns_per_day/6 then
				id = "morning"
			elseif i <= 3*turns_per_day/6 then
				id = "afternoon"
			elseif i <= 4*turns_per_day/6 then
				id = "dusk"
			elseif i <= 5*turns_per_day/6 then
				id = "first_watch"
			end
			table.insert(schedule, time.schedule.defs[id])
		end
		return schedule
	end,

	set = function()
		local schedule
		if time.settings.schedule ~= nil then
			schedule = time.schedule.from_str(time.settings.schedule)
		else
			schedule = time.schedule.from_turns(time.settings.turns_per_day)
		end

		local schedule_wml = {}
		for i, def in ipairs(schedule) do
			table.insert(schedule_wml, {"time", def})
		end
		wesnoth.fire("replace_schedule", schedule_wml)
	end,
}


--! Functions related to tracking and displaying a global notion of "time".

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


events.register("new turn", function()
	if time.settings.track_time then
		local t = time.get()
		time.set(t and t + 24/maps.current.turns_per_day or 0)
	end
end)


events.register("prestart", function()
	if time.settings.track_time then
		wesnoth.fire("set_menu_item", {
			id=time.settings.menu_id,
			description=time.settings.menu_name,
			T.command({
				T.lua({
					code = [[
						local time = modular.require "time"
						time.display()
					]]
				})
			})
		})
	end
end)

return time