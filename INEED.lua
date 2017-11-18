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
INEED_gold = {}
INEED_unknown = {}
INEED.criteriaTypes = {
		[12] = "currency:%s",
		[36] = "item:%s",
		[42] = "item:%s",
		[57] = "item:%s",
}

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
	--INEED_Frame:RegisterEvent("TRADE_SKILL_CLOSE")
	INEED_Frame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
	--INEED_Frame:RegisterEvent("TRADE_SKILL_FILTER_UPDATE")
	-- ^^^ Fired immediately after TRADE_SKILL_SHOW, after something is created via tradeskill, or anytime the tradeskill window is updated (filtered, tree folded/unfolded, etc.)
	INEED_Frame:RegisterEvent("PLAYER_MONEY")
	-- Hide display
	INEED_Frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	INEED_Frame:RegisterEvent("PLAYER_REGEN_DISABLED")
end
function INEED.TRADE_SKILL_SHOW()
	--INEED.Print("TradeSkill window opened.")
	INEED.TradeSkillsScanned = false
end
function INEED.TRADE_SKILL_CLOSE()
end
function INEED.TRADE_SKILL_LIST_UPDATE()
	--INEED.Print("TradeSkill Update")
	if not INEED.TradeSkillsScanned then
		INEED.TradeSkillsScanned = true
		local recipeTable = C_TradeSkillUI.GetAllRecipeIDs()
		for i,recipeID in pairs(recipeTable) do
			local recipeInfo = C_TradeSkillUI.GetRecipeInfo( recipeID )
			if recipeInfo.learned then
				local itemLink = C_TradeSkillUI.GetRecipeItemLink( recipeID )
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
end
function INEED.TRADE_SKILL_FILTER_UPDATE()
	--INEED.Print("TradeSkill Filter Update")
end
function INEED.MAIL_SEND_INFO_UPDATE()
	INEED.mailInfo = {}
	INEED.mailInfo.mailTo = SendMailNameEditBox:GetText()
	INEED.mailInfo.items = {}

	for slot = 1, ATTACHMENTS_MAX_SEND do
		local link = GetSendMailItemLink( slot )
		if link then
			local itemID = INEED.getItemIdFromLink( link )
			local quantity = select( 4, GetSendMailItem( slot ) )
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
				INEED_data[i][realm][sendto].updated = time()
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
				local q = select( 4, GetInboxItem( mailID, itemIndex ) )
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
	INEEDUIListFrame:Show()
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
	INEEDUIListFrame:Show()
