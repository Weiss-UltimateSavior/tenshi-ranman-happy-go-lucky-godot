# 【Godot】天神乱漫 Happy Go Lucky!! 迁移任务经验总结

> 来源会话：`F:\我的文档\Documents\codex会话保存\【Godot】天神乱漫 Happy Go Lucky!!.txt`
> 任务主线：将 Slapstick（天神乱漫前作，2002，MEG/MGD/MGS 封包）迁移至 Ren'Py；解析并 98%+ 还原天神乱漫 Happy GO Lucky!!（Hxv4/PackinOne/cxdec XP3 封包）的哈希文件名；最终在 Godot 4.6 中以"100% 视觉复刻"为目标重建整个游戏（UI、立绘、剧情脚本、字体、音频、存档、Backlog、流程图等）。
> 本文件为该任务全程经验沉淀，按主题归纳，供后续同类任务直接复用。

---

## 0. 任务全景与最终状态

- **Ren'Py 迁移（Slapstick）**：241 个 `.MEG` 脚本、397 张图、5605 个 WAV、开场视频均接入，可启动可阅读；后按用户要求改为"中间 JSON 剧本 → 生成器 → Ren'Py"的工作流（对齐 LYRIC 项目做法）。
- **资源逆向（天神乱漫 HGL）**：`.alst` 口径文件名覆盖率从 22% 一路推进到 **99.72%**（36,726/36,829）；关键包 fgimage 99.94%、voice 99.98%、evimage 99.84%。
- **Godot 复刻**：标题/系统设定/存读档/Backlog/流程图/Extra/退出确认等 UI 均按原版 PIMG 坐标复刻；剧情播放器从"静态快照"升级为执行原始 SCN 命令链的播放器（转场、相机、粒子、滤镜、等待语义、TFT 字体等）；剧情推进性能从平均 992ms/句优化到 20~25ms/句（后续实测 0.04~9.4ms）。
- **相关报告产出**：
  - `F:\我的文档\Documents\Computer\report\天神乱漫_Hxv4_PackinOne_hash获取方案评估_20260620.md`
  - `F:\我的文档\Documents\Computer\report\天神乱漫_hash映射流程复盘_20260620.md`
  - `F:\我的文档\Documents\Computer\report\天神乱漫_PlayDRM维护与授权迁移方案_20260828.md`

---

## 1. 封包与资源逆向（Hxv4 / PackinOne / cxdec XP3）

### 1.1 核心机制结论
- XP3 索引里**没有真实文件名**，只有 `Ordinal` 生成的单字假名（`倀/倁/倂…`）。真实文件名是运行时由脚本/系统把字符串传给 `PackinOne.dll` 的 `PathNameHasher/FileNameHasher.Calculate()` 算出 hash 后去文件表匹配的。
- 完整还原必须合并两半：
  1. **内容提取**：`CxdecExtractor` 借游戏内部 `CxCreateIndex/CxCreateStream` 按 hash 导出文件 + `.alst`（目录hash/文件hash 表）。
  2. **名字映射**：`CxdecStringDumper` Hook hasher 虚表，记录 `文件名##YSig##hash` 到 `FileNameHash.log / DirectoryHash.log`（UTF-16LE）。
- hash 是单向的：日志里没有的 hash 无法反推原名，只能继续从"上游来源"找候选名。
- **批量探针（HashProbe）**：给 StringDumper 加一个可选线程，若存在 `StringHashDumper_Output\HashProbeCandidates.txt`，就逐行调用 `TVPIsExistentStorage(name)` 触发原版 hasher 写日志——这是不跑剧情就能批量补名的关键手段。

