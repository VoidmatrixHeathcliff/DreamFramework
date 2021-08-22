SplashScreen = UsingModule("SplashScreen")

Window = UsingModule("Window")
Graphic = UsingModule("Graphic")
Interactivity = UsingModule("Interactivity")
Time = UsingModule("Time")

Window.CreateWindow(
    "DreamFramework Dev_0.0.1",
    {
        x = Window.WINDOW_POSITION_DEFAULT,
        y = Window.WINDOW_POSITION_DEFAULT,
        w = 1280,
        h = 720
    },
    -- {}
    {Window.WINDOW_FULLSCREEN_DESKTOP}
)

Graphic.SetCursorShow(false)

local _FPS_ <const> = 60
local _COLOR_ <const> = {
    BLACK = {r = 0, g = 0, b = 0, a = 255},
    WHITE = {r = 255, g = 255, b = 255, a = 255},
    RED = {r = 255, g = 0, b = 0, a = 255},
    GREEN = {r = 0, g = 255, b = 0, a = 255},
    BLUE = {r = 0, g = 0, b = 255, a = 255},
}

isFullScreen = false

mapEventHandler = {
    [Interactivity.EVENT_QUIT] = function()
        isQuit = true
    end,
    [Interactivity.EVENT_KEYUP_F11] = function()
        isFullScreen = not isFullScreen
        if isFullScreen then
            Window.SetWindowMode(Window.WINDOW_MODE_FULLSCREEN_DESKTOP)
        else
            Window.SetWindowMode(Window.WINDOW_MODE_WINDOWED)
        end
    end
}

setmetatable(mapEventHandler, {
    __index = function(tb, key)
        return function() end
    end,
})

-- 当场景的 Update 函数返回 false 时表示当前场景结束
local function DrawCall()
    if not SplashScreen.Update() then
        isQuit = true
    end
end

SplashScreen.Init()

isQuit = false

while not isQuit do
    local _timeFrameStart = Time.GetInitTime()
    Graphic.SetDrawColor(_COLOR_.BLACK)
    Window.ClearWindow()
    while Interactivity.UpdateEvent() do
        mapEventHandler[Interactivity.GetEventType()]()
    end
    DrawCall()
    Window.UpdateWindow()
    Time.DynamicSleep(1000 / _FPS_, Time.GetInitTime() - _timeFrameStart)
end