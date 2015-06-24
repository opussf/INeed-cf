INEED_MSG_ADDONNAME = "INeed";
INEED_MSG_VERSION   = GetAddOnMetadata(INEED_MSG_ADDONNAME,"Version");
INEED_MSG_AUTHOR    = "opussf";

-- Colours
COLOR_RED = "|cffff0000";
COLOR_GREEN = "|cff00ff00";
COLOR_BLUE = "|cff0000ff";
COLOR_PURPLE = "|cff700090";
COLOR_YELLOW = "|cffffff00";
COLOR_ORANGE = "|cffff6d00";
COLOR_GREY = "|cff808080";
COLOR_GOLD = "|cffcfb52b";
COLOR_NEON_BLUE = "|cff4d4dff";
COLOR_END = "|r";

INEED = {}
INEED_data = {}
INEED_currency = {}
INEED_account = {}
INEED_unknown = {}

INEED.bindTypes = {
	[ITEM_SOULBOUND] = "Bound",
	[ITEM_BIND_ON_PICKUP] = "Bound",
}
INEED.scanTip = CreateFrame( "GameTooltip", "INEEDTip", UIParent, "GameTooltipTemplate" )
INEED.scanTip2 = _G["INEEDTipTextLeft2"]
INEED.scanTip3 = _G["INEEDTipTextLeft3"]
INEED.scanTip4 = _G["INEEDTipTextLeft4"]

function INEED.Print( msg, showName)
	-- print to the chat frame
	-- set showName to false to suppress the addon name printing
	if (showName == nil) or (showName) then
		msg = COLOR_PURPLE..INEED_MSG_ADDONNAME.."> "..COLOR_END..msg
	end
	DEFAULT_CHAT_FRAME:AddMessage( msg )
end
function INEED.OnLoad()
	SLASH_INEED1 = "/IN"
	SLASH_INEED2 = "/INEED"
	SlashCmdList["INEED"] = function(msg) INEED.command(msg); end

	INEED_Frame:RegisterEvent("ADDON_LOADED")
	INEED_Frame:RegisterEvent("BAG_UPDATE")
	INEED_Frame:RegisterEvent("MERCHANT_SHOW")
	INEED_Frame:RegisterEvent("MAIL_SHOW")
	INEED_Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	INEED_Frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
	-- Mail Events
	INEED_Frame:RegisterEvent("MAIL_SEND_INFO_UPDATE")
	INEED_Frame:RegisterEvent("MAIL_SEND_SUCCESS")
	INEED_Frame:RegisterEvent("MAIL_CLOSED")
	INEED_Frame:RegisterEvent("MAIL_INBOX_UPDATE")
	-- Tradeskill Events
	INEED_Frame:RegisterEvent("TRADE_SKILL_SHOW")
	INEED_Frame:RegisterEvent("TRADE_SKILL_CLOSE")
	INEED_Frame:RegisterEvent("TRADE_SKILL_UPDATE")
	-- ^^^ Fired immediately after TRADE_SKILL_SHOW, after something is created via tradeskill, or anytime the tradeskill window is updated (filtered, tree folded/unfolded, etc.)
end
function INEED.TRADE_SKILL_SHOW()
	INEED.Print("TradeSkill window opened.")
	for index = 1,GetNumTradeSkills() do
		if select( 2, GetTradeSkillInfo( index ) ) ~= "header" then
			local itemLink = GetTradeSkillItemLink( index )
			local itemID = INEED.getItemIdFromLink( itemLink )
			if INEED_data[itemID] and INEED_data[itemID][INEED.realm] then
				local names = {}
				local printItem = nil -- set to true if someone is actually found that has an outstanding need
				for name, data in pairs( INEED_data[itemID][INEED.realm] ) do
					if (data.faction == INEED.faction) and (data.needed - data.total - ( data.inMail or 0 ) > 0) then
						-- same faction, and not fulfilled via mail already
						tinsert( names, name )
						printItem = true -- set the flag on to print
					end
				end
				local _ = printItem and INEED.Print( itemLink.." is needed by: "..table.concat( names, ", " ) )
			end
		end
	end
end
function INEED.TRADE_SKILL_CLOSE()
end
function INEED.TRADE_SKILL_UPDATE()
end
function INEED.MAIL_SEND_INFO_UPDATE()
	INEED.mailInfo = {}
	INEED.mailInfo.mailTo = SendMailNameEditBox:GetText()
	INEED.mailInfo.items = {}

	for slot = 1, ATTACHMENTS_MAX_SEND do
		local link = GetSendMailItemLink( slot )
		if link then
			local itemID = INEED.getItemIdFromLink( link )
			local quantity = select( 3, GetSendMailItem( slot ) )
			INEED.mailInfo.items[itemID] = (INEED.mailInfo.items[itemID] and
					(INEED.mailInfo.items[itemID] + quantity) or
					quantity)
		end
	end
