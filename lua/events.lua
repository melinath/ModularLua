local dbg = modular.require("dbg")


--! A module which allows simple, efficient registration of lua functions
--! as event handlers.


events = {}


--! Event registration !--

--! Container for all registered events. Maps event names to lists of functions
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
local old_on_event = wesnoth.game_events.on_event
function wesnoth.game_events.on_event(name)
	local funcs = events.events[name]
	if funcs ~= nil then
		for i,f in ipairs(funcs) do
			dbg.pcall(f)
		end
	end
	if old_on_event ~= nil then old_on_event(name) end
end


return events