end
function INEED.MERCHANT_SHOW()
	-- Event handler.  Autopurchase
	--local numItems = GetMerchantNumItems()
	local purchaseAmount = 0
	local msgSent = false
	for i = 0, GetMerchantNumItems() do  -- Go through the items for sale
		local itemLink = GetMerchantItemLink( i )
		local itemID = INEED.getItemIdFromLink( itemLink )
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
			INEED_data[itemID][INEED.realm][INEED.name].updated = time()
			INEEDUIListFrame:Show()
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
			elseif isUsable and price == 0 and currencyCount > 0 then
				for ci = 1, currencyCount do
					local _, value, link = GetMerchantItemCostItem( i, ci )
					local itemID = INEED.getItemIdFromLink( link )
					if itemID
							and ((INEED_data[itemID] and INEED_data[itemID][INEED.realm] and INEED_data[itemID][INEED.realm][INEED.name] and (value > INEED_data[itemID][INEED.realm][INEED.name].needed))
							or (not ((INEED_data[itemID] and INEED_data[itemID][INEED.realm] and INEED_data[itemID][INEED.realm][INEED.name] and INEED_data[itemID][INEED.realm][INEED.name].needed >= value))))
							then
						INEED.addItem( link, value )
					end

					local currencyID = INEED.getCurrencyIdFromLink( link )
					if currencyID
							and ((INEED_currency[currencyID] and (value > INEED_currency[currencyID].needed))
							or (not INEED_currency[currencyID]))
							then
						INEED.addItem( link, value )
					end
				end
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
function INEED.PLAYER_MONEY()
	-- PLAYER_MONEY has changed
	if INEED_account.percent then  -- look to see if need to add to balance
		local change = GetMoney() - (INEED_account.current or 0)
		change = change * INEED_account.percent
		if ((not INEED_account.max) or ((INEED_account.balance or 0) < INEED_account.max)) and change>0 then
			INEED_account.balance = (INEED_account.balance or 0) + change
			if INEED_account.max and (INEED_account.balance > INEED_account.max) then
				INEED_account.balance = INEED_account.max
			end
			INEED.Print( "account: "..GetCoinTextureString((INEED_account.balance or 0)).." +"..GetCoinTextureString( change ) )
		end
	end
	INEED_account.current = GetMoney()
	if INEED_gold[INEED.realm] then
		if INEED_gold[INEED.realm][INEED.name] then
			if INEED_gold[INEED.realm][INEED.name].needed then
				itemFulfilled = false
				local needed = INEED_gold[INEED.realm][INEED.name].needed
				local total = GetMoney()
				local gained = total - INEED_gold[INEED.realm][INEED.name].total
				INEED_gold[INEED.realm][INEED.name].total = total
				INEED_gold[INEED.realm][INEED.name].updated = time()

				if total < needed then
					if INEED_options.showProgress or INEED_options.printProgress then
						local progressString = string.format("%s/%s %s",
								GetCoinTextureString(total), GetCoinTextureString(needed),
								(INEED_options.includeChange and
									string.format(" (%s%s%s%s) ", ((gained > 0) and COLOR_GREEN or COLOR_RED), ((gained > 0) and "+" or "-"),
										GetCoinTextureString(math.abs(gained)), COLOR_END)
									or "")
								)
						_ = INEED_options.showProgress and UIErrorsFrame:AddMessage( progressString, 1.0, 1.0, 0.1, 1.0 )
						_ = INEED_options.printProgress and INEED.Print( progressString )
					end
					INEEDUIListFrame:Show()
				elseif total >= needed then
					_ = INEED_options.showSuccess and
							INEED.showSplash( string.format("%s/%s",
									GetCoinTextureString(total), GetCoinTextureString(needed) ) )
					_ = INEED_options.printSuccess and
							INEED.Print( string.format( "Reached goal of %s.", GetCoinTextureString( needed ) ) )
					INEED_gold[INEED.realm][INEED.name] = nil
					INEED.clearData()
					itemFulfilled = true
				end
				_ = itemFulfilled and INEED.itemFulfilledAnnouce()
			end
		end
	end
end
function INEED.PLAYER_REGEN_DISABLED()
	-- combat start
	if INEED_options.combatHide then
		INEED.hide = true
		INEEDUIListFrame:Hide()
	end
end
function INEED.PLAYER_REGEN_ENABLED()
	-- combat ends
	INEED.hide = nil
	INEEDUIListFrame:Show()
end
function INEED.OnUpdate()
end
-----------------------------------------
-- Non Event functions
-----------------------------------------
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
	if INEED_options.doScreenShot then
		Screenshot()
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
	local realmCount = 0
	for realm in pairs(INEED_gold) do
		local charCount = 0
		realmCount = realmCount + 1
		for _ in pairs( INEED_gold[realm] ) do
			charCount = charCount + 1
		end
		if charCount == 0 then
			INEED_gold[realm] = nil
			realmCount = realmCount - 1
		end
	end
	if realmCount == 0 then
		INEED_gold = {}
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
function INEED.addItemToTable( tableIn, needed, total, includeFaction, link )
	-- given a table, make sure that the 'normal' structure exists.
	-- needed: how many are needed (required )
	-- total: total you have ( required )
	-- includeFaction: include the faction info (boolean)
	-- link: the link for the needed item (optional)
	-- return the modified table - or original table if nothing to do.
	if tableIn and needed and total then
		tableIn.needed = needed
		tableIn.total = total
		if includeFaction then
			tableIn.faction = INEED.faction
		end
		tableIn.link = link
		tableIn.added = tableIn.added or time()
		tableIn.updated = time()
	end
	return tableIn
