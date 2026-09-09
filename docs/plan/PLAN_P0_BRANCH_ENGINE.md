# P0 详细计划:选择支与分支引擎

> 目标:让玩家能从共通线出发、经过地图选择/对话选择,一路玩进任意一条已解析
> 的角色线(ru / 后续 st 扩展),并在流程图上留下正确的选择记录。
> 完成后"游戏能通关"的定义从"播放开场"升级为"分支路由与原版一致"。

---

## 0. 现状与缺口

| 能力 | 现状 | 缺口 |
|---|---|---|
| 文本/语音/BGM/舞台 | ✅ 可播,32 帧轨迹与基线一致 | — |
| 跨文件跳转 | `_jump_to_next_scene_or_storage()` 只认 `type==0` 且无条件的 next | 遇到带 `eval` 的 next 会盲选第一个;`_jump_to_next_storage()` 是空桩 |
| 选择支 UI | `scenes[].selects` 完全未解析 | 无选择界面、无选择记录 |
| 分支标志位 | 不存在 | 需要新建 flags 状态机并入存档 |
| 跳过已读文本 | 未实现 | 选择支重复观看依赖它(本计划只留接口) |

## 1. 已核实的数据契约(实现时以此为准)

### 1.1 选择支挂在 scene 上

```jsonc
// scenes[N] 同时携带:
"selects": [                       // 非空 = 到达此 scene 末尾时弹出选择
  {
    "exp":    "SetBranchFlags(\"ST02_03*MAP_move_1\",1)",  // 选中后执行(共 45/45 都有)
    "eval":   "CheckBranchFlags(\"map1_sak && map2_sak && map3_sak && acc_sak\")",
              // 可选(15/45):非空表示此选项仅在表达式为真时显示(地图选择的时间表)
    "name":   "咲夜",                 // 对话选择:不显示;地图选择:角色名(33/45 有)
    "place":  "廊下",                 // 地图选择的地点标签
    "text":   "卯ノ花に似合いそうなアクセサリー",  // 对话选择的按钮文案(12/45)
    "render": 1,                      // (12/45)有 = 对话选择样式
    "tag":    "ST04_04*0429_select:1",// (12/45)流程图节点 tag
    "selidx": 0,                      // 排序键
    "storage": "un_map01.ks",         // 45/45 全部跨文件
    "target": "*sak_map1"
  }, ...
],
"selectInfo": { "_type": 2, "_line": 461, "_init": {"bg": "school_classroom_A"} }
// _type==2  → 地图选择(5 个 scene,按 name+place 渲染大按钮,_init.bg 是底图)
// 无 _type → 对话选择(3 个 scene,text/render 字段驱动)
```

实测分布:8 个 scene、45 个选项;全部 `storage` 均为跨文件跳转;`selidx` 是稳定排序键。

### 1.2 分支判定

```jsonc
// scenes[N].nexts[] 的 eval 变体(共 5 种,全部实测枚举):
"CheckBranchFlags(\"acc_aoi\")"            // 单标志
"CheckBranchFlags(\"map1_sak && map2_sak && map3_sak && acc_sak\")"  // && 连接
// nexts 数组按顺序求值,第一个 eval 为真(或无 eval)的项生效;末尾通常有无
// eval 的兜底项。type==1 是不可达哨兵(跳 error.ks),永远跳过。
```

### 1.3 标志位的原版语义(`assets/main/scnchart.tjs`,已核对)

- `SetBranchFlags(key, value)`:写入 `f[key] = sf[key] = value`(f=游戏内,sf=系统全局)。
- `CheckBranchFlags(exp)`:把 exp 当 TJS 表达式求值;`CheckBranchFlags("a && b")`
  里的裸名先经 `UpdateBranchFlags` 从映射表展开成数值比较。
- **展开表在 `assets/main/scnchartdata.tjs`**(12.5 万字符,自动生成,无需再 dump):
  `"flags" => %[ "acc_sak" => [["ST04_04*0429_select", 1, 1]] ]`
  语义:`key 的值 = Σ (对每个条目: 若 f[场景*选择点] == 记录值 则 +1)`,即
  `CheckBranchFlags("acc_sak")` ≡ `f["ST04_04*0429_select"] == 1` 的累计。
  → Godot 侧只需把 `CheckBranchFlags("a && b")` 解析为
  `every(name in parts: flag_value(name) > 0)`,flag_value 用同一张表计算。
- 另有 7 个 `branches` 键(`ST04_05*0429_branch1` 等)是流程图分支节点名单。

