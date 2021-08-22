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
    {Window.WINDOW_RESIZABLE}
)

local _FPS_ <const> = 60
local _COLOR_ <const> = {
    BLACK = {r = 0, g = 0, b = 0, a = 255},
    WHITE = {r = 255, g = 255, b = 255, a = 255},
    RED = {r = 255, g = 0, b = 0, a = 255},
    GREEN = {r = 0, g = 255, b = 0, a = 255},
    BLUE = {r = 0, g = 0, b = 255, a = 255},
}

isQuit = false

mapEventHandler = {
    [Interactivity.EVENT_QUIT] = function()
        isQuit = true
    end,
}

setmetatable(mapEventHandler, {
    __index = function(tb, key)
        return function() end
    end,
})

local function DrawCall()
    SplashScreen.Update()
end

SplashScreen.Init()

while not isQuit do
    local _timeFrameStart = Time.GetInitTime()
    Graphic.SetDrawColor(_COLOR_.WHITE)
    Window.ClearWindow()
    while Interactivity.UpdateEvent() do
        mapEventHandler[Interactivity.GetEventType()]()
    end
    DrawCall()
    Window.UpdateWindow()
    Time.DynamicSleep(1000 / _FPS_, Time.GetInitTime() - _timeFrameStart)
end