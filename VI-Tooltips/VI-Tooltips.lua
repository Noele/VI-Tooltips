VITooltipsSpeechDB = VITooltipsSpeechDB or {}
VITooltipsSpeechDB.Speech = VITooltipsSpeechDB.Speech or {
    voiceID = 2,
    speechRate = 2,
    speechVolume = 100
}

Speech = {}
Speech.db = VITooltipsSpeechDB.Speech

BINDING_NAME_VITOOLTIPSLOCK = "Lock Tooltip"
BINDING_NAME_VITOOLTIPSTOGGLE = "Toggle Tooltip"
BINDING_NAME_VITOOLTIPREAD = "Read Tooltip using TTS"
SLASH_VITOOLTIPS1 = "/vitooltips"
SLASH_VITOOLTIPSTTSCONFIG1 = "/vitooltipsttsconfig"

SlashCmdList["VITOOLTIPSTTSCONFIG"] = function(msg)
    local args = {}
    for word in msg:gmatch("%S+") do
        table.insert(args, word)
    end

    if #args == 3 then
        local voiceID = tonumber(args[1])
        local speechRate = tonumber(args[2])
        local speechVolume = tonumber(args[3])

        -- Check if all values are valid numbers and within the range 0-100
        if voiceID and speechRate and speechVolume then
            if voiceID > 0 and voiceID <= 3 and speechRate >= 0 and speechRate <= 100 and speechVolume >= 0 and speechVolume <= 100 then
                VITooltipsSpeechDB.Speech.voiceID = voiceID
                VITooltipsSpeechDB.Speech.speechRate = speechRate
                VITooltipsSpeechDB.Speech.speechVolume = speechVolume
                Speech.db = VITooltipsSpeechDB.Speech
                print("TTS settings updated:")
                print("VoiceID: " .. VITooltipsSpeechDB.Speech.voiceID)
                print("SpeechRate: " .. VITooltipsSpeechDB.Speech.speechRate)
                print("SpeechVolume: " .. VITooltipsSpeechDB.Speech.speechVolume)
            else
                print("Invalid values:")
                print("Speech Rate and Speech Volume must be between 0 and 100.")
                print("Voice ID Must be between 1-3")
                print("Usage: /vitooltipsttsconfig <voiceID> <speechRate> <speechVolume>")
            end
        else
            print("Invalid values, all values must be numbers.")
            print("Usage: /vitooltipsttsconfig <voiceID> <speechRate> <speechVolume>")
        end
    else
        print("Usage: /vitooltipsttsconfig <voiceID> <speechRate> <speechVolume>")
        print("VoiceID: " .. VITooltipsSpeechDB.Speech.voiceID)
        print("SpeechRate: " .. VITooltipsSpeechDB.Speech.speechRate)
        print("SpeechVolume: " .. VITooltipsSpeechDB.Speech.speechVolume)
    end
end

local Current_Tooltip_Text = ""

local function GetToolTipText()
    local tooltipLines = {}

    for i = 1, GameTooltip:NumLines() do
        local leftLineText = _G["GameTooltipTextLeft" .. i]:GetText()
        local rightLineText = _G["GameTooltipTextRight" .. i]:GetText()

        local r, g, b = _G["GameTooltipTextLeft" .. i]:GetTextColor()
        local r2, g2, b2 = _G["GameTooltipTextRight" .. i]:GetTextColor()

        if leftLineText and leftLineText ~= "" then
            table.insert(tooltipLines, {text = leftLineText, color = {r, g, b}})
        end

        if rightLineText and rightLineText ~= "" then
            table.insert(tooltipLines, {text = rightLineText, color = {r2, g2, b2}})
        end
    end

    return tooltipLines
end

function VITooltips_Read()
	local readlist = GetToolTipText()
	local combinedText = ""
	for _, line in ipairs(readlist) do
		combinedText = combinedText .. line.text .. "\n"
	end
	if combinedText == "" or combinedText == nil then
		Speech:speak(Current_Tooltip_Text)
	else
		Speech:speak(combinedText)
	end
end

function Speech:speak(text)
    if C_VoiceChat and C_VoiceChat.SpeakText then
		C_VoiceChat.StopSpeakingText() -- Stop playing TTS on this frame

		C_Timer.After(0, function() -- Start TTS with new tooltip on next frame
			C_VoiceChat.SpeakText(
				VITooltipsSpeechDB.Speech.voiceID,
				text,
				Enum.VoiceTtsDestination.ScreenReader,
				VITooltipsSpeechDB.Speech.speechRate,
				VITooltipsSpeechDB.Speech.speechVolume
			)
end)
    else
        print("VoiceChat API is unavailable for TTS.")
    end
end

