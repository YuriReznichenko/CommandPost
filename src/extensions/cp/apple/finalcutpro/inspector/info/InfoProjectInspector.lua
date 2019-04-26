--- === cp.apple.finalcutpro.inspector.info.InfoProjectInspector ===
---
--- Info Inspector Module when a Project is selected.

local require               = require

--local log                   = require "hs.logger".new "infoInspect"

local axutils               = require "cp.ui.axutils"
local BasePanel             = require "cp.apple.finalcutpro.inspector.BasePanel"
local Button                = require "cp.ui.Button"
local go                    = require "cp.rx.go"
local IP                    = require "cp.apple.finalcutpro.inspector.InspectorProperty"
local strings               = require "cp.apple.finalcutpro.strings"

local Do                    = go.Do
local WaitUntil             = go.WaitUntil

local hasProperties         = IP.hasProperties
local staticText            = IP.staticText
local textField             = IP.textField

local childrenWithRole      = axutils.childrenWithRole
local childWithRole         = axutils.childWithRole
local withAttributeValue    = axutils.withAttributeValue
local withRole              = axutils.withRole

local InfoProjectInspector = BasePanel:subclass("InfoProjectInspector")

--- cp.apple.finalcutpro.inspector.info.InfoProjectInspector.matches(element) -> boolean
--- Function
--- Checks to see if an element matches what we think it should be.
---
--- Parameters:
---  * element - An `axuielementObject` to check.
---
--- Returns:
---  * `true` if matches otherwise `false`
function InfoProjectInspector.static.matches(element)
    local root = BasePanel.matches(element) and withRole(element, "AXGroup")
    local scrollArea = root and #childrenWithRole(root, "AXStaticText") >= 2 and childWithRole(root, "AXScrollArea")
    return scrollArea and withAttributeValue(scrollArea, "AXDescription", strings:find("FFInspectorModuleProjectPropertiesScrollViewAXDescription")) or false
end

--- cp.apple.finalcutpro.inspector.info.InfoProjectInspector.new(parent) -> InfoProjectInspector object
--- Constructor
--- Creates a new InfoProjectInspector object
---
--- Parameters:
---  * `parent`     - The parent
---
--- Returns:
---  * A InfoProjectInspector object
function InfoProjectInspector:initialize(parent)
    BasePanel.initialize(self, parent, "ProjectInfo")

    hasProperties(self, self.propertiesUI) {
        location           = staticText "FFInspectorModuleProjectPropertiesLocation",
        library            = staticText "FFInspectorModuleProjectPropertiesLibrary",
        event              = staticText "FFInspectorModuleProjectPropertiesEvent",
        lastModified       = staticText "FFInspectorModuleProjectPropertiesLastModified",
        notes              = textField "FFInspectorModuleProjectPropertiesNotes",
    }
end

--- cp.apple.finalcutpro.inspector.info.InfoProjectInspector:propertiesUI() -> hs._asm.axuielement object
--- Method
--- Returns the `hs._asm.axuielement` object for the Properties UI.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A `hs._asm.axuielement` object.
function InfoProjectInspector.lazy.prop:propertiesUI()
    return self.UI:mutate(function(original)
        return axutils.cache(self, "_properties", function()
            return axutils.childWithRole(original(), "AXScrollArea")
        end)
    end)
end

--- cp.apple.finalcutpro.inspector.info.InfoProjectInspector:modify() -> Button
--- Method
--- Gets the Modify Project button in the Info Inspector.
---
--- Parameters:
---  * None
---
--- Returns:
---  * An `Button` object.
function InfoProjectInspector.lazy.method:modify()
    return Button(self, function()
        local ui = self:UI()
        local button = childWithRole(ui, "AXButton")
        if button and button:attributeValue("AXTitle") == strings:find("FFInspectorMediaHeaderControllerButtonEdit") then
            return button
        end
    end)
end

--- cp.apple.finalcutpro.inspector.info.InfoProjectInspector.isShowing <cp.prop: boolean; read-only; live?>
--- Field
--- If `true`, the Project Info Inspector is showing on screen.
function InfoProjectInspector.lazy.prop:isShowing()
    return self.UI:ISNOT(nil)
end

--- cp.apple.finalcutpro.inspector.info.InfoProjectInspector:doShow() -> cp.rx.go.Statment
--- Method
--- A [Statement](cp.rx.go.Statement.md) that shows the panel.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `Statement`, resolving to `true` if successful and sending an error if not.
function InfoProjectInspector.lazy.method:doShow()
    return Do(self:app():doSelectMenu({"Window", "Project Properties…"}))
    :Then(
        WaitUntil(self.isShowing)
        :TimeoutAfter(3000, "The info panel didn't show.")
    )
    :Label(self:panelType() .. ":doShow")
end

return InfoProjectInspector
