--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                    C O M M A N D     S E T     P A N E L                   --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === core.welcome.panels.commandset  ===
---
--- Command Set Panel Welcome Screen.

--------------------------------------------------------------------------------
-- EXTENSIONS:
--------------------------------------------------------------------------------
local log										= require("hs.logger").new("commandset")

local image										= require("hs.image")
local timer										= require("hs.timer")
local toolbar                  					= require("hs.webview.toolbar")
local webview									= require("hs.webview")

local config									= require("cp.config")
local fcp										= require("cp.finalcutpro")
local generate									= require("cp.web.generate")
local generate									= require("cp.web.generate")
local template									= require("cp.template")

--------------------------------------------------------------------------------
-- THE MODULE:
--------------------------------------------------------------------------------
local mod = {}

	--------------------------------------------------------------------------------
	-- CONTROLLER CALLBACK:
	--------------------------------------------------------------------------------
	local function controllerCallback(message)

		-- log.df("Intro Panel Callback Result: %s", hs.inspect(message))

		local result = message["body"][1]
		if result == "commandsetQuit" then
			config.application():kill()
		elseif result == "commandsetSkip" then
			mod.manager.nextPanel(mod._priority)
		elseif result == "commandsetContinue" then

			local result = mod.shortcuts.enableHacksShortcuts()

			log.df("enableHacksShortcuts result: %s", result)

			if result then
				if fcp:isRunning() then fcp:restart() end
				config.set("enableHacksShortcutsInFinalCutPro", true)
				mod.manager.nextPanel(mod._priority)
				timer.doAfter(0.1, function() mod.manager.webview:hswindow():focus() end)
			end

		end

	end

	--------------------------------------------------------------------------------
	-- GENERATE CONTENT:
	--------------------------------------------------------------------------------
	local function generateContent()

		generate.setWebviewLabel(mod.webviewLabel)

		local result = [[
			<p>]] .. i18n("commandSetText") .. [[</p>
						<style>
				p.uiItem {
					display:inline;
					padding-left: 10px;
				}
			</style>
			<p>]] .. generate.button({title = i18n("continue")}, "commandsetContinue") .. " " .. generate.button({title = i18n("skip")}, "commandsetSkip") .. " " .. generate.button({title = i18n("quit")}, "commandsetQuit") .. "</p>"

		return result

	end

	--------------------------------------------------------------------------------
	-- INITIALISE MODULE:
	--------------------------------------------------------------------------------
	function mod.init(deps)

		mod.webviewLabel = deps.manager.getLabel()

		mod._id 			= "commandset"
		mod._priority		= 50
		mod._contentFn		= generateContent
		mod._callbackFn 	= controllerCallback

		mod.manager = deps.manager
		mod.shortcuts = deps.shortcuts

		mod.manager.addPanel(mod._id, mod._priority, mod._contentFn, mod._callbackFn)

		return mod

	end

--------------------------------------------------------------------------------
-- THE PLUGIN:
--------------------------------------------------------------------------------
local plugin = {
	id				= "core.welcome.panels.commandset",
	group			= "core",
	dependencies	= {
		["core.welcome.manager"]					= "manager",
		["finalcutpro.hacks.shortcuts"] 			= "shortcuts",
	}
}

--------------------------------------------------------------------------------
-- INITIALISE PLUGIN:
--------------------------------------------------------------------------------
function plugin.init(deps)
	return mod.init(deps)
end

return plugin