--[[
	Test.lua tests itself to see
	if the doctor is high.
	Have you ever seen recursive code?
	This one calls itself to get checked.
]]

--Now for the meat and potatoes let's test anyhting of the real world
--[[--
	gfxTables
	@module gfxTables
	@release 0.0.0
	@author Alejandro Alzate Sánchez
	@copyright Copyright (c) 2024 alejandro-alzate
	@summary gfxTables.lua |
	gfxTables.lua is a tool that will help you to print pretty Tables to the terminal!
	Have you ever been jealous of how pretty SQL consoles prints?
	Here gfxTables to help you! it has a simple interface where you can create beautiful
	console crafts with it.
]]


--[[--
	@function newTable
	@summary Create a new object
	@param style string How pretty it looks, Tells what type of characters should use for decoration
	@param showEnumerator boolean Tells if a index row in the left should be placed starting from 1 to n entries
	@param separateEntries boolean Sets if the entries has to be shown compact or separated
	@param default * What to fill when an entry is nil
	@usage local newTableObject = gfxTables.newTable("advanced", true)
	@return gfxTable table a new gfxTable Object used to poke at it
!]]

--- Now it will parse the library itself
local doctor = require("init")
local readfile = require("read-file")
local testString = readfile("test.lua")
local doctorString = readfile("init.lua")
--doctor.processString(testString)
doctor.processString(doctorString)