local debug = {}
local inspect = modular.require "inspect"
local dialog = modular.require "dialog"


function debug.inspect(data, depth)
	-- Displays a string representation of the data passed in to a max depth of
	-- ``depth``.
	wesnoth.fire("message", {message=inspect.tostring(data, depth)})
end


function debug.type(data)
	wesnoth.fire("message", {message=inspect.type(data)})
end

local settings = {
	rnext = 1,
	rprev = 2,
	rhist = 3,
	prompt = "> "
}
local shell = {}
shell = dialog.dialog:new(
	{
		vertical_placement="bottom",
		{widget="scroll_label", id="shell_output"},
		{widget="text_box", id="shell"},
		{
			{widget="button", id="shell_prev", label="Previous", return_value=settings.rprev},
			{widget="button", id="shell_next", label="Next", return_value=settings.rnext},
			--{widget="button", id="shell_view_history", label="History", return_value=settings.rhist}
		}
	},
	{
		meta = {
			__call = function() shell:display() end,
			__index = dialog.dialog,
		},
		settings = settings,
		output = nil,
		input = nil,
		
		history = {
			-- index of 0: Whatever is currently in the input box.
			-- index > 0: previously-entered commands, increasing age.
			index = 0,
			current = nil,
			next = function()
				-- increment the history index and set shell.history.current to whatever
				-- is there.
				local i = shell.history.index + 1
				if i == 1 then
					shell.history[0] = shell.input
				end
				if shell.history[i] ~= nil then
					shell.history.current = shell.history[i]
					shell.history.index = i
				end
			end,
			prev = function()
				-- decrement the history index and set shell.history.current to whatever
				-- is there.
				local i = shell.history.index - 1
				if shell.history[i] ~= nil then
					shell.history.current = shell.history[i]
					shell.history.index = i
				end
			end,
			add = function(val)
				table.insert(shell.history, 1, val)
				shell.history[0] = nil
				shell.history.current = nil
				shell.history.index = 0
			end,
		},
		
		print = function(...)
			local line = ""
			for i=1,arg['n'] do
				if line == "" then
					line = tostring(arg[i])
				else
					line = line .. "\t" .. tostring(arg[i])
				end
			end
			if shell.output == nil then
				shell.output = tostring(line)
			else
				shell.output = shell.output .. "\n" .. tostring(line)
			end
		end,
		
		eval = function(str)
			-- Evaluates a string input into the shell and returns the output.
			local env = {
				print = shell.print,
				clear = function()
					shell.output = nil
				end,
				tostring = inspect.tostring,
				type = inspect.type
			}
			setmetatable(env, {__index = _G, __newindex = _G})
			
			local func, err = loadstring(str, "shell")
			if err then
				-- Fall back on a python-like interpretation of the string as a raw value.
				local ret_func, ret_err = loadstring(string.format([[
					local x = %s
					if type(x) == 'string' then
						return string.format("'%%s'", x)
					else
						return tostring(x)
					end]], str))
				if ret_err then
					shell.print(err)
				else
					setfenv(ret_func, env)
					local success, rval = pcall(ret_func)
					if rval then
						shell.print(rval)
					end
				end
			else
				setfenv(func, env)
				local success, rval = pcall(func)
				if rval then
					shell.print(rval)
				end
			end
		end,
		
		display = function(self)
			local rval
			
			repeat
				rval = dialog.dialog.display(self)
			until rval == -2
		end,
		
		preshow = function(self)
			-- In preshow, set the output and input values dynamically.
			if shell.output ~= nil then
				wesnoth.set_dialog_value(shell.output, "shell_output")
			end
			if shell.history.current ~= nil then
				wesnoth.set_dialog_value(shell.history.current, "shell")
			end
		end,
		
		postshow = function(self)
			-- In postshow, store the shell dialog value.
			self.input = wesnoth.get_dialog_value "shell"
		end,
		
		on_enter = function(self)
			local input = self.input
			if input ~= "" then
				self.history.add(input)
			end
			self.print(string.format("%s%s", shell.settings.prompt, input))
			self.eval(input)
		end,
		
		on_button = function(self, rval)
			if rval == shell.settings.rnext then
				shell.history.next()
			elseif rval == shell.settings.rprev then
				shell.history.prev()
			end
		end
	}
)
setmetatable(shell, shell.meta)

debug.shell = shell

return debug