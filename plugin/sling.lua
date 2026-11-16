if vim.g.loaded_sling then
  return
end
vim.g.loaded_sling = true

-- defaults work without calling setup(); a setup() from the user config wins
local sling = require("sling")
if not sling.did_setup then
  sling.setup()
end
