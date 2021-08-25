os.execute("chcp 65001")

-- 语法错误输出
function OutputSyntaxError(msg, line)
    print(string.format("SyntaxError[%s:%d]:%s", fileName, line or lineNumber, msg))
end

-- 警告输出
function OutputWarning(msg, line)
    print(string.format("Warning[%s:%d]:%s", fileName, line or lineNumber, msg))
end

-- 节点类型
NodeType = {
    DIALOGUE = 1,           -- 对话语句
    COMMAND_BINDING = 2,    -- 绑定指令
    COMMAND_INDEPEND = 3,   -- 独立指令
    LABEL = 4               -- 标签语句
}

-- 编译器状态列表
CompilerStatusList = {
    SINGLELINE = 1,         -- 当前状态为单行
    MULTILINE_CMDS = 2,     -- 当前状态为多行指令
    MULTILINE_NOTES = 3     -- 当前状态为多行注释
}

--[[
    节点列表
    DIALOGUE:
        + file(string)
        + line(number)
        + type = NodeType.DIALOGUE
        + speaker(string)
        + words(string)
    COMMAND:
        + file(string)
        + line(number)
        + type = NodeType.COMMAND_BINDING / NodeType.COMMAND_INDEPEND
        + command(string)
    LABEL:
        + file(string)
        + line(number)
        + type = NodeType.LABEL
        + name(string)
--]]
NodeList = {}

-- 初始化编译器当前状态为单行状态
compilerStatus = CompilerStatusList.SINGLELINE

-- 多行指令节点临时对象
MultilineCMDNodeTemp = {
    command = {}            -- 在解析成功后会被拼接为字符串
}

-- 多行注释节点开始行号（仅用于调试信息输出使用）
-- 由于注释节点不会存储进入节点列表，所以使用变量追踪其开始位置
lineNumberMultilineNoteStart = 0