### 1.2 高收益候选来源优先级（实测验证的排序）
1. **SCN/PSB 内部恢复（决定性跃迁 43%→95%）**：对未命名的 `.ks.scn` PSB 用 FreeMote/Ulysses 反编译，JSON 根节点 `name` 直接给出脚本名，`voice/file/bg/bgm/storage/image` 字段给出资源名。**这一步应该前置到项目早期（基础工具链打通后立即做），不要先做大量编号爆破。**
2. **伴生文件派生规则**：`.ogg → .ogg.sli`（WaveLoopManager 伴生）、`.png → .pimg` 等，是"调用逻辑"不是穷举。
3. **内容反推**：未命名 UI 文件（ini/func）是 UTF-16 明文，内容里有 `psd,xxx`、`inc,option_comm.ini` 等字段 → 直接反推文件名（uipsd 29.7%→76%）。
4. **同源游戏文件表借名**：同厂游戏（千恋万花等，GARbro 可读真名）的 basename 喂给本作 hasher 验证；同内容文件按"大小+SHA256"跨游戏精确匹配（一次抓回 91 个系统脚本名）。
5. **编号规律受限爆破**：BGM 编号、EV 差分双字母（`ev0217aa`）、语音"角色前缀+场景号+行号"补洞；增量递减时（+528→+166→+119）果断停手。
6. **序列帧目录规律**：`video/fure_l/` 类目录按 0~240 帧序生成，一轮把 video 打到 95.34%。
7. **API 上游 Hook**：hook `TVPIsExistentStorage / TVPGetPlacedPath / TVPCreateIStream` 可看到真实 storage path 与调用栈（区分脚本层/插件/XP3 伪路径）；但启动阶段资源基本已覆盖，收益小，适合剧情推进时持续抓。
8. **二进制字符串扫描**：过滤后收益极低（只剩 25 个且多为误报），最后再做。

### 1.3 关键操作纪律（踩坑换来的）
- **每次跑探针前必须备份 `StringHashDumper_Output`**：dumper 启动会重建日志，强杀进程会导致 logger 未 flush、日志 0 字节。正确做法：`CloseMainWindow` 优雅关闭游戏后再读日志；合并时"备份 + 本轮新日志"去重合并。
- **合并/重建 manifest 拆步跑**：PowerShell 处理 60MB+ UTF-16 日志会超时，用 Python 做去重合并更稳；日志有 UTF-16/UTF-8 BOM 混用问题，合并后要按 UTF-16 写回。
- **日志文件锁**：probe 结束后游戏/loader 进程可能仍占用日志，先确认无残留进程再合并，先写临时目录再复制回。
- **Loader 启动细节**：`Start-Process -ArgumentList ('"{0}" --hash' -f $game)` 必须显式加引号，含空格路径会被截断；GARbro Console 的参数是 `-l`/`-x`（带横杠），不带横杠空输出没有参考价值。
- **依赖 DLL 检查**：`tenshin_hgl.exe` 导入表硬依赖 `Mai@KF.dll`（缺失则弹窗），捕获要用 `天神乱漫 Happy GO Lucky!!.exe`（依赖存在的 `ShiraYukiNoa.dll`）。用 `dumpbin /imports` 确认。
- **hash 日志膨胀控制**：FileNameHash.log 最终 70 万+ 行（含大量候选），真实有效性只看与 `.alst` 的交集（manifest 统计），不要被行数迷惑。

### 1.4 GARbro 定制
- 改 `ArcFormats/KiriKiri/ArcXP3.cs`：`KnownSchemes` 字典初始为空导致下拉框看不到新方案 → 改为惰性注入内置方案（`EnsureBuiltinSchemes()`）；自动检测同时认多个 exe 名（含中文文件名）。
- 改完必须重编译 ArcFormats + Console + GUI，并用二进制查 UTF-16 字符串/时间戳验证（PowerShell 反射检查会栈溢出，别走那条路）。
- 转换器小工具模式：写独立 C# 程序只引用 `GameRes.dll/ArcFormats.dll`（如 `Tlg2Png.exe`），不污染 GARbro 源码；注意 MEF 加载需要把 GARbro Release 的依赖 DLL 拷到 exe 旁边；WPF 图像解码需要 `[STAThread]`。

### 1.5 PBD（立绘层表）
- `.pbd` 是 `TJS/4s0` 二进制序列化（柚子社自有加密层，非 krkrZ 的 `KBAD100`），KrkrExtract 的 PbdDecoder 只到 ChaCha/BLAKE2s 初始化，没实现完。
- **现成工具 `krkr_pbd2json\pbd2json.exe` 可完整解析**（借原引擎 `Scripts.loadDataPack()`），输出 `layer_id/name/left/top/width/height`；64/64 个 PBD 全部导出成功。
- 教训：立绘"脸编号+16"之类的猜测映射必然错位——身体层（`_1_3..25` 大图）和脸部/部件层（`_1_26+` 小图）是两个编号域；`.sinfo` 只给"名称→图层名"，PBD 才给"图层名→序号+坐标"。**找到"序号→图层名"那一层之前不要假装 100%。**

