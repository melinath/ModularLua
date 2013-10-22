# ModularLua

ModularLua is meant to make it easier to develop Lua for Wesnoth add-ons by providing high-quality, decoupled utilites. Currently provides streamlined dialog creation, scenario tag support, and a debug shell with history, among other features.

## Installing ModularLua

There are two ways to install ModularLua. You can get it from the Wesnoth 1.11 add-on server, or you can clone the github repository ([github.com/melinath/ModularLua](https://github.com/melinath/ModularLua)) directly into your add-ons directory.

Once you have the code in place, you can start using ModularLua in your campaign by putting the following code in your campaign file:

```
# ~add-ons/MyCampaign/_main.cfg

...

[lua]
    code = <<
        modular = wesnoth.require "~add-ons/ModularLua/modular.lua"
        -- Require other modules here.
        debug = modular.require "debug"
        my_lua = modular.require("my_lua", "MyCampaign")
    >>
[/lua]

...

```

**All other code examples on this page assume that modular and debug are set as global variables.**

## Dialog creation

With Wesnoth's built-in dialog creation, there is a lot of flexibility. However, there's also a lot of boilerplate and room for mistakes, making even simple dialogs a pain and a half to set up. With ModularLua, you simply input a quick lua table representing the dialog, and it does the rest for you.

```lua
local dialog = modular.require("dialog")
local d = dialog.create({
    {widget="label", label="shell"},
    {{widget="label", label="egg"}, {widget="label", label="chicken"}}
})
d:display()
```

## Scenario-level tag registration

ModularLua makes creating new scenario-level tags easy. These tags can be used to easily store extra configuration for a scenario, or for any action that you would like to see at a scenario level instead of just inside an event or command block.

This code will allow [my_tag] as a scenario-level tag:

```lua
local scenario = modular.require("scenario")
local my_tag = scenario.tag:subclass({name = "my_tag"})
```

By default, this tag will just store the WML that was originally passed into it, and persist it across game saves. You can add more behavior by overriding the init method of your new tag. This tag will output the ``message`` attribute of its WML configuration table using ``wesnoth.message``.

```lua
local scenario = modular.require("scenario")
local wesnoth_message_tag = scenario.tag:subclass({
    name="wesnoth_message_tag",
    init = function(cls, cfg)
        local instance = scenario.tag.init(cls, cfg)

        if instance.message == nil then
            error("[wesnoth_message_tag] requires a 'message' attribute")
        end
        wesnoth.message(tostring(instance.message))
    end
})
```

## Debug shell

You can start the debug shell in-game with the following command:

``:lua debug.shell()``

The shell supports history, and provides special ``tostring`` and ``type`` commands which already know how to handle Wesnoth userdata.


## Class inheritance

ModularLua provides utilities for class inheritance out of the box. You could use them as follows:

```lua

local utils = modular.require "utils"

local my_class_instances = {}

my_class = utils.class:subclass({
    -- not required, but can be useful for keeping track and/or providing
    -- defaults.
    attribute_1 = nil,
    list_1 = {},

    do_something = function(self, var1, var2)
        -- do something!
        ...
    end,

    do_something_else = function(self)
        -- This one is based on set attributes!
        if self.attribute_1 == 'hi' then
            print "lo"
        elseif self.attribute_1 == 5 then
            print "4... 3... 2... 1..."
        end
    end,
})

```

You can then create instances of my_class like this:

```lua
instance = my_class:init({
    attribute_1 = 5,
    list_1 = {"foo", "bar", "biz"}
})

```
