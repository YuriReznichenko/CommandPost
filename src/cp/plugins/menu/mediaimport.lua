local settings					= require("hs.settings")

local metadata					= require("cp.metadata")

--- The SHORTCUTS menu section.

local PRIORITY = 1000

local SETTING = metadata.settingsPrefix .. ".menubarMediaImportEnabled"

local function isSectionDisabled()
	local setting = settings.get(SETTING)
	if setting ~= nil then
		return not setting
	else
		return false
	end
end

local function toggleSectionDisabled()
	local menubarEnabled = settings.get(SETTING)
	settings.set(SETTING, not menubarEnabled)
end

--- The Plugin
local plugin = {}

plugin.dependencies = {
	["cp.plugins.menu.manager"] 				= "manager",
	["cp.plugins.menu.preferences.menubar"] 	= "menubar",
}

function plugin.init(dependencies)
	-- Create the 'SHORTCUTS' section
	local shortcuts = dependencies.manager.addSection(PRIORITY)

	-- Disable the section if the shortcuts option is disabled
	shortcuts:setDisabledFn(isSectionDisabled)

	-- Add the separator and title for the section.
	shortcuts:addSeparator(0)
		:addItem(1, function()
			return { title = string.upper(i18n("mediaImport")) .. ":", disabled = true }
		end)

	-- Create the menubar preferences item
	dependencies.menubar:addItem(PRIORITY, function()
		return { title = i18n("show") .. " " .. i18n("mediaImport"),	fn = toggleSectionDisabled, checked = not isSectionDisabled()}
	end)

	return shortcuts
end

return plugin