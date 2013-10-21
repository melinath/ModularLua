local inspect = modular.require "inspect"
local dialog = modular.require "dialog"


local debug = {}


function debug.inspect(data, depth)
	-- Displays a string representation of the data passed in to a max depth of
	-- ``depth``.
	wesnoth.fire("message", {message=inspect.tostring(data, depth)})
end


function debug.type(data)
	wesnoth.fire("message", {message=inspect.type(data)})
end


local shell_settings = {
	rnext = 1,
	rprev = 2,
	rhist = 3,
	prompt = "> "
}

local shell
shell = dialog.dialog:init({
	grid = {
		vertical_placement="bottom",
		{widget="scroll_label", id="shell_output"},
		{widget="text_box", id="shell"},
		{
			{widget="button", id="shell_prev", label="<=", return_value=shell_settings.rprev},
			{widget="button", id="shell_next", label="=>", return_value=shell_settings.rnext},
			--{widget="button", id="shell_view_history", label="History", return_value=shell_settings.rhist}
		}
	},
	settings = shell_settings,
	output = nil,
	input = nil,
	
	history = {
		-- index of 0: Whatever is currently in the input box.
		-- index > 0: previously-entered commands, increasing age.
		index = 0,
		current = nil,
		prev = function()
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
		next = function()
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
		for i=1, select('#', ...) do
			if line == "" then
				line = tostring(select(i, ...))
			else
				line = line .. "\t" .. tostring(select(i, ...))
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
		
		local func, err = load(str, "shell", 't', env)
		if err then
			-- Fall back on a python-like interpretation of the string as a raw value.
			local ret_func, ret_err = load(string.format([[
				local x = %s
				if type(x) == 'string' then
					return string.format("'%%s'", x)
				else
					return tostring(x)
				end]], str), nil, 't', env)
			if ret_err then
				shell.print(err)
			else
				local success, rval = pcall(ret_func)
				if rval then
					shell.print(rval)
				end
			end
		else
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
})
debug.shell_dialog = shell


function debug.shell()
	debug.shell_dialog:display()
end


return debug