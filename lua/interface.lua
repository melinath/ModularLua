--! Functions etc. related to the user interface.

local helper = wesnoth.require "lua/helper.lua"
local T = helper.set_wml_tag_metatable {}

local utils = modular.require "utils"

local interface = {
	message = function(image_or_speaker, caption, message)
		--! Creates a wesnoth message. Arguments for this function are
		--! [image_or_speaker, [caption,]] message
		if message == nil then
			message = caption
			caption = nil
		end
		if message == nil then
			message = image_or_speaker
			image_or_speaker = nil
		end
		if message == nil then
			error("No message provided.")
		end
		local image, speaker
		if image_or_speaker ~= nil then
			local ios_type = inspect.type(image_or_speaker)
			if ios_type == "unit" then
				speaker = image_or_speaker.id
			elseif ios_type == "string" then
				-- Try to get a unit with this as the id.
				local unit_list = wesnoth.get_units({id=image_or_speaker})
				if #unit_list > 0 then
					speaker = unit_list[1].id
				else
					image = image_or_speaker
				end
			else
				error("Bad image or speaker.")
			end
		else
			image = "portraits/bfw-logo.png"
		end
		if speaker == nil then speaker = "narrator" end
		wesnoth.wml_actions.message({
			speaker = speaker,
			image = image,
			caption = caption,
			message = message,
		})
	end,
}

interface.menu = utils.class:subclass({
	--! Title of the menu. Displayed next to the menu image.
	title = nil,

	--! Path to the image to be used for this menu.
	image = nil,
	default_image = "portraits/bfw-logo.png",

	--! Speaker for the message.
	speaker = nil,
	default_speaker = 'narrator',

	--! A message to be displayed with the menu.
	message = nil,

	--! List of tables containing name and func keys.
	options = {},

	display = function(self)
		local choices = {}
		for i, option in ipairs(self.options) do
			choices[i] = option.name or option[1]
		end
		local speaker = self.speaker or self.default_speaker
		local image = self.image
		if image == nil and self.speaker == nil then
			image = self.default_image
		end
		local choice = helper.get_user_choice(
			{
				speaker = speaker,
				caption = self.title,
				image = image,
				message = self.message
			},
			choices
		)
		local func = self.options[choice].func or self.options[choice][2]
		func()
	end,
})


return interface