--- === cp.apple.finalcutpro.main.Timeline ===
---
--- Timeline Module.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Logger:
--------------------------------------------------------------------------------
--local log								= require("hs.logger").new("timeline")

--------------------------------------------------------------------------------
-- Hammerspoon Extensions:
--------------------------------------------------------------------------------
local eventtap							= require("hs.eventtap")
local timer								= require("hs.timer")

--------------------------------------------------------------------------------
-- CommandPost Extensions:
--------------------------------------------------------------------------------
local axutils							= require("cp.ui.axutils")
local prop								= require("cp.prop")

local id								= require("cp.apple.finalcutpro.ids") "Timeline"

local EffectsBrowser					= require("cp.apple.finalcutpro.main.EffectsBrowser")
local PrimaryWindow						= require("cp.apple.finalcutpro.main.PrimaryWindow")
local SecondaryWindow					= require("cp.apple.finalcutpro.main.SecondaryWindow")
local TimelineContent					= require("cp.apple.finalcutpro.main.TimelineContents")
local TimelineToolbar					= require("cp.apple.finalcutpro.main.TimelineToolbar")

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local Timeline = {}

--- cp.apple.finalcutpro.main.Timeline.matches(element) -> boolean
--- Function
--- Checks to see if an element matches what we think it should be.
---
--- Parameters:
---  * element - An `axuielementObject` to check.
---
--- Returns:
---  * `true` if matches otherwise `false`.
function Timeline.matches(element)
    return element:attributeValue("AXRole") == "AXGroup"
       and axutils.childWith(element, "AXIdentifier", id "Contents") ~= nil
end

--- cp.apple.finalcutpro.main.Timeline.matchesMain(element) -> boolean
--- Function
--- Checks to see if an element matches what we think it should be.
---
--- Parameters:
---  * element - An `axuielementObject` to check.
---
--- Returns:
---  * `true` if matches otherwise `false`
function Timeline.matchesMain(element)
    return element:attributeValue("AXIdentifier") == id "Contents"
end

-- _findTimeline(...) -> window | nil
-- Function
-- Gets the Timeline UI.
--
-- Parameters:
--  * ... - Table of elements.
--
-- Returns:
--  * An `axuielementObject` or `nil`
function Timeline._findTimeline(...)
    for i = 1,select("#", ...) do
        local window = select(i, ...)
        if window then
            local ui = window:timelineGroupUI()
            if ui then
                local timeline = axutils.childMatching(ui, Timeline.matches)
                if timeline then return timeline end
            end
        end
    end
    return nil
end