end
--[[  This code could be used to populate out going emails
	for i in pairs( INEED_data ) do
		--INEED.Print("item:"..i.." for "..(INEED.mailInfo.mailTo or 'nil').."-"..INEED.realm)
		if INEED_data[i][INEED.realm] and INEED_data[i][INEED.realm][INEED.mailInfo.mailTo] then  -- has record
			local theirRecord = INEED_data[i][INEED.realm][INEED.mailInfo.mailTo]
			local theyHave = (theirRecord.inMail or 0) + theirRecord.total
			INEED.Print( "   They have: "..theyHave )
			if (theirRecord.needed > theyHave) -- still need
					and (theirRecord.faction == INEED.faction) -- same faction
					and (GetItemCount( i, false ) > 0) then -- you have in bags
				INEED.Print( "   I have: "..GetItemCount( i, false ))
				INEED.Print( "I would use "..select( 2, GetItemInfo( i ) ) )
			end
		end
	end
end
]]
function INEED.MAIL_SEND_SUCCESS()
	--INEED.Print("Send mail SUCCESS")
	if INEED.mailInfo then
		local sendto, realm = strmatch( INEED.mailInfo.mailTo, "^(.*)-(.*)$" )
		sendto = sendto or INEED.mailInfo.mailTo
		realm = realm or INEED.realm
		--INEED.Print("Sent to: "..sendto.."--"..realm)
		for i, q in pairs(INEED.mailInfo.items) do
			if INEED_data[i] and INEED_data[i][realm] and INEED_data[i][realm][sendto] then
				INEED_data[i][realm][sendto].inMail =
						(INEED_data[i][realm][sendto].inMail and
						(INEED_data[i][realm][sendto].inMail + q) or q)
				--INEED.Print(i..":"..q)
			end
		end
	end
	INEED.makeOthersNeed()
end
function INEED.MAIL_CLOSED()
	--INEED.Print("Mail Frame CLOSED")
	INEED.mailInfo = nil
end
function INEED.MAIL_INBOX_UPDATE()
	INEED.inboxInventory = {}
	--INEED.Print("You have "..GetInboxNumItems().." messages.")
	for mailID = 1, GetInboxNumItems() do
		local itemCount = select( 8, GetInboxHeaderInfo( mailID ) )
		if itemCount then
			for itemIndex = 1, itemCount do
				local itemID = INEED.getItemIdFromLink( GetInboxItemLink( mailID, itemIndex ) )
				local q = select( 3, GetInboxItem( mailID, itemIndex ) )
				if itemID then
					INEED.inboxInventory[itemID] =
							(INEED.inboxInventory[itemID] and
							(INEED.inboxInventory[itemID] + q) or q )
				end
			end
		end
	end
	-- find all items that you need, and set or remove the inMail attribute
	for itemID in pairs(INEED_data) do
		for realm in pairs(INEED_data[itemID]) do
			for name in pairs(INEED_data[itemID][realm]) do -- name
				if (INEED.realm == realm and INEED.name == name ) then
					INEED_data[itemID][realm][name].inMail = INEED.inboxInventory[itemID]
					--INEED.Print("Set "..itemID.." inMail to "..(INEED.inboxInventory[itemID] or "nil"))
				end
			end
		end
	end
end
--------------
function INEED.ADDON_LOADED()
	-- Unregister the event for this method.
	INEED_Frame:UnregisterEvent("ADDON_LOADED")

	-- Setup needed variables
	INEED.name = UnitName("player")
	INEED.realm = GetRealmName()
	INEED.faction = UnitFactionGroup("player")

	-- Setup game settings
	GameTooltip:HookScript("OnTooltipSetItem", INEED.hookSetItem)
	ItemRefTooltip:HookScript("OnTooltipSetItem", INEED.hookSetItem)
	--INEED.Orig_GameTooltip_SetCurrencyToken = GameTooltip.SetCurrencyToken  -- lifted from Altaholic (thanks guys)
	--GameTooltip.SetCurrencyToken = INEED.hookSetCurrencyToken

	-- Load Options panel
	INEED.OptionsPanel_Reset()

	INEED.Print("Loaded")
end
function INEED.MAIL_SHOW()
	INEED.Print("Others on this server need:")
	INEED.showFulfillList()
end
function INEED.PLAYER_ENTERING_WORLD() -- Variables should be loaded here
	--INEED_Frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
	INEED_Frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
	-- Build data structure to track what other players need.
	INEED.makeOthersNeed()

	--INEED.test()
