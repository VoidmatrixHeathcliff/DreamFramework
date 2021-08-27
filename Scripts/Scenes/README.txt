+ 此文件夹下存放开发者自定义场景
+ 场景即 Lua 模块，语法和加载方式均遵循 Lua 标准
+ 场景文件名中请不要出现在 Lua 语法中不支持的字符
+ 自定义场景模块中必须实现 Init() 和 Update() 方法
+ 例如：名为 MyScene.lua 的文件中有如下内容：

return {
    Init = function() end,
    Update = function() end,
    Unload = function() end    -- 自定义卸载函数可选
}

+ 在 meta.json 中配置对应场景的 forced-unload 选项为 true 可以在模块卸载时强制移除
+ 关于自定义场景的内容详见文档