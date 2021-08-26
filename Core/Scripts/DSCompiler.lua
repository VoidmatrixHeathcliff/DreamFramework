--[[
    DreamScript 脚本编译器
    + CompileFile(path)：编译指定路径的脚本文件
    + _PrintCompileResult(node_list)：打印编译结果（仅调试使用）
--]]

DSCompilerConfig = UsingModule("DSCompilerConfig")

_module = {}

-- 当前正在编译的脚本文件名
local _fileName = nil

-- 当前编译位置行号
local _lineNumber = 0

-- 语法错误输出
local _OutputSyntaxError = function(msg, line)
    print(string.format("SyntaxError[%s:%d]:%s", _fileName, line or _lineNumber, msg))
end

-- 警告输出
local _OutputWarning = function(msg, line)
    print(string.format("Warning[%s:%d]:%s", _fileName, line or _lineNumber, msg))
end

-- 节点类型
local _NodeType = DSCompilerConfig.NodeType

-- 编译器状态列表
local _CompilerStatusList = {
    SINGLELINE = 1,         -- 当前状态为单行
    MULTILINE_COMMAND = 2,  -- 当前状态为多行指令
    MULTILINE_COMMENT = 3   -- 当前状态为多行注释
}

--[[
    节点列表
    DIALOGUE:
        + file(string)
        + line(number)
        + type = _NodeType.DIALOGUE
        + speaker(string)
        + words(string)
    COMMAND:
        + file(string)
        + line(number)
        + type = _NodeType.COMMAND_BINDING / _NodeType.COMMAND_INDEPEND
        + command(string)
    LABEL:
        + file(string)
        + line(number)
        + type = _NodeType.LABEL
        + name(string)
--]]
local _NodeList = {}

-- 初始化编译器当前状态为单行状态
local _compilerStatus = _CompilerStatusList.SINGLELINE

-- 多行指令节点临时对象
local tempNodeMultilineCMD = nil

-- 多行注释节点开始行号（仅用于调试信息输出使用）
-- 由于注释节点不会存储进入节点列表，所以使用变量追踪其开始位置
local _lineNumberMultilineCommentStart = 0

