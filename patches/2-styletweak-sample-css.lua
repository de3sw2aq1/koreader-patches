-- Replace the placeholder code for editing book-specific style tweaks

-- Edit book-specific tweak to match the books section break symbol.
-- The weird spacing in the CSS is legal, and is easier to position the cursor precisely with your finger, and edit or delete anything unneeded


local userpatch = require("userpatch")
local ReaderStyleTweak = require("apps/reader/modules/readerstyletweak")

local upvalue, up_value_idx = userpatch.getUpValue(ReaderStyleTweak.editBookTweak, 'BOOK_TWEAK_SAMPLE_CSS')
userpatch.replaceUpValue(ReaderStyleTweak.editBookTweak, up_value_idx, [[
p[
  _
  *=
  '***'
  i
]
{
    text-align: center;
    margin: 1rem 0;
    font-size: 1em;
}
]])
