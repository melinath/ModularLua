--! Easy dialog creation and display.

local helper = wesnoth.require "lua/helper.lua"
local T = helper.set_wml_tag_metatable {}

local dialog = {}

function dialog.parse(cfg)
	--[[
		Given a simple table input, converts it into a dialog.
		For example, the input:
			{widget="text_box", id="shell"}
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
	local rows = dialog.make_rows(cfg)
	local d = {
		T.tooltip{id="tooltip_large"},
		T.helptip{id="tooltip_large"},
		T.grid(rows)
	}
	for k, v in pairs(cfg) do
		if type(k) ~= "number" then
			d[k] = v
		end
	end
	return d
end

function dialog.make_rows(cfg, idx, rowlen)
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
			columns = dialog.make_columns{cfg[idx]}
			rowlen = 1
		else
			columns = dialog.make_columns(cfg[idx])
		end
		if (old_rowlen == nil and rowlen == 1) or old_rowlen == rowlen then
			-- We're okay to add the row to the current list of rows
			table.insert(rows, T.row(columns))
			idx = idx + 1
		elseif old_rowlen == nil then
			-- We're okay to generate a subgrid without increasing idx
			local subrows, new_idx = dialog.make_rows(cfg, idx, rowlen)
			idx = new_idx
			table.insert(rows, T.row{T.column{T.grid(subrows)}})
		else
			-- We need to return the rows we've made without increasing idx
			break
		end
	end
	return rows, idx
end

function dialog.make_columns(cfg)
	local columns = {}
	for i=1,#cfg do
		-- Easier to just set cfg[i], since the extra ``widget`` keyword will
		-- be ignored anyway.
		local cell = {
			cfg[i].widget,
			cfg[i]
		}
		table.insert(columns, T.column{
			horizontal_grow = true,
			cell
		})
	end
	return columns
end

--! A base class for dialogs
dialog.dialog = {
	new = function(self, grid, cfg)
		local o = cfg or {}
		setmetatable(o, self)
		o.dialog = dialog.parse(grid)
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
		return rval
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
dialog.dialog.__index = dialog.dialog

dialog.create = function(...)
	return dialog.dialog:init(table.unpack(...))
end

return dialog