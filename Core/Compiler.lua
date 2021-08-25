os.execute("chcp 65001")

-- 语法错误输出
function OutputSyntaxError(msg)
    print(string.format("SyntaxError[%s:%d]:%s", fileName, lineNumber, msg))
end

-- 警告输出
function OutputWarning(msg)
    print(string.format("Warning[%s:%d]:%s", fileName, lineNumber, msg))
end

-- 节点类型
NodeType = {
    DIALOGUE = 1,           -- 对话语句
    COMMAND_BINDING = 2,    -- 绑定指令
    COMMAND_INDEPEND = 3,   -- 独立指令
    LABEL = 4               -- 标签语句
}

-- 编译器状态
CompilerStatus = {
    SINGLELINE = 1,         -- 当前状态为单行
    MULTILINE_CMDS = 2,     -- 当前状态为多行指令
    MULTILINE_NOTES = 3     -- 当前状态为多行注释
}

--[[
    剧本节点列表
    DIALOGUE:
        + file(string)
        + type = NodeType.DIALOGUE
        + speaker(string)
        + words(string)
    COMMAND:
        + file(string)
        + type = NodeType.COMMAND_BINDING / NodeType.COMMAND_INDEPEND
        + command(string)
    LABEL:
        + file(string)
        + type = NodeType.LABEL
        + name(string)
--]]
NodeList = {}

-- 初始化编译器当前状态为单行状态
compilerStatus = CompilerStatus.SINGLELINE

-- 多行文本容器
MultilineContainer = {}

-- 配对符号列表
PairingSymbolList = {
    ["@"] = 1,
    ["$"] = 2
}

-- 语法匹配规则
Rules = {
    -- 匹配空白语句
    ["^(%s*)$"] = function(args)
        -- 如果当前为多行状态，则将当前行原始内容添加至多行文本容器中
        if compilerStatus ~= CompilerStatus.SINGLELINE then
            table.insert(MultilineContainer, args[1])
        end
    end,
    -- 匹配对话语句
    ["^(%s*(.-)%s*[^%%]%*%s*(.*))$"] = function(args)
        -- 如果当前为单行状态，则解析当前行语法
        if compilerStatus == CompilerStatus.SINGLELINE then
            table.insert(NodeList, {
                file = fileName,
                type = NodeType.DIALOGUE,
                speaker = string.gsub(args[2], "%%%*", "*"),
                words = string.gsub(args[3], "%%%*", "*")
            })
        -- 否则将当前行原始内容添加至多行文本容器中
        else
            table.insert(MultilineContainer, args[1])
        end
    end,
    -- 匹配单行指令
    ["^(%s*([@%$])[^{]%s*(.*))$"] = function(args)
        -- 如果当前为单行状态，则解析当前行语法
        if compilerStatus == CompilerStatus.SINGLELINE then
            local _node = {file = fileName}
            -- 尝试编译 Lua 语句
            local _result, _error = load(args[3])
            -- 如果编译成功则继续解析
            if _result then
                _node.command = args[3]
                -- 判断指令绑定类型
                if args[1] == "@" then
                    _node.type = COMMAND_BINDING
                else
                    _node.type = COMMAND_INDEPEND
                end
                table.insert(NodeList, _node)
            -- 如果编译失败则输出语法错误
            else
                OutputSyntaxError(_error)
            end
        -- 否则将当前行原始内容添加至多行文本容器中
        else
            table.insert(MultilineContainer, args[1])
        end
    end,
    -- 匹配多行指令起始标志
    ["^(%s*[@%$])$"] = function(args)
        -- 如果当前为单行状态，则解析当前行语法
        if compilerStatus == CompilerStatus.SINGLELINE then
            
        -- 否则如果当前行为多行指令，则出现了嵌套，输出语法错误
        elseif compilerStatus == CompilerStatus.MULTILINE_CMDS then
            OutputSyntaxError("multiline directives do not support nesting")
        -- 否则将当前行原始内容添加至多行文本容器中
        else
            table.insert(MultilineContainer, args[1])
        end
    end,
    -- 匹配多行指令结束标志
    ["^()$"] = function(args)
        if compilerStatus == CompilerStatus.SINGLELINE then
            
        else
            table.insert(MultilineContainer, args[1])
        end
    end,
    -- 匹配单行注释
    ["^(%s*%%%%(.*))$"] = function(args)
        -- 如果当前为多行状态，则将当前行原始内容添加至多行文本容器中
        if compilerStatus ~= CompilerStatus.SINGLELINE then
            table.insert(MultilineContainer, args[1])
        end
    end,
    -- 匹配多行注释起始标志
    ["^$"] = function(args)

    end,
    -- 匹配多行注释结束标志
    ["^$"] = function(args)

    end,
    -- 匹配标签语句
    ["^(%s*#%s*(.-)%s*)$"] = function(args)
        -- 如果当前为单行状态，则解析当前行语法
        if compilerStatus == CompilerStatus.SINGLELINE then
            table.insert(NodeList, {
                file = fileName,
                type = NodeType.LABEL,
                name = args[2]
            })
        -- 否则将当前行原始内容添加至多行文本容器中
        else
            table.insert(MultilineContainer, args[1])
        end
        
    end,
}

fileName = "Test.ds"

inputFile = io.open(fileName)

lineNumber = 0

while true do
    -- 从脚本文件中读取一行
    local _str_line = inputFile:read("*l")
    -- 如果读取成功则进行解析
    if _str_line then
        -- 行号自增
        lineNumber = lineNumber + 1
        -- 是否匹配成功标志
        local _isFoundRule = false
        -- 遍历规则列表，尝试匹配每条规则
        for rule, handler in pairs(Rules) do
            -- 获取匹配结果参数列表
            local _args = {string.match(_str_line, rule)}
            -- 如果匹配成功，则调用处理函数，并退出匹配循环
            if #_args ~= 0 then
                handler(_args)
                _isFoundRule = true
                break
            end
        end
        -- 如果没有找到对应的规则，则抛出错误
        if not _isFoundRule then
            OutputSyntaxError("unknown syntax")
        end
    -- 读取失败则表示到达文件尾部，结束循环
    else
        break
    end
end

-- speaker, words = string.match("*", "^%s*(.-)%s*%*%s*(.*)$")
-- print(type(speaker), words)

os.execute("pause")