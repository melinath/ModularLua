--! Defines functions and tags for handling generic "interactions" from e.g.
--! stepping on a particular location.

local helper = wesnoth.require "lua/helper.lua"
local items = wesnoth.require "lua/wml/items.lua"

local events = modular.require "events"
local scenario = modular.require "scenario"
local utils = modular.require "utils"


local interactions = {}


--! List of interaction instances.
interactions.interactions = {}


interactions.interaction = utils.matcher:subclass({
	x = nil,
	y = nil,
	image = nil,
	command_wml = nil,
	setup_wml = nil,
	init = function(cls, cfg)
		local instance = utils.matcher.init(cls, cfg)
		table.insert(interactions.interactions, instance)
		return instance
	end,

	run_commands = function(self)
		if self.command_wml ~= nil then utils.run_wml(self.command_wml) end
	end,

	run_setup = function(self)
		if self.setup_wml ~= nil then utils.run_wml(self.setup_wml) end
	end,
})

--! Interaction class
local interaction = scenario.tag:subclass({
	name="interaction",
	init = function(cls, cfg)
		local instance = scenario.tag.init(cls, cfg)
		
		local filter = helper.get_child(instance.wml, "filter")
		if (filter == nil) then error("~wml:[interaction] expects a [filter] child", 0) end
		local command_wml = helper.get_child(instance.wml, "command")
		if (command_wml == nil) then error("~wml:[interaction] expects a [command] child", 0) end
		filter = helper.literal(filter)
		command_wml = helper.literal(command_wml)
		local setup_wml = helper.get_child(instance.wml, "setup")
		if setup_wml ~= nil then setup_wml = helper.literal(setup_wml) end
		
		interactions.interaction:init({
			filters = {filter = filter},
			command_wml = command_wml,
			setup_wml = setup_wml,
			x = instance.wml.x,
			y = instance.wml.y,
			image = instance.wml.image
		})

		return instance
	end,
})


events.register("moveto", function()
	-- Old me thought this needed to be cached.
	local c = wesnoth.current.event_context
	local unit = wesnoth.get_unit(c.x1, c.y1)
	if unit ~= nil then
		for i, interaction in ipairs(interactions.interactions) do
			if interaction:matches() then
				wesnoth.fire("store_unit", {{"filter", {id=unit.id}}, variable="unit", kill=false})
				wesnoth.set_variable("x1", c.x1)
				wesnoth.set_variable("x2", c.x2)
				wesnoth.set_variable("y1", c.y1)
				wesnoth.set_variable("y2", c.y2)
				interaction:run_commands()
				wesnoth.set_variable("unit")
				wesnoth.set_variable("x1")
				wesnoth.set_variable("x2")
				wesnoth.set_variable("y1")
				wesnoth.set_variable("y2")
			end
		end
	end
end)

events.register("prestart", function()
	for i, interaction in ipairs(interactions.interactions) do
		if interaction.image and interaction.x and interaction.y then
			items.place_image(interaction.x, interaction.y, interaction.image)
		end
		interaction:run_setup()
	end
end)

return interactions