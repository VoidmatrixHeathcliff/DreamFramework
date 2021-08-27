GlobalSettings = require("GlobalSettings")

JSON = UsingModule("JSON")
Window = UsingModule("Window")
Graphic = UsingModule("Graphic")
Time = UsingModule("Time")
OS = UsingModule("OS")

local _module = {}

local _splashList = JSON.LoadJSONFromFile("../Splash.json")

local _imageSplashImage
local _textureSplashImage
local _widthSplashImage, _heightSplashImage

local _rectWindowContent = {x = 0, y = 0, w = 0, h = 0}
local _rectSplashImage = {x = 0, y = 0, w = 0, h = 0}

local _colorBackground = {
    White = GlobalSettings._COLOR_.WHITE_SOFT,
    Black = GlobalSettings._COLOR_.BLACK_SOFT,
}
local _colorMask = {
    r = GlobalSettings._COLOR_.BLACK_SOFT.r,
    g = GlobalSettings._COLOR_.BLACK_SOFT.g,
    b = GlobalSettings._COLOR_.BLACK_SOFT.b,
    a = 255
}

-- 当前 Splash 在自定义 Splash 列表中的索引
local _indexSplash = 1

-- 动画状态机中当前状态索引
local _indexSMA = 1

-- 动画状态机
local _stateMachineAnimation = {
    -- 场景淡入
    {
        isInitialized = false,
        isPlayOver = false,
        timeStart = 0,
        Play = function(self)
            _colorMask.a = Algorithm.Clamp(
                _colorMask.a - (Time.GetInitTime() - self.timeStart) / 300,
                0,
                255
            )
            if _colorMask.a == 0 then
                self.isPlayOver = true
            end
        end
    },
    -- 场景保持
    {
        isInitialized = false,
        isPlayOver = false,
        timeStart = 0,
        Play = function(self)
            if Time.GetInitTime() - self.timeStart >= _splashList[_indexSplash].Delay then
                self.isPlayOver = true
            end
        end
    },
    -- 场景淡出
    {
        isInitialized = false,
        isPlayOver = false,
        timeStart = 0,
        Play = function(self)
            _colorMask.a = Algorithm.Clamp(
                _colorMask.a + (Time.GetInitTime() - self.timeStart) / 300,
                0,
                255
            )
            if _colorMask.a == 255 then
                self.isPlayOver = true
            end
        end
    },
}

-- 加载当前 Splash 所需的素材
local function _LoadSplashAsset()
    _imageSplashImage = Graphic.LoadImageFromFile(OS.JoinPath("../Resource/Image/", _splashList[_indexSplash].Image))
    _textureSplashImage = Graphic.CreateTexture(_imageSplashImage)
    _widthSplashImage, _heightSplashImage = _imageSplashImage:GetSize()
end

-- 计算渲染内容
local function _CalculateRender()
    _rectWindowContent.w, _rectWindowContent.h = Window.GetWindowDrawableSize()
    local _scaling = math.min(_rectWindowContent.w / 1920, _rectWindowContent.h / 1080)
    _rectSplashImage.w = _widthSplashImage * _scaling
    _rectSplashImage.h = _heightSplashImage * _scaling
    _rectSplashImage.x = _rectWindowContent.w / 2 - _rectSplashImage.w / 2
    _rectSplashImage.y = _rectWindowContent.h / 2 - _rectSplashImage.h / 2
    -- 如果动画状态机索引没有达到状态机尾部，则状态机继续运行
    if _indexSMA <= #_stateMachineAnimation then
        local _state = _stateMachineAnimation[_indexSMA]
        if not _state.isInitialized then
            _state.timeStart = Time.GetInitTime()
            _state.isInitialized = true
        end
        if not _state.isPlayOver then
            _state:Play()
        else
            _indexSMA = _indexSMA + 1
        end
    -- 如果索引到达尾部，则重置状态机索引，并切换至下一 Splash
    else
        _indexSMA = 1
        _indexSplash = _indexSplash + 1
        -- 如果 Splash 索引尚未到达尾部
        if _indexSplash <= #_splashList then
            -- 将 image 和 texture 更新为对应 Splash 所指定的素材
            _LoadSplashAsset()
            -- 重置状态机各节点状态量
            for _, state in ipairs(_stateMachineAnimation) do
                state.isInitialized = false
                state.isPlayOver = false
            end
        end
    end
end

_module.Init = function()
    -- 如果存在用户自定义的 Splash 图片，则初始化第一个 Splash 场景
    if _indexSplash <= #_splashList then
        _LoadSplashAsset()
    end
end

_module.Update = function()
    _CalculateRender()
    -- 如果纹理不为 nil 且尚未播放完全部 Splash 则渲染当前场景
    -- 纹理为 nil 仅发生在开发者没有定义任何 Splash 的情况下
    if _textureSplashImage and _indexSplash <= #_splashList then
        Graphic.SetDrawColor(_colorBackground[_splashList[_indexSplash].Background])
        Graphic.DrawFillRectangle(_rectWindowContent)
        Graphic.CopyTexture(_textureSplashImage, _rectSplashImage)
        Graphic.SetDrawColor(_colorMask)
        Graphic.DrawFillRectangle(_rectWindowContent)
        return true
    else
        return false
    end
end

return _module