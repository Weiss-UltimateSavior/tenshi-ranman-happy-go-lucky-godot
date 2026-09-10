# 天神乱漫 Happy Go Lucky!! Godot 迁移任务表

目标：迁移到 Godot，并在视觉 UI 上尽力做到 100% 还原 HGL 版。

## 阶段 1：工程骨架

- [x] 创建 Godot 4.6 工程。
- [x] 固定设计分辨率为 1280x720。
- [x] 建立 `assets/`、`scenes/`、`scripts/`、`tools/`、`qa/` 目录。
- [x] 接入 `hash_manifest.json` 的 autoload 入口。
- [x] 复制或硬链接必要 UI 源资产。
- [x] 生成 UI 资产清单。
- [x] 建立 Godot 侧 HGL UI 公共运行层，复用 krkrZ Layer 缩放、贴图载入和 slot 定位规则。

## 阶段 2：HGL UI 资产复原

- [x] 盘点 `uipsd/*.pimg`、`uipsd/ini/*.ini`、`uipsd/func/*.func`。
- [x] 将标题相关 PIMG/PSB 拆出的 PNG 图层整理到 `assets/ui/exported/`。
- [ ] 将全部 PIMG/PSB 拆出的 PNG 图层整理到 `assets/ui/exported/`。
- [x] 重跑 FreeMote PIMG 反编译，补齐后恢复为 35/35 个 PIMG 成功输出。
- [x] 批量复制已解出的 `backlog`、`file`、`file_data`、`scnchart`、`cgviewlist`、`extra_stand`、`option_*` 等核心 PNG 图层。
- [x] 建立标题屏幕的素材、坐标、状态、动效对照表。
- [x] 建立通用 UI 编译器 `tools/compile_hgl_ui_screens.py`，输出屏幕图层、INI 绑定、FUNC 动作摘要。
- [x] 将 compiled UI 扩展到 `file`、`scnchart`、`cgviewlist`、`extra_stand`、`option_0simple` 到 `option_9gamepad`。
- [ ] 建立每个 UI 屏幕的状态、动效和动态对象对照表。
- [ ] 对缺失 PIMG 名称继续补 hash 映射。

## 阶段 3：标题界面 100% 复刻

- [ ] 获取原版标题界面截图作为 `qa/reference/title_*.png`。
- [x] 导入 `title.pimg` 图层。
- [x] 解析 `title.ini` 和 `title.func`。
- [x] 初步复刻 Start/Load/Continue/Flowchart/Extra/System/Exit 按钮位置和三态。
- [x] 标题页改为读取 `assets/ui/compiled/title_screen.json`，避免手写坐标。
- [x] 按 `main/sysse.ini` 接入标题按钮 hover/click 系统 SE。
- [x] 按 `main/default.tjs` 的 `TitleBGM=bgm54` 接入标题 BGM。
- [x] 按 `title.func` 将 Continue 在无继续记录时设为禁用。
- [ ] 精确复刻标题按钮禁用态灰度/染色和动效。
- [x] 输出当前 Godot 标题页截图：`qa/screenshots/title_current.png`。
- [ ] 获取原版截图并进行逐像素校准。

## 阶段 4：系统 UI 逐屏复刻

- [x] 建立通用静态 UI 预览器 `scripts/ui/hgl_static_screen.gd`。
- [x] 静态预览器支持 `option+option_0simple` 这类复合屏幕叠层。
- [x] 为 `option_0simple` 接入 HGL 原型实例化运行层：跳过 `_slider`、`_radbtn`、`_mute`、`_jump` 等原型状态层，并按 `cp:`、`RTX/CTX/DSSLIDER`、`<slider>` 生成按钮、开关和滑条。
- [x] 将设置页运行层扩展到已有对象数据的 `option_1display`、`option_2game1`、`option_3game2`、`option_4text`、`option_9gamepad`，支持通用 `_btn/_btn2/_btn3/_chk` 的 `RTX/TTX/RDS/BTX/BDS` 视觉状态。
- [ ] `window` / 对话框。
- [ ] `backlog` / 历史记录：底板和滚动条静态预览已通过，内容列表运行时未接。
- [ ] `file` / 存档读档：PIMG/PNG/compiled JSON 已补齐，底板预览已通过，存档条目动态内容未接。
- [ ] `option_*` / 设置页：`option_0simple/1display/2game1/3game2/4text/5sound/6dialog/8keyboard1/9gamepad` 已有 Godot 运行时；`option_5sound` 已恢复角色语音选择和角色预览，`option_6dialog` 已恢复三列 ON/OFF 确认按钮，`option_8keyboard1` 已恢复键位按钮骨架；`option_7mouse/8keyboard2` 仍需继续补命令板、拖拽分配和真实键位字符串来源。
- [ ] `quickmenu` / 快捷菜单。
- [ ] `cgviewlist` / CG 鉴赏。
- [ ] `extra_sound` / 音乐鉴赏。
- [ ] `extra_scene` / 回想。
- [ ] `scnchart` / 流程图：PIMG/PNG/compiled JSON 已补齐，静态面板预览已通过，路线节点数据未接。
- [ ] `mapsel` / 地图选择。

## 阶段 5：VN 运行时

- [ ] 定义 Godot 中间剧情格式。（当前直接读取 SCN 反编译 JSON；独立中间格式仍未定义）
- [x] 从 SCN JSON 转换剧情文本、角色、立绘、CG、BGM、SE、voice、choice。
      已用本地纯 Python 转换器 `tools/psb_to_json.py` 解出全部 216 个明文 PSB 剧本
      （`assets/scn/` JSON 75 → 291），全部地图落点与角色线正文可加载；
      2 个加密 scn（0429_sel/0604_sel）仍需 Windows FreeMote。
      （docs/plan/PLAN_P1_SCN_JSON_AND_STANDS.md §1）
- [x] 实现选择支与分支引擎：解析 `scenes[].selects`（对话/地图两型 UI、eval 过滤、selidx 排序）、`SetBranchFlags/CheckBranchFlags` 标志状态机（`tools/compile_branch_flags.py` 编译 `scnchartdata.tjs` → `branch_flags.json`）、`nexts[].eval` 分支求值、跨文件跳转与 gameend 返回标题（`docs/plan/PLAN_P0_BRANCH_ENGINE.md`）。
- [x] 实现存档 v2：branch_flags / selection_history / last_branch_decision / 挂起选择随档恢复，旧档零迁移。
- [x] 分支轨迹基线：`qa/traces/godot_branch_trace.json`（st04_04 佐奈选择 → st04_05 acc_san 判定），export/verify 支持多基线参数。
- [ ] 实现文本框、名字框、打字机、语音同步。
- [ ] 实现 Ctrl 快进、自动播放、回看、跳过已读。
- [ ] 实现存档、读档、章节状态、CG/BGM 解锁。（存读档与回放恢复已可用；章节/解锁状态未接）

## 阶段 6：完整内容接入

- [ ] 导入 bgimage、evimage、fgimage。
- [ ] 导入 voice、BGM、SE。
- [ ] 导入 video。
- [ ] 路线选择和分支完整验证。
- [ ] 与原版流程截图/日志对照。

## 阶段 7：打包

- [ ] 配置 Windows export preset。
- [ ] 导出 exe。
- [ ] 进行独立目录运行测试。
