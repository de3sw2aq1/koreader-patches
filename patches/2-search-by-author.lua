--[[ --
Adds "Search by author" to the long-press file dialog.
When tapped, triggers a file search from the home directory using the book's first author name as the search string.

This only works because I include author name in filename, and it still has false positives.

I thought about doing a Calibre metadata search for author, it probably will be more accurate.
But I don't like the Calibre search results UI as much, so this is good enough for me.

Mostly LLM-written, but I tested it works. Not sure all code paths were tested though.
--]] --
local FileManager = require("apps/filemanager/filemanager")
local _ = require("gettext")

local orig_FileManager_init = FileManager.init
FileManager.init = function (self)
    orig_FileManager_init(self)
    self:addFileDialogButtons("search_by_author", function(file, is_file, book_props)
        if not is_file then return end

        return {
            {
                text = _("Search by author"),
                enabled = true,
                callback = function()
                    -- Close the long-press dialog
                    local menu = self.file_chooser
                    if menu and menu.file_dialog then
                        local UIManager = require("ui/uimanager")
                        UIManager:close(menu.file_dialog)
                    end

                    -- Get the author string
                    local authors
                    if book_props and book_props.authors and book_props.authors ~= "" then
                        authors = book_props.authors
                    else
                        -- Try to get from doc_settings if book was previously opened
                        local BookList = require("ui/widget/booklist")
                        if BookList.hasBookBeenOpened(file) then
                            local doc_settings = BookList.getDocSettings(file)
                            local props = doc_settings:readSetting("doc_props")
                            if props and props.authors and props.authors ~= "" then
                                authors = props.authors
                            end
                        end
                    end

                    if not authors then
                        local InfoMessage = require("ui/widget/infomessage")
                        local UIManager = require("ui/uimanager")
                        UIManager:show(InfoMessage:new{
                            text = _("No author metadata available for this book."),
                        })
                        return
                    end

                    -- Authors may be newline-separated; pick the first one
                    local author = authors:match("^([^\n]+)")
                    if not author or author == "" then
                        author = authors
                    end

                    -- Trigger a file search from the home directory
                    local FileSearcher = require("apps/filemanager/filemanagerfilesearcher")
                    FileSearcher.search_string = author
                    FileSearcher.search_path = G_reader_settings:readSetting("home_dir")
                        or require("apps/filemanager/filemanagerutil").getDefaultDir()
                    -- Invalidate cache so the search runs fresh
                    FileSearcher.search_hash = nil

                    local Trapper = require("ui/trapper")
                    Trapper:wrap(function()
                        self.filesearcher:doSearch()
                    end)
                end,
            },
        }
    end)
end