-- 语法匹配规则
Rules = {
    -- 匹配空白语句
    ["^(%s*)$"] = function(args)
        -- 如果当前为多行指令，则将当前行原始内容添加至多行文本容器中
        if compilerStatus == CompilerStatusList.MULTILINE_CMDS then
            table.insert(MultilineCMDNodeTemp.command, args[1])
        end
    end,
    -- 匹配对话语句
    ["^(%s*(.-)%s*[^%%]%*%s*(.*))$"] = function(args)
        -- 如果当前为单行状态，则解析当前行语法
        if compilerStatus == CompilerStatusList.SINGLELINE then
            table.insert(NodeList, {
                file = fileName,
                line = lineNumber,
                type = NodeType.DIALOGUE,
                speaker = string.gsub(args[2], "%%%*", "*"),
                words = string.gsub(args[3], "%%%*", "*")
            })
        -- 否则如果当前为多行指令，则将当前行原始内容添加至多行文本容器中
        elseif compilerStatus == CompilerStatusList.MULTILINE_CMDS then
            table.insert(MultilineCMDNodeTemp.command, args[1])
        end
    end,
    -- 匹配单行指令
    ["^(%s*([@%$])[^{]%s*(.*))$"] = function(args)
        -- 如果当前为单行状态，则解析当前行语法
        if compilerStatus == CompilerStatusList.SINGLELINE then
            local _node = {file = fileName, line = lineNumber}
            -- 尝试编译 Lua 语句
            local _result, _error = load(args[3])
            -- 如果编译成功则继续解析
            if _result then
                _node.command = args[3]
                -- 判断指令类型
                if args[2] == "@" then
                    _node.type = COMMAND_BINDING
                else
                    _node.type = COMMAND_INDEPEND
                end
                table.insert(NodeList, _node)
            -- 如果编译失败则输出语法错误
            else
                OutputSyntaxError(_error)
            end
        -- 否则如果当前为多行指令，则将当前行原始内容添加至多行文本容器中
        elseif compilerStatus == CompilerStatusList.MULTILINE_CMDS then
            table.insert(MultilineCMDNodeTemp.command, args[1])
        end
    end,
    -- 匹配多行指令起始标志
    ["^(%s*([@%$]){%s*(.*))$"] = function(args)
        -- 如果当前为单行状态，则解析当前行语法
        if compilerStatus == CompilerStatusList.SINGLELINE then
            -- 将起始标志后方指令添加至多行文本容器中
            table.insert(MultilineCMDNodeTemp.command, args[3])
            MultilineCMDNodeTemp.file = fileName
            MultilineCMDNodeTemp.line = lineNumber
            -- 判断指令类型
            if args[2] == "@" then
                MultilineCMDNodeTemp.type = COMMAND_BINDING
            else
                MultilineCMDNodeTemp.type = COMMAND_INDEPEND
            end
            -- 设置当前编译器状态为多行指令
            compilerStatus = CompilerStatusList.MULTILINE_CMDS
        -- 否则如果当前行为多行指令，则出现了嵌套，输出语法错误
        elseif compilerStatus == CompilerStatusList.MULTILINE_CMDS then
            OutputSyntaxError("multiline directives do not support nesting")
        end
    end,
    -- 匹配多行指令结束标志
    ["^((.-)%s*}([@%$])(.*))$"] = function(args)
        -- 如果结束标志后方仍有其他内容，则输出警告
        if #args[4] ~= 0 then
            OutputWarning("content behind the end flag will be discarded")
        end
        -- 如果当前为多行指令，则解析当前行语法
        if compilerStatus == CompilerStatusList.MULTILINE_CMDS then
            -- 检查结束标志是否和开始标志匹配
            if (MultilineCMDNodeTemp.type == COMMAND_BINDING and args[3] == "@")
                or (MultilineCMDNodeTemp.type == COMMAND_INDEPEND and args[3] == "$")
            then
                -- 将结束标志前方指令添加至多行文本容器中
                table.insert(MultilineCMDNodeTemp.command, args[2])
                -- 将指令列表拼接为字符串
                MultilineCMDNodeTemp.command = table.concat(MultilineCMDNodeTemp.command, " ")
                -- 将多行指令节点临时对象添加到节点列表中
                table.insert(NodeList, MultilineCMDNodeTemp)
                -- 重置多行指令节点临时对象
                MultilineCMDNodeTemp = {command = {}}
                -- 重置当前编译器状态
                compilerStatus = CompilerStatusList.SINGLELINE
            -- 否则输出语法错误
            else
                OutputSyntaxError("start and end flags do not match")
            end
            -- 将结束标志前方指令添加至多行文本容器中
            table.insert(MultilineCMDNodeTemp.command, args[2])
        -- 否则如果当前行为单行状态，则缺失了开始标志，输出语法错误
        elseif compilerStatus == CompilerStatusList.MULTILINE_CMDS then
            OutputSyntaxError("missing multiline command start flag")
        end
    end,
    -- 匹配单行注释
    ["^(%s*%%%%(.*))$"] = function(args)
        -- 如果当前为多行指令，则将当前行原始内容添加至多行文本容器中
        if compilerStatus == CompilerStatusList.MULTILINE_CMDS then
            table.insert(MultilineCMDNodeTemp.command, args[1])
        end
    end,
    -- 匹配多行注释起始标志
    ["^(%s*%%{)$"] = function(args)
        -- 如果当前为单行状态，则解析当前行语法
        if compilerStatus == CompilerStatusList.SINGLELINE then
            -- 设置当前编译器状态为多行注释
            compilerStatus = CompilerStatusList.MULTILINE_NOTES
            -- 设置多行注释起始位置
            lineNumberMultilineNoteStart = lineNumber
        -- 如果当前为多行注释，则出现了嵌套，输出语法错误
        elseif compilerStatus == CompilerStatusList.MULTILINE_NOTES then
            OutputSyntaxError("multiline directives do not support nesting")
        -- 如果当前为多行指令，则将当前行原始内容添加至多行文本容器中
        else
            table.insert(MultilineCMDNodeTemp.command, args[1])
        end
    end,
    -- 匹配多行注释结束标志
    ["^(.*}%%(.*))$"] = function(args)
        -- -- 如果结束标志后方仍有其他内容，则输出警告
        -- if #args[4] ~= 0 then
        --     OutputWarning("content behind the end flag will be discarded")
        -- end
        -- -- 如果当前为多行指令，则解析当前行语法
        -- if compilerStatus == CompilerStatusList.MULTILINE_NOTES then
        --     -- 检查结束标志是否和开始标志匹配
        --     if (MultilineCMDNodeTemp.type == COMMAND_BINDING and args[3] == "@")
        --         or (MultilineCMDNodeTemp.type == COMMAND_INDEPEND and args[3] == "$")
        --     then
        --         -- 将结束标志前方指令添加至多行文本容器中
        --         table.insert(MultilineCMDNodeTemp.command, args[2])
        --         -- 将指令列表拼接为字符串
        --         MultilineCMDNodeTemp.command = table.concat(MultilineCMDNodeTemp.command, " ")
        --         -- 将多行指令节点临时对象添加到节点列表中
        --         table.insert(NodeList, MultilineCMDNodeTemp)
        --         -- 重置多行指令节点临时对象
        --         MultilineCMDNodeTemp = {command = {}}
        --     -- 否则输出语法错误
        --     else
        --         OutputSyntaxError("start and end flags do not match")
        --     end
        --     -- 将结束标志前方指令添加至多行文本容器中
        --     table.insert(MultilineCMDNodeTemp.command, args[2])
        -- -- 否则如果当前行为单行状态，则缺失了开始标志，输出语法错误
        -- elseif compilerStatus == CompilerStatusList.MULTILINE_CMDS then
        --     OutputSyntaxError("missing multiline command start flag")
        -- end
    end,
    -- 匹配标签语句
    ["^(%s*#%s*(.-)%s*)$"] = function(args)
        -- 如果当前为单行状态，则解析当前行语法
        if compilerStatus == CompilerStatusList.SINGLELINE then
            table.insert(NodeList, {
                file = fileName,
                line = lineNumber,
                type = NodeType.LABEL,
                name = args[2]
            })
        -- 如果当前为多行指令，则将当前行原始内容添加至多行文本容器中
        elseif compilerStatus == CompilerStatusList.MULTILINE_CMDS then
            table.insert(MultilineCMDNodeTemp.command, args[1])
        end
    end,
}

