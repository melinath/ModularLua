--! Miscellaneous utilities to help (for example) set up inheritance.


local utils = {}


--! Sequentially fires an array of wml tags (like a [commands] set).
function utils.run_wml(wml)
	for i=1, #wml do
		wesnoth.fire(wml[i][1], wml[i][2])
	end
end


--! Base class for inheritable objects.
utils.class = {
	--! Shortcut for parent class (metatable).
	parent_class = nil,

	subclass = function(cls, cfg)
		-- Create a subclass of the current class.
		-- cls is the thing being subclassed; cfg is the overriding
		-- table.
		if cls.__index ~= cls then
			-- Not a class.
			error("Instance can't be subclassed.")
		end
		local new_cls = cfg or {}
		new_cls.__index = new_cls
		setmetatable(new_cls, cls)
		return new_cls
	end,

	init = function(cls, cfg)
		-- Create an instance of the current class
		local instance = cfg or {}
		setmetatable(instance, cls)
		instance.class = cls
		return instance
	end,
}
utils.class.__index = utils.class


utils.matcher = utils.class:subclass({
	allowed_filters = {
		"filter",
		"filter_second",
		"filter_location",
	},
	filters = {},

	matches = function(self)
		local matched = true
		for i, filter_name in ipairs(self.allowed_filters) do
			if self.filters[filter_name] ~= nil then
				matched = self[filter_name](self.filters[filter_name])
			end
			if not matched then break end
		end
		return matched
	end,

	filter = function(filter_def)
		local c = wesnoth.current.event_context
		local unit = wesnoth.get_unit(c.x1, c.y1)
		return wesnoth.match_unit(unit, filter_def)
	end,

	filter_second = function(filter_def)
		local c = wesnoth.current.event_context
		local unit = wesnoth.get_unit(c.x2, c.y2)
		return wesnoth.match_unit(unit, filter_def)
	end,

	filter_location = function(filter_def)
		local c = wesnoth.current.event_context
		return wesnoth.match_location(c.x1, c.y1, filter_def)
	end,
})


return utils
