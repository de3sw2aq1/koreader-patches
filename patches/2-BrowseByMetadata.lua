-- BrowseByMetadata userpatch
-- 
-- This is poire-z's BrowseByMetadata proof of concept from https://github.com/koreader/koreader/issues/8472 converted into a userpatch
-- Based on code from https://github.com/poire-z/koreader/commit/ad03650b5d7e19a8de45857c83a2d7a4c7e13a4a
-- 
-- Regressions/changes in userpatch version:
-- * collate (sort) is not overridden, so the sort in the metadata menu is no longer forced to sort by size in BrowseByMetadata menus
-- * is_directory is not set to true in ListMenuItem:update() and MosaicMenuItem:update()
--   * I don't know what effect this was supposed to have, possibly change the display? It seems like it may already evaluate to true
-- * removed unused item.nb_sub_dirs display formatting
-- * instead of patching FileChooser:changeToPath(), ffiUtil.realpath() is patched globally to support virtual directories

local userpatch = require("userpatch")
local ffiUtil = require("ffi/util")
local util = require("util")
local _ = require("gettext")
local T = ffiUtil.template

local FileManager = require("apps/filemanager/filemanager")
local FileChooser = require("ui/widget/filechooser")

-- "\u{EA30} browse by metadata \u{EA30} \u{E7F5} \u{E7FC} \u{e8d5} \u{eec3} \u{e93a} \u{e92f} \u{e9c4} \u{ed49} \u{ea27} \u{edf8} \u{ebfa} \u{ebf8} \u{ebfc} \u{ec66} \u{ec68} \u{ec6d} \u{ec9e}"
local VIRTUAL_ITEMS = {
    ROOT = {
        browse_text = _("Browse by metadata"),
        filter_text = _("Filter by metadata"),
        symbol = "\u{e257}",
        -- symbol = "\u{ee30}",
        -- symbol = "\u{ee26}",
    },
    TITLE = {
        browse_text = _("Browse by title"),
        filter_text = _("Filter by title"),
        db_column = "title",
        symbol = "\u{f02d}",
        -- symbol = "\u{edf8}",
        -- symbol = "\u{e28B}",
        -- symbol = "\u{e7bc}",
        -- symbol = "\u{e8fc}",
        -- symbol = "\u{ea31}",
    },
    AUTHOR = {
        browse_text = _("Browse by author"),
        filter_text = _("Filter by author"),
        db_column = "authors",
        symbol = "\u{f2c0}",
        -- symbol = "\u{ed49}",
        -- symbol = "\u{f1ae}",
        -- symbol = "\u{f007}",
        -- symbol = "\u{e84e}",
    },
    SERIE = {
        browse_text = _("Browse by serie"),
        filter_text = _("Filter by serie"),
        db_column = "series",
        symbol = "\u{ecd7}",
        -- symbol = "\u{ec68}",
        -- symbol = "\u{ec75}",
        -- symbol = "\u{ed37}",
        -- symbol = "\u{f03d}",
        -- symbol = "\u{f447}",
    },
    LANGUAGE = {
        browse_text = _("Browse by language"),
        filter_text = _("Filter by language"),
        db_column = "language",
        symbol = "\u{f0e5}",
        -- symbol = "\u{ec9e}",
    },
    KEYWORD = {
        browse_text = _("Browse by keyword"),
        filter_text = _("Filter by keyword"),
        db_column = "keywords",
        symbol = "\u{f412}",
        -- symbol = "\u{e8d5}",
    },
    -- YEAR "\u{f073}", but not available in bookinfo or cre
}

local VIRTUAL_SUBITEMS_ORDERED = {
    VIRTUAL_ITEMS.TITLE,
    VIRTUAL_ITEMS.AUTHOR,
    VIRTUAL_ITEMS.SERIE,
    VIRTUAL_ITEMS.LANGUAGE,
    VIRTUAL_ITEMS.KEYWORD,
}
local VIRTUAL_ROOT_SYMBOL = VIRTUAL_ITEMS.ROOT.symbol
local VIRTUAL_SYMBOLS = {}
for k, v in pairs(VIRTUAL_ITEMS) do
    VIRTUAL_SYMBOLS[v.symbol] = v
end

