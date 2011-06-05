--! Functions etc. related to the user interface.

local helper = wesnoth.require "lua/helper.lua"
local T = helper.set_wml_tag_metatable {}

local interface = {
	message = function(image, message, speaker)
		if message == nil and speaker == nil then
			message = image
			image = "wesnoth-icon.png"
		end
		if speaker == nil then speaker = 'narrator' end
		wesnoth.fire("message", {speaker=speaker, image=image, message=message})
	end,
	get_choice = function(cfg, options)
		-- cfg is an (img, msg, speaker) table; options is a table of tables
		-- containing an option and a function.
		local o = {}
		local f = {}
		for i=1,#options do
			table.insert(o, _(options[i].opt))
			table.insert(f, options[i].func)
		end
		choice = helper.get_user_choice(cfg, o)
		f[choice]()
	end
}

interface.markup = {
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
local m = interface.markup

function m.tag(name, str) return m.concat("<", name, ">", str, "</", name, ">") end
function m.small(str) return m.tag("small", str) end
function m.big(str) return m.tag("big", str) end
function m.color(r, g, b, ...) return m.concat(m.color_prefix(r,g,b), m.concat(arg), m.color_suffix()) end

interface.dialog = {}
local d = interface.dialog
function d.parse(...)
	--[[
		Given a simple table input, converts it into a dialog.
		For example, the input:
			{type="text_box", id="shell"}
		would give the output (with T = helper.set_wml_tag_metatable {}):
			{
				T.tooltip{id="tooltip_large"},
				T.helptip{id="tooltip_large"},
				T.grid{
					T.row{
						T.column{
							horizontal_grow = true,
							T.text_box{
								id="shell"
							}
						}
					}
				}
			}
		This output can be used for wesnoth.show_dialog.
	]]
	local rows = d.make_rows(arg)
	dialog = {
		T.tooltip{id="tooltip_large"},
		T.helptip{id="tooltip_large"},
		T.grid(rows)
	}
	return dialog
end
function d.make_rows(cfg, idx, rowlen)
	-- Given a cfg, parses it into rows and returns them. If ``num_cols`` is
	-- provided, will start at idx and only parse while the number of columns
	-- remains the same. If ``num_cols`` is not provided, will build subgrids
	-- to hold different numbers of columns.
	local rows = {}
	local idx = idx or 1
	local old_rowlen = rowlen
	while idx <= #cfg do
		local rowlen = #cfg[idx]
		local columns
		if rowlen == 0 then
			-- it's a single-cell row.
			columns = d.make_columns{cfg[idx]}
			rowlen = 1
		else
			columns = d.make_columns(cfg[idx])
		end
		if (old_rowlen == nil and rowlen == 1) or old_rowlen == rowlen then
			-- We're okay to add the row to the current list of rows
			table.insert(rows, T.row(columns))
			idx = idx + 1
		elseif old_rowlen == nil then
			-- We're okay to generate a subgrid without increasing idx
			local subrows, new_idx = d.make_rows(cfg, idx, rowlen)
			idx = new_idx
			table.insert(rows, T.row{T.column{T.grid(subrows)}})
		else
			-- We need to return the rows we've made without increasing idx
			break
		end
	end
	return rows, idx
end
function d.make_columns(cfg)
	local columns = {}
	for i=1,#cfg do
		-- Easier to just set cfg[i], since the extra ``type`` keyword will
		-- be ignored anyway.
		local cell = {
			cfg[i].type,
			cfg[i]
		}
		table.insert(columns, T.column{
			horizontal_grow = true,
			cell
		})
	end
	return columns
end

--! A generic class for dialogs
d.dialog = {
	init = function(self, ...)
		local o = {}
		setmetatable(o, self)
		o.dialog = d.parse(unpack(arg))
		return o
	end,
	display = function(self)
		local rval = wesnoth.show_dialog(self.dialog, function() self:preshow() end, function() self:postshow() end)
		if rval == -1 then
			self:on_enter()
		elseif rval == -2 then
			self:on_esc()
		else
			self:on_button(rval)
		end
	end,
	
	-- hooks for handling dialog pre- and postshow.
	-- TODO: Should default to saving values for all relevant widgets.
	preshow = function(self) end,
	postshow = function(self) end,
	
	-- hooks for handling the dialog closing.
	on_enter = function(self) end,
	on_esc = function(self) end,
	on_button = function(self, rval) end,
}
d.dialog.__index = d.dialog

return interface