--! Functions etc. related to the user interface.

local helper = wesnoth.require "lua/helper.lua"
local T = helper.set_wml_tag_metatable {}

local utils = modular.require "utils"

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
}

interface.menu = utils.class:subclass({
	--! Title of the menu. Displayed next to the menu image.
	title = nil,

	--! Path to the image to be used for this menu.
	image = 'wesnoth-icon.png',

	--! Speaker for the message.
	speaker = 'narrator',

	--! A message to be displayed with the menu.
	message = nil,

	--! List of tables containing name and func keys.
	options = {},

	display = function(self)
		local choices = {}
		for i, option in ipairs(self.options) do
			choices[i] = option.name or option[1]
		end
		local choice = helper.get_user_choice(
			{
				speaker = self.speaker,
				caption = self.title,
				image = self.image,
				message = self.message
			},
			choices
		)
		local func = self.options[choice].func or self.options[choice][2]
		func()
	end,
})


return interface