--- === plugins.finalcutpro.timeline.height ===
---
--- Shortcut for changing Final Cut Pro's Timeline Height

local require           = require

local timer             = require "hs.timer"
local eventtap          = require "hs.eventtap"

local deferred          = require "cp.deferred"
local fcp               = require "cp.apple.finalcutpro"
local i18n              = require "cp.i18n"

local doUntil           = timer.doUntil

local mod = {}

--- plugins.finalcutpro.timeline.height.changeTimelineClipHeightAlreadyInProgress -> boolean
--- Variable
--- Change timeline clip height already in progress.
mod.changeTimelineClipHeightAlreadyInProgress = false

--- plugins.finalcutpro.timeline.height.shiftClipHeight(direction) -> boolean
--- Function
--- Shift Clip Height
---
--- Parameters:
---  * None
---
--- Returns:
---  * `true` if successful otherwise `false`.
local function shiftClipHeight(direction)
    --------------------------------------------------------------------------------
    -- Find the Timeline Appearance Button:
    --------------------------------------------------------------------------------
    local appearance = fcp.timeline.toolbar.appearance
    if appearance then
        appearance:show()
        if direction == "up" then
            appearance.clipHeight:increment()
        else
            appearance.clipHeight:decrement()
        end
        return true
    else
        return false
    end
end

--- plugins.finalcutpro.timeline.height.changeTimelineClipHeightRelease() -> none
--- Function
--- Change Timeline Clip Height Release.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
local function changeTimelineClipHeightRelease()
    mod.changeTimelineClipHeightAlreadyInProgress = false
    fcp.timeline.toolbar.appearance:hide()
end

--- plugins.finalcutpro.timeline.height.changeTimelineClipHeight(direction) -> none
--- Function
--- Change the Timeline Clip Height
---
--- Parameters:
---  * direction - "up" or "down"
---
--- Returns:
---  * None
function mod.changeTimelineClipHeight(direction)

    --------------------------------------------------------------------------------
    -- Prevent multiple keypresses:
    --------------------------------------------------------------------------------
    if mod.changeTimelineClipHeightAlreadyInProgress then return end
    mod.changeTimelineClipHeightAlreadyInProgress = true

    --------------------------------------------------------------------------------
    -- Change Value of Zoom Slider:
    --------------------------------------------------------------------------------
    local result = shiftClipHeight(direction)

    --------------------------------------------------------------------------------
    -- Keep looping it until the key is released.
    --------------------------------------------------------------------------------
    if result then
        doUntil(function() return not mod.changeTimelineClipHeightAlreadyInProgress end, function()
            shiftClipHeight(direction)
        end, eventtap.keyRepeatInterval())
    end

end

local plugin = {
    id = "finalcutpro.timeline.height",
    group = "finalcutpro",
    dependencies = {
        ["finalcutpro.commands"]    = "fcpxCmds",
    }
}

function plugin.init(deps)
    --------------------------------------------------------------------------------
    -- Only load plugin if Final Cut Pro is supported:
    --------------------------------------------------------------------------------
    if not fcp:isSupported() then return end

    --------------------------------------------------------------------------------
    -- Keyboard Actions:
    --------------------------------------------------------------------------------
    local fcpxCmds = deps.fcpxCmds
    fcpxCmds
        :add("cpChangeTimelineClipHeightUp")
        :whenActivated(function() mod.changeTimelineClipHeight("up") end)
        :whenReleased(function() changeTimelineClipHeightRelease() end)
        :activatedBy():ctrl():option():cmd("=")
        :titled(i18n("timelineClipHeight") .. " " .. i18n("increase") .. " (" .. i18n("keyboardShortcut") .. ")")
        :subtitled(i18n("holdDownShortcutKeyToRepeatAction"))

    fcpxCmds
        :add("cpChangeTimelineClipHeightDown")
        :whenActivated(function() mod.changeTimelineClipHeight("down") end)
        :whenReleased(function() changeTimelineClipHeightRelease() end)
        :activatedBy():ctrl():option():cmd("-")
        :titled(i18n("timelineClipHeight") .. " " .. i18n("decrease") .. " (" .. i18n("keyboardShortcut") .. ")")
        :subtitled(i18n("holdDownShortcutKeyToRepeatAction"))

    --------------------------------------------------------------------------------
    -- Non-Keyboard Actions (such as MIDI):
    --------------------------------------------------------------------------------
    local closeAppearancePopup = deferred.new(1):action(function()
        fcp.timeline.toolbar.appearance:hide()
    end)
    fcpxCmds
        :add("timelineClipHeightIncrease")
        :whenActivated(function()
            local appearance = fcp.timeline.toolbar.appearance
            appearance:show()
            appearance.clipHeight:increment()
            closeAppearancePopup()
        end)
        :titled(i18n("timelineClipHeight") .. " " .. i18n("increase"))

    fcpxCmds
        :add("timelineClipHeightDecrease")
        :whenActivated(function()
            local appearance = fcp.timeline.toolbar.appearance
            appearance:show()
            appearance.clipHeight:decrement()
            closeAppearancePopup()
        end)
        :titled(i18n("timelineClipHeight") .. " " .. i18n("decrease"))

    return mod
end

return plugin
