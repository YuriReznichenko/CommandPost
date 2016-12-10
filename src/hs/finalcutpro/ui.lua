--- === hs.finalcutpro ===
---
--- Controls for Final Cut Pro
---
--- Thrown together by:
---   David Peterson (https://randomphotons.com/)

local ax 									= require("hs._asm.axuielement")
local log									= require("hs.logger").new("fcpui")

UI = {}
    
function UI:new(element)
  o = {element = element}
  setmetatable(o, self)
  self.__index = self
  return o
end

--- hs.finalcutpro.ui:childCount() -> number
--- Function
--- Returns a UI pointing at the child with the named attribute and value, 
--- or nil if the element cannot have children.
---
--- Parameters:
---  * N/A
---
--- Returns:
---  * The number of children
---
function UI:childCount()
	return self.element:attributeValueCount("AXChildren")
end

--- hs.finalcutpro.ui:childAt(index) -> UI
--- Function
--- Returns a UI pointing at the child with the specified index.
---
--- Parameters:
---  * index - the child number to retrieve.
---
--- Returns:
---  * The child UI, or nil if none matched.
---
function UI:childAt(index)
	if self:childCount() >= index then
		local element = self.element:attributeValue("AXChildren")[index]
		if #element == 1 then
			element = element[1]
		end
		return UI:new(element)
	end
	return nil	
end

--- hs.finalcutpro.ui:childWith(attrName, attrValue) -> UI
--- Function
--- Returns a UI pointing at the child with the named attribute and value, or nil if none ws found.
---
--- Parameters:
---  * attrName - The attribute name
---  * attrValue - The attribute value
---
--- Returns:
---  * The child UI, or nil if none matched.
---
function UI:childWith(attrName, attrValue)
	local childCount = self:childCount()
	for i=1, childCount do
		local child = self.element:attributeValue("AXChildren")[i]
		if child:attributeValue(attrName) == attrValue then
			return UI:new(child)
		end
	end
	return nil
end

--- hs.finalcutpro.ui:childWithRole(roleName) -> UI
--- Function
--- Returns a UI pointing at the child with the named role, or nil if none ws found.
---
--- Parameters:
---  * roleName - The role to match
---
--- Returns:
---  * The child UI
---
function UI:childWithRole(roleName)
	return self:childWith("AXRole", roleName)
end

--- hs.finalcutpro.ui:childWithRole(roleName) -> UI
--- Function
--- Returns a UI pointing at the child with the named role, or nil if none ws found.
---
--- Parameters:
---  * roleName - The role to match
---
--- Returns:
---  * The child UI
---
function UI:childWithTitle(title)
	return self:childWith("AXTitle", title)
end

--- hs.finalcutpro.ui:parent(roleName) -> UI
--- Function
--- Returns a UI pointing at the parent, or nil if none exists.
---
--- Parameters:
---  * N/A
---
--- Returns:
---  * The parent UI
---
function UI:parent()
	local parent = self:attribute("AXParent")
	if parent then
		return UI:new(parent)
	else
		return nil
	end
end

--- hs.finalcutpro.ui:attribute(name) -> <value>
--- Function
--- Returns the value of the named attribute, if it exists.
---
--- Parameters:
---  * name - the attribute name
---
--- Returns:
---  * The attribute value
---
function UI:attribute(name)
	return self.element:attributeValue(name)
end

--- hs.finalcutpro.ui:press() -> UI
--- Function
--- Attempts to press the UI element.
---
--- Parameters:
---  * N/A
---
--- Returns:
---  * the same UI element
---
function UI:press()
  self.element:performAction("AXPress")
  return self
end

return UI