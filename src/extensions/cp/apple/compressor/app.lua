--- === cp.apple.compressor.app ===
---
--- The `cp.app` for Apple's Compressor.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- CommandPost Extensions:
--------------------------------------------------------------------------------
local app           = require("cp.app")

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local fcpApp = app.forBundleID("com.apple.Compressor")
return fcpApp