-- minimal progressbar, used with thick style

local Blitbuffer = require("ffi/blitbuffer")
local ProgressWidget = require("ui/widget/progresswidget")

ProgressWidget.bordersize = 0
ProgressWidget.bgcolor = Blitbuffer.COLOR_LIGHT_GRAY
ProgressWidget.fillcolor = Blitbuffer.COLOR_DARK_GRAY
