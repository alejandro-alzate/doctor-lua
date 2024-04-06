--[[--
	@module doctor-lua
	@release 0.0.0
	@author Alejandro Alzate Sánchez
	@copyright Copyright ©2024 alejandro-alzate
	@summary House-grown documentation tool for lua.
	@description |
	# Doctor.lua
	Create simple documents for your lua projects
	@url https://github.com/alejandro-alzate/doctor-lua
	@license $licenses.mit
	@library doctor-lua
]]
local doctor = {}
local json = require("json")
local totable = require("string-to-table")
local readfile = require("read-file")
local triggers = {
	start	= "%-%-%[%[%-%-",		--"%g*%s*%-%[%[%-*%s*%g*", -- This "--[["
	single	= "%-%-%-",				--"%g*%s*%-%-%s*%g*", -- This "---"
	finish	= "%]%]",				-- "%g*%s*%]%]%s*%g*", -- This "]]"
}
local keywords = {
	url				= {"@url"								},
	scope			= {"@scope"								},
	usage			= {"@usage",		"@use"				},
	author			= {"@author"							},
	method			= {"@method"							},
	module			= {"@module",		"@mod"				},
	ret				= {"@return",		"@ret"				},
	example			= {"@example",		"@exa",	"@eg"		},
	declare			= {"@declare",		"@decl"				},
	library			= {"@library",		"@lib"				},
	release			= {"@release",		"@rel"				},
	version			= {"@version",		"@ver"				},
	summary			= {"@summary",		"@sum"				},
	argument		= {"@argument",		"@arg"				},
	func			= {"@function",		"@func", "@fun"		},
	copyright		= {"@copyright",	"@copy"				},
	parameter		= {"@parameter",	"@param"			},
	description		= {"@description",	"@desc"				},
}
local handlers = {}
local documentationStack = {
	current = {
		line = 1
	},
	temporal = {
		func = {},
		module = {}
	},
	funcs = {},
	modules = {},
}
local lastKeywordFlushTrigger = false

--[[--
	@function getLineType
	@summary Process what type of value is being set
	@parameter inputText string *The line to parse
	@description |
	Gets a line and tests for every declared handle
	ends when finds a match or when runs out of handles
	to test
	@return |
	keywordName string The keyword name that made a match, when no match
	is made it returns false
	isMultine boolean Seeks for a pipe "|" to flag a multi-line handle
	@scope internal
]]
local function getLineType(inputText)
	assert(
		type(inputText) == "string",
		"Cannot process line type since inputText is not a string type"
		.."\nReceived type: " .. type(inputText)
		)
	local text = tostring(inputText)

	--print("Input:", text)
	for keywordName, keywordPatterns in pairs(keywords) do
		--print("\tTesting for:", keywordName, keywordPatterns)
		for _, pattern in ipairs(keywordPatterns) do
			--print("\t\tTesting pattern:", pattern)
			catch = text:match("".. pattern .. "")
			if catch then
				--print("Test caught this one:", keywordName, pattern, catch)
				local lastChar = text:sub(text:len(), text:len())
				local isMultine = lastChar == "|"
				return keywordName, isMultine
			end
		end
	end
	return false
end

--[[--
	@function isBlockCommentTrigger
	@summary Seeks for a string combo to trigger handle search
	@parameter inputText string *The line to test
	@return hit boolean *Returns true when the special string combo is found
	@description |
	Tests for the presence of the string combo "---" triple hyphen.
	when found returns true or false otherwise.
	@scope internal
]]
local function isBlockCommentTrigger(inputText)
	local text = inputText
	local pattern = triggers.start
	local hit = false
	assert(
		type(inputText) == "string",
		"Cannot process if is the start of a block comment since inputText is not a string type"
		.."\nReceived type: " .. type(inputText)
		)
	hit = type(text:match(pattern)) == "string"
	--print("isBlock", hit, text)
	return hit
end

