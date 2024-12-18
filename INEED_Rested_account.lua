-- INEED_Rested_account.lua
_, INEED = ...

function INEED.SaveAccount()
	Rested.me.account = math.floor(INEED_account.balance or 0)
end

function INEED.RestedAccountReport( realm, name, charStruct )
	local rn = Rested.FormatName( realm, name )

	local c = math.floor(charStruct.account or 0)
	Rested.accountMax = math.max( Rested.accountMax or 1, c )

	g, s, c = Rested.GoldSilverCopperFromCopper( charStruct.account or 0 )
	Rested.strOut = string.format( "%sg %ss %sc :: %s",
		g, s, c, rn )
	table.insert( Rested.charList, { ( ( charStruct.account and charStruct.account or 0) / Rested.accountMax ) * 150, Rested.strOut } )
	return 1
end

if Rested then
	Rested.EventCallback( "PLAYER_MONEY", INEED.SaveAccount )
	Rested.EventCallback( "PLAYER_ENTERING_WORLD", INEED.SaveAccount )

	Rested.dropDownMenuTable["INEED Account"] = "account"
	Rested.commandList["account"] = {["help"] = {"","INeed Account"}, ["func"] = function()
			Rested.reportName = "INEED Account"
			Rested.UIShowReport( INEED.RestedAccountReport )
		end
	}
end
