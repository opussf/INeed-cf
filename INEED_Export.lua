#!/usr/bin/env lua

dataFile = arg[1]
exportType = arg[2]

function FileExists( name )
   local f = io.open( name, "r" )
   if f then io.close( f ) return true else return false end
end
function DoFile( filename )
	local f = assert( loadfile( filename ) )
	return f()
end
function GetFormattedDate( TS )
	dateFormat = "%Y-%m-%dT%H:%M:%S"
	return os.date( dateFormat, TS )
end

function ExportXML()
	strOut = "<?xml version='1.0' encoding='utf-8' ?>\n"
	strOut = strOut .. "<ineed>\n"

	for itemID, ineedStruct in pairs( INEED_data ) do
		strOut = strOut .. string.format( '<item id="%s">\n', itemID )

		for realm, realmStruct in pairs( ineedStruct ) do
			for playerName, playerStruct in pairs( realmStruct ) do

				strOut = strOut .. string.format( '\t<player realm="%s" name="%s" faction="%s" has="%s" needs="%s" added="%s" addedTS="%s" updated="%s" updatedTS="%s" />\n',
						realm, playerName, playerStruct.faction, playerStruct.total + (playerStruct.inMail or 0), playerStruct.needed,
						GetFormattedDate(playerStruct.added), playerStruct.added,
						(playerStruct.updated and GetFormattedDate(playerStruct.updated) or ''), playerStruct.updated or '' )
				itemLink = ( playerStruct.link or (itemLink or nil) ) -- set to link if given, or set to itemLink if not nil, or set to nil
			end
		end
		itemName = string.match(itemLink, "%[(.*)%]")

		strOut = strOut .. string.format( '\t<itemLink><![CDATA[%s]]></itemLink>\n', (itemLink or '') )
		strOut = strOut .. string.format( '\t<itemName><![CDATA[%s]]></itemName>\n', (itemName or '') )
		strOut = strOut .. "</item>\n"
	end

	strOut = strOut .. "</ineed>"
	return strOut

end
function ExportJSON()
	strOut = '{"INEED": [\n'
	itemList = {}
	for itemID, ineedStruct in pairs( INEED_data ) do
		itemStr = string.format( '\t{"id": %s, "players": ', itemID )
		playerList = {}
		for realm, realmStruct in pairs( ineedStruct ) do
			for playerName, playerStruct in pairs( realmStruct ) do
				table.insert( playerList, string.format( '{"name": "%s", "realm": "%s", "faction": "%s", "has": %s, "needs": %s, "added": "%s", "addedTS": %s, "updated": "%s", "updatedTS": %s}',
						playerName, realm, playerStruct.faction, playerStruct.total + (playerStruct.inMail or 0), playerStruct.needed,
						os.date("%Y-%m-%dT%H:%M:%S", playerStruct.added), playerStruct.added,
						(playerStruct.updated and os.date("%Y-%m-%dT%H:%M:%S", playerStruct.updated) or ''), playerStruct.updated or '' ) )
				itemLink = ( playerStruct.link or (itemLink or nil) )
				itemLink = string.gsub( itemLink, "([\"])", "\\\"" )
			end
		end
		itemName = string.match( itemLink, "%[(.*)%]" )

		-- add players:
		itemStr = itemStr .. '['.. table.concat( playerList, ", " ) .."], "

		-- add item metadata
		itemStr = itemStr .. string.format( '"itemLink": "%s", "itemName": "%s" }', (itemLink or ''), (itemName or '') )

		table.insert( itemList, itemStr )
	end
	strOut = strOut .. table.concat( itemList, ",\n " ).."\n]}\n"

	return strOut
end

functionList = {
	["xml"] = ExportXML,
	["json"] = ExportJSON,
}

func = functionList[string.lower( exportType )]

if dataFile and FileExists( dataFile ) and exportType and func then
	DoFile( dataFile )
	strOut = func()
	print( strOut )
else
	io.stderr:write( "Something is wrong.  Lets review:\n" )
	io.stderr:write( "Data file provided: "..( dataFile and " True" or "False" ).."\n" )
	io.stderr:write( "Data file exists  : "..( FileExists( dataFile ) and " True" or "False" ).."\n" )
	io.stderr:write( "ExportType given  : "..( exportType and " True" or "False" ).."\n" )
	io.stderr:write( "ExportType valid  : "..( func and " True" or "False" ).."\n" )
end