end
function INEED.showProgress()
end
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
	INEEDUIListFrame:Show()
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

				INEED_data[itemID][INEED.realm][INEED.name] = INEED.addItemToTable( INEED_data[itemID][INEED.realm][INEED.name],
						quantity, youHave, true, linkString )
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
		local recipeTable = C_TradeSkillUI.GetAllRecipeIDs()
		for i,recipeID in pairs(recipeTable) do
			if recipeID == tonumber(enchantID) then -- found the enchant link just needed
				--INEED.Print( "Needing :"..recipeID )
				local madeItemLink = C_TradeSkillUI.GetRecipeItemLink( recipeID )
				local minMade, maxMade = C_TradeSkillUI.GetRecipeNumItemsProduced( recipeID )
				INEED.addItem( madeItemLink, minMade * quantity ) -- If a tradeskill makes more than one at a time.

				local numReagents = C_TradeSkillUI.GetRecipeNumReagents( recipeID )
				for reagentIndex = 1, numReagents do
					local _, _, reagentCount = C_TradeSkillUI.GetRecipeReagentInfo( recipeID, reagentIndex )
					local reagentLink = C_TradeSkillUI.GetRecipeReagentItemLink( recipeID, reagentIndex )
					INEED.addItem( reagentLink, reagentCount * quantity )
				end
				local toolName = C_TradeSkillUI.GetRecipeTools( recipeID )
				if toolName then
					INEED.Print( toolName )
					local _, toolLink = GetItemInfo( toolName )
					INEED.addItem( toolLink, 1 )
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

				INEED_currency[currencyID] = INEED.addItemToTable( INEED_currency[currencyID], quantity, curAmount, false)
				INEED_currency[currencyID]['name'] = curName -- custom field

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
	local needGoldAmount, modify = INEED.parseGold( itemLink )
	if needGoldAmount then
		local curAmount = GetMoney()
		if modify then
			needGoldAmount = curAmount + needGoldAmount
		end
		--print("Need gold amount: "..(needGoldAmount or "nil") )
		if curAmount < needGoldAmount then
			INEED.Print( string.format( "Needing: %s/%s",
					GetCoinTextureString(curAmount), GetCoinTextureString(needGoldAmount) ) )
			INEED_gold[INEED.realm] = INEED_gold[INEED.realm] or {}
			INEED_gold[INEED.realm][INEED.name] = INEED_gold[INEED.realm][INEED.name] or {}
			INEED_gold[INEED.realm][INEED.name] = INEED.addItemToTable( INEED_gold[INEED.realm][INEED.name], needGoldAmount, curAmount )
		elseif needGoldAmount == 0 then
			if INEED_gold[INEED.realm] and INEED_gold[INEED.realm][INEED.name] then
				INEED.Print( "Removing gold from your need list" )
				INEED_gold[INEED.realm][INEED.name] = nil
			end
		end
		return itemLink  -- return done
	end
	local achievementID = INEED.getAchievementIdFromLink( itemLink )
	if achievementID then
		_, name, points, completed = GetAchievementInfo( achievementID )
		if not completed then
			numCriteria = GetAchievementNumCriteria( achievementID )
			if numCriteria then
				for i = 1, numCriteria do
					desc, criteriaType, completedCriteria, quantity, reqQuantity, charName, flags, assetID, quantityString, criteriaID = GetAchievementCriteriaInfo( achievementID, i )
					criteriaFormatString = INEED.criteriaTypes[criteriaType]
					if criteriaFormatString and not completedCriteria then
						INEED.addItem( string.format( criteriaFormatString, assetID ).." "..reqQuantity )
					end
				end
			end
		end
		return itemLink
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
function INEED.getAchievementIdFromLink( achievementLink )
	if achievementLink then
		return strmatch( achievementLink, "achievement:(%d*)" )
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
	-- Search for items that are needed, based on search term
	for itemID, _ in pairs(INEED_data) do
		for realm, _ in pairs(INEED_data[itemID]) do
			for name, data in pairs(INEED_data[itemID][realm]) do
				if ( searchTerm == "me" and name == INEED.name and realm == INEED.realm ) or
						( searchTerm == "realm" and realm == INEED.realm ) or
						( searchTerm == "all" ) then
					table.insert( updatedItems, {
							["updated"] = (data.updated or data.added or 1),
							["displayStr"] = string.format("%i/%i x %s for %s of %s",
									data.total, data.needed, (select( 2, GetItemInfo( itemID ) ) ), name, realm ),
					} )
				end
			end
		end
	end

	-- add currency entries, which are only for you
	for currencyID, cData in pairs( INEED_currency ) do
		table.insert( updatedItems, {
				["updated"] = (cData.updated or cData.added or 1),
				["displayStr"] = string.format("%i/%i x %s",
						cData.total, cData.needed, GetCurrencyLink( currencyID ) )
		})
	end

	-- add the Gold entries (Use the search value here)
	for realm, _ in pairs( INEED_gold ) do
		for name, data in pairs( INEED_gold[realm] ) do
			if ( searchTerm == "me" and name == INEED.name and realm == INEED.realm ) or
					( searchTerm == "realm" and realm == INEED.realm ) or
					( searchTerm == "all" ) then
				table.insert( updatedItems, {
						["updated"] = (data.updated or data.added or 1),
						["displayStr"] = string.format("%s/%s for %s of %s",
								GetCoinTextureString( data.total ), GetCoinTextureString( data.needed ),
								name, realm )
				} )
			end
		end
	end

	-- sort the values by updated
	table.sort( updatedItems, function(a,b)	return a.updated<b.updated end ) -- sort by updated, most recent is last

	-- display the list
	for _, item in pairs( updatedItems ) do
		itemID = item.itemID
		if showHeader then INEED.Print("Needed items:"); showHeader=nil; end
		INEED.Print( item.displayStr )
	end
	return updatedItems
