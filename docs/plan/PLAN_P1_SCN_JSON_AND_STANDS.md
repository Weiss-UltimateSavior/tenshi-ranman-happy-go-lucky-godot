# P1 详细计划:本地 SCN JSON 转换器、素材归位与 Windows 补缺

> 目标:用本地工具解锁 216 个剧本文件(全部地图落点与角色线正文),把
> 误置的整身立绘素材与 PBD 元数据归位,并把必须依赖 Windows 的工作压缩到
> 最小的一次性清单。
> 前置:`docs/plan/PLAN_P0_BRANCH_ENGINE.md` 已完成(选择支与分支引擎全绿)。

---

## 0. 筛查结论(2026-09-10,硬证据)

| 项目 | 实测 |
|---|---|
| `assets/` 全部 JSON | 112 个 = 75 剧本(assets/scn)+ 32 UI 编译 + 5 其他 |
| 两个归档内 JSON 总数 | 75(原版)/ 40(godot,仅 UI 编译) |
| `assets/scn/` 的 `.scn` | 293 个,**216 明文 PSB v3 + 77 加密** |
| 明文 PSB 的 JSON 状态 | **全部未解**(216/216) |
| 加密 `.scn` 的 JSON 状态 | 已解 75(共通线 st/ru)/ 未解 2(`0429_sel.ks`、`0604_sel.ks`) |
| 35 个跨文件跳转目标 | 32 明文 PSB(全部 map 落点 + wk0604_01/wk0701 + 0716_sel + re_0604_sel)、2 加密、1 非 scn |
| `start.ks` | 不在 scn 中;是 `assets/data/scenario/start.ks`(KAG 系统脚本),引擎已特判 gameend |
| PBD 元数据 | 64 个 TJS/4s0(2.4–3.8KB)完整存在于**原版归档** `extracted_final/fgimage/<角色>/*.pbd` |
| godot assets 的 `.pbd` | 60 个被 **TLG 整身合成大图**占据(1.2MB 级),仅まひろ 4 个保留真元数据(资产错配) |
| 本地工具 | 无 FreeMote 二进制、无 mono;有 .NET 10;FreeMote 源码已获取(PSB v3 结构已确认) |

**核心判断**:原文二进制齐备,缺的只是"格式转换"。216/218 个剧本 JSON
可以完全本地解出;立绘的 64 个 PBD 元数据需要 Windows 一次性 dump(或走降级路线)。

## 1. 项目一:本地 PSB v3 → SCN JSON 转换器(最高优先级)

### 1.1 交付物

- `tools/psb_to_json.py`——纯 Python 3,零第三方依赖
- 输出目录与现有 75 个 JSON 同构:`assets/scn/<stem>.ks.json`
- 覆盖率:`assets/scn/` 下明文 PSB 216/216 全部成功转换

### 1.2 数据契约(已从 FreeMote 源码核实,实现以此为准)

**文件包装**:若前 4 字节为 `MDF`/`MFL` → 跳过 6 字节(4 字节原始长度 + 2 字节压缩头)
后用 zlib 解压整包;否则原样。明文 scn 均为直接 PSB。

**PSB v3 头部(44 字节,小端)**:

| 偏移 | 字段 | 说明 |
|---:|---|---|
| 0 | Signature | `"PSB\0"` |
| 4 | Version | u16,实测 = 3 |
| 6 | HeaderEncrypt | u16,实测 = 0 |
| 8 | HeaderLength | u32,实测 44;`IsOffsetNamesCorrect` 要求 == OffsetNames |
| 12 | OffsetNames | u32 |
| 16 | OffsetStrings | u32 |
| 20 | OffsetStringsData | u32 |
| 24 | OffsetChunkOffsets | u32 |
| 28 | OffsetChunkLengths | u32 |
| 32 | OffsetChunkData | u32 |
| 36 | OffsetEntries | u32 |
| 40 | Checksum | u32(v>2 才有) |

校验:任一头字段越界或 `Signature` 非 `PSB\0` → fail-loud 并计入失败清单。

**压缩数组(PsbArray)**:首字节为计数,`count = byte - 0x90 + 1`
(`0x90` = `PsbObjType.ArrayN1`);随后按 count 宽度读取:
1→u8,2→u16,3→3 字节,4→u32,5~8→u64。