-- 语法匹配规则
local _RULES_ = {
    {
        -- 匹配空白语句
        rule = "^(%s*)$",
        handler = function(args)
            -- 如果当前为多行指令，则将当前行原始内容添加至多行文本容器中
            if _compilerStatus == _CompilerStatusList.MULTILINE_COMMAND then
                table.insert(tempNodeMultilineCMD.command, args[1])
            end
        end
    },
    {
        -- 匹配对话语句
        rule = "^(%s*(.-)%s*[^%%]%*%s*(.*))$",
        handler = function(args)
            -- 如果当前为单行状态，则解析当前行语法
            if _compilerStatus == _CompilerStatusList.SINGLELINE then
                table.insert(_NodeList, {
                    file = _fileName,
                    line = _lineNumber,
                    type = _NodeType.DIALOGUE,
                    speaker = string.gsub(args[2], "%%%*", "*"),
                    words = string.gsub(args[3], "%%%*", "*")
                })
            -- 否则如果当前为多行指令，则将当前行原始内容添加至多行文本容器中
            elseif _compilerStatus == _CompilerStatusList.MULTILINE_COMMAND then
                table.insert(tempNodeMultilineCMD.command, args[1])
            end
        end
    },
    {
        -- 匹配单行指令
        rule = "^(%s*([@%$])[^{]%s*(.*))$",
        handler = function(args)
            -- 如果当前为单行状态，则解析当前行语法
            if _compilerStatus == _CompilerStatusList.SINGLELINE then
                local _node = {file = _fileName, line = _lineNumber}
                -- 尝试编译 Lua 语句
                local _result, _error = load(args[3])
                -- 如果编译成功则继续解析
                if _result then
                    _node.command = args[3]
                    -- 判断指令类型
                    if args[2] == "@" then
                        _node.type = _NodeType.COMMAND_BINDING
                    else
                        _node.type = _NodeType.COMMAND_INDEPEND
                    end
                    table.insert(_NodeList, _node)
                -- 如果编译失败则输出语法错误
                else
                    _OutputSyntaxError(_error)
                end
            -- 否则如果当前为多行指令，则将当前行原始内容添加至多行文本容器中
            elseif _compilerStatus == _CompilerStatusList.MULTILINE_COMMAND then
                table.insert(tempNodeMultilineCMD.command, args[1])
            end
        end
    },
    {
        -- 匹配多行指令起始标志
        rule = "^(%s*([@%$]){%s*(.*))$",
        handler = function(args)
            -- 如果当前为单行状态，则解析当前行语法
            if _compilerStatus == _CompilerStatusList.SINGLELINE then
                -- 将起始标志后方指令添加至多行文本容器中
                table.insert(tempNodeMultilineCMD.command, args[3])
                tempNodeMultilineCMD.file = _fileName
                tempNodeMultilineCMD.line = _lineNumber
                -- 判断指令类型
                if args[2] == "@" then
                    tempNodeMultilineCMD.type = _NodeType.COMMAND_BINDING
                else
                    tempNodeMultilineCMD.type = _NodeType.COMMAND_INDEPEND
                end
                -- 设置当前编译器状态为多行指令
                _compilerStatus = _CompilerStatusList.MULTILINE_COMMAND
            -- 否则如果当前行为多行指令，则出现了嵌套，输出语法错误
            elseif _compilerStatus == _CompilerStatusList.MULTILINE_COMMAND then
                _OutputSyntaxError("multiline command do not support nesting")
            end
        end
    },
    {
        -- 匹配多行指令结束标志
        rule = "^((.-)%s*}([@%$])%s*)$",
        handler = function(args)
            -- 如果当前为多行指令，则解析当前行语法
            if _compilerStatus == _CompilerStatusList.MULTILINE_COMMAND then
                -- 检查结束标志是否和开始标志匹配
                if (tempNodeMultilineCMD.type == _NodeType.COMMAND_BINDING and args[3] == "@")
                    or (tempNodeMultilineCMD.type == _NodeType.COMMAND_INDEPEND and args[3] == "$")
                then
                    -- 将结束标志前方指令添加至多行文本容器中
                    table.insert(tempNodeMultilineCMD.command, args[2])
                    -- 将指令列表拼接为字符串
                    tempNodeMultilineCMD.command = table.concat(tempNodeMultilineCMD.command, " ")
                    -- 尝试编译 Lua 语句
                    local _result, _error = load(tempNodeMultilineCMD.command)
                    -- 如果编译成功则继续解析
                    if _result then
                        -- 将多行指令节点临时对象添加到节点列表中
                        table.insert(_NodeList, tempNodeMultilineCMD)
                    -- 如果编译失败则输出语法错误
                    else
                        _OutputSyntaxError(_error, tempNodeMultilineCMD.line)
                    end
                    -- 重置多行指令节点临时对象
                    tempNodeMultilineCMD = {command = {}}
                    -- 重置当前编译器状态
                    _compilerStatus = _CompilerStatusList.SINGLELINE
                -- 否则输出语法错误
                else
                    _OutputSyntaxError("start and end flags do not match")
                end
            -- 否则如果当前行为单行状态，则缺失了开始标志，输出语法错误
            elseif _compilerStatus == _CompilerStatusList.SINGLELINE then
                _OutputSyntaxError("missing multiline command start flag")
            end
        end
    },
    {
        -- 匹配单行注释
        rule = "^(%s*%%%%(.*))$",
        handler = function(args)
            -- 如果当前为多行指令，则将当前行原始内容添加至多行文本容器中
            if _compilerStatus == _CompilerStatusList.MULTILINE_COMMAND then
                table.insert(tempNodeMultilineCMD.command, args[1])
            end
        end
    },
    {
        -- 匹配多行注释起始标志
        rule = "^(%s*%%{)$",
        handler = function(args)
            -- 如果当前为单行状态，则解析当前行语法
            if _compilerStatus == _CompilerStatusList.SINGLELINE then
                -- 设置当前编译器状态为多行注释
                _compilerStatus = _CompilerStatusList.MULTILINE_COMMENT
                -- 设置多行注释起始位置
                _lineNumberMultilineCommentStart = _lineNumber
            -- 如果当前为多行注释，则出现了嵌套，输出语法错误
            elseif _compilerStatus == _CompilerStatusList.MULTILINE_COMMENT then
                _OutputSyntaxError("multiline comment do not support nesting")
            -- 如果当前为多行指令，则将当前行原始内容添加至多行文本容器中
            else
                table.insert(tempNodeMultilineCMD.command, args[1])
            end
        end
    },
    {
        -- 匹配多行注释结束标志
        rule = "^(.*}%%%s*)$",
        handler = function(args)
            -- 如果当前为多行指令，则解析当前行语法
            if _compilerStatus == _CompilerStatusList.MULTILINE_COMMENT then
                -- 设置当前编译器状态为单行状态
                _compilerStatus = _CompilerStatusList.SINGLELINE
                -- 重置多行注释起始位置
                _lineNumberMultilineCommentStart = 0
                -- table.insert(tempNodeMultilineCMD.command, args[2])
            -- 否则如果当前行为单行状态，则缺失了开始标志，输出语法错误
            elseif _compilerStatus == _CompilerStatusList.SINGLELINE then
                _OutputSyntaxError("missing multiline comment start flag")
            -- 如果当前为多行指令，则将当前行原始内容添加至多行文本容器中
            else
                table.insert(tempNodeMultilineCMD.command, args[1])
            end
        end
    },
    {
        -- 匹配标签语句
        rule = "^(%s*#%s*(.-)%s*)$",
        handler = function(args)
            -- 如果当前为单行状态，则解析当前行语法
            if _compilerStatus == _CompilerStatusList.SINGLELINE then
                -- 检查标签名是否为空
                if #args[2] ~= 0 then
                    table.insert(_NodeList, {
                        file = _fileName,
                        line = _lineNumber,
                        type = _NodeType.LABEL,
                        name = args[2]
                    })
                -- 为空则输出语法错误
                else
                    _OutputSyntaxError("label name cannot be empty")
                end
            -- 如果当前为多行指令，则将当前行原始内容添加至多行文本容器中
            elseif _compilerStatus == _CompilerStatusList.MULTILINE_COMMAND then
                table.insert(tempNodeMultilineCMD.command, args[1])
            end
        end
    }
}

