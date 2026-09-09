# AGENT.md — 代理工作规范

本文件汇总本仓库全部工程文档中沉淀的规范,供任何代理/开发者在本仓库工作前
通读。**每条规范后括注其出处文档**;规范与出处冲突时,以出处原文为准。

文档分层:`docs/` 根目录 = 长期有效工程文档;`docs/plan/` = 前瞻计划;
`docs/history/` = Windows 端资源恢复与早期迁移的过程记录。
(docs/history/README.md、docs/plan/README.md)

---

## 1. 工程定位与硬约束

1.1 本工程是《天神乱漫 Happy GO Lucky!!》(HGL)到 Godot 4.6 的复刻迁移,
目标是 **100% 视觉与行为还原原版 HGL**。
(MIGRATION_TASKS.md 目标行;history/【Godot】总纲 §0、§6)

1.2 引擎版本钉死 Godot 4.6/4.6.3,不得擅自升级 major/minor。
(project.godot `config/features`;ENVIRONMENT.md)

1.3 游戏资源(`assets/`,约 7GB)不入 git;装载来自拆分 7z 归档。
.gitignore 覆盖 `assets/ qa/ .godot/ *.exe` 与本地构建产物
(`tools/tlg2png/tlg2png`)。(.gitignore;README.md;提交 8ae479a)

1.4 Windows 开发者环境(原游戏目录、Codex 工作目录、`Tlg2Png.exe` 等
绝对路径)**不得破坏**;跨平台适配一律做成"按平台解析、Windows 原路径优先
保持不动"。示例:story_player 的 `_tlg2png_path()`。
(docs/tlg2png.md 使用节;scripts/story/story_player.gd;PLAN_P0_BRANCH_ENGINE.md)

1.5 DRM 合规红线:不分析/不修改/不绕过/不伪造 PlayDRM 授权,不把汉化版
DLL/EXE 当授权依据;合规路径仅限诊断、合法授权恢复、重发行与迁移版完善。
(history/天神乱漫_PlayDRM维护与授权迁移方案_20260828.md §3;history/【Godot】总纲 §7)

1.6 代理只把改动放入 git 暂存区,**commit 由用户完成**。
(来源:用户约定,2026-09-10;非文档规范)

## 2. 架构规范

2.1 **数据驱动管线优先,禁止逐屏手写坐标**:UI 一律由
"PIMG+INI+FUNC → 编译器(`tools/compile_hgl_ui_screens.py`)→ compiled JSON →
运行层装配"产出。
(docs/krkrz_hgl_ui_assembly.md §4"对 Godot 的复刻规则";history/【Godot】总纲 §2.1)

2.2 解析与生成分层:解析器/编译器只产出中间 JSON,生成器与运行层只读
中间 JSON,不再直接碰原始 dump。
(history/【Godot】总纲 §5.4"中间格式分层")

2.3 UI 运行层继承公共基类 `scripts/ui/hgl_ui_screen.gd`
(源 1920x1080 → 目标 1280x720 的 2/3 缩放、纹理缓存、slot 定位)。
(MIGRATION_TASKS.md 阶段 1;krkrz_hgl_ui_assembly.md §6)

2.4 剧情播放器是"SCN JSON 事件驱动执行器":命令/状态应用与文本显示分离,
未识别的对象类落入通用视觉路径;新增能力前先查全量命令覆盖审计
(`tools/audit_scn_command_coverage.gd` → `qa/reports/`),**数据中不存在
的命令不实现**(如 `transall`)。
(history/【Godot】总纲 §3.1、§5.1;docs/compatibility_validation.md)

2.5 资源路径解析走 `ResourceIndex`(hash manifest)与 `AppConfig` 常量,
不在业务代码里散落绝对路径;新增外部路径必须进入 AppConfig 并做平台解析。
(scripts/autoload/resource_index.gd、app_config.gd;提交 8ae479a)

## 3. UI 复刻规范

(除标注外均出自 krkrz_hgl_ui_assembly.md §4-§5、§10-11;history/【Godot】总纲 §2.2)

3.1 PSD/PIMG 图层顺序是"最上层在前":静态层一律**反向绘制**,文字层最后画。