**names 表**(OffsetNames 起):依次为三个 PsbArray——`Charset`、`NamesData`、
`NameIndexes`;名字按 UTF-8 解码,charset 用于 Shift-JIS 回退(实测脚本名字
含日文,需按 UTF-8 优先、失败回退 UTF-8/ignore,并记录警告)。

**entries 树**(OffsetEntries 起):类型标签递归解码,关键标签:
`0x80–0x8F` fix map、`0x90–0x9F` fix array、`0xA0–0xBF` fix string、
`0xC0/NULL`、`0xC1/False`? 等常量、`0xC4–0xC6` string8/16/32、
`0xCC–0xD3` uint/int 8/16/32/64、`0xD4–0xD9` fix raw、`0xDA/0xDB` raw16/32、
`0xDC/0xDD` array16/32、`0xDE/0xDF` map16/32、`0xE0–0xFF` negative fix num。
map 的键是 names 表索引(数值),值继续递归;字符串值引用 strings 表偏移。

**输出 JSON 形态**:必须与现有 75 个文件一致——顶层为字典(含
`scenes`/`outlines`/`hash`/`name` 等键),`scenes[].lines` 为
`[行号, 状态字典]` 混合数组,文本在 `scenes[].texts`,`nexts[].type/eval/exp/
storage/target`,`selects[]` 全套字段。**验收以能直接被 story_player 加载为
准**(不重命名、不改结构)。

### 1.3 实施步骤

1. [x] 搭骨架:`psb_to_json.py <input.scn> [output.json]`,实现 MDF 检测、
      头解析、PsbArray、names/strings 表读取;先只打印统计(names 数/entries 根类型)
2. [x] entries 树递归解码 → Python dict/list/str/int
3. [x] JSON 序列化:对齐现有 75 个文件的键序与数值形态(整数不要变浮点、
      中文不转义由 `ensure_ascii=False`)
4. [x] **单文件验证**:`ao_map01.ks.scn` → JSON,人工 diff 现有同类文件的结构
      (键集合、`scenes[].label` 以 `*` 开头、`lines` 混合数组形态)
5. [x] **批量转换**:全部明文 PSB → `assets/scn/`,输出统计
      (成功数/失败数/每文件 scenes·texts 计数),失败文件逐个归类
6. [x] **结构自检脚本** `tools/qa_scn_json_integrity.gd` 或 Python 校验:
      对每个新 JSON 断言必需键存在、`nexts[].storage` 可解析、`selects[].selidx` 连续
7. [x] **端到端验证(关键)**:实机从 st02_03 地图选择 → 选佐奈 →
      `sn_map01.ks` 成功加载并继续播放(不再是 "Scenario not found");
      并把该路径加进分支轨迹基线
8. [ ] 若你手上仍能访问 Windows:用 FreeMote `PsbDecompile -t Scn` 对
      **3~5 个明文 PSB** 生成黄金参照,与我们的输出逐字段对比(最强验证)
      —— 未执行(本机无 Windows 环境);已用"结构比对现有 75 个文件 +
      StoryPlayer 实机加载 + 双轨迹基线"作为替代验证,见 §1.6

### 1.4 风险与对策

| 风险 | 对策 |
|---|---|
| psb 变体(压缩数组宽度/raw 引用)解码错位 | 以 FreeMote 源码为唯一参照;解码失败必 fail-loud 并列出文件与偏移,绝不静默产出半截 JSON |
| 日文名编码(UTF-8 vs Shift-JIS) | charset 表优先,失败回退并 warning;抽样人工核对名字正确性 |
| 输出的 JSON 与现有 75 个形态不一致导致播放器旁路 | 以"story_player 可直接加载 + 轨迹基线可复现"为唯一验收;不做字段重命名 |
| chunk(图片资源)引用 | 本任务只解剧本结构,chunk 一律忽略(剧本 JSON 不需要);遇到无法跳过的情况记录并跳过该文件 |

### 1.5 工作量

1.5~2 天(解析器 1 天 + 批量与验证 0.5~1 天)。

### 1.6 完成记录(2026-09-10)

