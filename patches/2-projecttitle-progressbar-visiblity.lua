--[[ --
Patch for ProjectTitle to show progress bars how I want:
* Show progress bar always, even if hide_file_info == false
* Except, hide the progress bar if new/finished/abandoned (only show if reading)
--]] --

local userpatch = require("userpatch")
local BookList = require("ui/widget/booklist")

local function patchProjectTitleShowProgressBar(plugin)
  local ptutil = require("ptutil")
  local original_showProgressBar = ptutil.showProgressBar
  function ptutil.showProgressBar(pages)
    local est_page_count, show_progress_bar = original_showProgressBar(pages)

    -- Get self from caller via debug
    -- self will be an instance of either MosaicMenuItem or ListMenuItem
    -- Use self.bookpath to find the current book for this progress bar
    local self_name, self = debug.getlocal(2, 1) -- get first parameter (always self) to caller function
    if self_name ~= "self" or not type(self) == "table" or not self.filepath then
      -- should be unreachable
      return est_page_count, show_progress_bar
    end
    -- we could try to read book_info from self, but BookList does caching anyway, this is fine:
    local book_info = BookList.getBookInfo(self.filepath)
    local status = book_info.status

    -- always show progress bar (always, don't hide for hide_file_info or other settings)
    show_progress_bar = est_page_count ~= nil
    -- hide progress bar if status is not "reading"
    show_progress_bar = show_progress_bar and status == "reading"    

    return est_page_count, show_progress_bar
  end
end

userpatch.registerPatchPluginFunc("coverbrowser", patchProjectTitleShowProgressBar)