end
function INEED.BAG_UPDATE()
	local itemFulfilled = false   -- has an item been fulfilled yet?
	for itemID, _ in pairs(INEED_data) do  -- loop over the stored data structure
		local iHaveNum = GetItemCount( itemID, true ) -- include bank
		local _, itemLink = GetItemInfo( itemID )
		if itemLink and INEED_data[itemID][INEED.realm] and INEED_data[itemID][INEED.realm][INEED.name] then
			INEED_data[itemID][INEED.realm][INEED.name].faction = INEED.faction -- force update incase faction is changed
			--INEED.("I have a record for item "..itemLink)
			local gained = iHaveNum - INEED_data[itemID][INEED.realm][INEED.name].total
			if INEED_data[itemID][INEED.realm][INEED.name].total ~= iHaveNum then
				--INEED.Print("Recorded does not equal what I have")
				INEED_data[itemID][INEED.realm][INEED.name].updated = time()
				INEED_data[itemID][INEED.realm][INEED.name]['total'] = iHaveNum
				if INEED_options.showProgress or INEED_options.printProgress then
					local progressString = string.format("%i/%i %s%s",
							iHaveNum, INEED_data[itemID][INEED.realm][INEED.name].needed,
								(INEED_options.includeChange
									and string.format("(%s%+i%s) ", ((gained > 0) and COLOR_GREEN or COLOR_RED), gained, COLOR_END)
									or ""),
							itemLink)
					if INEED_options.showProgress then
						UIErrorsFrame:AddMessage( progressString, 1.0, 1.0, 0.1, 1.0 )
					end
					if INEED_options.printProgress and
							(INEED_data[itemID][INEED.realm][INEED.name].total < INEED_data[itemID][INEED.realm][INEED.name].needed ) then
						INEED.Print( progressString )
					end
				end
			end
			-- Success!
			if INEED_data[itemID][INEED.realm][INEED.name].total >=
			   INEED_data[itemID][INEED.realm][INEED.name].needed then
			   	-- Clear the need entry
				--INEED.Print( "You now have the number of "..itemLink.." that you needed." )
				if INEED_options.showSuccess then
					INEED.showSplash( string.format("%i/%i %s", iHaveNum,
							INEED_data[itemID][INEED.realm][INEED.name].needed, itemLink) )
				end
				if INEED_options.printSuccess then
					INEED.Print( string.format( "Reached goal of %i of %s", INEED_data[itemID][INEED.realm][INEED.name].needed,
							itemLink ) )
				end
				INEED_data[itemID][INEED.realm][INEED.name] = nil
				INEED.clearData()
				itemFulfilled = true
			end
		elseif itemLink and INEED.othersNeed
						and INEED.othersNeed[itemID]
						and INEED.othersNeed[itemID][INEED.realm]
						and INEED.othersNeed[itemID][INEED.realm][INEED.faction] then
			-- valid item, and it is needed by someone (if it got here, it is not needed by current player - anymore )

			local gained = iHaveNum - INEED.othersNeed[itemID][INEED.realm][INEED.faction].mine
			if gained ~= 0 then
				INEED.othersNeed[itemID][INEED.realm][INEED.faction].mine = iHaveNum
				if INEED_options.showGlobal or INEED_options.printProgress then
					local progressString = string.format("-=%i/%i %s%s=-",
							(INEED.othersNeed[itemID][INEED.realm][INEED.faction].total
								+ (INEED.othersNeed[itemID][INEED.realm][INEED.faction].inMail and INEED.othersNeed[itemID][INEED.realm][INEED.faction].inMail or 0)
								+ iHaveNum),
							INEED.othersNeed[itemID][INEED.realm][INEED.faction].needed,
							(INEED_options.includeChange
								and string.format("(%s%+i%s) ", ((gained > 0) and COLOR_GREEN or COLOR_RED), gained, COLOR_END)
								or ""),
							itemLink)
					if INEED_options.showGlobal then
						UIErrorsFrame:AddMessage( progressString, 1.0, 1.0, 0.1, 1.0 )
					end
--					if INEED_options.printProgress and INEED_options.showGlobal and
--							(INEED_data[itemID][INEED.realm][INEED.name].total < INEED_data[itemID][INEED.realm][INEED.name].needed ) then
--						INEED.Print( progressString )
--					end

				end
			end
		end
	end

	if itemFulfilled then
		INEED.itemFulfilledAnnouce()
	end
end
INEED.UNIT_INVENTORY_CHANGED = INEED.BAG_UPDATE
function INEED.CURRENCY_DISPLAY_UPDATE()
	--INEED.Print("CURRENCY_DISPLAY_UPDATE")
	local itemFulfilled = false
	for currencyID, cData in pairs( INEED_currency ) do
		--local curName, curAmount, _, earnedThisWeek, weeklyMax, totalMax, isDiscovered = GetCurrencyInfo( currencyID )
		local iHaveNum = select( 2, GetCurrencyInfo( currencyID ) )
		local currencyLink = GetCurrencyLink( currencyID )
		local gained = iHaveNum - cData.total
		if cData.total ~= iHaveNum then
			local progressString = string.format("%i/%i %s%s",  -- Build the progress string
					iHaveNum, cData.needed,
					(INEED_options.includeChange
						and string.format("(%s%+i%s) ", ((gained > 0) and COLOR_GREEN or COLOR_RED), gained, COLOR_END)
						or ""),
					currencyLink)
			_ = INEED_options.showProgress and UIErrorsFrame:AddMessage( progressString )
			_ = INEED_options.printProgress and INEED.Print( progressString )
			INEED_currency[currencyID]['total'] = iHaveNum
			INEED_currency[currencyID]['updated'] = time()
		end
		-- Success!
		if cData.total >= cData.needed then
			-- Clear the currency Need entry
			if INEED_options.showSuccess then
				INEED.showSplash( string.format( "%i/%i %s", iHaveNum, cData.needed, currencyLink ) )
			end
			_ = INEED_options.printSuccess and INEED.Print( string.format( "Reached goal of %i of %s", cData.needed, currencyLink ) )

			INEED_currency[currencyID] = nil
			itemFulfilled = true
		end
	end
	if itemFulfilled then
		INEED.itemFulfilledAnnouce()
	end