--- cp.apple.finalcutpro.main.Timeline.new(app) -> Timeline
--- Constructor
--- Creates a new `Timeline` instance.
---
--- Parameters:
---  * app - The `cp.apple.finalcutpro` object.
---
--- Returns:
---  * A new `Timeline` object.
function Timeline.new(app)

    local o = prop.extend({
        _app = app,
    },	Timeline)

    local UI = prop(function(self)
        return axutils.cache(self, "_ui", function()
            return Timeline._findTimeline(app:secondaryWindow(), app:primaryWindow())
        end,
        Timeline.matches)
    end)

    prop.bind(o) {

        --- cp.apple.finalcutpro.main.Timeline.UI <cp.prop: hs._asm.axuielement; read-only>
        --- Field
        --- Returns the `axuielement` representing the 'timeline', or `nil` if not available.
        UI = UI,

        --- cp.apple.finalcutpro.main.Timeline.isOnSecondary <cp.prop: boolean; read-only>
        --- Field
        --- Checks if the Timeline is on the Secondary Display.
        isOnSecondary = UI:mutate(function(original)
            local ui = original()
            return ui ~= nil and SecondaryWindow.matches(ui:window())
        end),

        --- cp.apple.finalcutpro.main.Timeline.isOnPrimary <cp.prop: boolean; read-only>
        --- Field
        --- Checks if the Timeline is on the Primary Display.
        isOnPrimary = UI:mutate(function(original)
            local ui = original()
            return ui ~= nil and PrimaryWindow.matches(ui:window())
        end),

        --- cp.apple.finalcutpro.main.Timeline.isShowing <cp.prop: boolean; read-only>
        --- Field
        --- Checks if the Timeline is showing on either the Primary or Secondary display.
        isShowing = UI:mutate(function(original)
            local ui = original()
            return ui ~= nil and #ui > 0
        end),

        --- cp.apple.finalcutpro.main.Timeline.mainUI <cp.prop: hs._asm.axuielement; read-only>
        --- Field
        --- Returns the `axuielement` representing the 'timeline', or `nil` if not available.
        mainUI = UI:mutate(function(original, self)
            return axutils.cache(self, "_main", function()
                local ui = original()
                return ui and axutils.childMatching(ui, Timeline.matchesMain)
            end,
            Timeline.matchesMain)
        end),

        --- cp.apple.finalcutpro.main.Timeline.isPlaying <cp.prop: boolean>
        --- Field
        --- Is the timeline playing?
        isPlaying = app:viewer().isPlaying:mutate(function(original)
            return original()
        end),

        --- cp.apple.finalcutpro.main.Timeline.isLockedPlayhead <cp.prop: boolean>
        --- Field
        --- Is Playhead Locked?
        isLockedPlayhead = prop.new(function(self)
            return self._locked == true
        end),

        --- cp.apple.finalcutpro.main.Timeline.isLockedInCentre <cp.prop: boolean>
        --- Field
        --- Is Playhead Locked in the centre?
        isLockedInCentre = prop.new(function(self)
            return self._lockInCentre == true
        end),
    }

    -- These are bound separately because TimelineContents uses `UI` and `mainUI`
    prop.bind(o) {
        --- cp.apple.finalcutpro.main.Timeline.isLoaded <cp.prop: boolean; read-only>
        --- Field
        --- Checks if the Timeline has finished loading.
        isLoaded = o:contents().isLoaded,

        --- cp.apple.finalcutpro.main.Timeline.isFocused <cp.prop: boolean; read-only>
        --- Field
        --- Checks if the Timeline is the focused panel.
        isFocused = o:contents().isFocused,
    }

    -----------------------------------------------------------------------
    -- Watch for playing & stopping:
    -----------------------------------------------------------------------
    o.isPlaying:watch(function(isPlaying)
        o:update(isPlaying)
    end)

    return o
end

--- cp.apple.finalcutpro.main.Timeline:app() -> App
--- Method
--- Returns the app instance representing Final Cut Pro.
---
--- Parameters:
---  * None
---
--- Returns:
---  * App
function Timeline:app()
    return self._app
end

-----------------------------------------------------------------------
--
-- TIMELINE UI:
--
-----------------------------------------------------------------------

--- cp.apple.finalcutpro.main.Timeline:show() -> Timeline
--- Method
--- Show's the Timeline on the Primary Display.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `Timeline` object.
function Timeline:show()
    if not self:isShowing() then
        self:showOnPrimary()
    end
    return self
end

--- cp.apple.finalcutpro.main.Timeline:showOnPrimary() -> Timeline
--- Method
--- Show's the Timeline on the Primary Display.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `Timeline` object.
function Timeline:showOnPrimary()
    local menuBar = self:app():menu()

    -- if the timeline is on the secondary, we need to turn it off before enabling in primary
    if self:isOnSecondary() then
        menuBar:selectkMenu({"Window", "Show in Secondary Display", "Timeline"})
    end
    -- Then enable it in the primary
    if not self:isOnPrimary() then
        menuBar:selectMenu({"Window", "Show in Workspace", "Timeline"})
    end

    return self
end

