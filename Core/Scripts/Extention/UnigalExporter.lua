--[[
    DreamScript -> UnigalScript 导出工具
    + Export(src, dst)：将 src 路径下的 DreamScript 文件导出到 dst 指定的 UnigalScript 文件中
--]]

DSCompiler = UsingModule("DSCompiler")
DSCompilerConfig = UsingModule("DSCompilerConfig")

XML = UsingModule("XML")

_module = {}

-- 绑定和非绑定指令前缀注释映射表
-- 因 Unigal 当前标准下不支持在 <codeblock /> 标签中存放其他标签
-- 为区分绑定指令和非绑定指令，在代码块前方添加注释
local _CommentPrefixMapping = {
    [DSCompilerConfig.NodeType.COMMAND_BINDING] = " -- non-blocking command \n",
    [DSCompilerConfig.NodeType.COMMAND_INDEPEND] = " -- blocking command \n"
}

_module.Export = function(src, dst)

    local _result_compile = DSCompiler.CompileFile(src)

    -- 如果编译结果为 nil 则报错并直接返回
    if not _result_compile then
        print("Export failed: source file compile failed")
        return
    end

    local _document = XML.CreateEmpty()

    local _node_head = _document:AppendChild("head")
    local _node_body = _document:AppendChild("body")

    local _node_src_engine = _node_head:AppendChild("src_engine")
    _node_src_engine:SetText("DreamFramework - EntherEngine")

    for _, node in ipairs() do
        -- 处理对话语句
        if node.type == DSCompilerConfig.NodeType.DIALOGUE then
            local _node_text = _node_body:AppendChild("text")
            local _node_name = _node_text:AppendChild("character"):AppendChild("name")
            if #node.speaker ~= 0 then
                _node_name:SetText(node.speaker)
            else
                _node_name:AppendChild("NULL")
            end
            local _node_part = _node_text:AppendChild("content"):AppendChild("part")
            if #node.words ~= 0 then
                _node_part:SetText(node.words)
            else
                _node_part:AppendChild("NULL")
            end
        -- 处理标签语句
        elseif node.type == DSCompilerConfig.NodeType.LABEL then
            _node_body:AppendChild("code"):AppendChild("struct")
                :AppendChild("label"):AppendChild("label_name"):SetText(node.name)
        -- 处理 绑定/非绑定 指令
        else
            local _node_codeblock = _node_body:AppendChild("codeblock")
            _node_codeblock:AppendAttribute("enginefamily"):SetValue("EtherEngine")
            _node_codeblock:AppendAttribute("enginename"):SetValue("DreamFramework")
            _node_codeblock:AppendAttribute("lang"):SetValue("Lua")
            _node_codeblock:SetText(_CommentPrefixMapping[node.type]..node.command)
        end
    end

    _document:SaveAsFile(dst)

end

return _module