### 1.4 需要动的现有函数(`scripts/story/story_player.gd`)

- `_continue_until_text()`(L788):scene 播完调 `_jump_to_next_scene_or_storage`,
  需改为"先查 selects,再求值 nexts"。
- `_jump_to_next_scene_or_storage()`(L827):加 eval 求值与兜底语义。
- `_jump_to_next_storage()`(L848):空桩 → 真实现(同 storage 链尾续接)。
- `export_save_state()` / `import_save_state()`(L3933/L4032):加 flags 与
  selection history 两个新字段。
- `_clear_runtime_story_state()`(L4093):重置 flags 的运行态部分。

## 2. 实施步骤(按依赖排序,每步可独立验证)

### 步骤 1:标志位状态机 `BranchFlags`(~80 行,纯逻辑,先行合入)

- [x] 新建 `scripts/story/branch_flags.gd`(RefCounted,非 autoload,由
      StoryPlayer 持有),字段:
  - `scene_values: Dictionary` — `"ST04_04*0429_select" -> int`(选择点取值)
  - `flag_cache: Dictionary` — 展开计算缓存
- [x] 启动时解析 `assets/main/scnchartdata.tjs`:它是 TJS 源文本但结构规整,
      用正则抽取 `"flags"` 段的 `key => [[scene, value, weight], ...]` 条目
      (不需完整 TJS 解析器;写 `tools/compile_branch_flags.py` 把它一次性
      编译成 `assets/ui/compiled/branch_flags.json` 入库,运行时读 JSON,
      与 UI 编译管线同一模式)。
- [x] API:
  - `set_branch(key: String, value: int)`
  - `check(expr: String) -> bool`:解析 `name (&& name)*`;每个 name 取
    `Σ(scene_values[tag]==v ? w : 0) > 0`(与 UpdateBranchFlags 对齐,当前
    数据 weight 恒为 1)
- [x] 验证:单测脚本 `tools/qa_branch_flags.gd` 覆盖:单标志、`&&` 链、
      未知 name 视为 false、重复 Set 覆盖语义。

### 步骤 2:nexts 求值与跨文件跳转(~60 行)

- [x] `_jump_to_next_scene_or_storage()` 重写:
  1. 顺序遍历 nexts,跳过 `type != 0`;
  2. 有 `eval` → `BranchFlags.check(eval)`,为假继续;
  3. 命中项:`storage` 缺省 = 当前文件(同文件 `_select_scene`);
     跨文件 `_load_scenario()` + `_select_scene()`;
  4. 全部落空 → `_show_error`(保留现有错误通道,不静默)。
- [x] `_jump_to_next_storage()` 真实现:场景无 nexts 时,顺序扫描同文件
      之后 label 的首个可跳项;找不到才报"End of playable scenario"。
      (现有 75 文件全部经 nexts 链接,此函数只是防御性兜底。)
- [x] **不实现**任意 `exp` 求值:遇到非 `CheckBranchFlags(...)`/非 error
      哨兵的 `exp`(当前数据里仅 `ru05_04 → start.ks *gameend_title` 一处
      回标题),硬编码为"跳回标题"并在 trace 中记录 `gameend` 事件。
- [x] 验证:`tools/qa_story_nexts_eval.gd` —— 从 `st04_05 *0429_branch2`
      分别注入 `ST04_04*0429_select=1/2/3`,断言落到
      `*0429_sak/*0429_san/*0429_ano` 三条不同路径。

### 步骤 3:选择支数据通路(~50 行)

- [x] `scene.get("selects")` 非空时,`_continue_until_text()` 在 scene 的
      行播放完之后**不自动跳转**,改为:
  1. 过滤:有 `eval` 的选项先过 `BranchFlags.check`;
  2. 按 `selidx` 排序;
  3. `_pending_selects = 可用选项`,进入等待态(复用 `_request_action_wait()`
     的等待机制,使 skip/auto 在选择挂起时自动暂停——与原版一致);
  4. `action_requested.emit("select_show")`。
- [x] 选择后执行:`BranchFlags.set_branch(tag 解析, exp 里的数值)` →
      按 `storage/target` 跳转(复用步骤 2 的跳转函数);记录
      `selection_history`(见步骤 5)。
- [x] `exp` 解析:正则 `SetBranchFlags\("([^"]+)",\s*(\d+)\)`,不引入
      表达式求值器;解析失败按"无操作选项"处理并 push_warning。
- [x] 验证:`tools/qa_story_selects.gd` —— st02_03 地图选择 7 项按 selidx
      排列;st04_04 对话选择 4 项;选中后 flags 与落点正确。