**交付物**:`tools/psb_to_json.py`(纯 Python 3,零第三方依赖,约 380 行)、
`tools/qa_scn_json_integrity.py`(结构自检)、`tools/qa_story_map_route.gd`
(端到端回归)。

**结果**:`assets/scn/` 明文 PSB **216/216 全部转换成功**,JSON 总数
75 → **291**(712 个场景),结构自检零异常;2 个失败为加密文件
(`0429_sel.ks`/`0604_sel.ks`,符合预期,仍需 Windows)。

**端到端**:st02_03 地图选择 → 佐奈 → `sn_map01.ks` 加载成功并播放
「なんだこれ？」(此前为 "Scenario not found")。已固化为
`qa_story_map_route.gd`,并新增第三条轨迹基线
`qa/traces/godot_map_route_trace.json`(60 帧:st02_03 → sn_map01 46 帧 →
st02_04 13 帧,含选择事件 `*san_map1`),verify 通过。

**回归**:opening(32 帧)+ branch(201 帧)双轨迹基线全绿;
`qa_branch_flags` / `qa_story_nexts_eval` / `qa_story_selects` /
`qa_saveload_branch` 全绿。

实现中定位并修复的 6 处格式问题(均以 FreeMote 源码为准):

1. **`UnzipUInt` 是小端**(`MemoryMarshal.Read<uint>`),初版误作大端。
2. **`ArrayN`(0x0D–0x14)是内联数值数组**(`new PsbArray(width, br)`),
   不是偏移量对象列表——偏移列表只属于 `List`(0x20)与 `Objects`(0x21)。
   误用会导致解析器乱 seek 直到文件尾。
3. **names 链式解码的终止条件**:循环条件是"当前节点非 0",根节点自身
   承载首字符之外的前驱,写成"父节点为 0 则终止"会丢掉首字符
   (`_meswinchange` 被读成 `meswinchange`)。
4. **构造函数缺少 `seek(offset_entries)`**:`_load_chunks()` 结束后 reader
   停在 chunk 长度表末尾,不做 seek 直接从文件尾解析。
5. 数值符号:宽度 < 8 字节的整数按有符号解释(`IntValue` 语义),8 字节
   按有符号 64 位。
6. 输出形态:键排序(`sort_keys=True`)、`ensure_ascii=False` 保留日文原字、
   `indent=1` 与现有文件一致;resource 引用输出为 `#resource#<n>` 字符串
   (剧本 JSON 中实际不出现)。

**已知边界**:
- 2 个加密 scn 仍需 Windows FreeMote(见 §3.1 A 批)。
- 216 个新 JSON 合计约 655 MB,`assets/` 在 `.gitignore` 内,随归档分发,
  不入 git。
- Windows 黄金参照对比(步骤 8)未执行,替代验证见上。

## 2. 项目二:素材归位(整身合成图与 PBD 元数据)

### 2.1 背景(筛查发现)

godot assets 的 `assets/fgimage/<角色>/<prefix>_<变体>.pbd` 中,60 个是
**TLG5 整身合成大图**(由提取管线误置),4 个(まひろ)才是真元数据;
而**原版归档**的 `extracted_final/fgimage/<角色>/*.pbd` 全部是 TJS/4s0 元数据。

### 2.2 动作

1. [ ] 从原版归档提取 64 个 TJS/4s0 元数据到
       `assets/fgimage/pbd_meta/<角色>/<prefix>_<变体>.pbd`(保留原始字节,不做转换)
2. [ ] 把 60 个 TLG 整身合成图从 `.pbd` 名位移出:转换为 PNG 后存为
       `assets/fgimage/<角色>/<prefix>_<变体>_body.png`
       (用本地 `tools/tlg2png/tlg2png`;转换后校验尺寸/非空)
3. [ ] 在 `docs/` 记录该资产错配(来源、影响、归位规则),避免后续再被误当元数据
4. [ ] 更新 `.gitignore` 说明:`pbd_meta/` 体积小(合计约 200KB)可考虑
       `git add -f` 入库分发;`*_body.png` 属大图,留在本地素材层

### 2.3 与立绘渲染的关系