end
function INEED.MERCHANT_SHOW()
	-- Event handler.  Autopurchase
	--local numItems = GetMerchantNumItems()
	local purchaseAmount = 0
	local msgSent = false
	for i = 0, GetMerchantNumItems() do
		local itemID = INEED.getItemIdFromLink( GetMerchantItemLink( i ) )
		if INEED_data[itemID] and
				INEED_data[itemID][INEED.realm] and
				INEED_data[itemID][INEED.realm][INEED.name] then
			-- itemCount = GetMerchantItemCostInfo(index)
			-- texture, value, link = GetMerchantItemCostItem(index, currency)
			local currencyCount = GetMerchantItemCostInfo( i )  -- 0 if just gold.

			local itemName, _, price, quantity, _, isUsable = GetMerchantItemInfo( i )
			local maxStackPurchase = GetMerchantItemMaxStack( i )
			local itemT = INEED_data[itemID][INEED.realm][INEED.name]
			local neededQuantity = itemT.needed - itemT.total
			if not msgSent then INEED.Print("This merchant sells items that you need"); msgSent=true; end
			if isUsable and INEED_account.balance and currencyCount == 0 then  -- I have money to spend, and not a special currency
				-- How many can I afford at this price.
				local canAffordQuantity = math.floor(((INEED_account.balance or 0) * quantity) / price)
				-- INEED.Print("I have "..GetCoinTextureString( INEED_account.balance or 0).." to spend")
				-- INEED.Print("I can afford "..canAffordQuantity.." items")
				local purchaseQuantity = math.min( canAffordQuantity, neededQuantity )
				INEED.Print(purchaseQuantity.." "..itemName.." @"..GetCoinTextureString( price / quantity ))

				local bought = 0
				for lcv = 1, math.ceil(purchaseQuantity / maxStackPurchase), 1 do
					local buyAmount = math.min(maxStackPurchase, purchaseQuantity - bought)
					BuyMerchantItem( i, buyAmount )
					bought = bought + buyAmount
				end

				local itemPurchaseAmount = ((purchaseQuantity/quantity) * price)
				purchaseAmount = purchaseAmount + itemPurchaseAmount
				INEED_account.balance = INEED_account.balance - itemPurchaseAmount
			end
		end
	end
	if purchaseAmount > 0 then
		INEED.Print("==========================")
		INEED.Print("Total:   "..GetCoinTextureString(purchaseAmount) )
		INEED.Print("Balance: "..GetCoinTextureString( INEED_account.balance or 0 ) )
	end
	--[[
	GetMerchantItemLink(index) - Returns an itemLink for the given purchasable item
	numItems = GetMerchantNumItems();
	name, texture, price, quantity, numAvailable, isUsable, extendedCost = GetMerchantItemInfo(index)
	BuyMerchantItem(index {, quantity});
	]]--
end
function INEED.OnUpdate()
end
-- Non Event functions
function INEED.makeOthersNeed()
	-- This parses the saved data to determine what other players need.
	-- Call this at ADDON_LOADED and probably MAIL_SEND_SUCCESS?
	--INEED.Print("-=-=-=-=-  makeOthersNeed  -=-=-=-=-=-")
	INEED.othersNeed = { }
	for itemID, _ in pairs(INEED_data) do  -- loop over the stored data structure
		local iHaveNum = GetItemCount( itemID, true ) or 0 -- include bank
		INEED.othersNeed[itemID] = {}
		for realm, _ in pairs( INEED_data[itemID] ) do
			INEED.othersNeed[itemID][realm] = {}
			for name, data in pairs( INEED_data[itemID][realm] ) do
				local faction = INEED_data[itemID][realm][name].faction or ""
				if data.faction and not ((realm == INEED.realm) and (name == INEED.name)) then
					INEED.othersNeed[itemID][realm][data.faction] =
							(INEED.othersNeed[itemID][realm][data.faction] and INEED.othersNeed[itemID][realm][data.faction]
							or { ['needed'] = 0, ['total'] = 0, ['mine'] = iHaveNum })
					INEED.othersNeed[itemID][realm][data.faction].needed =
							INEED.othersNeed[itemID][realm][data.faction].needed + data.needed
					INEED.othersNeed[itemID][realm][data.faction].total =
							INEED.othersNeed[itemID][realm][data.faction].total + data.total + (data.inMail and data.inMail or 0)
				end
			end
		end
	end
