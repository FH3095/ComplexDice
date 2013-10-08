
local complexDice = FH3095_getComplexDice()
local loadFunction = loadstring

function complexDice:printMsg(msg)
	ts3.printMessageToCurrentTab(self.const.MODULE_NAME .. ": " .. msg)
end

function complexDice:debugMsg(msg)
	if self.const.DEBUG ~= 0 then
		if self.const.DEBUG_MSG_IN_CHAT ~= 0 then
			self:printMsg(msg)
		end
		print(self.const.MODULE_NAME .. ": " .. msg)
	end
end

function complexDice:checkError(msg,errorCode)
	if errorCode ~= ts3errors.ERROR_ok then
		self:printMsg("ERROR: " .. msg .. errorCode)
	end
end

function complexDice:getMyClientID(serverConnectionHandlerID)
	local myClientID, error = ts3.getClientID(serverConnectionHandlerID)
	self:checkError("Getting own client ID: ",error)
	if myClientID == 0 then
		self:printMsg("Not connected")
		return 0
	end

	return myClientID
end

function complexDice:getMyChannelID(serverConnectionHandlerID)
	local myChannelID, error = ts3.getChannelOfClient(serverConnectionHandlerID, self:getMyClientID(serverConnectionHandlerID))
	self:checkError("Getting own channel: ",error)

	return myChannelID
end

function complexDice:getMyUID(serverConnectionHandlerID)
	local myUID, error = ts3.getClientVariableAsString(serverConnectionHandlerID, self:getMyClientID(serverConnectionHandlerID), ts3defs.ClientProperties.CLIENT_UNIQUE_IDENTIFIER)
	self:checkError("Getting own UID: ",error)

	return myUID
end


function complexDice:calcDiceResultModificator(str)
	local diceResultModificator = 0
	if str:find("[%+%-]") ~= nil then
		local pStart=str:find("[%+%-]")
		local resultFunctionCode = "return 0 " .. str:sub(pStart)
		local resultFunction,error = loadFunction(resultFunctionCode)
		if resultFunction == nil and nil == self.var.diceResult.error then
			self.var.diceResult.error = "Error calculating diceResult-Modificator for dice \"" .. str .. "\" (" .. resultFunctionCode .. "): " .. error
			return 0
		end
		diceResultModificator = resultFunction()
		self:debugMsg("calcDiceResultModificator: Result: " .. diceResultModificator .. " ; Code: " .. resultFunctionCode)
	end
	return diceResultModificator
end

function complexDice:calcDicesResult(dices,diceSides,diceResultModificator)
	local result = {}
	local sum = 0
	for i = 1, dices do
		local rnd = math.random(1,diceSides)+diceResultModificator
		result[i] = rnd
		sum = sum + rnd
	end
	table.sort(result)
	return sum, result
end

function complexDice.calcDices(str) -- called as callback from string.gsub
	local self = complexDice
	self:debugMsg("Calc result for " .. str)
	local ret=str:sub(2,-2)
	local diceResultModificator = self:calcDiceResultModificator(ret)
	local _,_,dices,diceSides=ret:find("^(%d*)d(%d+)")
	if nil == dices or "" == dices then
		dices = 1
	else
		dices = tonumber(dices)
	end
	diceSides = tonumber(diceSides)
	if 0 == diceSides then
		if nil == self.var.diceResult.error then
			self.var.diceResult.error = "Invalid dice: \"" .. str .. "\": Dice with 0 sides is not allowed."
		end
		return nil
	end

	local ret = "[" .. dices .. "d" .. diceSides
	if diceResultModificator >= 0 then
		ret = ret .. "+"
	end
	ret = ret .. diceResultModificator .. "]"
	local sum,dicesResult = self:calcDicesResult(dices,diceSides,diceResultModificator)
	table.insert(self.var.diceResult,{dice = ret, sum = sum, dices = dicesResult})

	self:debugMsg("calcDices: " .. ret .. " = " .. sum)
	return ret
end