3.2 原型(`cp:_btn`、`@x/cp:_radbtn`)是复制语义:原型层不直接画,实例按
目标 rect 平移,原点取第一个 prototype 的坐标,不是目标坐标。

3.3 辅助/覆盖层(`assign/cover`、`touchvolume/`、`bg/#help` 等)按原版默认
状态隐藏;跳过规则只限定在已接运行层的页面,防止误伤其他页。

3.4 点击只走一个入口:透明原生 Button 热区 + 视觉层 `MOUSE_FILTER_IGNORE`;
禁止框架层 `_input` 兜底与热区双层响应。

3.5 动态重建控件的 hover 不依赖 `mouse_entered`,在统一输入入口按原始坐标
每帧同步命中/悬浮。

3.6 INI/FUNC 是 UTF-16LE:编码检测必须 BOM/NUL 优先,禁止先试 cp932
(会"成功"解出乱码导致 0 对象)。

3.7 画布缩放:默认 1920→1280 用 2/3;个别资源标注异常(如 window.pimg
1440 高)时,先核对画布内其他已知控件坐标再定映射,**不要想当然改比例**。

3.8 复合屏幕(`option+option_0simple`)按"框架底图 / 详情 / 导航 overlay"
三层结构叠层,不是单文件处理。

3.9 模态弹窗用独立 `CanvasLayer`(如 layer=100)承载;`z_index` 不得超出
Godot `CANVAS_ITEM_Z_MAX`(10000 会进错误状态)。

3.10 右键返回放在 `_input` 并 `set_input_as_handled()`(放
`_unhandled_input` 会被全屏 STOP 控件拦截);返回只移除覆盖层、保留底层,
并记录返回来源。

3.11 QA 交互测试修改过 `system_settings.cfg` 的,结束必须恢复原值;
旧占位值要保留一次性兼容迁移逻辑。
(history/【Godot】总纲 §2.3)

## 4. 剧情播放器规范

(除标注外均出自 history/【Godot】总纲 §3;docs/compatibility_validation.md)

4.1 SCN 文法:`[行号, 状态字典, ...]` 是状态快照(只应用不显示);独立
数字行才是推进并显示的文本;`texts` 按同位置关联。该文法改动必须先跑
全量 QA 固化(75 文件/210 场景/14,436 文本/24,753 快照基线)。

4.2 `["new", 名, 类]` 声明与后随参数字典分离配对;对象用声明名,但播放
通道可能不同(`loopse _lse0` → 实际通道 `_se0`),改名会破坏后续 stop。

4.3 SCN 存在 mojibake(UTF-8 被 CP932 错解),资源解析前做编码修复/别名
映射(STAND_DRESS_MOJIBAKE 模式)。

4.4 相机语义:`stage` 的 xpos/ypos/zoom 是镜头(反向位移+边界);空 `env`
状态 = 恢复默认相机,不继承上一段;常量以 `envinit.tjs` 为准。

4.5 等待语义(`wait/waitvoice/wact/delaydone`)是阻塞点,必须执行而非
近似;`beginskip/endskip` 区间文本照常应用状态但不显示不进 backlog。
轨迹(fixture)用显式即时模式,运行版保留真实等待。

4.6 转场只有 `crossfade` 与 `universal`(rule 蒙版按原始灰度采样,不做
sRGB 转换,`vague=64`);`msgoff` 三种编码(布尔/数字/字符串)都要兼容;
并发转场用引用计数。

4.7 动作语义:`@+N` 相对值以"动作开始前基准值"为基准;缺失属性沿用上一
帧(部分更新不得重置角色);多段 MoveAction 编成顺序 Tween 链;清场时
取消受跟踪旧 Tween。

4.8 `day_full` 是白色 alpha 遮罩 + kokuban 黑板底图走 rule_9 转场,
不能整图 alpha 淡入;Backlog 页码是运行时 ShowDateLayer 绘制,不是整图缩放。