---

## 2. UI 100% 复刻（PIMG / INI / FUNC 体系）

### 2.1 原版 UI 组装模型（krkrZ + HGL 脚本）
- krkrZ 只提供 Layer 树（父子、坐标、可见性、绘制顺序、命中转发）；真正的 UI 语义在游戏资源里：
  - `.pimg`（PSB 容器）：画布尺寸（1920x1080）、图层树、图层 PNG 切片。
  - `.ini`：对象声明，`@obj:slot` 绑定、`cp:_btn` 原型复制、`<slider>`/`<onoff>`/`<key>` 控件声明、`RTX/TTX/BTX/CTX/DSSLIDER` 状态宏。
  - `.func`：行为与默认状态（如 `helpbase,visible,false`、`sysse,title`、按钮动作）。
- **推荐架构**：写"UI 编译器"把 PIMG+INI+FUNC 编译成 JSON（图层、对象、控件、绑定），Godot 运行层按 JSON 装配。手写坐标必然错。
- 复用现成工具：GARbro 可把 `.pimg` 当容器抽 TLG（再用 Tlg2Png 转 PNG）；FreeMote `PsbDecompile` 可反编译 `.pimg/.ks.scn` 为 JSON（旧版 toolkit 会因 `System.Runtime.CompilerServices.Unsafe` DLL 冲突失败，**Ulysses-FreeMoteToolkit v4.5.1 可用**）。

### 2.2 反复出现的通用规则（每条都踩过坑）
- **PSD 图层顺序是"最上层在前"**：正向绘制会把底图盖住文字/标题 → 静态层一律反向绘制；文字层要在所有复制底条画完后再画。
- **原型（prototype）层不能直接画**：`cp:_btn`、`@xxx/cp:_radbtn` 是复制语义——原型画在源位置，实例要按目标 rect 平移；原点始终取第一个 prototype 的坐标，不是目标坐标。
- **辅助/覆盖层要按原版默认状态隐藏**：`assign/cover`、`assign/mask`、`touchvolume/`、`bg/#help`、`bg/help2` 等；跳过规则先限定在已接运行层的页面，避免误伤其他页（曾把 file 页清空的回归）。
- **点击只走一个入口**：透明原生 Button 热区 + 视觉层 `MOUSE_FILTER_IGNORE`。双层响应（框架层 `_input` 兜底 + 热区）会导致"切页三声音效+延迟"。
- **hover 状态**：动态重建的 TextureRect 不一定触发 `mouse_entered`；在统一输入入口按原始坐标每帧同步命中/悬浮最稳。
- **UI 编译器编码坑**：INI 是 UTF-16LE，`cp932` 能"成功"读出乱码导致解析 0 对象——必须 BOM/NUL 优先检测编码。这一坑让 4 个设置页对象数从 0 恢复到几十个。
- **源画布坐标系**：UI 多为 1920x1080 → 目标 1280x720 用 2/3 等比；但个别资源（如 window.pimg 标注 1440 高）不能想当然改 Y 比例——先核对画布内其他已知控件坐标确认实际采用的映射，再定缩放。
- **复合屏幕**：`option+option_0simple` 是两层 JSON 叠加（框架+详情），要三层结构（框架底图/详情/导航 overlay）而不是单文件处理。