SlashCmdList["VITOOLTIPS"] = function(msg)
    local keys = {msg:match("^%s*(%S+)%s*,%s*(%S+)%s*$")}

    if #keys == 2 then
        if keys[1]:upper() == keys[2]:upper() then
            print("Error: Lock and Toggle cannot use the same key")
            return
        end

        local oldLockKey = GetBindingKey("VITOOLTIPSLOCK")
        local oldToggleKey = GetBindingKey("VITOOLTIPSTOGGLE")

        if oldLockKey then SetBinding(oldLockKey, nil) end
        if oldToggleKey then SetBinding(oldToggleKey, nil) end

        SetBinding(keys[1]:upper(), "VITOOLTIPSLOCK")
        SetBinding(keys[2]:upper(), "VITOOLTIPSTOGGLE")
        SaveBindings(2)
        print("Lock tooltip bound to " .. keys[1]:upper())
        print("Toggle tooltip bound to " .. keys[2]:upper())
    else
        print("VI-Tooltips commands:")
        print("/vitooltips KEY1,KEY2 - Bind lock to KEY1 and toggle to KEY2")
        print("Example: /vitooltips F8, F9")
    end
end

local customTooltipFrame = CreateFrame("Frame", "CustomTooltipFrame", UIParent)
customTooltipFrame:SetFrameStrata("TOOLTIP")
customTooltipFrame:SetFrameLevel(9999)
customTooltipFrame:Hide()

local bg = customTooltipFrame:CreateTexture(nil, "BACKGROUND")
bg:SetColorTexture(0, 0, 0, 1)
bg:SetAllPoints(customTooltipFrame)

local lastTooltipLines = {}
local fontStrings = {}
local currentScale = 1

local tooltipVisible = false
local tooltipKeyPressed = false
local tooltipLocked = false
local lockKeyDown = false

local function ToggleTooltip()
    if tooltipVisible then
        customTooltipFrame:Hide()
        tooltipVisible = false
    else
        customTooltipFrame:Show()
        tooltipVisible = true
    end
end

local function ToggleTooltipLock()
    tooltipLocked = not tooltipLocked
    if tooltipLocked then
        print("|cffff0000Tooltip locked.|r")
    else
        print("|cff00ff00Tooltip unlocked.|r")
    end
end

function VITooltips_Lock()
    ToggleTooltipLock()
end

function VITooltips_Toggle()
    ToggleTooltip()
end


local function DuplicateTooltip()
    if GameTooltip:IsShown() then
        C_Timer.After(0.1, function()   -- Wait 0.1s and then check if we're still hovered over something, this is to let other addons update the tooltip, without this, things like the auctionator addon wont tell us the price, and also the vendor price does not show
            if not GameTooltip:IsShown() then
                return
            end

            local updatedTooltipLines = {}
            local totalHeight = 0
            local maxWidth = 0

            for _, fontString in ipairs(fontStrings) do
                fontString:Hide()
            end
            wipe(fontStrings)

            local tooltipLines = GetToolTipText()

            for _, line in ipairs(tooltipLines) do
                local duplicateFound = false

                for _, existingLine in ipairs(updatedTooltipLines) do
                    if existingLine.text == line.text then
                        duplicateFound = true
                        break
                    end
                end

                if not duplicateFound then
                    table.insert(updatedTooltipLines, line)
                end
            end

            if #updatedTooltipLines > 0 then
                Current_Tooltip_Text = ""
                for i, line in ipairs(updatedTooltipLines) do
                    local textLine = line.text
                    local color = line.color

                    local fontString = customTooltipFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    fontString:SetText(textLine)
                    fontString:SetTextColor(unpack(color))

                    Current_Tooltip_Text = Current_Tooltip_Text .. "\n" .. textLine

                    if i == 1 then
                        fontString:SetPoint("TOP", customTooltipFrame, "TOP", 0, -8)
                    else
                        fontString:SetPoint("TOP", fontStrings[i - 1], "BOTTOM", 0, -2)
                    end

                    table.insert(fontStrings, fontString)

                    totalHeight = totalHeight + fontString:GetStringHeight() + 2
                    maxWidth = math.max(maxWidth, fontString:GetStringWidth())
                end

                local textWidth = maxWidth + 16
                local textHeight = totalHeight + 16

                customTooltipFrame:SetSize(textWidth, textHeight)
                customTooltipFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            end
        end)
    end
end

local function OnMouseWheel(self, delta)
    if delta > 0 then
        currentScale = currentScale * 1.1
    elseif delta < 0 then
        currentScale = currentScale / 1.1
    end

    currentScale = math.max(0.5, math.min(5, currentScale))

    customTooltipFrame:SetScale(currentScale)

    local totalHeight = 0
    local maxWidth = 0
    for _, fontString in ipairs(fontStrings) do
        totalHeight = totalHeight + fontString:GetStringHeight() + 2
        maxWidth = math.max(maxWidth, fontString:GetStringWidth())
    end

    local textWidth = maxWidth + 16
    local textHeight = totalHeight + 16
    customTooltipFrame:SetSize(textWidth, textHeight)
end

local tooltipPreventerFrame = CreateFrame("Frame")
tooltipPreventerFrame:SetScript("OnUpdate", function(self, elapsed)
    if tooltipVisible and not tooltipLocked then
        DuplicateTooltip()
    end
end)

hooksecurefunc(GameTooltip, "Hide", function()
    if customTooltipFrame:IsShown() then
        customTooltipFrame:Show()
    end
end)

customTooltipFrame:SetScript("OnMouseWheel", OnMouseWheel)
