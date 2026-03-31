--[[ --
If a book file is newer than it's sidecar, the book was updated and may have new chapters.
Reset a book's status to new and no percent read if detected.

Implemented as a patch to `BookList.getBookInfo()` which is in-memory only (does not modify sidecar) and is cached.

TODO: maybe combine 2-100-percent-finished.lua into this patch. Unsure if it needs to be set for places outside BookList though.
--]] --

local DocSettings = require("docsettings")
local BookList = require("ui/widget/booklist")

local function isBookNewerThanSidecar(book_path, sidecar_path)
    local book_mtime = lfs.attributes(book_path, "modification")
    if not book_mtime then
        return nil
    end

    local sidecar_mtime = lfs.attributes(sidecar_path, "modification")
    if not sidecar_mtime then
        return nil
    end

    return book_mtime > sidecar_mtime
end

local original_getBookInfo = BookList.getBookInfo
function BookList.getBookInfo(file)
  if not BookList.hasBookInfoCache(file) then
    if DocSettings:hasSidecarFile(file) then
      local doc_settings = DocSettings:open(file)
      BookList.setBookInfoCache(file, doc_settings)
      local book_info = BookList.book_info_cache[file]

      local sidecar_path = doc_settings.source_candidate
      if isBookNewerThanSidecar(file, sidecar_path) then
        book_info.status = nil
        book_info.percent_finished = nil
      end 
    else
      BookList.book_info_cache[file] = { been_opened = false }
    end
  end
  return BookList.book_info_cache[file]
end