function complexDice:rollDices(diceString)
	self:debugMsg("rollDices: \"" .. diceString .. "\"")

	if nil == diceString:match("^[d%d%+%-%*%/%(%)% ]+$") then
		self:printMsg("Invalid dice string. Only allowed characters are: d, 0-9, +, -, *, / and parentheses ()")
		return ""
	end

	self.var.diceResult = {}
	self.var.diceResult.request = diceString
	diceString = " " .. diceString -- Add whitespace, so [^%(] has something to match at the beginning of the string
	diceString = diceString:gsub("([^%(%d])(" .. "%d*d%d+" .. ")","%1(%2)")

	diceString = diceString:gsub(" ","") -- Remove whitespaces

	self:debugMsg("rollDices: Prepared dice string: " .. diceString)

	diceString = diceString:gsub("(%(" .. "%d*d%d+[%+%-%d]*" .. "%))", self.calcDices)

	self.var.diceResult.formattedRequest = diceString

	local sumFunctionCode = diceString
	for _,result in ipairs(self.var.diceResult) do
		local diceCode = "0"
		for _,diceValue in ipairs(result.dices) do
			if diceValue >= 0 then
				diceCode = diceCode .. "+"
			end
			diceCode = diceCode .. diceValue
		end
		sumFunctionCode = sumFunctionCode:gsub("%[(%d+d%d+[%+%-]%d+)%]","(" .. diceCode .. ")", 1)
	end

	if nil == sumFunctionCode:match("^[%d%+%-%*%/%(%)]+$") then
		self.var.diceResult.error = "Can't convert string to result. Resulting function code: " .. sumFunctionCode
		return
	end

	sumFunctionCode = "return " .. sumFunctionCode
	local resultFunction,error = loadFunction(sumFunctionCode)
	if nil == resultFunction and nil == self.var.diceResult.error then
		self.var.diceResult.error = "Error calculating sum (Code: \"" .. sumFunctionCode .. "\"): " .. error
		return
	end

	self.var.diceResult.sum = resultFunction()
	self:debugMsg("rollDices: Calculating result for Function: " .. sumFunctionCode .. " = " .. self.var.diceResult.sum)
end

function complexDice:sendTextMessage(serverConnectionHandlerID,responseMode,responseID,message)
	if ts3defs.TextMessageTargetMode.TextMessageTarget_CHANNEL == responseMode then
		local error = ts3.requestSendChannelTextMsg(serverConnectionHandlerID, message, self:getMyChannelID(serverConnectionHandlerID))
		self:checkError("Send Text-Message to channel: ",error)
	else
		local error = ts3.requestSendPrivateTextMsg(serverConnectionHandlerID, message, responseID)
		self:checkError("Send Text-Message to user: ",error)
	end
end

function complexDice:printDices(serverConnectionHandlerID,fromName,responseMode,responseID)
	if nil ~= self.var.diceResult.error then
		local message = fromName .. ": ERROR: " .. self.var.diceResult.error
		self:sendTextMessage(serverConnectionHandlerID,responseMode,responseID,message)
		self:debugMsg(message)
		return
	end

	local message = fromName .. ": " .. self.var.diceResult.request .. " = " .. self.var.diceResult.formattedRequest .. " = " .. self.var.diceResult.sum .. "\n"
	local diceMessage = ""
	for _,result in ipairs(self.var.diceResult) do
		diceMessage = diceMessage .. "[b]" .. result.dice .. "[/b] = { "
		local firstDice = 1
		for _,diceResult in ipairs(result.dices) do
			if 0 == firstDice then
				diceMessage = diceMessage .. ", "
			end
			firstDice = 0
			diceMessage = diceMessage .. diceResult
		end
		diceMessage = diceMessage .. " }\n"

		if string.len(message .. diceMessage) > self.const.TS_MAX_CHAT_MESSAGE_LENGTH then
			self:sendTextMessage(serverConnectionHandlerID,responseMode,responseID,message)
			message = diceMessage
		else
			message = message .. diceMessage
		end
		diceMessage = ""
	end

	if "" ~= message then
		self:sendTextMessage(serverConnectionHandlerID,responseMode,responseID,message)
	end
end

-- Callback functions

local function stringStartsWith(str,start)
	return str:sub(1,string.len(start)) == start
end


function complexDice.onTextMessageEvent(serverConnectionHandlerID, targetMode, toID, fromID, fromName, fromUniqueIdentifier, message, ffIgnored)
	local ret = 0
	local self = complexDice
	self:debugMsg("onTextMessageEvent: " .. serverConnectionHandlerID .. " , " .. targetMode .. " , " .. toID .. " , " .. fromID .. " , " .. fromName .. " , " .. fromUniqueIdentifier .. " , " .. message .. " , " .. ffIgnored)

	local myUID = self:getMyUID(serverConnectionHandlerID)
	if fromUniqueIdentifier == myUID and self.const.OPEN_OWN_PRIVATE_CHAT == message then
		ts3.requestSendPrivateTextMsg(serverConnectionHandlerID,"My own chat.",fromID)
	elseif (fromUniqueIdentifier == myUID or self.const.ROLL_FOR_OTHERS) and ts3defs.TextMessageTargetMode.TextMessageTarget_SERVER ~= targetMode then
		local rollCommand = 0
		local diceString = ""
		if stringStartsWith(message,self.const.ROLL_COMMAND) then
			rollCommand = 1
			diceString = message:sub(self.const.ROLL_COMMAND:len()+1)
		elseif stringStartsWith(message,self.const.PRIVATE_ROLL_COMMAND) then
			rollCommand = 2
			diceString = message:sub(self.const.PRIVATE_ROLL_COMMAND:len()+1)
		end
		if rollCommand ~= 0 then
			local responseMode = targetMode
			local responseID = 0 -- Not needed for response to channel
			if ts3defs.TextMessageTargetMode.TextMessageTarget_CLIENT == targetMode then
				responseID = fromID
			end
			if 2 == rollCommand then -- Private Roll.
				responseMode = ts3defs.TextMessageTargetMode.TextMessageTarget_CLIENT
				responseID = fromID
			end
			self:rollDices(diceString)
			self:printDices(serverConnectionHandlerID,fromName,responseMode,responseID)
		end
	end


	return ret
end