end
function INEED.itemFulfilledAnnouce()
	if INEED_options.audibleSuccess then
		if INEED_options.doEmote and INEED_options.emote then
			DoEmote( INEED_options.emote )
		end
		if INEED_options.playSoundFile and INEED_options.soundFile then
			PlaySoundFile( INEED_options.soundFile )
		end
	end
end
function INEED.showSplash( msg )
	-- Show the 'success' messages in the middle splash
	INEED_SplashFrame:Show()
	INEED_SplashFrame:AddMessage( msg, 1, 1, 1 )
end
function INEED.clearData()
	-- this function will look for 'empty' realms and items and clear them
	for itemID in pairs(INEED_data) do
		local realmCount = 0
		for realm in pairs(INEED_data[itemID]) do
			local charCount = 0
			realmCount = realmCount + 1
			for _ in pairs(INEED_data[itemID][realm]) do -- name
				charCount = charCount + 1
			end
			if charCount == 0 then
				INEED_data[itemID][realm] = nil
				realmCount = realmCount - 1
			end
		end
		if realmCount == 0 then
			INEED_data[itemID] = nil
		end
	end
end
function INEED.hookSetItem(tooltip, ...)  -- is passed the tooltip frame as a table
	local item, link = tooltip:GetItem()  -- name, link
	local itemID = INEED.getItemIdFromLink( link )

--[[
	local tooltipName = tooltip:GetName()
	local tooltipLine2 = _G[tooltipName.."TextLeft2"]
	local tooltipLine3 = _G[tooltipName.."TextLeft3"]
	local tooltipLine4 = _G[tooltipName.."TextLeft4"]
	local BindTypes = {
		[ITEM_SOULBOUND] = "Bound",
		[ITEM_BIND_ON_PICKUP] = "Bound",
	}


	INEED.Print( "tooltip:name = "..( tooltipName or "unknown" ).." "..
			( ( BindTypes[tooltipLine2:GetText()] or BindTypes[tooltipLine3:GetText()] or BindTypes[tooltipLine4:GetText()] ) and "isBound" or "isNotBound" ) )
]]
	-- local ScanTip2 = _G["AppraiserTipTextLeft2"]
	--.." "..ITEM_SOULBOUND.." "..ITEM_BIND_ON_PICKUP )
	-- INEED.Print("item: "..(item or "nil").." ID: "..itemID)

	if itemID and INEED_data[itemID] then
		for realm in pairs(INEED_data[itemID]) do
			if realm == INEED.realm then
				for name, data in pairs(INEED_data[itemID][realm]) do
					tooltip:AddDoubleLine(string.format("%s", name),
							string.format("Needs: %i / %i", data.total + (data.inMail or 0), data.needed) )
				end
			end
		end
	end
end
--[[ Figure out how to do this later.
function INEED.hookSetCurrencyToken(tooltip, index, ...)
	INEED.Orig_GameTooltip_SetCurrencyToken( tooltip, index, ... )
	if not index then return end
	local currency, _, _, _, _, ec, _, _, currencyID = GetCurrencyListInfo( index )
	local a,        b, c, d, e, f,  g, h, i = GetCurrencyListInfo( index )
	INEED.Print("a:"..a)
	INEED.Print("b:"..(b and "true" or "false"))
	INEED.Print("c:"..(c and "true" or "false"))
	INEED.Print("d:"..(d and "true" or "false"))
	INEED.Print("e:"..(e and "true" or "false"))
	INEED.Print("f:"..f)
	INEED.Print("g:"..g)
	INEED.Print("h:"..h)
	INEED.Print("i:"..(i or "nil"))
end
]]--
function INEED.parseCmd(msg)
	if msg then
		local i,c = strmatch(msg, "^(|c.*|r)%s*(%d*)$")
		if i then  -- i is an item, c is a count or nil
			return i, c
		else  -- Not a valid item link
			msg = string.lower(msg)
			local a,b,c = strfind(msg, "(%S+)")  --contiguous string of non-space characters
			if a then
				-- c is the matched string, strsub is everything after that, skipping the space
				return c, strsub(msg, b+2)
			else
				return ""
			end
		end
	end