--- cp.apple.finalcutpro.main.Timeline:showOnSecondary() -> Timeline
--- Method
--- Show's the Timeline on the Secondary Display.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `Timeline` object.
function Timeline:showOnSecondary()
    local menuBar = self:app():menu()

    -- if the timeline is on the secondary, we need to turn it off before enabling in primary
    if not self:isOnSecondary() then
        menuBar:selectMenu({"Window", "Show in Secondary Display", "Timeline"})
    end

    return self
end

--- cp.apple.finalcutpro.main.Timeline:hide() -> Timeline
--- Method
--- Hide's the Timeline (regardless of whether it was on the Primary or Secondary display).
---
--- Parameters:
---  * None
---
--- Returns:
---  * `Timeline` object.
function Timeline:hide()
    local menuBar = self:app():menu()
    -- Uncheck it from the primary workspace
    if self:isOnSecondary() then
        menuBar:selectMenu({"Window", "Show in Secondary Display", "Timeline"})
    end
    if self:isOnPrimary() then
        menuBar:selectMenu({"Window", "Show in Workspace", "Timeline"})
    end
    return self
end

-----------------------------------------------------------------------
--
-- CONTENT:
-- The Content is the main body of the timeline, containing the
-- Timeline Index, the Content, and the Effects/Transitions panels.
--
-----------------------------------------------------------------------

--- cp.apple.finalcutpro.main.Timeline:contents() -> TimelineContent
--- Method
--- Gets the Timeline Contents. The Content is the main body of the timeline,
--- containing the Timeline Index, the Content, and the Effects/Transitions panels.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `TimelineContent` object.
function Timeline:contents()
    if not self._content then
        self._content = TimelineContent.new(self)
    end
    return self._content
end

-----------------------------------------------------------------------
--
-- EFFECT BROWSER:
-- The (sometimes hidden) Effect Browser.
--
-----------------------------------------------------------------------

--- cp.apple.finalcutpro.main.Timeline:effects() -> EffectsBrowser
--- Method
--- Gets the (sometimes hidden) Effect Browser.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `EffectsBrowser` object.
function Timeline:effects()
    if not self._effects then
        self._effects = EffectsBrowser.new(self, EffectsBrowser.EFFECTS)
    end
    return self._effects
end

-----------------------------------------------------------------------
--
-- TRANSITIONS BROWSER:
-- The (sometimes hidden) Transitions Browser.
--
-----------------------------------------------------------------------

--- cp.apple.finalcutpro.main.Timeline:transitions() -> EffectsBrowser
--- Method
--- Gets the (sometimes hidden) Transitions Browser.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `EffectsBrowser` object.
function Timeline:transitions()
    if not self._transitions then
        self._transitions = EffectsBrowser.new(self, EffectsBrowser.TRANSITIONS)
    end
    return self._transitions
end

-----------------------------------------------------------------------
--
-- PLAYHEAD:
-- The timeline Playhead.
--
-----------------------------------------------------------------------

--- cp.apple.finalcutpro.main.Timeline:playhead() -> Playhead
--- Method
--- Gets the Timeline Playhead.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `Playhead` object.
function Timeline:playhead()
    return self:contents():playhead()
end

-----------------------------------------------------------------------
--
-- PLAYHEAD:
-- The Playhead that tracks under the mouse while skimming.
--
-----------------------------------------------------------------------

--- cp.apple.finalcutpro.main.Timeline:skimmingPlayhead() -> Playhead
--- Method
--- Gets the Playhead that tracks under the mouse while skimming.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `Playhead` object.
function Timeline:skimmingPlayhead()
    return self:contents():skimmingPlayhead()
end

-----------------------------------------------------------------------
--
-- TOOLBAR:
-- The bar at the top of the timeline.
--
-----------------------------------------------------------------------

--- cp.apple.finalcutpro.main.Timeline:toolbar() -> TimelineToolbar
--- Method
--- Gets the bar at the top of the timeline.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `TimelineToolbar` object.
function Timeline:toolbar()
    if not self._toolbar then
        self._toolbar = TimelineToolbar.new(self)
    end
    return self._toolbar
end

