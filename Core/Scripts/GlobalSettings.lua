local _module = {}

-- 帧率
_module._FPS_ = 144

-- 内置调色板
_module._COLOR_ = {
    BLACK = {r = 0, g = 0, b = 0, a = 255},
    BLACK_SOFT = {r = 25, g = 25, b = 25, a = 255},
    WHITE = {r = 255, g = 255, b = 255, a = 255},
    WHITE_SOFT = {r = 245, g = 245, b = 245, a = 255},
    RED = {r = 255, g = 0, b = 0, a = 255},
    GREEN = {r = 0, g = 255, b = 0, a = 255},
    BLUE = {r = 0, g = 0, b = 255, a = 255},
}

return _module