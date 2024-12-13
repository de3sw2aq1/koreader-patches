-- Show title and author in TOC instead of "Table of Contents" header

local ReaderToc = require("apps/reader/modules/readertoc")
local TextBoxWidget = require("ui/widget/textboxwidget")

local onShowToc = ReaderToc.onShowToc
ReaderToc.onShowToc = function(self)
    onShowToc(self)

    local title_bar = self.toc_menu.title_bar

    title_bar:setTitle(self.ui.doc_props.title)

    -- doesn't work, no subtitle_widget
    -- self.toc_menu.title_bar:setSubTitle(self.ui.doc_props.authors)

    title_bar.subtitle = self.ui.doc_props.authors
    local subtitle_max_width = title_bar.width - 2*title_bar.title_h_padding
    title_bar.subtitle_widget = TextBoxWidget:new{
        text = title_bar.subtitle,
        face = title_bar.subtitle_face,
        max_width = subtitle_max_width,
        truncate_left = title_bar.subtitle_truncate_left,
        padding = 0,
        lang = title_bar.lang,
        alignment = title_bar.align,
    }
    table.insert(title_bar.title_group, title_bar.subtitle_widget)
    title_bar.title_group:resetLayout()
    -- still seems to maybe not be updating height
end
