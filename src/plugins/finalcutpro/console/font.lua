--- === plugins.finalcutpro.console.font ===
---
--- Final Cut Pro Font Console

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Logger:
--------------------------------------------------------------------------------
local log				= require("hs.logger").new("fontConsole")

--------------------------------------------------------------------------------
-- Hammerspoon Extensions:
--------------------------------------------------------------------------------
local inspect           = require("hs.inspect")
local styledtext        = require("hs.styledtext")

--------------------------------------------------------------------------------
-- CommandPost Extensions:
--------------------------------------------------------------------------------
local config            = require("cp.config")
local dialog            = require("cp.dialog")
local fcp               = require("cp.apple.finalcutpro")
local just              = require("cp.just")
local tools             = require("cp.tools")

--------------------------------------------------------------------------------
-- Local Lua Functions:
--------------------------------------------------------------------------------
local execute           = hs.execute

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local mod = {}

--- plugins.finalcutpro.console.font.FONT_EXTENSIONS -> table
--- Constant
--- Table of support font file extensions.
mod.FONT_EXTENSIONS = {
    "ttf",
    "otf",
    "ttc",
}

--- plugins.finalcutpro.console.font.IGNORE_FONTS -> table
--- Constant
--- Fonts to ignore as they're used internally by Final Cut Pro or macOS.
mod.IGNORE_FONTS = {
    ["FCMetro34"] = true -- Final Cut Pro Internal Font not available in Final Cut Pro Inspector.
}

--- plugins.finalcutpro.console.font.fontLookup -> table
--- Variable
--- Provides a lookup between Font Names and their position in the Final Cut Pro dropdown menu.
mod.fontLookup = {}

--- plugins.finalcutpro.console.font.fontCount -> number
--- Variable
--- The number of fonts available.
mod.fontCount = 0

-- getFinalCutProFontPaths() -> none
-- Function
-- Gets a table of all the fonts currently used by Final Cut Pro.
--
-- Parameters:
--  * None
--
-- Returns:
--  * Table
local function getFinalCutProFontPaths()
    local result = {}
    local fcpApp = fcp:application()
    local processID = fcpApp and fcpApp:pid()
    if processID then
        local o, s, t, r = execute("lsof -p " .. processID)
        if o and s and t == "exit" and r == 0 then
            local lines = tools.lines(o)
            for _, line in pairs(lines) do
                for _, ext in pairs(mod.FONT_EXTENSIONS) do
                    if string.find("." .. string.lower(line), "." .. ext) then
                        local _, position = string.find(line, " /")
                        if position then
                            local path = string.sub(line, position)
                            if path then
                                table.insert(result, path)
                            end
                        end
                    end
                end
            end
        else
            log.ef("Failed to run `lsof` on Final Cut Pro.")
        end
    end
    return result
end

-- loadFinalCutProFonts() -> none
-- Function
-- Loads all of Final Cut Pro's Fonts into CommandPost.
--
-- Parameters:
--  * None
--
-- Returns:
--  * Table
function loadFinalCutProFonts()
    local fontPaths = getFinalCutProFontPaths()
    for _, file in pairs(fontPaths) do
        if tools.doesFileExist(file) then
            local result = styledtext.loadFont(file)
        end
    end
end

