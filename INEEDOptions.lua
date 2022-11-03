INEED_options = {
	["showProgress"] = true,
	["showSuccess"] = true,
	["audibleSuccess"] = true,
	["doEmote"] = true,
	["emote"] = "CHEER",
	["showGlobal"] = true,
	["barCount"] = 6,
	["hideInCombat"] = true,
	["displayUIList"] = true,
	["displayUIListDisplaySeconds"] = 300, -- 5 minute default
	["autoRepair"] = true,
	["fillBars"] = true,
	["displayUIListFillbarsSeconds"] = 300, -- show filled bars for another 5 minutes
}

function INEED.OptionsPanel_OnLoad(panel)
	panel.name = "INeed"
	INEEDOptionsFrame_Title:SetText(INEED_MSG_ADDONNAME.." "..INEED_MSG_VERSION)
	--panel.parent=""
	panel.okay = INEED.OptionsPanel_OKAY
	panel.cancel = INEED.OptionsPanel_Cancel
	--panel.default = FB.OptionsPanel_Default;
	panel.refresh = INEED.OptionsPanel_Refresh

	InterfaceOptions_AddCategory(panel)
	--InterfaceAddOnsList_Update();
	--FB.OptionsPanel_TrackPeriodSlider_OnLoad()
end
function INEED.OptionsPanel_Reset()
	-- Called from Addon_Loaded
	INEED.OptionsPanel_Refresh()
end
function INEED.OptionsPanel_OKAY()
	-- Data was recorded, clear the temp
	INEED.oldValues = nil
	INEED_account["max"] = MoneyInputFrame_GetCopper(INEEDOptionsFrame_Money_AccountMax)
	INEED_account["balance"] = MoneyInputFrame_GetCopper(INEEDOptionsFrame_Money_AccountCurrent)
	INEED.updateTitleText()
end
function INEED.OptionsPanel_Cancel()
	-- reset to temp and update the UI
	if INEED.oldValues then
		for key,val in pairs(INEED.oldValues) do
			--FB.Print(key..":"..val);
			INEED_options[key] = val;
		end
	end
	INEED.oldValues = nil;
end

function INEED.OptionsPanel_Refresh()
	-- Called when options panel is opened.
	INEEDOptionsFrame_ShowProgress:SetChecked(INEED_options["showProgress"])
	INEEDOptionsFrame_PrintProgress:SetChecked(INEED_options["printProgress"])
	INEEDOptionsFrame_ShowGlobalProgress:SetChecked(INEED_options["showGlobal"])
	INEEDOptionsFrame_IncludeChange:SetChecked(INEED_options["includeChange"])

	INEEDOptionsFrame_AlertOnSuccess:SetChecked(INEED_options["showSuccess"])
	INEEDOptionsFrame_PrintSuccess:SetChecked(INEED_options["printSuccess"])
	INEEDOptionsFrame_SuccessScreenShot:SetChecked(INEED_options["doScreenShot"])
	INEEDOptionsFrame_DoEmote:SetChecked(INEED_options["doEmote"])
	INEED.OptionsPanel_EditBox_OnLoad( INEEDOptionsFrame_DoEmoteEditBox, "emote" )

	INEEDOptionsFrame_CombatHide:SetChecked(INEED_options["combatHide"])
	INEED.OptionsPanel_EditBox_OnLoad( INEEDOptionsFrame_DisplayBarCount, "barCount" )
	INEEDOptionsFrame_FillOldest:SetChecked(INEED_options["fillBars"])

	INEEDOptionsFrame_AutoRepair:SetChecked(INEED_options["autoRepair"])

	-- Slush
	INEED.OptionsPanel_Account_EditBox_OnShow( INEEDOptionsFrame_AccountPercent, "percent" )
	MoneyInputFrame_SetCopper( INEEDOptionsFrame_Money_AccountMax, math.floor(INEED_account.max or 0) )
	INEEDOptionsFrame_Money_AccountMax.gold:SetCursorPosition(0)
	INEEDOptionsFrame_Money_AccountMax.silver:SetCursorPosition(0)
	INEEDOptionsFrame_Money_AccountMax.copper:SetCursorPosition(0)
	MoneyInputFrame_SetCopper( INEEDOptionsFrame_Money_AccountCurrent, math.floor(INEED_account.balance or 0) )
	INEEDOptionsFrame_Money_AccountCurrent.gold:SetCursorPosition(0)
	INEEDOptionsFrame_Money_AccountCurrent.silver:SetCursorPosition(0)
	INEEDOptionsFrame_Money_AccountCurrent.copper:SetCursorPosition(0)

	--INEED.Print("Options Panel Refresh: "..INEED_options["emote"])
