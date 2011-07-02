local debug = {}
local inspect = modular.require "inspect"


function debug.inspect(data, depth)
	-- Displays a string representation of the data passed in to a max depth of
	-- ``depth``.
	wesnoth.fire("message", {message=inspect.tostring(data, depth)})
end


function debug.type(data)
	wesnoth.fire("message", {message=inspect.type(data)})
end

return debug