--- plugins.finalcutpro.console.font.onActivate() -> none
--- Function
--- Handles Console Activations.
---
--- Parameters:
---  * handler - Handler instance.
---  * action - Action table.
---  * text - Selected text from the Console.
---
--- Returns:
---  * None
function mod.onActivate(_, action)
    if action and action.fontName then

        --------------------------------------------------------------------------------
        -- Make sure Final Cut Pro has been scanned for Fonts:
        --------------------------------------------------------------------------------
        if not mod._scannedFinalCutPro then
            mod._handler:reset(true)
        end

        --------------------------------------------------------------------------------
        -- Get Font Name from action:
        --------------------------------------------------------------------------------
        local fontName = action.fontName

        --------------------------------------------------------------------------------
        -- Get font ID from lookup table:
        --------------------------------------------------------------------------------
        local id = mod.fontLookup[fontName]

        --------------------------------------------------------------------------------
        -- Make sure Inspector is open:
        --------------------------------------------------------------------------------
        local inspector = fcp:inspector()
        inspector:show()
        if not just.doUntil(function() return inspector:isShowing() end) then
            dialog.displayErrorMessage("Failed to open the Inspector.")
            return
        end

        --------------------------------------------------------------------------------
        -- Make sure the Text Inspector is open:
        --------------------------------------------------------------------------------
        local text = inspector:text()
        text:show()
        if not just.doUntil(function() return text:isShowing() end) then
            dialog.displayMessage(i18n("pleaseSelectATitle"))
            return
        end

        --------------------------------------------------------------------------------
        -- Make sure we can get the currently selected font:
        --------------------------------------------------------------------------------
        local f = text:basic():font()
        if not f or not f.family then
            dialog.displayErrorMessage(string.format("Failed to get Font Dropdown: %s", f))
            return
        end

        --------------------------------------------------------------------------------
        -- Get the Font Family UI:
        --------------------------------------------------------------------------------
        local ui = f.family:UI()
        if not ui then
            dialog.displayErrorMessage(string.format("Failed to get Font Family UI: %s", ui))
            return
        end

        --------------------------------------------------------------------------------
        -- Activate the drop down:
        --------------------------------------------------------------------------------
        ui:performAction("AXPress")
        local menu = just.doUntil(function()
            return ui:attributeValue("AXChildren") and ui:attributeValue("AXChildren")[1]
        end)
        if not menu then
            dialog.displayErrorMessage(string.format("Failed to get Font Family UI: %s", ui))
            return
        end

        --------------------------------------------------------------------------------
        -- Get the kids:
        --------------------------------------------------------------------------------
        local kids = menu:attributeValue("AXChildren")
        if not kids then
            dialog.displayErrorMessage(string.format("Failed to get Font Kids: %s", kids))
            return
        end

        --------------------------------------------------------------------------------
        -- Compare the number of items in the drop down to what we've cached:
        --------------------------------------------------------------------------------
        local fontCount = mod.fontCount or 0
        local kidsCount = #kids or 0
        local difference = kidsCount - fontCount
        if difference == 0 then
            if menu[id] then
                --------------------------------------------------------------------------------
                -- Click on chosen font:
                --------------------------------------------------------------------------------
                local result = menu[id]:performAction("AXPress")
                if result then
                    return
                end
            end
        else
            --------------------------------------------------------------------------------
            -- Wrong number of fonts comparing Console with Popup:
            --------------------------------------------------------------------------------
            dialog.displayErrorMessage(string.format("An error has occured where the number of fonts in the CommandPost (%s) is different to the number of fonts in Final Cut Pro (%s).\n\nPlease try restarting Final Cut Pro & CommandPost and try again.", fontCount, kidsCount))
        end
    else
        --------------------------------------------------------------------------------
        -- Bad Action:
        --------------------------------------------------------------------------------
        dialog.displayErrorMessage("Something went wrong with the action you supplied. Try re-applying the action and try again.")
    end
end

--- plugins.finalcutpro.console.font.show() -> none
--- Function
--- Shows the Font Console.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function mod.show()

    --------------------------------------------------------------------------------
    -- Show the Inspector:
    --------------------------------------------------------------------------------
    local inspector = fcp:inspector()
    inspector:show()
    if not just.doUntil(function() return inspector:isShowing() end) then
        dialog.displayErrorMessage("Failed to open the Inspector.")
        return
    end

    --------------------------------------------------------------------------------
    -- Make sure there's a "Text" tab:
    --------------------------------------------------------------------------------
    if not inspector:tabAvailable("Text") then
        dialog.displayMessage(i18n("pleaseSelectATitle"))
        return
    end

    --------------------------------------------------------------------------------
    -- Setup Activator:
    --------------------------------------------------------------------------------
    if not mod.activator then
        mod.activator = mod.actionmanager.getActivator("finalcutpro.font")
        mod.activator:preloadChoices()
        mod.activator:allowHandlers("fcpx_fonts")
        mod.activator:onActivate(mod.onActivate)
    end

    --------------------------------------------------------------------------------
    -- Show the Activator:
    --------------------------------------------------------------------------------
    mod.activator:show()

end