-- 编译指定路径的脚本文件
_module.CompileFile = function(path)

    -- 打开输入文件
    local _inputFile = io.open(path)
    -- 如果文件打开失败直接返回
    if not _inputFile then return end

    -- 清空上次编译缓存，重置文件名和行号
    _NodeList, _fileName, _lineNumber = {}, path, 0
    -- 重置编译器状态
    _compilerStatus = _CompilerStatusList.SINGLELINE

    -- 初始化多行指令节点临时对象
    tempNodeMultilineCMD = {
        command = {}    -- 在解析成功后会被拼接为字符串
    }

    -- 初始化多行注释节点开始行号
    local _lineNumberMultilineCommentStart = 0

    -- 开始逐行读入编译
    while true do
        -- 从脚本文件中读取一行
        local _str_line = _inputFile:read("*l")
        -- 如果读取成功则进行解析
        if _str_line then
            -- 行号自增
            _lineNumber = _lineNumber + 1
            -- 是否匹配成功标志
            local _isFoundRule = false
            -- 遍历规则列表，尝试匹配每条规则
            for _, rule in ipairs(_RULES_) do
                -- 获取匹配结果参数列表
                local _args = {string.match(_str_line, rule.rule)}
                -- 如果匹配成功，则调用处理函数，并退出匹配循环
                if #_args ~= 0 then
                    rule.handler(_args)
                    _isFoundRule = true
                    break
                end
            end
            -- 如果没有找到对应的规则，则检查当前状态
            if not _isFoundRule then
                -- 如果当前状态为多行指令，则将当前行原始内容添加至多行文本容器中
                if _compilerStatus == _CompilerStatusList.MULTILINE_COMMAND then
                    table.insert(tempNodeMultilineCMD.command, _str_line)
                -- 否则如果当前状态不为多行注释，则输出语法错误
                elseif _compilerStatus ~= _CompilerStatusList.MULTILINE_COMMENT then
                    _OutputSyntaxError("unknown syntax")
                end
            end
        -- 读取失败则表示到达文件尾部，结束循环
        else
            break
        end
    end
    
    -- 检查编译器状态是否正常
    if _compilerStatus == _CompilerStatusList.MULTILINE_COMMAND then
        _OutputSyntaxError("mutline command flag not closed", tempNodeMultilineCMD.line)
    elseif _compilerStatus == _CompilerStatusList.MULTILINE_COMMENT then
        _OutputSyntaxError("mutline comment flag not closed", _lineNumberMultilineCommentStart)
    end

    -- 返回编译结果
    return _NodeList

end

-- 打印编译结果
_module._PrintCompileResult = function(node_list)
    for _, node in ipairs(node_list) do
        if node.type == _NodeType.DIALOGUE then
            print(string.format("[%s:%d]-%s", node.file, node.line, "DIALOGUE"))
            print("[speaker]"..node.speaker)
            print("[words]"..node.words)
        elseif node.type == _NodeType.COMMAND_BINDING then
            print(string.format("[%s:%d]-%s", node.file, node.line, "COMMAND_BINDING"))
            print("[command]"..node.command)
        elseif node.type == _NodeType.COMMAND_INDEPEND then
            print(string.format("[%s:%d]-%s", node.file, node.line, "COMMAND_INDEPEND"))
            print("[command]"..node.command)
        elseif node.type == _NodeType.LABEL then
            print(string.format("[%s:%d]-%s", node.file, node.line, "LABEL"))
            print("[name]"..node.name)
        else
            print(string.format("[%s:%d]-%s", node.file, node.line, "UNKONWN"))
            print("未知属性节点")
        end
        print("\n==========================================================\n")
    end
end

return _module
