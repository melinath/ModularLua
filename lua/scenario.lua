local helper = wesnoth.require "lua/helper.lua"

local events = modular.require "events"
local utils = modular.require "utils"


local scenario = {}


--! Scenario-level tag handling !--

--! ModularLua supports scenario-level tags out of the box, something which is
--! generally a pain to implement otherwise. All scenario tags created with
--! ModularLua can also be used as action tags; in this case, a new instance of
--! the scenario tag will be added to the scenario-level information. By
--! default, scenario-level tags are not expected to "do" anything beyond
--! storing information about the current scenario (see, for example,
--! ModularLua/lua/maps.lua).

--! Container for all known scenario-level tag classes. Maps tag names to
--! classes.
scenario.tag_classes = {}


--! Container for all tag instances. A plain list.
scenario.tags = {}


scenario.tag = utils.class:subclass({
	--! Base class for scenario-level tags. New tags can be registered by
	--! calling ``scenario.tag:subclass`` and passing in the name of the tag and a
	--! configuration table defining its behavior.
	
	--! What the tag name is.
	name = nil,

	--! Whether or not the tag's configuration should persist between scenarios.
	persist = false,
	
	subclass = function(cls, cfg)
		--! In addition to creating the class, store it in tag_classes and
		--! register a wml action to create new instances of the tag class.
		new_cls = utils.class.subclass(cls, cfg)

		if new_cls.name == nil then error("Tag class requires name.") end
		if scenario.tag_classes[new_cls.name] ~= nil then
			error("Scenario-level tag called '" .. new_cls.name .."' already exists.")
		end
		if wesnoth.wml_actions[new_cls.name] ~= nil then
			error("WML tag called '" .. new_cls.name .."' already exists.")
		end

		scenario.tag_classes[new_cls.name] = new_cls
		scenario.tags[new_cls.name] = {}
		wesnoth.wml_actions[new_cls.name] = function(wml) new_cls:from_wml(wml) end
		return new_cls
	end,
	init = function(cls, cfg)
		--! Makes sure that there is a "wml" key in the cfg for this init.
		--! And that tag name is not overridden. And records the tag.
		--! All else is irrelevant.
		if cfg.name ~= nil then error("Tag instance cannot override tag name.") end
		if cfg.wml == nil then error("Tag instance requires WML to store.") end
		local instance = utils.class.init(cls, cfg)
		table.insert(scenario.tags[cls.name], instance)
		return instance
	end,

	from_wml = function(cls, wml)
		cls:init({wml=wml})
	end,
	to_wml = function(self)
		--! Returns a WML-formatted representation of the tag. By default, this
		--! is simply the wml that was stored during ``init``, so that
		--! using the output of this tag to create a new instance would result
		--! in an instance identical to ``self``.
		return self.cfg
	end
})


--! Initialize scenario-level declarations of the tag on load.
local old_on_load = wesnoth.game_events.on_load
function wesnoth.game_events.on_load(cfg)
	-- First, go through the cfg and instantiate all scenario-level tags.
	for i=1, #cfg do
		local name, wml = table.unpack(cfg[i])
		local cls = scenario.tag_classes[name]
		if cls ~= nil then cls:from_wml(wml) end
	end

	-- Now loop backwards and remove the scenario-level tags from cfg.
	for i=#cfg, 1, -1 do
		local name, wml = table.unpack(cfg[i])
		if scenario.tag_classes[name] then table.remove(cfg, i) end
	end
	old_on_load(cfg)
end


--! Save all instances of the tag to the scenario level on save.
local old_on_save = wesnoth.game_events.on_save
function wesnoth.game_events.on_save()
	cfg = old_on_save()
	for name, tags in pairs(scenario.tags) do
		for i, tag in ipairs(tags) do
			table.insert(cfg, {tag.name, tag:to_wml()})
		end
	end
	return cfg
end


local function persist_variable_name(name)
	return string.format("modular.scenario.tags.%s", name)
end


local function save_persisting_tags()
	--! Saves tags that are marked to persist as wesnoth variables.
	for name, tags in pairs(scenario.tags) do
		if scenario.tag_classes[name].persist then
			local arr = {}
			for i, tag in ipairs(tags) do
				table.insert(arr, tag.to_wml())
			end
			helper.set_variable_array(persist_variable_name(tag.name), arr)
		end
	end
end
events.register("victory", save_persisting_tags)
events.register("defeat", save_persisting_tags)

local function load_persisted_tags()
	--! Loads persisted tags from the previous scenario.
	for name, cls in pairs(scenario.tag_classes) do
		if cls.persist then
			local var_name = persist_variable_name(name)
			local arr = helper.get_variable_array(var_name)
			for i, wml in ipairs(arr) do
				cls:from_wml(wml)
			end
			-- Clear the variable.
			wesnoth.set_variable(var_name, nil)
		end
	end
end
events.register("prestart", load_persisted_tags)


--! General scenario setup as a scenario-level template tag.
scenario.setup = nil


--! List of functions which take a scenario setup config as their only
--! argument and which finalize settings in various modules based on that.
scenario.setup_handlers = {}


scenario.tag:subclass({
	name = "setup",
	init = function(cls, cfg)
		local instance = scenario.tag.init(cls, cfg)

		if scenario.setup ~= nil then error("Only one setup tag is allowed.") end
		scenario.setup = instance.wml
		for i, func in ipairs(scenario.setup_handlers) do
			func(scenario.setup)
		end

		return instance
	end,
})


return scenario