### 2.3 设置页功能化要点
- 原版 `option.func` 的 `auto,fullscreen/audio/speed/skipall` 是系统自动绑定语义；实现统一 `SystemSettings` autoload（全屏、音量、静音、文字速度、跳过、确认项、颜色、字体、透明度），控件点击写状态 + 播原版 `sysse.ini` 映射的 SE。
- **QA 污染配置**：交互 QA 写过 `system_settings.cfg`（黑字、37% 透明度）污染后续截图——QA 结束必须恢复原值；旧占位值要加一次性兼容迁移。
- 色盘（`auto,colorpick`）、窗口透明度预览（`file,rendersample`）、字体选择等"运行时绘制"的对象在 PNG 里不存在，必须程序化重建。
- **模态弹窗层级**：剧情消息层用绝对高层级后，普通子节点弹窗会被压住；`z_index=10000` 超过 Godot `CANVAS_ITEM_Z_MAX` 会进错误状态——**用独立 `CanvasLayer(layer=100)` 承载模态**，别用超范围 z_index。
- 右键返回：放在 `_unhandled_input` 会被全屏 `MOUSE_FILTER_STOP` 控件拦截 → 移到 `_input` 并 `set_input_as_handled()`；返回要"只移除覆盖层、保留底下剧情"，并记录"返回来源"。

---

## 3. 剧情播放器（SCN JSON → 可执行命令链）

### 3.1 剧本数据格式（FreeMote 反编译产物）
- `[行号, 状态字典, ...]` 是**状态快照**（应用状态不显示文本）；**独立数字行**才是推进并显示的文本；`texts` 数组按同位置关联。这套文法要用全量 QA 固化（75 文件/210 场景/14,436 条文本/24,753 条快照）。
- 数字行号是全局"行号"，不保证每个都有 `texts` 项；部分行是纯状态。
- `["new", 名称, 类别]` 声明 + 后随无 class 参数字典 = 创建对象；**对象名要用声明名，但播放通道可能不同**：`loopse` 声明 `_lse0`、实际通道 `_se0`，后续 `stop _se0` 按通道名停止——改名会导致停止指令失效（音效停不下来的根因）。
- 脚本 JSON 有 mojibake：UTF-8 被 CP932 错解（`繧ｭ繝ｩ繧ｭ繝ｩ.ogg` ← `キラキラ.ogg`）、`蛻ｶ譛肴丼` ← `制服春`。资源解析前要做编码修复/别名映射。
- 相机：`stage` 的 `xpos/ypos/zoom` 是镜头（反向位移+覆盖边界），不是 UI 坐标；空 `env` 状态 = 恢复默认相机，不能继承上一段（背景被放大裁切的根因）。`slayer` 是相机层、`day_full` 默认 150% 缩放、`100%` 对应 `zorder=133` 等常量都在 `envinit.tjs`。
- 立绘 `zorder/zpos` 只做场景内排序；消息窗 `absoluteBase=1000001` 强制在最前。混用会导致立绘压住 HUD。

### 3.2 必须执行（而非近似）的原版系统
- **等待语义**：`wait` / `waitvoice` / `wact`（含 MoveAction/SinAction/RandomAction 的 tween 计数）都是阻塞点；`beginskip/endskip` 区间内文本照常应用状态但不显示不进 backlog。
- **转场**：只存在 `crossfade`（13123 次）与 `universal`+rule 蒙版（1244 次）；`universal` 按 8-bit 灰度阈值揭示（**规则图按原始数值采样，不做 sRGB 伽马转换**），`vague=64` 默认；`msgoff` 是转场期间临时收起消息窗（布尔/数字/字符串三种编码都要兼容），并发转场要引用计数。
- **滤镜**：`doBoxBlur`、`doGrayScale`、`adjustGamma`、`tc_overcolor/tc_light`、`overcolor`——统一材质，递归应用到立绘 PSD 分层。
- **特效层**：`stageeff`（flare/花火）= `ltAdditive` 加法混合、位于背景与事件 CG 之间、不随相机；`.asd` 逐帧时序播放；`particle`（rise1~5）是 60 帧精灵图发射器，按原始宏参数（范围/角度/速度/寿命/淡出）实时生成；`raster/rasterlines/rastercycle` 是逐扫描行位移 shader。
- **动作**：`@+N` 相对值以"该动作开始前的基准值"为基准（非累计）；缺失属性沿用上一帧（部分更新不能把角色重置回 (0,0)）；`opacity 0..255`、`visvalue 0..100` 语义分开；多段 MoveAction 编成顺序 Tween 链。
- **日期卡**：`day_full` 是白色 alpha 遮罩 + `kokuban.png` 黑板底图（`cg_kokuban` 宏），走 `rule_9` 遮罩转场，**不能整图 alpha 淡入**（发灰根因）；`showdate.tjs` 的 Backlog 页码是运行时 ShowDateLayer（花朵+文字），不是 `date_full` 整图缩放。