- PBD 元数据是"图层名 → layer_id + 坐标"的权威表;
  `story_player._stand_pbd_layers()` 已有 4 条候选路径,其中
  `RESTORED_ROOT/fgimage/<角色>/<prefix>_<变体>.pbd.json` 可直接消费入库的 JSON
- 元数据**未解析成 JSON 之前立绘仍不可用**(TJS/4s0 需引擎密钥);
  本项目的产出是"素材就位",渲染解锁见项目三

### 2.4 工作量

0.5 天(提取 + 批量 TLG→PNG + 文档)。

## 3. 项目三:Windows 一次性补缺 + 降级路线决策

### 3.1 必须依赖 Windows 的最小清单(共 66 个文件)

| 批次 | 工具 | 输入 | 产出 | 放置路径 |
|---|---|---|---|---|
| A. 加密剧本 2 个 | `Ulysses-FreeMoteToolkit v4.5.1\PsbDecompile.exe -t Scn -e SHIFT-JIS -indent` | `assets/scn/0429_sel.ks.scn`、`0604_sel.ks.scn` | `<stem>.ks.json` | `assets/scn/` |
| B. PBD 元数据 64 个 | `krkr_pbd2json\pbd2json.exe`(借原引擎 `Scripts.loadDataPack()`) | 项目二提取出的 64 个 `.pbd` | 64 个 JSON(含 `layer_id/name/left/top/width/height`) | `assets/fgimage/<角色>/<prefix>_<变体>.json` |

命令与格式(项目 A):

```powershell
$tool = 'E:\Galgame_Tools\Ulysses-FreeMoteToolkit-v4.5.1\PsbDecompile.exe'
& $tool -t Scn -e SHIFT-JIS -indent -o <输出目录> <输入.ks.scn>
```

验证:产出 JSON 能被 story_player 直接加载;`0429_sel` 的 `*0429_san` 标签存在。

### 3.2 降级路线(若无 Windows):整身合成图 + `.stand` 偏移

在第 3.1 无法执行时,用项目二归位的整身图做**降级立绘**:

1. [ ] 用 `<prefix>_<变体>_body.png` 作为身体底图(整身,含留白的脸部区域)
2. [ ] 表情脸用 `.sinfo` 的 face 层名 + `.stand` 的 `facexoff/faceyoff` 定位
       ——**只使用 `.stand` 已声明的偏移,不猜编号**
3. [ ] 在 trace/QA 中标注 `stand_source: "composite"` 以示与 PBD 精确合成的区别
4. [ ] 局限必须写进文档:多差分(手/口/眼分层)与部件级遮挡无法还原

**决策点**:是否接受降级立绘?若追求 100% 复刻,应优先安排一次 Windows 会话
(项目 A+B,合计约 30 分钟操作),而不是长期走降级路线。

### 3.3 工作量

Windows 侧 0.5 小时操作 + 回传验证 0.5 天;降级路线实现 1 天。

## 4. 依赖关系与推荐顺序

```
项目一(本地 PSB 解析器)  ← 建议立即开工,收益最大、零外部依赖
   └─ 解锁 216 剧本 → 地图选择/角色线可玩 → 轨迹基线扩展
项目二(素材归位)          ← 可与项目一并行,纯搬运
   └─ 产出 64 个可解析的 PBD 元数据 + 60 张整身图
项目三(Windows 补缺)      ← 一次性,取决于你能否访问 Windows
   └─ A(2 个加密 scn)+ B(64 个 PBD JSON)→ 立绘精确合成 + 分支落点补全
```

## 5. 验收标准(Definition of Done)

1. `tools/psb_to_json.py` 将 `assets/scn/` 全部 216 个明文 PSB 转为 JSON,
   失败 0 个;每个 JSON 通过结构自检(必需键、`nexts` 可解析)
2. 实机端到端:st02_03 地图选择 → 佐奈 → `sn_map01.ks` 继续播放;
   新路径纳入分支轨迹基线且 verify 通过
3. 64 个 PBD 元数据与 60 张整身图归位,清单与实际文件一一对应
4. Windows 批次(若执行):`0429_sel` 分支落点可继续播放,立绘按 PBD 精确合成;
   两条既有轨迹基线保持全绿
5. 文档更新:`MIGRATION_TASKS.md` 阶段 5/6 勾选、本计划勾选、素材错配说明落档