end
function INEED.itemIsSoulbound( itemLink )
	-- return 1 or nil to reflect if the item is BOP or bound
	if itemLink then
		INEED.scanTip:SetOwner(UIParent, "ANCHOR_NONE")
		INEED.scanTip:ClearLines()
		INEED.scanTip:SetHyperlink( itemLink )
		return INEED.bindTypes[INEED.scanTip2:GetText()] or INEED.bindTypes[INEED.scanTip3:GetText()] or INEED.bindTypes[INEED.scanTip4:GetText()]
	else
		INEED.Print("itemIsSoulbound was called wit a 'nil' value.")
	end

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
						--if not itemLink then INEED.Print(itemID.." created a nil link.") end
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
function INEED.parseGold( valueIn )
	-- parse the gold value passed in
	-- returns value, modify
	--     modify is true if the value should be added, value could be negative
	-- nil is a sign of invalid value
	-- may be a bug to examine, but this seems to never return nil
	local sub,add = false, false
	local valid = false
	if valueIn and valueIn ~= "" then
		sub = strfind( valueIn, "^[-]" )  -- given a negative number, subtract this amount
		add = strfind( valueIn, "^[+]" )  -- given a number with a +, add this ammount instead of replace
		if tonumber(valueIn) then
			value = tonumber(valueIn)  -- just use this value
			valid = true
		else
			local gold   = strmatch( valueIn, "(%d+)g" )
			local silver = strmatch( valueIn, "(%d+)s" )
			local copper = strmatch( valueIn, "(%d+)c" )
			valid = (gold or silver or copper)
			value = ((gold or 0) * 10000) + ((silver or 0) * 100) + (copper or 0)
			if sub then value = -value end
		end
		if valid then return value, (sub or add) end
	end
