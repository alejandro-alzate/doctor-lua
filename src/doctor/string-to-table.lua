local function strToTbl(string)
	local returnTable = {}
	local line = ''
	if type(string) ~= 'string' then
		return returnTable
	end
	for i=1, string:len() do
		if string:sub(i,i) == '\n' then
			table.insert(returnTable, line)
			line = ''
		end
		line = line .. string:sub(i,i):gsub('\n', '')
	end
	return returnTable
end
return strToTbl