### 3.3 消息窗与文本渲染
- 原版常量要从 `default.tjs/config.tjs` 取：窗口色 `#D3727A`、75% 透明度、正文 39px 源字号（SizeCoef 26）→ 输出 26px、行距 12 源像素 → 8px、未读白字/已读 `#EFDFFF`、描边启用时不叠加阴影。
- 消息窗着色 = **原版 `omPsOverlay`（Photoshop Overlay 混合，伽马空间）**，不是普通 modulate 乘色。Godot 坑：`canvas_item` shader 的输入 `COLOR` 已含纹理采样色，最后再 `* COLOR` 会把灰度底图二次相乘压暗（RGB(121,84,76) vs 原版 RGB(225,174,175)）——只复用 alpha，不重复乘 RGB。
- **TFT 位图字体**：原版默认字体不是 OTF，是 `deffontmap.tjs` 指定的 `font1_39.tft`（预渲染位图字体）。按 krkrZ `PrerenderedFont.cpp` 实现解析：Unicode 索引 + RLE 解压 + `OriginX/OriginY/AscentOfsY` 基线 + 39+12=51 源像素行进。日文 UTF-32 缓冲区要按 4 字节解码码点（按单字节读会把"春樹"拆成高低字节乱码）。行首 `「` 悬挂：绘制占位压缩到 3 源像素，但换行计算仍按完整字格——绘制与换行占位分开。
- TFT 性能：首次全字库解压 1.1s → 只解码所需字形 156ms → 惰性+首屏预热+分帧预热+描边 GPU 绘制 → 31 字形约 24~29ms。**不要在 `_draw()` 里才建字形纹理**（会白屏）；入树前 `queue_redraw()` 不生效要 deferred。
- `TextureRect` 与自定义 `_draw()` 组合时原生纹理路径会吞自绘结果 → 位图文本用纯 `Control`。
- Backlog 行文 = 名称区（右对齐 `x=47..504`）+ 正文区（左对齐 `x=524..1639`）两块独立 TextRender，不是拼接居中单行；历史行高 `blockStep=180`。

### 3.4 立绘合成（StandLayer 复刻）
- 链路：`.stand`（角色/pose 入口，UTF-16LE，含 `xoffset/yoffset/leveloffset/facexoff/faceyoff`）→ `.sinfo`（dress/face/pose → 图层名）→ **PBD JSON**（图层名 → layer_id + left/top/width/height）→ TLG 部件 PNG。
- 缩放：`custom.tjs` `StandLayer._selectImage`——按 `zoom` 选 `_1`（50%）或 `_3`（100%）素材，`1/(zoom/imageScale)` 构造仿射；**不要额外乘 0.5 之类的经验系数**（立绘变半大的根因）；顶部保护不要夹住原版负向 Y 偏移。
- 头像窗（msgwin/face）由 SCN 的 `originx/originy/facemask` 驱动，不要"按说话者自动重建"覆盖脚本指定的表情。
- **旧截图不能当调参依据**：布局改动后必须用当前构建重放同一原始场景再对比，否则会把已修复的部分改回去。

---

## 4. 性能优化（剧情无感推进）

实测路径：992ms/句（峰值 17.7s）→ 40ms → 25ms → 0.04~9.4ms。手段按收益排序：

