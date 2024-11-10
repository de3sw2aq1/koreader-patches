
local FileChooser = require("ui/widget/filechooser")
local util = require("util")

--[[
Randomly sort/shuffle.

The first time each item is seen in the sort, add its name to the cache in a
random position. Sorting is done by the item's index in the randomized cache
list. Re-sort to re-randomize.
--]]

FileChooser.collates.random = {
    text = "random",
    menu_order = 999,
    can_collate_mixed = true,
    init_sort_func = function(cache)
        local cache = {}
        return function(a, b)
            local a_index = util.arrayContains(cache, a.text)
            if not a_index then
                a_index = math.random(1, #cache + 1)
                table.insert(cache, a_index, a.text)
            end

            local b_index = util.arrayContains(cache, b.text)
            if not b_index then
                b_index = math.random(1, #cache + 1)
                table.insert(cache, b_index, b.text)
                if b_index <= a_index then
                    a_index = a_index + 1
                end
            end

            return a_index < b_index
        end, cache
    end,
}
