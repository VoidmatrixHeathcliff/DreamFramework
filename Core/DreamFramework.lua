GlobalSettings = require("GlobalSettings")

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
    {}
    -- {Window.WINDOW_FULLSCREEN_DESKTOP}
)

Graphic.SetCursorShow(false)

-- 场景列表
sceneList = {
    {
        name = "Scene.SplashScreen",
        module = nil,
        isInitialized = false,
        isForcedUnload = true
    },
    {
        name = "Scene.CustomSplashScreen",
        module = nil,
        isInitialized = false,
        isForcedUnload = true
    },
}

isFullScreen = false

-- 事件处理函数映射表
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

-- 设置映射表的 __index 元方法为空函数，防止未定义的事件触发
setmetatable(mapEventHandler, {
    __index = function(tb, key)
        return function() end
    end,
})

-- 当前场景索引
indexScene = 1

isQuit = false

while not isQuit do
    local _timeFrameStart = Time.GetInitTime()
    Graphic.SetDrawColor(GlobalSettings._COLOR_.BLACK)
    Window.ClearWindow()
    -- 事件处理：调用事件映射表中对应的回调函数
    while Interactivity.UpdateEvent() do
        mapEventHandler[Interactivity.GetEventType()]()
    end
    -- 当场景索引到达场景列表尾部时则游戏退出
    if indexScene <= #sceneList then
        local _scene = sceneList[indexScene]
        -- 检查当前场景是否加载
        if not _scene.module then
            _scene.module = require(_scene.name)
        end
        -- 检查当前场景是否初始化
        if not _scene.isInitialized then
            _scene.module.Init()
            _scene.isInitialized = true
        end
        -- 当场景的 Update 函数返回 false 时表示当前场景结束
        if not _scene.module.Update() then
            -- 检查当前场景是否需要强制卸载
            if _scene.isForcedUnload then
                _scene.module = nil
                package.loaded[_scene.name] = nil
                _scene.isInitialized = false
            end
            -- 场景列表索引递增
            indexScene = indexScene + 1
        end
    else
        isQuit = true
    end
    Window.UpdateWindow()
    Time.DynamicSleep(1000 / GlobalSettings._FPS_, Time.GetInitTime() - _timeFrameStart)
end