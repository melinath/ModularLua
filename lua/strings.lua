--! String manipulation functions.
local strings = {}

strings.capfirst = function(str)
	return str:sub(1,1):upper() .. str:sub(2)
end

return strings