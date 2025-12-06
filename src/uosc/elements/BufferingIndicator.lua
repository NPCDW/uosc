local Element = require('elements/Element')

---@class BufferingIndicator : Element
local BufferingIndicator = class(Element)

function BufferingIndicator:new() return Class.new(self) --[[@as BufferingIndicator]] end
function BufferingIndicator:init()
	Element.init(self, 'buffering_indicator', {ignores_curtain = true, render_order = 2})
	self.enabled = false
	self:decide_enabled()
end

function BufferingIndicator:decide_enabled()
	local cache = state.cache_underrun or state.cache_buffering and state.cache_buffering < 100
	if cache or not state.path then
		self.enabled = true
	else
		self.enabled = false
	end
end

function BufferingIndicator:on_prop_path() self:decide_enabled() end
function BufferingIndicator:on_prop_cache_buffering() self:decide_enabled() end
function BufferingIndicator:on_prop_cache_underrun() self:decide_enabled() end

function BufferingIndicator:render()
	local ass = assdraw.ass_new()
	ass:rect(0, 0, display.width, display.height, {color = bg, opacity = config.opacity.buffering_indicator})
	local size = round(30 + math.min(display.width, display.height) / 10)
	local opacity = (Elements.menu and Elements.menu:is_alive()) and 0.3 or 0.8
	ass:spinner(display.width / 2, display.height / 2, size, {color = fg, opacity = opacity})
	return ass
end

return BufferingIndicator