end
function INEED.addItem( itemLink, quantity )
	-- returns itemLink of what was added
	quantity = quantity or 1
	local itemID = INEED.getItemIdFromLink( itemLink )
	if itemID then
		local youHave =  GetItemCount( itemID, true ) -- include bank
		local inBags = GetItemCount( itemID, false ) -- only in bags
		if quantity > 0 then
			local linkString = select( 2, GetItemInfo( itemID ) ) or "item:"..itemID
			if quantity > youHave then
				INEED.Print( string.format( "Needing: %i/%i %s (item:%s Bags: %i Bank: %i)",
						youHave, quantity, linkString, itemID, inBags, youHave-inBags ) )
				INEED_data[itemID] = INEED_data[itemID] or {}
				INEED_data[itemID][INEED.realm] = INEED_data[itemID][INEED.realm] or {}
				INEED_data[itemID][INEED.realm][INEED.name] = INEED_data[itemID][INEED.realm][INEED.name] or {}

				--INEED_data[itemID] = INEED_data[itemID] or {[INEED.realm]={[INEED.name]={}}}
				INEED_data[itemID][INEED.realm][INEED.name]['link'] = linkString -- only for debuging
				INEED_data[itemID][INEED.realm][INEED.name]['needed'] = quantity
				INEED_data[itemID][INEED.realm][INEED.name]['total'] = youHave
				--INEED_data[itemID][INEED.realm][INEED.name]['total'] = 0  -- Force an update if you already have some
				INEED_data[itemID][INEED.realm][INEED.name]['added'] = INEED_data[itemID][INEED.realm][INEED.name]['added'] or time() -- only set if new
				INEED_data[itemID][INEED.realm][INEED.name]['updated'] = time() -- Allow persistent adding to update
				INEED_data[itemID][INEED.realm][INEED.name]['faction'] = INEED.faction
			else
				INEED.Print( string.format( COLOR_RED.."-------"..COLOR_END..": %i/%i %s (item:%s Bags: %i Bank: %i)",
						youHave, quantity, linkString, itemID, inBags, youHave-inBags ) )
			end
		elseif quantity == 0 then
			if INEED_data[itemID] and
					INEED_data[itemID][INEED.realm] and
					INEED_data[itemID][INEED.realm][INEED.name] then
				INEED.Print( string.format( "Removing %s from your need list", itemLink ) )
				INEED_data[itemID][INEED.realm][INEED.name] = nil
				INEED.clearData()
			end
		end
		return itemLink   -- return early
	end
	local enchantID = INEED.getEnchantIdFromLink( itemLink )
	if enchantID then
		INEED.Print( string.format( "You need: %i %s (enchant:%s)", quantity, itemLink, enchantID ) )
		local numSkills = GetNumTradeSkills()
		for index = 1, numSkills do  -- loop through the recepies
			local testEnchantID = INEED.getEnchantIdFromLink( GetTradeSkillRecipeLink( index ) )  -- enchantID
			if enchantID == testEnchantID then  -- linked enchant == enchant from list ?
				local ItemLink = GetTradeSkillItemLink( index )  -- add the item, there may be a bug here
				local minMade, maxMade =GetTradeSkillNumMade( index )
				INEED.addItem( ItemLink, minMade * quantity ) -- If a tradeskill makes more than one at a time.

				local numReagents = GetTradeSkillNumReagents( index )
				for reagentIndex = 1, numReagents do
					local _, _, reagentCount = GetTradeSkillReagentInfo( index, reagentIndex )
					local reagentLink = GetTradeSkillReagentItemLink( index, reagentIndex )
					INEED.addItem( reagentLink, reagentCount * quantity )
				end
			end
		end
		return itemLink -- return done
	end
	local currencyID = INEED.getCurrencyIdFromLink( itemLink )
	if currencyID then
		local curName, curAmount, _, earnedThisWeek, weeklyMax, totalMax, isDiscovered = GetCurrencyInfo( currencyID )
		quantity = (totalMax > 0 and quantity > totalMax) and totalMax or quantity
		local currencyLink = GetCurrencyLink( currencyID ) or ("currency:"..currencyID)
		--print("I need "..quantity.." of "..itemLink)
		if quantity > 0 then
			if quantity > curAmount then
				INEED.Print( string.format( "Needing: %i/%i %s (currency:%s)",
						curAmount, quantity, currencyLink, currencyID ) )
				INEED_currency[currencyID] = INEED_currency[currencyID] or {}
				INEED_currency[currencyID]['needed'] = quantity
				INEED_currency[currencyID]['total'] = curAmount
				INEED_currency[currencyID]['added'] = INEED_currency[currencyID]['added'] or time()
				INEED_currency[currencyID]['updated'] = time()
				INEED_currency[currencyID]['name'] = curName
			else
				--local currencyLink = GetCurrencyLink( currencyID )
				INEED.Print( string.format( COLOR_RED.."-------"..COLOR_END..": %s %i / %i",
						currencyLink, curAmount, quantity ) )

			end
		elseif quantity == 0 then
			if INEED_currency[currencyID] then
				INEED.Print( string.format( "Removing %s from your need list", currencyLink ) )
				INEED_currency[currencyID] = nil
			end
		end
		return itemLink -- return done
	end
	if itemLink then
		INEED.Print("Unknown link or command: "..string.sub(itemLink, 12))
		INEED_unknown[time()] = itemLink
		INEED.PrintHelp()
	end
end
function INEED.getItemIdFromLink( itemLink )
	-- returns just the integer itemID
	-- itemLink can be a full link, or just "item:999999999"
	if itemLink then
		return strmatch( itemLink, "item:(%d*)" )
	end
end
function INEED.getEnchantIdFromLink( enchantLink )
	-- returns just the integer enchantID
	-- enchantLink can be a full link, or just "enchant:999999999"
	if enchantLink then
		return strmatch( enchantLink, "enchant:(%d*)" )
	end