-- 当前正在编译的脚本文件名
fileName = "Test.ds"

inputFile = io.open(fileName)

-- 当前编译位置行号
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
        if not _isFoundRule then
            -- 如果没有找到对应的规则，则检查当前状态
            -- 如果当前状态为多行指令，则将当前行原始内容添加至多行文本容器中
            if compilerStatus == CompilerStatusList.MULTILINE_CMDS then
                table.insert(MultilineCMDNodeTemp.command, _str_line)
            -- 否则如果当前状态不为多行注释，则输出语法错误
            elseif compilerStatus ~= CompilerStatusList.MULTILINE_CMDS then
                OutputSyntaxError("unknown syntax")
            end
        end
    -- 读取失败则表示到达文件尾部，结束循环
    else
        break
    end
end

-- 检查编译器状态是否正常
if compilerStatus == CompilerStatusList.MULTILINE_CMDS then
    OutputSyntaxError("mutline commands flag not closed", MultilineCMDNodeTemp.line)
elseif compilerStatus == CompilerStatusList.MULTILINE_CMDS then
    OutputSyntaxError("mutline notes flag not closed", lineNumberMultilineNoteStart)
end

-- speaker, words = string.match("*", "^%s*(.-)%s*%*%s*(.*)$")
-- print(type(speaker), words)

os.execute("pause")