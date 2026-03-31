--[[
Set/unset reading status to "complete" (finshed) automatically if `percent_finished` is 100%

* Will also _remove_ complete status from books if they are not at 100% `percent_finished`
* Abandoned/on-hold status should be ignored and not modified.
* This status _probably_ won't persist to the sidecar (but might, no promises).

Implemented as a patch to `DocSettings.readSetting()` for the key `summary`.
--]]


local DocSettings = require("docsettings")
local FileChooser = require("ui/widget/filechooser")
local filemanagerutil = require("apps/filemanager/filemanagerutil")


local readSetting = DocSettings.readSetting
DocSettings.readSetting = function (self, key, default)
    local setting = readSetting(self, key, default)

    if setting and key == "summary" then
        local percent_finished = readSetting(self, "percent_finished")
        if setting.status == "reading" and percent_finished == 1.0 then
            setting.status = "complete"
        elseif setting.status == "complete" and percent_finished ~= 1.0 then
            setting.status = "reading"
        end
    end

    return setting
end