--[[--
	@function isSingleLineCommentTrigger
	@summary Seeks for a string combo to trigger handle search
	@parameter inputText string *The line to test
	@return hit boolean *Returns true when the special string combo is found
	@description |
	Tests for the presence of the string combo "- - [ [ - -" double hyphen then
	double square brackets then double hyphen again.
	when found returns true or false otherwise.
	@scope internal
]]
local function isSingleLineCommentTrigger(inputText)
	local text = inputText or ""
	local pattern = triggers.single
	local hit = false
	assert(
		type(inputText) == "string",
		"Cannot process if is the start of a single line comment since inputText is not a string type"
		.."\nReceived type: " .. type(inputText)
		)
	hit = type(text:match(pattern)) == "string" and (not type(text:match(triggers.single)))
	--print("isSingle", hit, text)
	return hit
end

--[[--
	@function isBlockCommentFinish
	@summary Seeks for a string combo to end handle search
	@parameter inputText string *The line to test
	@return hit boolean *Returns true when the special string combo is found
	@description |
	Tests for the presence of the string combo "] ]" double square brackets
	on [inputText].
	when found returns true or false otherwise.
	@scope internal
]]
local function isBlockCommentFinish(inputText)
	local text = inputText or ""
	local pattern = triggers.finish
	local hit = false
	assert(
		type(inputText) == "string",
		"Cannot process if is the start of a single line comment since inputText is not a string type"
		.."\nReceived type: " .. type(inputText)
		)
	hit = type(text:match(pattern)) == "string"
	--print("isFinish", hit, text)
	return hit
end

--[[--
	@function updateParameters
	@summary inserts new parameters and updates old ones
	@parameter inputKeyword string *Determines the behavior
	@parameter inputValue string *Determines the data to store
	@parameter funcKeyword string *Especial keyword case
	@parameter modKeyword string *Especial keyword case
	@scope internal
	@description |
	Looks for where to input certain fields and updates (concatenates) existing ones
]]
local function updateParameters(inputKeyword, inputValue, funcKeyword, modKeyword)
	--Clean the input
	if inputValue:sub(inputValue:len(), inputValue:len()) == "|" then
		inputValue = inputValue:sub(1, inputValue:len() - 1)
	end
	if inputValue:sub(1,1) == "\t" then
		inputValue = inputValue:sub(2, inputValue:len())
	end

	--Insert the input
	if lastKeywordFlushTrigger == funcKeyword and (inputKeyword ~= funcKeyword) then
		--print("current function."..inputKeyword)
		--print(documentationStack.temporal.func[inputKeyword])
		documentationStack.temporal.func[inputKeyword] = (documentationStack.temporal.func[inputKeyword] or "").. " " .. inputValue
	elseif lastKeywordFlushTrigger == modKeyword and (inputKeyword ~= modKeyword) then
		--print("current module."..inputKeyword)
		--print(documentationStack.temporal.module[inputKeyword])
		documentationStack.temporal.module[inputKeyword] = (documentationStack.temporal.module[inputKeyword] or "").. " " .. inputValue
	end
end