end
function INEED.accountInfo( value )
	value, modify = INEED.parseGold( value )

	if value then
		INEED_account.balance = INEED_account.balance
				and (modify and INEED_account.balance + value)
				or value
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
INEED.archaeologyCurrencies = {
	1174, --  1 - Demonic
	1173, --  2 - Highmountain Tauren
	1172, --  3 - Highborne
	828, --  4 - Ogre
	821, --  5 - Draenor Clans
	829, --  6 - Arakkoa
	677, --  7 - Mogu
	676, --  8 - Pandaren
	754, --  9 - Mantid
	399, -- 10 - Vrykul
	385, -- 11 - Troll
	401, -- 12 - Tol'vir
	397, -- 13 - Orc
	400, -- 14 - Nerubian
	394, -- 15 - Night Elf
	393, -- 16 - Fossil
	398, -- 17 - Draenei
	384, -- 18 - Dwarf
}
function INEED.archScan()
	--print("ArchScan")
	local numRaces = GetNumArchaeologyRaces()
	--print("NumRaces: "..numRaces)
	for i = 1, GetNumArchaeologyRaces() do
		--print("i: "..i..":"..GetArchaeologyRaceInfo( i ) )
		if INEED.archaeologyCurrencies[i] then

			local raceName, raceTexture, raceItemID, numFragmentsCollected, numFragmentsRequired, maxFragments = GetArchaeologyRaceInfo( i )
			if select( 7, GetCurrencyInfo(INEED.archaeologyCurrencies[i]) ) then
				INEED.addItem( "currency:"..INEED.archaeologyCurrencies[i], numFragmentsRequired )
			end
		end
	end
end
function INEED.slush( strIn )
	--print( "Slush( "..strIn.. " )")
	local percentLoc, percentLocEnd = strfind( strIn, "[.0-9]*%%")
	if percentLoc then
		--print( percentLoc, percentLocEnd )
		local percent = strsub( strIn, percentLoc, percentLocEnd-1 )
		local goldValue = strsub( strIn, percentLocEnd+2 )
		--print( "goldValue: "..goldValue )
		local maxValue, modify = INEED.parseGold( goldValue )

		--print( "Slush( "..(percent or "nil")..", "..(maxValue or "nil").." )" )
		--print( percent.."::"..(maxValue or "nil").." -> "..value.."::"..(modify and "true" or "false") )

		INEED_account.percent = percent / 100
		INEED_account.max = (modify) and (INEED_account.max and INEED_account.max + maxValue) or maxValue
		INEED_account.current = GetMoney()
	end
	INEED.Print( "Slush: "..(INEED_account.percent and ((INEED_account.percent * 100).."%") or "")..
			(INEED_account.max and (" max: "..GetCoinTextureString(INEED_account.max)) or "") )
end

-- Testing functions

function INEED.test()
	INEEDUIFrame:Hide()
	INEEDUIFrame:Show()
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
	["arch"] = {
		["func"] = INEED.archScan,
		["help"] = {"", "Scans the archaeology items"},
	},
	["slush"] = {
		["func"] = INEED.slush,
		["help"] = {"[percent%] [MaxAmount]", "Sets an auto fill percent up to MaxAmount"},
	},
	["combat"] = {
		["func"] = function()
				INEED_options.combatHide = not INEED_options.combatHide or nil
				INEED.Print( "Hide: "..( INEED_options.combatHide and "ON" or "OFF" ) )
				end,
		["help"] = {"", "Toggle combat hide"}
	},
	["test"] = {
		["func"] = INEED.test,
		["help"] = {"","Do something helpful"},
	},
}

