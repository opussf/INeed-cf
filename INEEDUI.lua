-- General functions
INEED.UIListHeaderHeight = 16
INEED.UIListBarWidth = 250
INEED.UIListBarHeight = 12

INEED.UIList_bars = {}
function INEED.UIListAssureBars( barsNeeded )
	-- make sure that there are enough bars to handle the need
	-- frameIn = frame to add bars to
	-- barsNeeded = # of bars to assure exist.
	-- barTable = table to add bars to (remove later to tie a table to the frame) (frameIn:GetName().."_bars")
	-----
	-- checks and adds bars to frameIn_bars
	--
	-- Hard coding to support the List Frame for now.  Generalize later
	-- Based on function from FactionBars

	-- INEED.UIList_bars

	local count = 0
	for b in pairs(INEED.UIList_bars) do
		count = count + 1
	end
	--INEED.Print("Bars I need: "..barsNeeded..". Bars I have: "..count)
	if (barsNeeded > count) then
		for i = count+1, barsNeeded do
			-- Create a bar
			--INEED.Print("Creating bar# "..i)
			local newBar = CreateFrame( "StatusBar", "INEED.UIListBar"..i, INEEDUIListFrame, "INEEDUIListBarTemplate" )
			newBar:SetWidth( INEED.UIListBarWidth )
			newBar:SetHeight( INEED.UIListBarHeight )
			if (i == 1) then
				newBar:SetPoint( "TOPLEFT", "INEEDUIListFrame_TitleText", "BOTTOMLEFT" )
			else
				newBar:SetPoint( "TOPLEFT", INEED.UIList_bars[i-1], "BOTTOMLEFT" )
			end
			local text = newBar:CreateFontString("INEED.UIListText"..i, "OVERLAY", "INEEDUIListBarTextTemplate" )
			newBar.text = text
			text:SetPoint("TOPLEFT", newBar, "TOPLEFT", 5, 0)

			INEED.UIList_bars[i] = newBar
		end
	end
	return max(count, barsNeeded)
end


-- List display functions
function INEED.UIListOnLoad()
	INEED.Print("Loading UI - List")
	INEEDUIListFrame:Hide()