1. **资源预热**：后台线程预读后续 N 行资源（背景/CG/立绘部件/语音/BGM）；跨脚本时预读 next storage 的 JSON + 扫描其开头资源。
2. **路径解析缓存**：避免每句 `file_exists`。
3. **TLG 转换绝不放在主线程**：缺失就排队后台转并立即返回；**按角色目录批量转换**（144 个部件 24s）远快于逐文件调用转换器（10 个 53s，冷启动 .NET 是大头）；全量预生成缓存（1426/1426）+ `.complete` 标记防重转。
4. **当前资源 key 去重**：BGM 相同不碰播放器、背景/CG 相同不重设 texture、立绘/头像视觉 key 不变不销毁重建。
5. **预热扫描增量窗口**：每行只分析一次，不重复扫 80 行。
6. **纹理上传限流**：每帧限制 Image→Texture 数量；当前要显示的走即时取缓存。
7. **异步预读的坑**：next 脚本同步解析会制造峰值 → 改后台解析+主线程空闲帧合并；job 去重 key 按 storage 不按 target；JSON 预读 key 与资源扫描 key 分离。
8. **竞态**：预热线程与主线程同步转换同一 TLG 会读到半写入 PNG——单点转换 + 坏缓存清理。
9. **音频**：OGG 扩展名正确但内容仍是 XP3 加密流是"语音不播"的根因；用 ffprobe 验证 `OggS` 头，按 manifest 批量回填真解密文件（data_hgl 7415 个 + voice 补齐）。
10. **Backlog 滚动**：虚拟化可见行缓存（只建新进入视口的行）；滚动动画按原版固定 200ms 可中断模型（指数趋近会拖半秒尾巴）；拖动滑块用连续浮点跟随+抓取偏移，不用缓动。

---

## 5. 工程与验证方法论

### 5.1 回归测试体系（复刻任务的核心资产）
- **每个修复都配一个不可回退的 QA 脚本**（`tools/qa_*.gd`），累计几十个：剧情 trace（32 帧基线：脚本游标/文本/声音/舞台/立绘/头像状态）、等待语义、转场、滤镜、相机、动作序列、粒子、影片、语音播放、文本布局、消息窗 shader 像素采样、TFT 字形像素验证、Backlog 输入（hover/滚轮/拖动/跳转）、标题动作路由、存读档、右键返回、性能基准、全量 SCN 命令覆盖审计。
- **测试语义要跟着原版走**：等待语义实现后，旧 QA"剧情总是即时推进"的假设失效——测试显式启用即时轨迹模式，运行版保留真实等待。
- **QA 自身问题要与运行时问题分离**：autoload 未初始化（`--script` 模式限制）、headless dummy renderer 拿不到 viewport、节点路径变更（`SceneCamera/`）、测试数据与原版截图不是同一页——先判断是夹具过时还是真回归。
- **全量审计驱动优先级**：统计全部 SCN 的命令/对象/动作类型与调用频次，按真实分布补齐（而不是剧情里偶遇个例）；`transall` 在 75 个 JSON 中不存在就不实现。
- **验收标准**："看起来接近"不算数——原版场景可重放轨迹 + 截图像素差异 + 输入结果 + 音频时序 + 存档状态共同验收。

### 5.2 Godot 4.6 GDScript 高频坑
- **严格类型推断**：`max()/min()`、从 Variant 字典/数组取值赋给局部变量、`:=` 混合表达式都会被当错误——给局部变量显式标 `String/float/Array/Variant`。这是本项目出现频率最高的编译错误。
- **同名函数不支持重载**——改成不同函数名。
- **JSON 数字读成 float**：路径拼 `2628.0.png`、对白索引被跳过（只认 TYPE_INT）——做数值规范化/同时接受 int/float。
- **bool() 不接受字符串 Variant**："true" 字符串要显式按类型分支解析。
- **headless 限制**：dummy renderer 无 viewport 截图（加防护跳过）；`--script` 模式不初始化 autoload；`res://` 不能直接 `Image.save_png()`（用展开绝对路径）；帧截图用官方 `--write-movie` 比 self-write 截图脚本可靠（不可靠的实验脚本要删除，防止误导后续）。
- **颜色空间**：Godot 线性空间 vs 原 D3D 伽马空间的 Overlay 混色差异；`source_color` 标记会二次转换；shader 输出不要重复 `pow(...,2.2)`。
- **queue_free 延迟销毁**：重建同名控件时新旧短暂重叠、命中错乱——运行时控件改同步释放。
- **信号回调内同步销毁节点**：潜在崩溃警告，延后释放时机。
- **Tween 生命周期**：重启剧情/清场要取消受跟踪的旧 Tween（旧淡入覆盖新场景）；节点运动 Tween 绑定节点生命周期。
- **PNG 导入状态**：headless/未开编辑器时 `.import` 不存在 → 直接读文件路径生成 `ImageTexture`；新拷入的 PNG 要强制重新导入。
- **字体**：Windows `.ttc` 运行时加载会原生崩溃 → 项目内白名单字体 + 原始 `.otf` 文件直接加载（导入对象可能返回无效字体面）；OS.get_system_fonts() 在无头环境报错。
- **多进程协调**：并行跑两个 Godot QA 会抢资源超时——拆开跑；编辑器校验会驻留扫描进程，只清理本次明确启动的进程，不碰用户进程。

