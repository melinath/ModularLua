--! Utilities for generating markup.

local markup = {
	bullet = "&#8226; ",
	
	color_prefix = function(r, g, b)
		-- cribbed from lua/wml/objectives.lua
		return string.format('<span foreground="#%02x%02x%02x">', r, g, b)
	end,
	color_suffix = function() return "</span>" end,
	
	concat = function(...)
		-- Concatanate strings and userdata.
		local s = ""
		for i=1,#arg do
			s = s .. arg[i]
		end
		return s
	end,
}

local m = markup

function m.tag(name, str) return m.concat("<", name, ">", str, "</", name, ">") end
function m.small(str) return m.tag("small", str) end
function m.big(str) return m.tag("big", str) end
function m.color(r, g, b, ...) return m.concat(m.color_prefix(r,g,b), m.concat(arg), m.color_suffix()) end

return markup