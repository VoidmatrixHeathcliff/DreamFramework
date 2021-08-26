--[[
    DreamScript 脚本编译器配置
    + NodeType：节点类型
-- ]]

_module = {}

_module.NodeType = {
    DIALOGUE = 1,           -- 对话语句
    COMMAND_BINDING = 2,    -- 绑定指令
    COMMAND_INDEPEND = 3,   -- 独立指令
    LABEL = 4               -- 标签语句
}

return _module