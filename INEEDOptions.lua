INEED_options = {
	["showProgress"] = true,
	["showSuccess"] = true,
	["audibleSuccess"] = true,
	["doEmote"] = true,
	["emote"] = "CHEER",
	["playSoundFile"] = false,
	["soundFile"] = "Sound\\Creature\\BabyMurloc\\BabyMurlocDance.wav",
	["showGlobal"] = true,
	["barCount"] = 6,
	["hideInCombat"] = true,
	["displayUIList"] = true,
	["displayUIListDisplaySeconds"] = 300, -- 5 minute default
}

function INEED.OptionsPanel_OnLoad(panel)
	INEED.Print("OptionsPanel_OnLoad")
	panel.name = "INeed";
	INEEDOptionsFrame_Title:SetText(INEED_MSG_ADDONNAME.." "..INEED_MSG_VERSION);
	--panel.parent=""
	panel.okay = INEED.OptionsPanel_OKAY;
	panel.cancel = INEED.OptionsPanel_Cancel;
	--panel.default = FB.OptionsPanel_Default;
	panel.refresh = INEED.OptionsPanel_Refresh;

	InterfaceOptions_AddCategory(panel);
	InterfaceAddOnsList_Update();
	--FB.OptionsPanel_TrackPeriodSlider_OnLoad()
end
function INEED.OptionsPanel_Reset()
	-- Called from Addon_Loaded
	INEED.OptionsPanel_Refresh()
end
function INEED.OptionsPanel_OKAY()
	-- Data was recorded, clear the temp
	INEED.oldValues = nil
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
--	INEEDOptionsFrame_ShowProgress:SetChecked(INEED_options["showProgress"])
--	INEEDOptionsFrame_AlertOnSuccess:SetChecked(INEED_options["showSuccess"])
--	INEEDOptionsFrame_AudibleAlert:SetChecked(INEED_options["audibleSuccess"])
--	INEEDOptionsFrame_DoEmote:SetChecked(INEED_options["doEmote"])
--	INEEDOptionsFrame_PlaySound:SetChecked(INEED_options["playSoundFile"])

	INEEDOptionsFrame_DoEmoteEditBox:SetText(INEED_options["emote"])
	INEEDOptionsFrame_PlaySoundEditBox:SetText(INEED_options["soundFile"])

	--INEED.Print("Options Panel Refresh: "..INEED_options["emote"])
end

function INEED.OptionsPanel_CheckButton_OnLoad( self, option, text )
	--FB.Print("CheckButton_OnLoad( "..option..", "..text.." ) -> "..(FB_options[option] and "checked" or "nil"));
	getglobal(self:GetName().."Text"):SetText(text);
	self:SetChecked(INEED_options[option]);
end
function INEED.OptionsPanel_CheckButton_PostClick( self, option )
	if INEED.oldValues then
		INEED.oldValues[option] = INEED.oldValues[option] or INEED_options[option];
	else
		INEED.oldValues={[option]=INEED_options[option]};
	end
	INEED_options[option] = self:GetChecked();
end
function INEED.OptionsPanel_EditBox_OnLoad( self, option )
	self:SetText(INEED_options[option])
	self:SetCursorPosition(0)
end

-- PostClick for checkbuttons
function INEED.OptionsPanel_CheckButton_PostClick( self, option )
	if INEED.oldValues then
		INEED.oldValues[option] = INEED.oldValues[option] or INEED_options[option]
	else
		INEED.oldValues={[option]=INEED_options[option]}
	end
	INEED_options[option] = self:GetChecked()
end
function INEED.OptionsPanel_EditBox_TextChanged( self, option )
	if INEED.oldValues then
		INEED.oldValues[option] = INEED.oldValues[option] or INEED_options[option]
	else
		INEED.oldValues={[option]=INEED_options[option] }
	end
	INEED_options[option] = self:GetText()
end