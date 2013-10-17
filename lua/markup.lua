--! Utilities for generating markup.

local markup = {
	bullet = "&#8226; ",
}


function markup.concat(...)
	-- Concatanate strings and userdata.
	local s = ""
	for i=1, select('#', ...) do
		s = s .. select(i, ...)
	end
	return s
end


function markup.tag(name, ...)
	-- Syntax: tag(name, [attrs], contents...)
	local attr_str = ""
	local start = 1
	
	if type(select(1, ...)) == 'table' then
		--Then they've provided attrs.
		local attrs = {}
		for k,v in pairs(...) do
			table.insert(attrs, string.format('%s="%s"', k, v))
		end
		attr_str = " " .. table.concat(attrs, " ")
		start = 2
	end
	local open = string.format("<%s%s>", name, attr_str)
	local close = string.format("</%s>", name)
	return markup.concat(open, table.unpack(select(start, ...)), close)
end


function markup.small(...) return markup.tag("small", table.unpack(...)) end
function markup.big(...) return markup.tag("big", table.unpack(...)) end

local function minmax(val, min, max)
	return math.max(math.min(val, max), min)
end
function markup.color(r, g, b, ...)
	local r, g, b = minmax(r, 0, 255), minmax(g, 0, 255), minmax(b, 0, 255)
	local attrs = {foreground=string.format("#%02x%02x%02x", r, g, b)}
	return markup.tag("span", attrs, table.unpack(...))
end

markup.escape_values = {
	["<"] = "&lt;",
	[">"] = "&gt;",
}

function markup.escape(str)
	-- Makes a string pango-safe by converting special entities to their
	-- entity equivalents.
	return (string.gsub(str, "([<>])", markup.escape_values))
end

return markup