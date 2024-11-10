-- Automatically fake-add books to collections based on first path component
-- 
-- e.g. put /mnt/onboard/foo/bar/baz.epub into collection foo if home_dir is /mnt/onboard/
--
-- Doesn't actually add books to collections, but lies and says they're in one in isFileInCollection()
-- seems to be good enough for History filtering by category
-- Collection name is the first path component (relative to home_dir)
-- Collections are automatically created on startup, to populate the collections list for filtering

local FileChooser = require("ui/widget/filechooser")
local ReadCollection = require("readcollection")

function starts_with(str, prefix)
    return string.sub(str, 1, #prefix) == prefix
end

local dirs, files = FileChooser:getList(G_reader_settings:readSetting("home_dir"), "access")
for _, dir in pairs(dirs) do
    local dir_name = string.match(dir.path, ".*/([^/]+)")
    if ReadCollection.coll[dir_name] == nil then 
        ReadCollection:addCollection(dir_name)
    end
end

local isFileInCollection = ReadCollection.isFileInCollection
ReadCollection.isFileInCollection = function (self, file, collection_name)
    fake_collection_dir = G_reader_settings:readSetting("home_dir") .. "/" .. collection_name .. "/"
    return starts_with(file, fake_collection_dir) or isFileInCollection(self, file, collection_name)
end