### 5.3 PowerShell / 环境坑（反复出现）
- `-LiteralPath` 不展开通配符；`New-Item -LiteralPath` 某些版本不兼容；路径含空格/连续感叹号会出问题 → 用引号包完整命令行、必要时换 Python/cmd。
- 日文/中文输出编码：设置 UTF-8；GBK 控制台打不出日文中点 → 打印转义。
- heredoc（Bash 风格）PowerShell 不吃。
- 清理进程：按精确路径/命令行匹配，避免误杀用户进程（曾用文本匹配误伤当前 PowerShell）。
- F 盘目录枚举可能卡死（杀软/同步扫描）→ 改用 `cmd` 判定存在性、直接写固定文件路径绕过枚举。
- C 盘临时空间不足 → 换目标盘工作目录。
- 全盘递归 grep/搜索超时 → 缩小范围（按扩展名/目录分层）、`rg --files` 先列后读。
- Godot 可执行路径可能是**目录**（`Godot_v4.6.3-stable_win64.exe` 实为文件夹）——列目录找真正的 exe/console。

### 5.4 工作流经验
- **并行读旧快照**：改文件后马上并行搜索会读到生成前旧内容——按顺序"生成→确认"，不要把旧状态误判成新状态。
- **补丁漂移**：Edit 上下文对不上就取精确片段拆小块打，不要硬套大补丁；缩进/制表符问题用字节级查看。
- **非 git 目录**：用文件级检查 + QA 脚本兜底，不假装有 diff；不留未追踪生成物当回退状态。
- **中间格式分层**：解析（build_script_json.py / UI 编译器）与生成（generate_project.py / 运行层）分离，生成器只读中间 JSON，不再碰原始 dump。
- **文档同步**：每个机制结论（krkrz_hgl_ui_assembly.md、MIGRATION_TASKS.md、compatibility_validation.md）落文档，避免"看起来完成但其实没复刻行为"的坑；过时描述及时删改。
- **烟测**：Ren'Py 用 8 秒启动烟测 + errors.txt/traceback.txt 检查；大脚本编译要等 `.rpyc` 全部生成；烟测留下的 log.txt/saves 按整理口径移走清空。
- **残留进程**：每轮结束确认并收掉自己留下的 `python -`、MSBuild/Roslyn、Godot 校验进程。

---

## 6. 引擎选型结论（Galgame 迁移）

| 目标 | 推荐 |
|---|---|
| 剧情最快跑通 | Ren'Py（内置文本/立绘/CG/BGM/语音/选项/快进/存读档/回想/历史/音量） |
| UI 视觉 100% 复刻 | **Godot**（2D/UI 轻、自由度高，但要自建 VN 系统） |
| 复杂商业多平台 | Unity/团结（本项目场景过重，不推荐） |

- 最终结论（实践验证）：直接迁移"原始代码"不现实——原版主体是编译态 TJS/KAG + XP3/PBD/PIMG/TFT 资源，反编译逐项迁移本质仍是重建兼容层。**保真度最高是保留 KrkrZ/KAG 原运行时；Godot 重建适合后续扩展但成本显著更高**（PBD、PIMG、TFT、KAG 动画、系统脚本行为都要逐项补）。
- 补丁作者视角：做汉化/移植补丁不需要完全逆向 exe/dll，核心是"掌握引擎资源管线 + 脚本转换 + 少量二进制 patch"。

---

## 7. 合规边界（DRM 相关）

