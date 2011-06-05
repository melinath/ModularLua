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

return interface