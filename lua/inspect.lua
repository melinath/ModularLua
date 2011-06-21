--! Various helper functions for inspecting data in Lua.

local inspect = {}
local helper = wesnoth.require "lua/helper.lua"


inspect.settings = {
	base_indent = "   ",
	max_depth = 20,
}


inspect.userdata_types = {
	"unit",
	"side",
	"wml object",
	"translatable string"
}


function inspect.type(data)
	-- Returns a string representation of the type of data. If the data is
	-- wesnoth userdata, intelligently returns a string representing the type
	-- of userdata. Note: This only checks what the data claims to be, not
	-- the validity of that claim.
	local data_type = type(data)
	if data_type == "userdata" then
		local mt = getmetatable(data)
		for i=1,#inspect.userdata_types do
			if inspect.userdata_types[i] == mt then
				data_type = mt
				break
			end
		end
	end
	return data_type
end


function inspect.userdata(data)
	-- Converts userdata to a table if possible; otherwise, returns the data
	-- unchanged.
	local data_type = inspect.type(data)
	if data_type == "unit" or data_type == "side" then
		return data.__cfg
	elseif data_type == "wml object" then
		return data.__literal
	end
	return data
end


function inspect.tostring(data)
	-- Returns a string representation of the ``data``, up to ``depth`` levels
	-- of the table, if applicable.
	local result = ""
	local data = inspect.userdata(data)
	if type(data) == "table" then
		local max_depth = inspect.settings.max_depth
		local base_indent = inspect.settings.base_indent
		local known = {
			[tostring(data)] = true
		}
		
		local function recurse(data, depth, indent)
			local depth = depth or 1
			local indent = indent or base_indent
			local result = ""
			for k, v in pairs(data) do
				result = result .. indent .. k .. " = "
				if type(v) == "userdata" then v = inspect.userdata(v) end
				if type(v) == "table" then
					if depth >= max_depth then
						result = result .. "{<max recursion reached>},\n"
					else
						v = helper.literal(v)
						local id = tostring(v)
						if known[id] then
							result = result .. "{<loop detected>},\n"
						else
							known[id] = true
							result = result .. "{\n" .. recurse(v, depth + 1, indent .. base_indent) .. indent .. "},\n"
							known[id] = false
						end
					end
				else
					result = result .. tostring(v) .. ",\n"
				end
			end
			return result
		end
		return "{\n" .. recurse(data) .. "}"
	else
		return tostring(data)
	end
end


function inspect.is_wml_table(data)
	-- Returns true if ``data`` is a wml table and false otherwise.
	-- Currently NOT IMPLEMENTED.
	if type(data) ~= "userdata" then return false end
	return true
end

return inspect