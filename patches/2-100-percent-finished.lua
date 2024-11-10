local DocSettings = require("docsettings")
local FileChooser = require("ui/widget/filechooser")
local filemanagerutil = require("apps/filemanager/filemanagerutil")

-- Set/unset status to complete automatically when status is read if percent_finished is 100%
-- NOTE: Will remove complete status from books if they are not at 100% percent_finished
-- NOTE: This status _probably_ won't persist to the sidecar (but maybe will)

local readSetting = DocSettings.readSetting
DocSettings.readSetting = function (self, key, default)
    local setting = readSetting(self, key, default)

    if setting and key == "summary" then
        local percent_finished = readSetting(self, "percent_finished")
        if percent_finished == 1.0 then
            setting.status = "complete"
        elseif setting.status == "complete" and percent_finished ~= 1.0 then
            setting.status = "reading"
        end
    end

    return setting
end

-- not easily patchable, make status in filebrowser bold when complete:
--
-- if not BookInfoManager:getSetting("hide_page_info") then
--     local wpageinfo = TextWidget:new{
--         text = pages_str,
--         face = Font:getFace("cfont", fontsize_info),
--         fgcolor = fgcolor,
--         bold = status == "complete",
--     }
--     table.insert(wright_items, wpageinfo)
-- end
