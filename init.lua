--
-- Author: FH3095
--

require("ts3init")
require("ts3defs")
require("ts3errors")

local function protectTable(tbl)
	local function metaTableConstProtect(_,key,value)
		if nil ~= tbl[key] then
			print(tostring(key) .. " is a read-only variable! (Tried to change to \'" .. tostring(value) .. "\'.)")
			return
		end
		rawset(tbl,key,value)
	end

	return setmetatable ({}, -- You need to use a empty table, otherwise __newindex would only be called for first entry
		{
			__index = tbl, -- read access -> original table
			__newindex = metaTableConstProtect,
	})
end

local complexDice = {
	const = {
		MODULE_NAME = "Complex Dice",
		MODULE_FOLDER = "ComplexDice",
		DEBUG = 0,
		DEBUG_MSG_IN_CHAT = 1,
		ROLL_COMMAND = "!roll ", -- Space is important (otherwise !roll(d2) or !rolld2 would be valid)
		PRIVATE_ROLL_COMMAND = "!proll ",
		OPEN_OWN_PRIVATE_CHAT = "!self",
		TOGGLE_ROLL_FOR_OTHERS = "!rollforothers",
		TS_MAX_CHAT_MESSAGE_LENGTH = 1023,
	},
	var = {},
	config = {
		ROLL_FOR_OTHERS = 0,
	},
}

complexDice.const = protectTable(complexDice.const)

function FH3095_getComplexDice()
	return complexDice
end

require(complexDice.const.MODULE_FOLDER .. "/randomlua")
complexDice.const.random = twister(os.time())

require(complexDice.const.MODULE_FOLDER .. "/ComplexDice")


local registeredEvents = {
	onTextMessageEvent = complexDice.onTextMessageEvent
}

ts3RegisterModule(complexDice.const.MODULE_NAME, registeredEvents)