4.9 消息窗常量(窗口色 #D3727A、75% 透明、39px 源字号、行距 12 源像素、
已读色 #EFDFFF)从 `default.tjs/config.tjs` 取,不硬编码猜值;着色是
Photoshop Overlay 混合,shader 只复用 alpha、不重复乘 RGB。

4.10 文本渲染用原版 TFT 位图字体(`font1_39.tft`),按 krkrZ
`PrerenderedFont.cpp` 实现解析;UTF-32 按 4 字节读码点;行首 `「` 悬挂的
绘制占位与换行计算分开;禁止在 `_draw()` 里才建字形纹理。

4.11 立绘合成链:`.stand` → `.sinfo` → **PBD JSON**(图层名→layer_id+坐标,
权威层表)→ TLG 部件 PNG;身体层与脸部/部件层是两个编号域,**在拿到 PBD
层表之前不猜映射、不假装 100%**;缩放按 `custom.tjs` 的 `_1/_3` 素材档,
不加经验系数。
(history/【Godot】总纲 §1.5、§3.4;docs/tlg2png.md 已知限制节)

4.12 头像窗由 SCN 的 `originx/originy/facemask` 驱动,不按说话者自动重建。

## 5. 性能规范

(均出自 history/【Godot】总纲 §4)

5.1 后台预热线程预读后续 N 行资源与下一脚本 JSON;主线程只做合并取用。

5.2 TLG 转换绝不放主线程:缺失就排队后台转并立即返回;**按角色目录批量
转换**;全量预生成缓存 + `.complete` 标记防重转;预热线程与主线程禁止同步
转换同一文件(半写入 PNG 竞态)。

5.3 当前资源 key 去重:BGM/背景/CG/立绘视觉 key 不变就不碰播放器/不重建。

5.4 纹理上传限流(每帧限额);预读 job 去重 key 按 storage;音频内容须
验证 OggS 头(XP3 加密流曾伪装 .ogg 扩展名)。

5.5 性能以基准数字验收(0.04~9.4ms/句基线),不凭感觉调参。

## 6. QA 与验收规范

(均出自 docs/compatibility_validation.md;history/【Godot】总纲 §5.1)

6.1 **每个修复必须配一个不可回退的 QA 脚本**(`tools/qa_*.gd`),先写回归
再改渲染器/规则。

6.2 验收标准:"看起来接近"不算数 —— 原版场景可重放**轨迹**(SCN 游标:
storage/target/scene/line)+ 截图像素差异 + 输入结果 + 音频时序 + 存档状态
共同验收;没有脚本游标的截图不是验收物。

6.3 两条剧情轨迹基线(`qa/traces/`)必须始终通过:
`qa_export_story_trace.gd` 导出、`qa_verify_story_trace.gd` 校验;任何改动
后先跑轨迹再谈合并。

6.4 优先级由全量命令覆盖审计的真实频次驱动,不由个例偶遇驱动。

6.5 QA 自身问题与运行时问题先分离判断:autoload 未初始化(--script 模式
限制)、headless 无 viewport、节点路径变更、测试数据页面对不上 —— 先判
夹具过时还是真回归。

6.6 旧截图不能当调参依据:布局改动后必须用**当前构建**重放同一原始场景
再对比。

## 7. GDScript 编码规范

(均出自 history/【Godot】总纲 §5.2)

7.1 局部变量显式标注类型(`String/float/Array/Variant`);`max()/min()`、
Variant 字典取值、`:=` 混合表达式都会触发严格类型推断编译错误 —— 这是
本仓库最高频的编译错误来源。

7.2 同名函数不支持重载,改用不同函数名。

7.3 JSON 数字一律读成 float:路径拼接、索引比较前做数值规范化/同时接受
int/float(`2628.0.png` 教训)。

7.4 `bool()` 不接受字符串 Variant,"true"/"false" 字符串显式按类型分支解析。

7.5 headless 限制:dummy renderer 无 viewport 截图(加防护跳过);
`--script` 模式不初始化 autoload;`res://` 不能直接 `Image.save_png()`
(用展开绝对路径);帧截图用官方 `--write-movie`。

7.6 颜色空间:Godot 线性 vs 原 D3D 伽马;shader 输出不要重复 `pow(,2.2)`,
`source_color` 标记会二次转换。

7.7 `queue_free` 延迟销毁会造成新旧控件重叠/命中错乱 —— 运行时重建的同名
控件用同步释放;信号回调内不同步销毁节点。

7.8 Windows `.ttc` 运行时加载会崩溃:字体走项目内白名单 OTF/TTF
(SystemSettings.MESSAGE_FONT_OPTIONS)。

7.9 不留未追踪的实验性脚本/生成物冒充回退状态;并行跑多个 Godot QA 会
互相抢资源超时,拆开跑。

## 8. 工具链规范

8.1 TLG→PNG:Windows 用既有 `Tlg2Png.exe`(Codex 工作目录);其它平台用
本地构建的 `tools/tlg2png/tlg2png.c`(`cc -O2` 编译,二进制不入库);
`TJS/4s0` 容器不是图像,跳过并容错。
(docs/tlg2png.md)

8.2 立绘 PBD 图层元数据:Windows 端 `krkr_pbd2json\pbd2json.exe` 已
64/64 导出;**待办是把产物 JSON 入库**(见 PLAN_P0 风险表),入库前不要
用猜测映射代替 PBD 层表。
(history/【Godot】总纲 §1.5;docs/plan/PLAN_P0_BRANCH_ENGINE.md §4)

8.3 反编译统一用 Ulysses-FreeMoteToolkit v4.5.1 的 `PsbDecompile.exe`
(`-t Scn -e SHIFT-JIS -indent`);旧版 toolkit 有 DLL 冲突不可用。
(history/【Godot】总纲 §2.1、§8)

8.4 PowerShell 批处理坑:路径必须引号包完整命令行;日志先备份再探测、
优雅关闭进程再合并;60MB+ UTF-16 日志合并用 Python 不用 PowerShell。
(history/【Godot】总纲 §1.3、§5.3)

## 9. 分支引擎数据契约(P0 实施时遵守)

(均出自 docs/plan/PLAN_P0_BRANCH_ENGINE.md §1)

9.1 选择项在 `scenes[].selects`(45 项/8 场景):`exp` 必有
(`SetBranchFlags("tag",value)`),`eval` 可选(15 条,纯 `&&` 的
`CheckBranchFlags`),按 `selidx` 排序,storage 全部跨文件。

9.2 分支判定:`nexts[]` 顺序求值,跳过 `type!=0`,带 `eval` 的用标志表
求值,命中即走;eval 展开表在 `assets/main/scnchartdata.tjs`(编译成
JSON 入库);`CheckBranchFlags("a && b")` ≡ 每个名字累计命中 > 0。

9.3 **不实现**通用 TJS 表达式求值器;`ru05_04 → start.ks *gameend_title`
的回标题跳转特判。

9.4 存档 v2:新增 `branch_flags`/`selection_history`/`pending_selects`
全部可选字段,旧档零迁移。

## 10. 文档与工作流规范

10.1 文档分层:长期工程文档在 `docs/` 根;前瞻计划在 `docs/plan/`
(命名 `PLAN_<优先级>_<主题>.md`);过程记录/复盘/报告在 `docs/history/`。
(docs/plan/README.md;docs/history/README.md)

10.2 每个机制结论必须落文档(krkrz_hgl_ui_assembly.md、
MIGRATION_TASKS.md、compatibility_validation.md),防止"看起来完成但
没复刻行为";过时描述及时删改。
(history/【Godot】总纲 §5.4)

10.3 任务状态以 MIGRATION_TASKS.md 勾选为准,完成即更新。
(MIGRATION_TASKS.md)

10.4 并行读旧快照坑:改文件后按"生成→确认"顺序验证,不把生成前的旧内容
误判为新状态;Edit 补丁对不上就取精确片段拆小块,不硬套大补丁。
(history/【Godot】总纲 §5.4)

10.5 每轮工作结束确认并清理自己启动的残留进程(Godot 校验、python -、
MSBuild),不碰用户进程。
(history/【Godot】总纲 §5.4)

## 11. 核心心法

- 优先找"程序调用逻辑/数据来源",而不是暴力穷举。
(history/【Godot】总纲 §9)
- 一切参数以原始资源/脚本为证据(PIMG 坐标、tjs 常量、PBD 层表),
分析原始代码后再动手,不猜。
(history/【Godot】总纲 §9)
- 敢于承认未完成,把差距拆成可量化清单逐个收敛。
(history/【Godot】总纲 §9)