- 原版 `tenshin_hgl.exe` 的 PlayDRM 校验在 EXE 启动阶段的**本机原生代码**，不在脚本/资源里；汉化版不弹窗是因为用了另一套启动程序 + `ShiraYukiNoa.dll` 加载链。
- **不移除/绕过/伪造 DRM**：即使声称为公司内部维护、获得口头授权，也不分析补丁点/验证分支/替换 DLL 接口。可做的合规路径：原版启动诊断与依赖排查、恢复合法授权数据、由持有版权方授权的公司重发行（含新授权客户端）、以自有资源继续完善迁移版、写维护/构建/QA 文档。
- 实际案例：8 字节 DRM 补丁把 `MessageBoxA` 导入改到缺失的 `Mai@KF.dll` 导致无窗口驻留——保留损坏补丁备份 + 用小启动器重定向到可工作入口是合规修复；恢复 `.org` 原始核心后停在 PlayDRM 窗口属预期行为。
- 启动器工程：独立小启动器（C/C#，CreateProcessW、转发参数、写日志）是通用做法；转换目标要听用户的（"要 Kirikiri 版启动器而不是 Godot 版"）。

---

## 8. 可复用的工具与脚本清单（本次产出）

- `build_hash_manifest.py`：hash 日志 + `.alst` → manifest/统计/恢复视图（含 UTF-16 处理）。
- `collect_filename_candidates.py` / `generate_pattern_candidates.py` / `generate_companion_logic_candidates.py` / `collect_scn_hash_json_candidates.py` / `collect_*_candidates.py` 系列：各类候选提取器（静态扫描/编号规律/伴生派生/内容反推/同源借名/API trace）。
- `merge_hash_backup_current.py`、`compute_backup_coverage_timeline.py`：日志合并与覆盖率时间线重算。
- `Tlg2Png.exe`（引用 GARbro DLL 的 TLG→PNG 转换器）。
- `tjs_bc_dump.py`：TJS2100 字节码反汇编驱动（krkrZ tjsByteCodeLoader 格式）。
- Godot 侧：`compile_hgl_ui_screens.py`（PIMG/INI/FUNC→JSON 编译器）、`hgl_ui_screen.gd`/`hgl_static_screen.gd`（运行层）、`story_player.gd`（SCN 执行器）、`tft_bitmap_text.gd`（TFT 字体渲染）、`white_ball_emitter.gd`、`resource_index.gd`、`system_settings.gd`、`audio_manager.gd`、`save_load_screen.gd`、`exit_confirm_dialog.gd`。
- QA 套件：`tools/qa_*.gd`（40+ 个回归脚本）+ 截图对比 `qa/screenshots/`。

---

## 9. 下次同类任务的最佳流程（复盘结论）

```
1. 摸清封包/引擎世代，找现成工具（GARbro/FreeMote/KrkrExtract/pbd2json），先验证可读性
2. 基础工具链打通：内容提取(.alst) + hasher Hook + 目录映射 + 日志备份/合并/manifest 流程
3. 【第一优先级】反编译全部 SCN/PSB，从内部 name/voice/file 字段抽真实资源名 → 批量 probe
4. 伴生派生(.sli/.pimg) + 内容反推 + 同源借名，按收益递减逐轮补缺，增量明显下降就停
5. 覆盖率报告同步更新（每轮标注前/后覆盖率与步骤）
6. UI 复刻：PIMG+INI+FUNC → 编译成 JSON → 运行层装配（反向绘制/原型复制/状态隐藏/单入口输入）
7. 剧情复刻：建立 SCN 文法 QA → 全量命令审计按频次补实现 → 原始样本驱动回归
8. 字体/文本：直接解析原版位图字体（TFT），保留原字形/字距/悬挂/换行规则
9. 性能：预热+缓存+key去重+批量转换，基准确数（不要凭感觉调）
10. 每个修复配不可回退的 QA；验收=轨迹重放+像素对比+输入+音频+存档
```

**核心心法**：
- 优先找"程序调用逻辑/数据来源"，而不是暴力穷举——SCN 内部名、伴生派生、内容反推的收益率远高于编号爆破。
- 一切参数以原始资源/脚本为证据（PIMG 坐标、tjs 常量、PBD 层表），**分析原始代码后再动手，不猜**；用户明确要求过"请分析原始代码解决而不是猜"。
- 敢于承认未完成（"不能假装 100%"），把差距拆成可量化清单逐个收敛。
- 修复后用**当前构建**重放同场景对比，旧截图不作依据。