end
function INEED.getCurrencyIdFromLink( currencyLink )
	-- currency:402
	if currencyLink then
		return strmatch( currencyLink, "currency:(%d*)" )
	end
end
function INEED.command(msg)
	local cmd, param = INEED.parseCmd(msg);
	--INEED.Print("cl:"..cmd.." p:"..(param or "nil") )
	local cmdFunc = INEED.CommandList[cmd];
	if cmdFunc then
		cmdFunc.func(param);
	elseif ( cmd and cmd ~= "") then  -- exists and not empty
		--INEED.Print("cl:"..cmd.." p:"..(param or "nil"))
		--param, targetString = INEED.parseTarget( param )
		INEED.addItem( cmd, tonumber(param) )
		INEED.makeOthersNeed()
		--[[
		if targetString then
			INEED.addTarget( cmd, tonumber(param), targetString )
		end
		]]
		--InterfaceOptionsFrame_OpenToCategory(FB_MSG_ADDONNAME);
	else
		INEED.PrintHelp()
	end
end
function INEED.PrintHelp()
	INEED.Print(INEED_MSG_ADDONNAME.." ("..INEED_MSG_VERSION..") by "..INEED_MSG_AUTHOR);
	for cmd, info in pairs(INEED.CommandList) do
		INEED.Print(string.format("%s %s %s -> %s",
			SLASH_INEED1, cmd, info.help[1], info.help[2]));
	end
end
function INEED.showList( searchTerm )
	searchTerm = (searchTerm and string.len(searchTerm) ~= 0) and searchTerm or "me"    -- me | realm | all
	local showHeader = true
	local updatedItems = {}
	for itemID, _ in pairs(INEED_data) do
		for realm, _ in pairs(INEED_data[itemID]) do
			for name, data in pairs(INEED_data[itemID][realm]) do
				if ( searchTerm == "me" and name == INEED.name and realm == INEED.realm ) or
						( searchTerm == "realm" and realm == INEED.realm ) or
						( searchTerm == "all" ) then
					table.insert( updatedItems, { ["itemID"] = itemID, ["added"] = data.added, ["updated"] = (data.updated or data.added or 1) } )
				end
			end
		end
	end
	table.sort( updatedItems, function(a,b)	return a.updated<b.updated end ) -- sort by updated
	for _, item in pairs( updatedItems ) do
		itemID = item.itemID
		for realm, _ in pairs( INEED_data[itemID] ) do
			for name, data in pairs( INEED_data[itemID][realm] ) do
				if ( searchTerm == "me" and name == INEED.name and realm == INEED.realm ) or
						( searchTerm == "realm" and realm == INEED.realm ) or
						( searchTerm == "all" ) then
					if showHeader then INEED.Print("Needed items:"); showHeader=nil; end
					local itemLink = select( 2, GetItemInfo( itemID ) ) or "item:"..itemID
					INEED.Print(string.format("%i/%i x %s is needed by %s of %s", data.total, data.needed,
							itemLink, name, realm))
				end
			end
		end
	end
	--[[
	table.sort( items, function(a,b) return a.updated > b.updated end ) -- more recnet updated is last
	INEED.Print("Needed items:")
	for itemID, data in pairs( items ) do
		local itemLink = select( 2, GetItemInfo( itemID ) ) or "item:"..itemID
		INEED.Print(string.format("%i/%i x %s is needed by %s of %s", data.total, data.needed,
				itemLink, name, realm))
	end
	]]
	for currencyID, cData in pairs( INEED_currency ) do
		local currencyLink = GetCurrencyLink( currencyID )
		INEED.Print( string.format( "%i/%i x %s", cData.total, cData.needed, currencyLink ) )
	end
end
function INEED.itemIsSoulbound( itemLink )
	-- return 1 or nil to reflect if the item is BOP or bound
	INEED.scanTip:SetOwner(UIParent, "ANCHOR_NONE")
	INEED.scanTip:ClearLines()
	INEED.scanTip:SetHyperlink( itemLink )
	return INEED.bindTypes[INEED.scanTip2:GetText()] or INEED.bindTypes[INEED.scanTip3:GetText()] or INEED.bindTypes[INEED.scanTip4:GetText()]
end
function INEED.showFulfillList()
	-- returns number of items you can fulfill, or nil if none
    youHaveTotal = nil
	for itemID, _ in pairs(INEED_data) do
		for realm, _ in pairs(INEED_data[itemID]) do
			if realm == INEED.realm then  -- this realm
				local names = {}
				local itemLink = nil
				local isSoulBound = nil
				for name, data in pairs(INEED_data[itemID][realm]) do
					if (name ~= INEED.name) and (data.faction and data.faction == INEED.faction) then -- not you and right faction
						itemLink = select( 2, GetItemInfo( itemID ) )
						isSoulBound = INEED.itemIsSoulbound( itemLink )
						--INEED.Print( "Looking at "..itemLink..". Which is "..( INEED.itemIsSoulbound( itemLink ) and "soulbound" or "not soulbound" ) )
						if not isSoulBound then
							local youHaveNum = GetItemCount( itemID, true )
							local neededValue = data.needed - data.total - ( data.inMail or 0 )
							if (youHaveNum > 0) and (neededValue > 0) then
								youHaveTotal = youHaveTotal and youHaveTotal + youHaveNum or youHaveNum
								itemLink = itemLink or "item:"..itemID
								tinsert( names, name.." - "..neededValue )
								--INEED.Print(string.format("%s x %i is needed by %s. You have %i", itemLink,
								--		data.needed - data.total,  name, youHaveNum ) )
							else
								itemLink = nil  -- you don't have any, clear the itemLink
							end
						end
					end
				end
				if itemLink and not isSoulBound then
					INEED.Print( string.format( "%s -- %s", itemLink, table.concat( names, ", " ) ) )
				end
			end
		end
	end
	return youHaveTotal -- for unit testing