local VIRTUAL_PATH_TYPE_ROOT = "VIRTUAL_PATH_TYPE_ROOT"
local VIRTUAL_PATH_TYPE_META_VALUES_LIST = "VIRTUAL_PATH_TYPE_META_VALUES_LIST"
local VIRTUAL_PATH_TYPE_MATCHING_FILES = "VIRTUAL_PATH_TYPE_MATCHING_FILES"

-- Patch FileManager:setupLayout()
local FileManager_setupLayout = FileManager.setupLayout
FileManager.setupLayout = function (self)
    FileManager_setupLayout(self)

    file_chooser_showFileDialog = self.file_chooser.showFileDialog
    self.file_chooser.showFileDialog = function (self, item)
        if self:getVirtualPathTypePath(item.path) then
            -- Clear book_props to block coverbrowser's showFileDialog
            -- (it seems like file_chooser's showFileDialog maybe should always unconditionally clear book_props early? currently it only does so if is_file is true)
            self.book_props = nil

            -- don't display a file dialog for virtual directories
            return true
        end 

        return file_chooser_showFileDialog(self, item)
    end
end

-- Add FileChooser:getVirtualPathTypePath()
function FileChooser:getVirtualPathTypePath(path)
    if not path then return end
    if path:find("/"..VIRTUAL_ROOT_SYMBOL.."$") then
        return VIRTUAL_PATH_TYPE_ROOT
    end
    if path:find("/"..VIRTUAL_ROOT_SYMBOL.."/") then
        local _, last_part = util.splitFilePathName(path)
        local symbol = VIRTUAL_SYMBOLS[last_part]
        if symbol then
            if symbol == VIRTUAL_ITEMS.ROOT then
                return VIRTUAL_PATH_TYPE_ROOT
            elseif symbol ~= VIRTUAL_ITEMS.TITLE then
                return VIRTUAL_PATH_TYPE_META_VALUES_LIST
            end
        end
        return VIRTUAL_PATH_TYPE_MATCHING_FILES
    end
end

-- Add FileChooser:getVirtualList()
function FileChooser:getVirtualList(path, collate)
    local dirs, files = {}, {}
    local base_dir, virtual_root, virtual_path = path:match("(.-)/("..VIRTUAL_ROOT_SYMBOL..")(.*)")
    if not virtual_root then
        return dirs, files
    end
    local fragments = {}
    for fragment in util.gsplit(virtual_path, "/") do
        -- XXX issue if / in metadata content (Frank Thilliez keywords
        table.insert(fragments, fragment)
    end
    if #fragments == 0 or fragments[#fragments] == VIRTUAL_ROOT_SYMBOL then
        local filtering = #fragments > 0
        if filtering then
            -- Showing a 2nd ROOT symbol: make a tap on the subitems just replace it
            path = path:match("(.*)/.*")
        end
        for i, v in ipairs(VIRTUAL_SUBITEMS_ORDERED) do
            item = true
            if collate then -- when collate == nil count only to display in folder mandatory
                local fake_attributes = {
                    mode = "directory",
                    modification = 0,
                    access = 0,
                    change = 0,
                    size = i,
                }
                item = self:getListItem(nil, v.symbol.." "..(filtering and v.filter_text or v.browse_text), path.."/"..v.symbol, fake_attributes, collate)
                item.is_virtual_dir = true
                item.mandatory = nil
            end
            table.insert(dirs, item)
        end
        return dirs, files
    end
    -- We have arguments
    local meta_name
    local filters = {}
    local filters_seen = {}
    local cur_value
    while #fragments > 0 do
        local fragment = table.remove(fragments)
        local meta = VIRTUAL_SYMBOLS[fragment]
        if meta then
            if meta == VIRTUAL_ITEMS.ROOT or meta == VIRTUAL_ITEMS.TITLE then
                do end -- do nothing
            else
                local db_meta_name = meta.db_column
                if cur_value ~= nil then
                    table.insert(filters, {db_meta_name, cur_value})
                    if not filters_seen[db_meta_name] then
                        filters_seen[db_meta_name] = {}
                    end
                    filters_seen[db_meta_name][cur_value] = true
                else
                    meta_name = db_meta_name
                end
            end
        else
            cur_value = fragment
            if cur_value == "\u{2205}" then
                cur_value = false -- NULL
            end
        end
    end
    if meta_name == "title" then
        meta_name = nil
    end
    if meta_name then
        local matching_values = self.filemanager.coverbrowser:getMatchingMetadataValues(base_dir, meta_name, filters)
        for i, v in ipairs(matching_values) do
            -- Ignore those already present in the current filters
            if not filters_seen[meta_name] or not filters_seen[meta_name][v[1]] then
                local fake_attributes = {
                    mode = "directory",
                    modification = 0,
                    access = 0,
                    change = 0,
                    size = i,
                }
                local name = v[1] or "\u{2205}"
                local this_path = path.."/"..(v[1] or "\u{2205}")
                item = self:getListItem(nil, name, this_path, fake_attributes, collate)
                item.nb_sub_files = v[2]
                item.is_virtual_dir = true
                item.mandatory = self:getMenuItemMandatory(item)
                table.insert(dirs, item)
            end
        end
    else
        local matching_files = self.filemanager.coverbrowser:getMatchingFiles(base_dir, filters)
        for i, v in ipairs(matching_files) do
            local filepath = v[1]
            local attributes = lfs.attributes(filepath)
            if attributes and attributes.mode == "file" then
                local item = self:getListItem(path, v[2], filepath, attributes, collate)
                table.insert(files, item)
            end
        end
    end
    return dirs, files
end

-- Patch FileChooser:genItemTableFromPath()
local FileChooser_genItemTableFromPath = FileChooser.genItemTableFromPath
FileChooser.genItemTableFromPath = function (self, path)
    local collate = self:getCollate()
    if self:getVirtualPathTypePath(path) then
        local dirs, files = self:getVirtualList(path, collate)
        return self:genItemTable(dirs, files, path)
    end
    return FileChooser_genItemTableFromPath(self, path)
end

-- Patch FileChooser:genItemTable()
local FileChooser_genItemTable = FileChooser.genItemTable
FileChooser.genItemTable = function (self, dirs, files, path)
    local virtual_path_type = self:getVirtualPathTypePath(path)

    -- TODO: somehow force collate to "size" for virtual directories
    -- if virtual_path_type == VIRTUAL_PATH_TYPE_ROOT then
    --     -- Listing "browse by title"...
    --     collate = self.collates["size"]
    --     collate_mixed = false
    -- end

    local item_table = FileChooser_genItemTable(self, dirs, files, path)

    if item_table[1] and item_table[1].path:find("/..$") then
        item_table[1].path = virtual_path_type ~= nil and path:gsub("(/[^/]+$", "") or path.."/.."
        item_table[1].is_virtual_dir = virtual_path_type ~= nil
    end

    -- Plugins may not yet be loaded, so we can't use self.filemanager.coverbrowser to check if CoverBrowser will be available
    local coverbrowser_available = not G_reader_settings:readSetting("plugins_disabled") or not G_reader_settings:readSetting("plugins_disabled")["coverbrowser"]
    if self.filemanager and coverbrowser_available and path and (virtual_path_type == nil or virtual_path_type == VIRTUAL_PATH_TYPE_MATCHING_FILES) then
        table.insert(item_table, 1, {
            --text = "\u{EA30} browse by metadata \u{EA30} \u{E7F5} \u{E7FC} \u{e8d5} \u{eec3} \u{e93a} \u{e92f} \u{e9c4} \u{ed49} \u{ea27} \u{edf8} \u{ebfa} \u{ebf8} \u{ebfc} \u{ec66} \u{ec68} \u{ec6d} \u{ec9e}",
            text = VIRTUAL_ROOT_SYMBOL .. " " .. (virtual_path_type and VIRTUAL_ITEMS.ROOT.filter_text or VIRTUAL_ITEMS.ROOT.browse_text),
            path = path.."/"..VIRTUAL_ROOT_SYMBOL,
            is_virtual_dir = true,
            is_virtual_root_dir = true,
        })
    end

    return item_table
end

-- Patch FileChooser:getMenuItemMandatory()
local FileChooser_getMenuItemMandatory = FileChooser.getMenuItemMandatory
FileChooser.getMenuItemMandatory = function (self, item, collate)
    if item.nb_sub_files then
        return T("%1 \u{F016}", item.nb_sub_files)
    end

    return FileChooser_getMenuItemMandatory(self, item, collate)
end

-- Patch ffiUtil.realpath()
local ffiUtil_realpath = ffiUtil.realpath
ffiUtil.realpath = function (path)
    if FileChooser:getVirtualPathTypePath(path) then
        if util.stringEndsWith(path, "/..") then -- process "go up"
            return path:gsub("(/[^/]+/%.%.$", "")
        end
        return path
    end
    return ffiUtil_realpath(path)
end

userpatch.registerPatchPluginFunc("coverbrowser", function(CoverBrowser)
    local BookInfoManager = require("bookinfomanager")
    local MosaicMenu = require("mosaicmenu")
    local ListMenu = require("listmenu")

    -- Add BookInfoManager:getMatchingMetadataValues()
    function BookInfoManager:getMatchingMetadataValues(base_dir, meta_name, filters)
        local vars = {}
        local sql = T("select %1, count(1) from bookinfo where directory glob ?", meta_name)
            -- GLOB is case sensitive, unlike LIKE. Also, LIKE is case insentive only
            -- with ASCII chars, and not Unicode ones, so it's a bit useless.
        table.insert(vars, base_dir..'*')
        for _, filter in ipairs(filters) do
            local name, value = filter[1], filter[2]
            local name, value = filter[1], filter[2]
            if value == false then
                sql = T("%1 and %2 is NULL", sql, name)
            elseif name == "authors" or name == "keywords" then
                -- authors and keywords may have multiple values, separated by \n
                sql = T("%1 and '\n'||%2||'\n' GLOB ?", sql, name)
                table.insert(vars, "*\n"..value.."\n*")
            else
                sql = T("%1 and %2=?", sql, name)
                table.insert(vars, value)
            end
        end
        sql = T("%1 group by %2", sql, meta_name)
            -- We might want to "group by" in a somehow case insentive manner,
            -- but we would need to pick one of the variously cased values to
            -- be returned and display, but which?
            -- (mey be using group_concat(meta_name), and picking the one
            -- with the most occurences, or the first)
        -- logger.warn(sql, vars)
        self:openDbConnection()
        local stmt = self.db_conn:prepare(sql)
        stmt:bind(table.unpack(vars))
        local results = {}
        local xresults = {}
        local use_results_as_is = meta_name ~= "authors" and meta_name ~= "keywords"
        while true do
            local row = stmt:step()
            if not row then
                break
            end
            if use_results_as_is then
                table.insert(results, {row[1] or false, tonumber(row[2])})
            else
                -- authors and keywords may have multiple values, separated by \n
                local value, nb = row[1] or false, tonumber(row[2])
                if value and value:find("\n") then
                    for val in util.gsplit(value, "\n") do
                        xresults[val] = xresults[val] and (xresults[val] + nb) or nb
                    end
                else
                    xresults[value] = xresults[value] and (xresults[value] + nb) or nb
                end
            end
        end
        if not use_results_as_is then
            for value, nb in pairs(xresults) do
                table.insert(results, {value, nb})
            end
        end
        return results
    end

    -- Add BookInfoManager:getMatchingFiles()
    function BookInfoManager:getMatchingFiles(base_dir, filters)
        local vars = {}
        local sql = "select directory||filename, filename from bookinfo where directory glob ?"
        table.insert(vars, base_dir..'*')
        for _, filter in ipairs(filters) do
            local name, value = filter[1], filter[2]
            if value == false then
                sql = T("%1 and %2 is NULL", sql, name)
            elseif name == "authors" or name == "keywords" then
                -- authors and keywords may have multiple values, separated by \n
                sql = T("%1 and '\n'||%2||'\n' GLOB ?", sql, name)
                table.insert(vars, "*\n"..value.."\n*")
            else
                sql = T("%1 and %2=?", sql, name)
                table.insert(vars, value)
            end
        end
        -- logger.warn(sql, vars)
        self:openDbConnection()
        local stmt = self.db_conn:prepare(sql)
        stmt:bind(table.unpack(vars))
        local results = {}
        while true do
            local row = stmt:step()
            if not row then
                break
            end
            table.insert(results, {row[1], row[2]})
        end
        -- logger.warn(results)
        return results
    end

    -- Add CoverBrowser:getMatchingMetadataValues()
    function CoverBrowser:getMatchingMetadataValues(base_dir, meta_name, filters)
        return BookInfoManager:getMatchingMetadataValues(base_dir, meta_name, filters)
    end

    -- Add CoverBrowser:getMatchingFiles()
    function CoverBrowser:getMatchingFiles(base_dir, filters)
        return BookInfoManager:getMatchingFiles(base_dir, filters)
    end

    -- TODO: restore patches to set is_directory in ListMenuItem:update() and MosaicMenuItem:update()
end)
