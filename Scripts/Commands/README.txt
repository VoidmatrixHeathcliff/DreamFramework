+ 此文件夹中存放开发者自定义指令脚本
+ 脚本即 Lua 模块，语法和加载方式均遵循 Lua 标准
+ 脚本文件名中请不要出现在 Lua 语法中不支持的字符
+ 例如：名为 MyCmd.lua 的文件中有如下内容：

return {
    MyFun = function(content)
        print(content)
    end
}

在 DreamScript 脚本中如下的指令将触发 MyFun 函数的调用：

@ MyCmd.MyFun("Hello DreamFramework")

或

$ MyCmd.MyFun("Hello DreamFramework")

+ 关于自定义指令的内容详见文档