--[[--
	@function keywordPush
	@summary Handles the presence of keywords in the string
	@parameter inputKeyword string *Determines the behavior
	@parameter inputValue string *Determines the data to store
	@scope internal
	@description |
	This function has different behaviors based in [inputKeyword]
	When [inputKeyword] is a function flushes all other parameters and starts
	clean this is why is so important to declare function at the start of
	the comment since it flags a push operation, same behavior with module
	but it pushes all declared functions as well.
]]
local function keywordPush(inputKeyword, inputValue)
	local funcKeyword = "func"
	local funcListeners = {
		"parameter", "summary", "description", "usage",
		"ret", "scope", "example",
	}

	local modKeyword = "module"
	local modListeners = {
		"release", "author", "copyright", "url", "usage",
		"version",
	}

	--print("keyword push:", inputKeyword:sub(1,6), inputValue:sub(1, 80))

	--Flush & Push operations:
	if inputKeyword == funcKeyword then
		lastKeywordFlushTrigger = funcKeyword
		if documentationStack.temporal.func.name then
			--print("flushing last function", documentationStack.temporal.func.name)
			table.insert(documentationStack.funcs, documentationStack.temporal.func)
			documentationStack.temporal.func = {}
			--print("and creating a new one", inputValue)
			documentationStack.temporal.func.name = inputValue
		else
			--print("first function declared!!", inputValue:gsub("%s", ""))
			local name, _ = inputValue:gsub("%s", "")
			documentationStack.temporal.func["name"] = name
		end
	elseif inputKeyword == "module" then
		lastKeywordFlushTrigger = "module"
		if documentationStack.temporal.module.name then
			documentationStack.modules.funcs = documentationStack.funcs
			if documentationStack.temporal.func.name then
				table.insert(documentationStack.modules.funcs, documentationStack.temporal.func)
			end
			documentationStack.funcs = {}
			table.insert(documentationStack.modules, documentationStack.temporal.module)
			documentationStack.temporal.module = {}
			documentationStack.temporal.module.funcs = {}
		else
			--print("first module declared!!", inputValue)
			documentationStack.temporal.module.name = inputValue
		end
	end

	--Based in the latest flush operation
	--Change the behavior accordingly to listen to only
	--relevant keywords
	updateParameters(inputKeyword, inputValue, funcKeyword, modKeyword)
end


--[[--
	@function forceFlush
	@scope internal
	@summary flushes any temporal data
	@description |
	Searches for any temporal stored data and flushes immediately
	said cached data for further use, this is done automatically internally.
]]
local function forceFlush()
	--Flush any temporal declared function to the the functions table
	if documentationStack.temporal.func.name then
		table.insert(documentationStack.funcs, documentationStack.temporal.func)
		documentationStack.temporal.func = {}
	end

	--Flush any temporal module
	if documentationStack.temporal.module.name then
		documentationStack.temporal.module.funcs = documentationStack.funcs
		documentationStack.funcs = {}

	end
end

--[[--
	@function doctor.processString
	@summary Ingests a string for processing
	@parameter inputText string *The string to get processed
	@description |
	Receives a string on [inputText] and process it to create a structure
	Based on the special comments scattered on the file.
	@scope public
]]
function doctor.processString(inputText)
	local text = inputText or ""
	local textArray = totable(text.."\n")
	local onComment = false
	local singleLineComment = true
	local keyword, isMultine = false, false
	local rawKeyword = ""

	-- print("keywd", "mulln", "k", "m", "index")
	for i,v in ipairs(textArray) do
		if isBlockCommentTrigger(v) then onComment = true;singleLineComment = false;end
		if isSingleLineCommentTrigger(v) and (not onComment) then onComment = true;singleLineComment = true;end

		if onComment then
			local k, m = getLineType(v, i)
			if not k then
				if isMultine then
				end
			else
				keyword = k
				rawKeyword = tostring(v):match("%@%w+"):gsub("@", "")
				isMultine = m
			end
			-- print(
			-- 	tostring(keyword):sub(1,5),
			-- 	tostring(isMultine):sub(1,5),
			-- 	tostring(k):sub(1,5),
			-- 	tostring(m):sub(1,5),
			-- 	tostring(i):sub(1,5),
			-- 	rawKeyword:sub(1,5),
			-- 	tostring(v):gsub("%@%w+% ", "")--,
			-- 	--tostring(v)
			-- 	)

		end

		if singleLineComment then onComment = false; keyword = false end
		if isBlockCommentFinish(v) then onComment = false; keyword = false end

		if onComment and keyword then
			keywordPush(keyword, v:gsub("%@%w+% ", ""))
		end
	end
	forceFlush()

	print(json.encode(documentationStack))
end


return doctor