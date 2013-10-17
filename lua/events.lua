--! A module which allows simple, efficient registration of new scenario-level
--! tags and new event handlers.
local game_events = wesnoth.game_events
local helper = wesnoth.require "lua/helper.lua"


events = {}


--! Event registration !--

--! Container for all registered events. Maps event names to tables of functions
--! to be run for that event.
events.events = {}


function events.register(name, func)
	--! Registers a function to be run when the event with the given ``name`` is
	--! fired by the wesnoth game engine.
	if events.events[name] == nil then events.events[name] = {} end
	table.insert(events.events[name], func)
end


--! On each event, runs all functions that have been registered for that event
--! in the order in which they were registered. All event functions are run in
--! protected mode; a failing function will not stop subsequent functions from
--! running. If ``modular.settings.debug`` is ``true``, then an error message
--! will be printed for each failing function.
local old_on_event = game_events.on_event
function game_events.on_event(name)
	local funcs = events.events[name]
	if funcs ~= nil then
		for i,f in ipairs(funcs) do
			local success, rval = pcall(f)
			if not success and modular.settings.debug then
				modular.message(string.format("%s failed for %s event: %s", tostring(f), name, rval))
			end
		end
	end
	if old_on_event ~= nil then old_on_event(name) end
end


--! Scenario-level tag handling !--

--! ModularLua supports scenario-level tags out of the box, something which is
--! generally a pain to implement otherwise. All scenario tags created with
--! ModularLua can also be used as action tags; in this case, a new instance of
--! the scenario tag will be added to the scenario-level information. By
--! default, scenario-level tags are not expected to "do" anything beyond
--! storing information about the current scenario (see, for example,
--! ModularLua/lua/maps.lua).

--! Container for all known scenario-level tags.
events.tags = {}

events.tag = {
	--! Base class for scenario-level tags. New tags can be registered by
	--! calling ``events.tag:new`` and passing in the name of the tag and a
	--! configuration table defining its behavior.
	
	--! Whether or not the tag's configuration should persist between scenarios.
	persist = false,
	
	new = function(self, name, cfg)
		--! Given a name and a configuration table, register the class as a
		--! ModularLua event tag and register a wml action to create new
		--! instances of the tag class.
		local cls = cfg or {}
		cls.__index = cls
		setmetatable(cls, self)
		cls.instances = {}
		events.tags[name] = cls
		table.insert(events.tags, {name, cls})
		wesnoth.wml_actions[name] = function(cfg) cls:init(cfg) end
		return cls
	end,
	init = function(cls, cfg)
		--! By default, the init method simply stores the WML configuration
		--! that was used to initialize the tag so that the information can be
		--! dumped back into the scenario context on save. Subclasses should
		--! override the init method to provide more complex functionality if
		--! it is needed. Any subclasses which do so should be sure to call
		--! cls:get_parent().init(cls, cfg) to make sure that the new instance
		--! is properly handled by the events framework.
		local obj = {}
		setmetatable(obj, cls)
		table.insert(cls.instances, obj)
		obj.cfg = cfg
		return obj
	end,
	get_parent = function(self)
		--! Returns the parent class of ``self`` if ``self`` is a class.
		return getmetatable(self)
	end,
	dump = function(self)
		--! Returns a WML-formatted representation of the tag. By default, this
		--! is simply the cfg that was stored during ``init``, so that
		--! using the output of this tag to create a new instance would result
		--! in an instance identical to ``self``.
		return self.cfg
	end
}
events.tag.__index = events.tag


--! Initialize scenario-level declarations of the tag on load.
local old_on_load = game_events.on_load
function game_events.on_load(cfg)
	local scenario_tags = {}

	-- First, collect the scenario-level tags. Loops through in reverse.
	-- Need to do it this way so removal doesn't screw up the order.
	for i=#cfg,1,-1 do
		local tag = cfg[i]
		if events.tags[tag[1]] then
			table.insert(scenario_tags, cfg[i])
			table.remove(cfg, i)
		end
	end

	-- Now loop through them backwards and init them. This means the tags are
	-- instantiated in the order they're declared. This is important so that map
	-- setup data (for example) is available ASAP.
	for i=#scenario_tags, 1, -1 do
		local tag = scenario_tags[i]
		events.tags[tag[1]]:init(tag[2])
	end
	old_on_load(cfg)
end


--! Save all instances of the tag to the scenario level on save.
local old_on_save = game_events.on_save
function game_events.on_save()
	cfg = old_on_save()
	for i, tag_def in ipairs(events.tags) do
		local name, cls = table.unpack(tag_def)
		for i=1,#cls.instances do
			table.insert(cfg, {name, cls.instances[i]:dump()})
		end
	end
	return cfg
end


local function persist_variable_name(name)
	return string.format("modular.events.%s", name)
end


local function save_persisting_tags()
	--! Saves tags that are marked to persist as wesnoth variables.
	for i, tag_def in ipairs(events.tags) do
		local name, cls = table.unpack(tag_def)
		if cls.persist then
			local arr = {}
			for i=1,#cls.instances do
				table.insert(arr, cls.instances[i]:dump())
			end
			helper.set_variable_array(persist_variable_name(name), arr)
		end
	end
end
events.register("victory", save_persisting_tags)
events.register("defeat", save_persisting_tags)

local function load_persisted_tags()
	--! Loads persisted tags from the previous scenario.
	for i, tag in ipairs(events.tags) do
		local name, cls = table.unpack(tag)
		if cls.persist then
			-- Hack to work around the built-in library's lack of a default for
			-- array length in helper.get_variable_array. Remove in 1.10.
			local var_name = persist_variable_name(name)
			local array_length = wesnoth.get_variable(var_name .. ".length")
			if array_length ~= nil then
				local arr = helper.get_variable_array(var_name)
				for i=1,#arr do
					cls:init(arr[i])
				end
			end
		end
	end
end
events.register("prestart", load_persisted_tags)

return events