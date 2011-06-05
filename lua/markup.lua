--! Utilities for generating markup.

local markup = {
	bullet = "&#8226; ",
	
	concat = function(...)
		-- Concatanate strings and userdata.
		local s = ""
		for i=1,#arg do
			s = s .. arg[i]
		end
		return s
	end,
	
	tag = function(name, ...)
		-- Syntax: tag(name, [attrs], contents...)
		local attr_str = ""
		local contents = arg
		
		if type(contents[1]) == 'table' then
			--Then they've provided attrs.
			local attrs = {}
			for k,v in pairs(contents[1]) do
				table.insert(attrs, string.format('%s="%s"', k, v))
			end
			attr_str = " " .. table.concat(attrs, " ")
			table.remove(contents, 1)
		end
		local open = string.format("<%s%s>", name, attr_str)
		local close = string.format("</%s>", name)
		return m.concat(open, unpack(contents), close)
	end
}

local m = markup

function m.small(...) return m.tag("small", unpack(arg)) end
function m.big(...) return m.tag("big", unpack(arg)) end

local function minmax(val, min, max)
	return math.max(math.min(val, max), min)
end
function m.color(r, g, b, ...)
	local r, g, b = minmax(r, 0, 255), minmax(g, 0, 255), minmax(b, 0, 255)
	local attrs = {foreground=string.format("#%02x%02x%02x", r, g, b)}
	return m.tag("span", attrs, unpack(arg))
end

return markup