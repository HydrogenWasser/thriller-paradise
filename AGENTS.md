# Repository Guidelines

## 项目结构与模块组织
本仓库的实际 Godot 工程位于 `thriller-paradise/`。入口场景是 `scenes/Main.tscn`。核心逻辑在 `scripts/`，其中 `GameMaster.gd` 负责 UI、输入与打字机效果，`LogicManager.gd` 负责剧情状态机与指令解析，`AudioManager.gd` 负责音频。剧情数据放在 `data/`，当前主文件为 `hirata_world.json`，设计说明见根目录 `GameDesign.md`。着色器资源位于 `shaders/`。`.godot/` 为生成目录，不要手动编辑。

## 设计基线
这是一个“纯文本流”心理恐怖游戏，核心体验依赖黑底、留白、富文本删除线、颜色突变、CRT 干扰和失控的打字机节奏。修改 UI 或文案时，优先保持“排版即视觉”的方向，不要把体验做成常规图形化冒险游戏。顶部栏、感官区、叙事区、指令区是固定骨架，除非任务明确要求，否则不要随意改动布局职责。

## 构建、运行与验证命令
在 `thriller-paradise/` 下运行：

```powershell
& "D:\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe" --path .
```

打开编辑器：

```powershell
& "D:\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe" --editor --path .
```

做无界面启动检查：

```powershell
& "D:\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe" --headless --path . --quit
```

## 代码与数据约定
遵循现有 GDScript 风格：脚本文件名使用 `PascalCase.gd`，函数和变量使用 `snake_case`，能标注类型时尽量标注。新增剧情优先写入 JSON，而不是继续把分支硬编码到脚本里。后续扩展剧情节点时，优先支持 `hidden_breaks`、`requires_flag`、`terror_change`、`reasoning_change` 这类设计稿中定义的数据字段。涉及“现实覆写”时，使用 BBCode，例如 `[color=red]` 和 `[s]`。

## 指令解析与玩法实现要求
普通输入先匹配显式选项，再处理关键词推理。若实现 `hidden_breaks`，应优先检测隐藏触发器，再回退到常规选项和兜底回复。惊吓值升高时允许乱码、谎言提示和节奏干扰；玩家识破矛盾时，应让惊吓值下降并揭示更真实的文本层。

## 测试与提交流程
仓库目前没有自动化测试。每次修改后至少验证启动、指令输入、场景跳转、富文本效果和相关剧情分支。若改动了 JSON，确认每个 `options` 和跳转节点都有效。提交信息使用简短祈使句，如 `Add hidden break parsing`。PR 需说明改动目的、涉及文件、手动验证范围；界面或表现改动附截图或短视频。

## 协作注意事项
不要删除 Godot 生成的 `.uid` 文件。`data/` 下内容默认视为人工维护的剧情资产；除非任务明确要求，否则不要大段重写已有叙事文本。若需求目标不清楚，先回到原始体验目标和设计稿约束再继续实现。