end

function INEED.OptionPanel_KeepOriginalValue( option )
	if INEED.oldValues then
		INEED.oldValues[option] = INEED.oldValues[option] or INEED_options[option];
	else
		INEED.oldValues={[option]=INEED_options[option]};
	end
end

function INEED.OptionsPanel_CheckButton_OnLoad( self, option, text )
	--FB.Print("CheckButton_OnLoad( "..option..", "..text.." ) -> "..(FB_options[option] and "checked" or "nil"));
	getglobal(self:GetName().."Text"):SetText(text);
	self:SetChecked(INEED_options[option]);
end
function INEED.OptionsPanel_EditBox_OnLoad( self, option )
	self:SetText( tostring( INEED_options[option] ) )
	self:SetCursorPosition(0)
	if self:IsNumeric() then
		self:SetValue(INEED_options[option])
	end
end
function INEED.OptionsPanel_Account_EditBox_OnShow( self, option )
	self:SetText( tostring( INEED_account[option] ) )
	self:SetCursorPosition(0)
	if self:IsNumeric() then
		self:SetValue( INEED_account[option] )
	end
end
function INEED.OptionsPanel_Account_EditBox_TextChanged( self, option )
	if self:HasFocus() then
		INEED_account[option] = tonumber(self:IsNumeric() and self:GetNumber() or self:GetText())
		if self:IsNumeric() then
			self:SetNumber(INEED_account[option])
		end
	end
end
-- OnClick for checkbuttons
function INEED.OptionsPanel_CheckButton_OnClick( self, option )
	INEED.OptionPanel_KeepOriginalValue( option )
	INEED_options[option] = self:GetChecked()
end
function INEED.OptionsPanel_EditBox_TextChanged( self, option )
	INEED.OptionPanel_KeepOriginalValue( option )
	INEED_options[option] = (self:IsNumeric() and self:GetNumber() or self:GetText())
	if self:IsNumeric() then
		self:SetValue(INEED_options[option])
	end
end
INEED.durationKeys = {
	["Days"]    = {86400, 1000000000000},
	["Hours"]   = {3600, 24},
	["Minutes"] = {60, 60},
	["Seconds"] = {1, 60}
}
-- Duration field events
function INEED.OptionsPanel_Duration_OnShow( self, option )
	local myName = strmatch(self:GetName(), "_(%a*)$")
	local calcStruct = INEED.durationKeys[myName]
	if calcStruct then
		local duration = INEED_options[option] or 0
		local displayValue = math.floor( (duration/calcStruct[1])%calcStruct[2] )
		self:SetNumber( displayValue )
	end
	self:SetCursorPosition(0)
end
function INEED.OptionsPanel_Duration_TextChanged( self, option )
	if self:HasFocus() then
		local myName = strmatch(self:GetName(), "_(%a*)$")
		local duration = INEED_options[option]
		local newValue = duration
		local calcStruct = INEED.durationKeys[myName]
		if calcStruct then
			local displayValue = tonumber( self:GetNumber() ) or 0
			local originalSec = math.floor( (duration/calcStruct[1])%calcStruct[2] ) * calcStruct[1]
			newValue = ( duration - originalSec ) + ( displayValue * calcStruct[1] )
		end
		INEED.OptionPanel_KeepOriginalValue( option )
		INEED_options[option] = newValue
	end
end

function INEED.OptionsPanel_MaxGold_Changed()
	-- Leave this here
end

-- Slider events
function INEED.OptionsPanel_Slider_ValueChanged( self, option )
	if INEED.oldValues then
		INEED.oldValues[option] = INEED.oldValues[option] or INEED_options[option]
	else
		INEED.oldValues={[option]=INEED_options[option]}
	end
	INEED_options[option] = floor(self:GetValue())
end