-----------------------------------------------------------------------
--
-- PLAYHEAD LOCKING:
-- If the playhead is locked, it will be kept as close to the middle
-- of the timeline view panel as possible at all times.
--
-----------------------------------------------------------------------

function Timeline:update(isPlaying)

    --------------------------------------------------------------------------------
    -- Stop the checker if the timeline isn't playing:
    --------------------------------------------------------------------------------
    if not isPlaying or not self._locked then
        if self._checker then
            self._checker:stop()
            self._checker = nil
        end
        return
    end

    --------------------------------------------------------------------------------
    -- Don't create multiple checkers:
    --------------------------------------------------------------------------------
    if self._checker and isPlaying then
        return
    end

    --------------------------------------------------------------------------------
    -- Lock in centre:
    --------------------------------------------------------------------------------
    local lockInCentre = self._lockInCentre

    --------------------------------------------------------------------------------
    -- Calculate the original offset of the playhead:
    --------------------------------------------------------------------------------
    local content = self:contents()
    local playhead = content:playhead()
    local viewFrame = content:viewFrame()
    if viewFrame then
        self._originalOffset = playhead:position() - viewFrame.x
        if lockInCentre or self._originalOffset <= 0 or self._originalOffset >= viewFrame.w then
            --------------------------------------------------------------------------------
            -- Align the playhead to the centre of the timeline view:
            --------------------------------------------------------------------------------
            self._originalOffset = math.floor(viewFrame.w/2)
        end
    end

    --------------------------------------------------------------------------------
    -- Create the 'check' function that will loop to keep the playhead in position:
    --------------------------------------------------------------------------------
    local checkFn = function()

        --------------------------------------------------------------------------------
        -- Timeline isn't visible:
        --------------------------------------------------------------------------------
        local contentFrame = content:viewFrame()
        local playheadPosition = playhead:position()
        if contentFrame == nil or playheadPosition == nil then
            return
        end

        --------------------------------------------------------------------------------
        -- Reset the original offset if the viewFrame gets too narrow:
        --------------------------------------------------------------------------------
        if self._originalOffset >= contentFrame.w then self._originalOffset = math.floor(contentFrame.w/2) end

        --------------------------------------------------------------------------------
        -- Track the timeline:
        --------------------------------------------------------------------------------
        local timelineFrame = content:timelineFrame()
        local scrollWidth = timelineFrame.w - contentFrame.w
        local scrollPoint = timelineFrame.x*-1 + playheadPosition - self._originalOffset
        local scrollTarget = scrollPoint/scrollWidth

        -----------------------------------------------------------------------
        -- Don't change timeline position if SHIFT key is pressed:
        -----------------------------------------------------------------------
        local modifiers = eventtap.checkKeyboardModifiers()
        if modifiers and not modifiers["shift"] then
            content:scrollHorizontalTo(scrollTarget)
        end

    end

    --------------------------------------------------------------------------------
    -- Start the timer:
    --------------------------------------------------------------------------------
    self._checker = timer.doEvery(0.001, checkFn)
end

--- cp.apple.finalcutpro.main.Timeline:lockPlayhead() -> self
--- Method
--- Locks the playhead on-screen.
---
--- Parameters:
---  * None
---
--- Returns:
---  * Self
function Timeline:lockPlayhead()
    self._locked = true
    return self
end

--- cp.apple.finalcutpro.main.Timeline:unlockPlayhead() -> self
--- Method
--- Unlock Playhead.
---
--- Parameters:
---  * None
---
--- Returns:
---  * Self
function Timeline:unlockPlayhead()
    self._locked = false
    return self
end

--- cp.apple.finalcutpro.main.Timeline:lockInCentre(value) -> self
--- Method
--- Sets whether or not the playhead is locked in the centre.
---
--- Parameters:
---  * value - `true` if locked in the centre, otherwise `false`.
---
--- Returns:
---  * Self
function Timeline:lockInCentre(value)
    self._lockInCentre = value == true or false
    return self
end

return Timeline
