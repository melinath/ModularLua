--! Functions etc. related to the user interface.

local helper = wesnoth.require "lua/helper.lua"
local T = helper.set_wml_tag_metatable {}

local interface = {
	message = function(image, message, speaker)
		--! Fires a wesnoth message. Arguments for this function are effectively
		--! [image], message, [speaker]
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

interface.menu = {
	--! Title of the menu.
	title = nil,

	--! Path to the impoge to be used for this menu.
	image = nil,

	--! A message to be displayed with the menu.
	message = nil,

	--! Table mapping option text to functions or submenus.
	options = {},

	new = function(cls, cfg)
		local new_cls = cfg or {}
		setmetatable(new_cls, cls)
		new_cls.__index = new_cls
		return new_cls
	end,
}
interface.menu.__index = interface.menu

--The menu - each option can either have a submenu or a function which executes arbitrary code. No, not quite right. A menu maps names to actions. Functions. A submenu is just another function. But nesting...
--Okay, so make menus a special thing, then let them have intros, outtros, tree structure. No, just tree structure.

return interface