end
function INEED.UIListOnUpdate()
	-- Create a sorted index table of most recent updated items
	if (INEED.UIListLastUpdate or 0) + 1 > time() then
		return -- no need to update
	end
	INEED.UIListLastUpdate = time()

	local count = 0
	local sortedDisplayItems = {}

	-- need progress, link, updated..  for items that I need.
	for itemID in pairs(INEED_data) do
		if INEED_data[itemID][INEED.realm] and INEED_data[itemID][INEED.realm][INEED.name] then
			local updatedTS = INEED_data[itemID][INEED.realm][INEED.name].updated or INEED_data[itemID][INEED.realm][INEED.name].added
			--INEED.Print(itemID..":"..(time()-updatedTS).." <? "..(INEED_options["displayUIListDisplaySeconds"] or "nil") )
			if ((time() - updatedTS) < (INEED_options["displayUIListDisplaySeconds"] or 0)) then
					-- I need this item, and it has been updated within the update window
				table.insert( sortedDisplayItems,
						{["updated"] = updatedTS,
						 ["itemPre"] = "item:",
						 ["id"] = itemID,  -- itemPre..id can be used to get the link.
						 ["total"] = INEED_data[itemID][INEED.realm][INEED.name].total,
						 ["needed"] = INEED_data[itemID][INEED.realm][INEED.name].needed,
						 ["linkStr"] = (select( 2, GetItemInfo( itemID ) ) or "item:"..itemID)
				})
				count = count + 1
			end
		end
	end
	-- process currency
	for curID in pairs(INEED_currency) do
		local updatedTS = INEED_currency[curID].updated or INEED_currency[curID].added
		if ((time() - updatedTS) < (INEED_options["displayUIListDisplaySeconds"] or 0)) then
			table.insert( sortedDisplayItems,
					{["updated"] = updatedTS,
					 ["itemPre"] = "currency:",
					 ["id"] = curID,
					 ["total"] = INEED_currency[curID].total,
					 ["needed"] = INEED_currency[curID].needed,
					 ["linkStr"] = (GetCurrencyLink( curID, INEED_currency[curID].total ) or ("currency:"..curID))
			})
			count = count + 1
		end
	end
	if INEED_gold[INEED.realm] and INEED_gold[INEED.realm][INEED.name] then
		local g = INEED_gold[INEED.realm][INEED.name]
		table.insert( sortedDisplayItems,
				{["updated"] = g.updated,
				 ["itemPre"] = "",
				 ["id"] = "",
				 ["total"] = g.total,
				 ["needed"] = g.needed,
				 ["linkStr"] = "",
				 ["showString"] = GetCoinTextureString(g.total).."/"..GetCoinTextureString(g.needed),
		})
		count = count + 1
	end
	-- process othersNeed
	for itemID in pairs( INEED.othersNeed ) do
		if INEED.othersNeed[itemID][INEED.realm] and INEED.othersNeed[itemID][INEED.realm][INEED.faction] then
			updatedTS = INEED.othersNeed[itemID][INEED.realm][INEED.faction].updated or nil
			--print( "--> item:"..itemID.." for "..INEED.realm.." and "..INEED.faction.." :"..
			--		(INEED.othersNeed[itemID][INEED.realm][INEED.faction].updated or "noUpdate") )
		end
		if updatedTS and ((time() - updatedTS) < (INEED_options["displayUIListDisplaySeconds"] or 0)) then
			--print( "Maybe show "..(select( 2, GetItemInfo( itemID ) ) or "item:"..itemID ).." in list?" )
			addThis = true
			--[[
			for _, displayItem in pairs( sortedDisplayItems ) do
				if displayItem.id == itemID then addThis = false end
			end
			]]
			if addThis then
				table.insert( sortedDisplayItems,
						{["updated"] = updatedTS,
						 ["itemPre"] = "item:",
						 ["id"] = itemID,
						 ["total"] =  (INEED.othersNeed[itemID][INEED.realm][INEED.faction].mine or 0) +
						 		(INEED.othersNeed[itemID][INEED.realm][INEED.faction].total or 0),
						 ["needed"] =  INEED.othersNeed[itemID][INEED.realm][INEED.faction].needed,
						 ["linkStr"] = "-->"..( select( 2, GetItemInfo( itemID ) ) or "item:"..itemID ).."<--"
				})
				count = count + 1
			end
		end
		updatedTS = nil  -- since this is used in logic, clear the logic
	end

	-- return early, no need to sort an empty table.
	if (count == 0 and INEEDUIListFrame:IsShown()) then
		INEEDUIListFrame:Hide()
		--INEED.Print("Hide List Frame: "..time())
		return;
	end
	INEEDUIListFrame:Show()
	-- sort table by updated, use itemPre..id as subsort
	table.sort( sortedDisplayItems, function(a,b) return (a.updated>b.updated or (a.updated==b.updated and (a.itemPre..a.id)<(b.itemPre..b.id) ) ); end)

	local barsNeeded = min(count, INEED_options["barCount"])
	local barCount = INEED.UIListAssureBars( barsNeeded )

	INEEDUIListFrame:SetHeight( (INEED.UIListBarHeight*barsNeeded) + INEED.UIListHeaderHeight )

	for i = 1, barsNeeded do
		local data = sortedDisplayItems[i]
		local linkString = data.linkStr
		local outStr = data.showString or string.format( "%i/%i %s", data.total, data.needed, linkString )

		INEED.UIList_bars[i]:SetMinMaxValues( 0, data.needed )
		INEED.UIList_bars[i]:SetValue( data.total )
		INEED.UIList_bars[i].text:SetText( outStr )
		INEED.UIList_bars[i]:SetStatusBarColor( 0, 0.3, 0.9 )


		INEED.UIList_bars[i]:SetFrameStrata("LOW")
		INEED.UIList_bars[i]:Show()
	end
	for barsHide = barsNeeded + 1, barCount do
		if INEED.UIList_bars[barsHide]:IsShown() then
			--INEED.Print("Hiding: "..barsHide)
			INEED.UIList_bars[barsHide]:Hide()
		end
	end
end
function INEED.UIListOnDragStart()
	INEEDUIListFrame:StartMoving()
end
function INEED.UIListOnDragStop()
	INEEDUIListFrame:StopMovingOrSizing()
end