end
function INEED.accountInfo( value )
	local sub,add = false, false
	if value and value ~= "" then
		sub = strfind( value, "^[-]" )
		add = strfind( value, "^[+]" )
		if tonumber(value) then
		else
			local gold   = strmatch( value, "(%d+)g" )
			local silver = strmatch( value, "(%d+)s" )
			local copper = strmatch( value, "(%d+)c" )
			value = ((gold or 0) * 10000) + ((silver or 0) * 100) + (copper or 0)
			if sub then value = -value end
		end
		INEED_account.balance = INEED_account.balance
				and ((sub or add) and INEED_account.balance + value)
				or tonumber(value)
	end
	if INEED_account.balance and INEED_account.balance <= 0 then
		INEED_account.balance = nil
	end
	INEED.Print( "The current autoSpend account balance is: "..
			( INEED_account.balance and GetCoinTextureString( INEED_account.balance ) or "0" ) )
end
function INEED.remove( nameIn )
	local delName, delRealm = strmatch( nameIn , "^(.*)-(.*)$")
	if delName then
		local delRealm = delRealm or INNED.realm
		for itemID, _ in pairs(INEED_data) do
			for realm, _ in pairs(INEED_data[itemID]) do
				if string.lower(realm) == delRealm then  -- this realm
					for name, _ in pairs(INEED_data[itemID][realm]) do
						if string.lower(name) == delName then -- delete this char
							INEED_data[itemID][realm][name] = nil
							local linkString = select( 2, GetItemInfo( itemID ) ) or "item:"..itemID
							INEED.Print("Removing "..linkString.." for "..name.."-"..realm)
						end
					end
				end
			end
		end
		INEED.clearData()
	end
end

-- Testing functions

function INEED.test()
	INEEDUIFrame:Hide()
--[[
	INEED.Print("Registering for event")
	INEED_Frame:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
	INEED.Print("OpeningCalendar")
	OpenCalendar()
	local weekday, month, day, year = CalendarGetDate()
	INEED.Print(weekday..":"..month..":"..day..":"..year)
	local numEventsToday = CalendarGetNumDayEvents(0, day)  -- 0 month offset
	INEED.Print("NumEvents:"..numEventsToday)
	for eventIndex = 1, numEventsToday do
		local title, hour, minute, calendarType, sequenceType, eventType = CalendarGetDayEvent( 0, day, eventIndex )
		--INEED.Print("title:"..title.." hour:"..hour.." minute:"..minute.." calendarType:"..calendarType.." sequenceType:"
		--		..sequenceType.." eventType:"..eventType)
	end
]]
end
function INEED.CALENDAR_UPDATE_EVENT_LIST()
	--INEED.Print("EVENT LIST triggered")
end
function INEED.CALENDAR_OPEN_EVENT(arg1, arg2, arg3)
	for k,v in pairs(arg1) do
		--INEED.Print(k.."==>"..v)
	end
	--INEED.Print("a1:"..(arg1 or "nil").." a2:"..(arg2 or "nil").." a3:"..(arg3 or "nil"))
	INEED_Frame:UnegisterEvent("CALENDAR_OPEN_EVENT")
end

-- end experimental

-- this needs to be at the end because it is referencing functions
INEED.CommandList = {
	["help"] = {
		["func"] = INEED.PrintHelp,
		["help"] = {"","Print this help."},
	},
	["list"] = {
		["func"] = INEED.showList,
		["help"] = {"", "Show a list of needed items"},
	},
	["account"] = {
		["func"] = INEED.accountInfo,
		["help"] = {"[amount]", "Show account info, and set a new amount"},
	},
	["<link>"] = {
		["func"] = INEED.PrintHelp,
		["help"] = {"[quantity]", "Set quantity needed of <link>"},
	},
	["options"] = {
		["func"] = function() InterfaceOptionsFrame_OpenToCategory( INEED_MSG_ADDONNAME ) end,
		["help"] = {"", "Open the options panel"},
	},
	["remove"] = {
		["func"] = INEED.remove,
		["help"] = {"<name>-<realm>", "Removes <name>-<realm>"},
	},
	["test"] = {
		["func"] = INEED.test,
		["help"] = {"","Do something helpful"},
	},
}