### 步骤 4:选择 UI(地图 / 对话两型,~180 行)

- [x] 新建 `scripts/ui/select_screen.gd`(继承 `hgl_ui_screen.gd`),从
      compiled JSON 取图层;首版允许用原版按钮图层 + 代码布局:
  - **对话选择**(有 `render`/`text`):复用 `dialog.json` 的按钮三态图层
    (exit_confirm_dialog.gd 已验证该图层链),竖排 `selidx` 顺序,
    hover 播 `sel1`、点击播 `ok1`(对齐 `AudioManager` 既有映射)。
  - **地图选择**(`_type == 2`):`selectInfo._init.bg` 作底图(evimage,
    走 `_resolve_image("evimage", bg)`),选项按 `name` + `place` 渲染;
    坐标首版用 `selidx` 均布占位,**在 P3 再对照原版 `mapsel.pimg` 校准**。
- [x] 输入:左键选择、右键无操作(原版选择中不可取消);Esc 忽略。
- [x] 与 backlog/skip 的互斥:选择挂起时 `_set_message_window_hidden(false)`,
      禁用 Ctrl 快进与自动播放(`_process` 里 `_pending_selects` 判定)。
- [x] 验证:`tools/qa_capture_select_screens.gd` 截图两种选择界面,
      人工比对原版截图(截图来源:游戏 OR 原版 `qa/reference/`,任务清单
      里已有"获取原版截图"条目,此处合并推进)。

### 步骤 5:存档与回放(~40 行)

- [x] `export_save_state()` 新增:
  - `"branch_flags": scene_values`(整型字典,直接 JSON 安全)
  - `"selection_history": [{storage, target, tag, selidx}]`(流程图/回想用)
  - `"pending_selects"`:若正挂起选择,保存选项列表;读档后重弹。
- [x] `import_save_state()` 恢复三者;`_clear_runtime_story_state()` 清空
      (新游戏)但 `jump_to_history_entry()` 保留主历史(与 backlog 既有
      preserved_history 语义一致)。
- [x] **兼容性**:旧存档无新字段 → 默认空字典,不迁移不报错。
      `SAVE_FORMAT` 加 `v: 2` 标记。
- [x] 验证:在 st04_04 选择"买给佐奈"→ 存档 → 读档 → 分支落点一致;
      `tools/qa_saveload_branch.gd` 自动化。

### 步骤 6:轨迹基线扩展与回归门(~60 行)

- [x] `tools/qa_export_story_trace.gd` 扩展第二条路线脚本:
      `st01_01 → … → st04_04 选择("佐奈")→ st04_05 分支 → 落点断言`,
      每帧记录新增 `branch_flags` 快照与 `selection` 事件。
- [x] 新基线 `qa/traces/godot_branch_trace.json`;`qa_verify_story_trace`
      支持多基线文件参数。
- [x] 把"两条 trace + 既有 qa_* 选择性回归"写进 `docs/compatibility_validation.md`
      的 Acceptance Sequence,作为后续每个改动的最低门槛。

## 3. 明确不做(防蔓延)

- **不实现**通用 TJS 表达式求值器(数据里只有 `CheckBranchFlags`/`SetBranchFlags`
  两种模式 + 一处 gameend,全部特判)。
- **不校准**地图选择的像素级坐标(归 P3,先功能后校准)。
- **不做**已读文本管理/readskip(选择 UI 的"已读 ✓"标记留接口)。
- **不碰** Windows 环境任何路径与工具。

## 4. 风险与对策

| 风险 | 对策 |
|---|---|
| 跳转目标文件缺 JSON(如 `un_map01.ks` 只有 .scn) | 跳转前 `_load_scenario` 失败时给出明确错误"需补 scn json: xxx";**P1 的 218 个 JSON 提取与本计划解耦**,sel 目标文件(un_map01 等)在原版归档中只有 .scn,联调时先人工标注预期落点 |
| scnchartdata.tjs 正则抽取漏条目 | 编译脚本输出条目数与原文件 `"branches"` 计数(7)对账;单测覆盖全部 5 种 eval 变体 |
| `&&` 之外的逻辑符 | 全量枚举过 eval(5 种)与 select eval(15 条,纯 `&&`);编译脚本遇未知语法 fail-loud 并列出 |
| 选择挂起与 skip/auto/wait 状态机互锁 | 复用现有 `_is_script_waiting()` 通道,选择是新的等待源;轨迹 instant 模式下用"注入选择"API 而非真实点击 |
| 存档兼容 | 新字段全部可选,v2 标记,旧档零迁移 |
| ~~立绘 PBD 图层元数据缺失~~ → **已解决,待回填** | 原"已知限制"已推翻:《【Godot】迁移任务经验总结》1.5 节确认现成工具 `krkr_pbd2json\pbd2json.exe` 已 64/64 导出 PBD JSON(`layer_id/name/left/top/width/height`)。**行动项:在 Windows 端把这批 pbd2json 产物(64 个 JSON,体积极小)入库到仓库约定目录**,即可解除 macOS 立绘合成对 Windows 的最后依赖;该回填与本计划解耦,但建议在步骤 4(选择 UI)联调立绘前完成 |

