-- The confirmation dialog in front of the two reset buttons, so its confirm button always reads "Reset". It opens on
-- the plugin build layer rather than in the small content or settings layer. When the dialog cannot be shown, the
-- reset runs unconfirmed so the button still works.

local Client = require("src/client")

local ConfirmDialog = {}

---@param options table { title, body, onConfirm = function() }
function ConfirmDialog.show(options)
    local parent = Client.pluginLayer()
    if parent == nil then
        options.onConfirm()
        return
    end
    local ok, err = pcall(function()
        prettyui.Confirm.new(parent, {
            title = options.title,
            body = options.body,
            confirmLabel = "Reset",
            confirmVariant = "negative",
            onConfirm = options.onConfirm,
        })
    end)
    if not ok then
        log("Blueprint Helper: confirm dialog failed: " .. tostring(err))
        options.onConfirm()
    end
end

return ConfirmDialog
