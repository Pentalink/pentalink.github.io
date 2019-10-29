Class = require 'lib/class'
push = require 'lib/push'
Event = require 'lib/knife.event'
Timer = require 'lib/knife.timer'

require 'src/Util'

require 'src/states/BaseState'
require 'src/states/StateStack'

require 'src/states/game/StartState'

require 'src/constants'

gFonts = {
    ['small'] = love.graphics.newFont('fonts/Antaro.ttf', 8),
    ['medium'] = love.graphics.newFont('fonts/Antaro.ttf', 40),
    ['medium-bigger'] = love.graphics.newFont('fonts/Antaro.ttf', 50),
    ['large'] = love.graphics.newFont('fonts/Antaro.ttf', LARGE_FONT_SIZE)
}

gSounds = {
    ['menu-select'] = love.audio.newSource('sounds/menu_select.wav')
}