## 5. 工作量与顺序

| 步骤 | 预估 | 依赖 |
|---|---|---|
| 1. BranchFlags 状态机 + 编译脚本 | 0.5 天 | 无 |
| 2. nexts 求值 + 跨文件跳转 | 0.5 天 | 步骤 1 |
| 3. selects 数据通路 | 0.5 天 | 步骤 1、2 |
| 4. 选择 UI 两型 | 1~1.5 天 | 步骤 3 |
| 5. 存档/读档/回放 | 0.5 天 | 步骤 3 |
| 6. 轨迹基线 + 回归门 | 0.5 天 | 步骤 2~5 |
| 合计 | **3.5~4 天** | |

建议提交切分:步骤 1+2 一个 commit(纯逻辑+测试),步骤 3+5 一个,步骤 4 一个,
步骤 6 一个——每个 commit 都保持 `qa_verify_story_trace` 通过。

## 6. 验收标准(Definition of Done)

1. 从 `st01_01` 自动播到 `st04_04`,注入选择"佐奈",经 `st04_05 *0429_branch2`
   正确落入佐奈分支;改选"咲夜/葵/不买"各得预期落点(4 条路径全覆盖)。
2. 地图选择场景(st02_03)7 选项按 eval 过滤正确(未满足条件的选项不显示)。
3. 选择→存档→读档→继续,落点与不存档直玩一致。
4. 新旧两条 trace 基线全部通过;`qa_branch_flags`/`qa_story_nexts_eval`/
   `qa_story_selects`/`qa_saveload_branch` 全绿。
5. Windows 环境回归:`--ui-screen`/标题动作/既有存档行为无变化。

---

## 7. 完成记录(2026-09-10)

全部 6 个步骤已实现并通过验证:

| 交付物 | 状态 |
|---|---|
| `tools/compile_branch_flags.py` → `assets/ui/compiled/branch_flags.json` | ✅ 41 flag 名 / 42 triples / 7 branch 节点对账通过 |
| `scripts/story/branch_flags.gd` | ✅ 含 `CheckBranchFlags("...")` 调用串剥壳 |
| `scripts/ui/select_screen.gd` | ✅ 对话/地图两型;eval 过滤与 selidx 排序经截图与断言验证 |
| story_player.gd:nexts eval / 跨文件跳转 / selects 挂起 / 存档 v2 / gameend | ✅ 关键修复:跨文件决策"先加载后变更 cursor",避免失败决策污染状态 |
| `qa_branch_flags` / `qa_story_nexts_eval` / `qa_story_selects` / `qa_saveload_branch` | ✅ 全绿 |
| 双轨迹基线:opening(32 帧)+ branch(201 帧,st04_04 佐奈选择 → st04_05 acc_san 判定 → 0429_sel.ks 决策) | ✅ 双 verify 通过 |
| `qa_capture_select_screens.gd` | ✅ 窗口模式截图两型(headless 自动跳过) |

实现中的关键修正(对应计划风险表):

1. `check()` 接收的 eval 是完整调用串 `CheckBranchFlags("...")`,需要剥壳再按
   `&&` 拆分。
2. 跨文件决策必须"先 `_load_scenario` 成功再变更 storage/target"——先改后载
   会让失败决策留下错配状态(storage 指向新文件而 scenario 仍是旧文件),后续
   推进会在错误的剧本上播放。
3. `_show_error` 只写消息框不更新 `current_entry`,轨迹终态检测需读实时
   text_label,否则缺 JSON 路径会以旧台词无限重发决策。

已知边界(与风险表一致):branch2 的落点 0429_sel.ks 的 SCN JSON 尚未导出,
轨迹以"决策记录 + 显式 Scenario not found"收尾;P1 补齐剩余 218 个 JSON 后
该路径可继续播放。