--- plugins.finalcutpro.commands.actions.onChoices([choices]) -> none
--- Function
--- Adds available choices to the selection.
---
--- Parameters:
--- * `choices` - The optional `cp.choices` to add choices to.
---
--- Returns:
--- * None
function mod.onChoices(choices)

    --------------------------------------------------------------------------------
    -- Load Final Cut Pro Fonts:
    --------------------------------------------------------------------------------
    if fcp:isRunning() then
        mod._scannedFinalCutPro = true
        loadFinalCutProFonts()
    end

    --------------------------------------------------------------------------------
    -- Add Fonts to Table:
    --------------------------------------------------------------------------------
    local fonts = {}
    local newFonts = {}
    for _, fontName in pairs(styledtext.fontNames()) do
        if string.sub(fontName, 1, 1) ~= "." then
            local fontInfo = styledtext.fontInfo(fontName)
            local familyName = fontInfo and fontInfo.familyName
            if familyName then
                table.insert(fonts, familyName)
            end
        end
    end

    --------------------------------------------------------------------------------
    -- Remove Duplicate, Ignored & Hidden Fonts:
    --------------------------------------------------------------------------------
    local hash = {}
    for _,fontName in ipairs(fonts) do
        if (not hash[fontName]) then
            if string.sub(fontName, 1, 1) ~= "." and mod.IGNORE_FONTS[fontName] == nil then
                newFonts[#newFonts+1] = fontName
                hash[fontName] = true
            end
        end
    end

    --------------------------------------------------------------------------------
    -- Sort and add to table:
    --------------------------------------------------------------------------------
    mod.fontLookup = {}
    table.sort(newFonts, function(a, b) return string.lower(a) < string.lower(b) end)
    for id,fontName in pairs(newFonts) do
            --------------------------------------------------------------------------------
            -- Add ID to Font Lookup Table:
            --------------------------------------------------------------------------------
            mod.fontLookup[fontName] = id

            --------------------------------------------------------------------------------
            -- Add choice to Activator:
            --------------------------------------------------------------------------------
            if choices then
                local name = styledtext.new(fontName, {font = { name = fontName, size = 18 } })
                choices
                    :add(name)
                    :id(fontName)
                    :params({
                        fontName = fontName,
                    })
            end
            print(fontName)
    end

    --------------------------------------------------------------------------------
    -- Store the font count:
    --------------------------------------------------------------------------------
    mod.fontCount = newFonts and #newFonts or 0

end

--- plugins.finalcutpro.commands.actions.getId(action) -> string
--- Function
--- Get ID.
---
--- Parameters:
--- * action - The action table.
---
--- Returns:
--- * The ID as a string.
function mod.getId(action)
    return string.format("%s:%s", "fcpx_fonts", action.id)
end

--- plugins.finalcutpro.commands.actions.onExecute(action) -> none
--- Function
--- On Execute.
---
--- Parameters:
--- * action - The action table.
---
--- Returns:
--- * None
function mod.onExecute(action)
    if not mod._consoleFontCount then mod.onChoices() end
    mod.onActivate(nil, action)
end

--------------------------------------------------------------------------------
--
-- THE PLUGIN:
--
--------------------------------------------------------------------------------
local plugin = {
    id              = "finalcutpro.console.font",
    group           = "finalcutpro",
    dependencies    = {
        ["finalcutpro.commands"]        = "fcpxCmds",
        ["core.action.manager"]         = "actionmanager",
    }
}

--------------------------------------------------------------------------------
-- INITIALISE PLUGIN:
--------------------------------------------------------------------------------
function plugin.init(deps)

    --------------------------------------------------------------------------------
    -- Initialise Module:
    --------------------------------------------------------------------------------
    mod.actionmanager = deps.actionmanager

    --------------------------------------------------------------------------------
    -- Create new Font Handler:
    --------------------------------------------------------------------------------
    mod._handler = mod.actionmanager.addHandler("fcpx_fonts", "fcpx")
        :onChoices(mod.onChoices)
        :onExecute(mod.onExecute)
        :onActionId(mod.getId)

    --------------------------------------------------------------------------------
    -- Add the command trigger:
    --------------------------------------------------------------------------------
    deps.fcpxCmds:add("cpFontConsole")
        :groupedBy("commandPost")
        :whenActivated(mod.show)

    return mod

end

return plugin
