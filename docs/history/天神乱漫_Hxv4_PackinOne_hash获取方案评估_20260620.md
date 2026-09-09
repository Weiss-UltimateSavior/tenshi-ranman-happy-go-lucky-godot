# 天神乱漫 Hxv4/PackinOne Hash 获取方案评估

日期：2026-06-20  
对象：`E:\Galgame\天神乱漫 Happy GO Lucky!!`  
相关工具：

- `E:\Galgame_Tools\GARbro-master`
- `E:\Galgame_Tools\KrkrExtractForCxdecV2-main`
- `E:\Galgame_Tools\Ulysses-FreeMoteToolkit-v4.5.1`
- 工作目录：`C:\Users\羽濑川小鸢\Documents\Codex\2026-06-20\new-chat\work\tenshin_hgl`

## 0. 两个方案的区别、联系与后续路线

目前围绕“真实文件名 hash 映射”有两个可行方向。

### 0.1 方案 A：静态候选生成 + 原始 hasher 批量探测

这是当前主方案。

核心思路：

1. 从已解出的剧情 JSON、系统 UI 脚本、INI、FUNC、配置文本中收集可能的真实资源名。
2. 对资源名做规则扩展，例如补 `.ogg`、`.pimg`、`.png`、`.tlg`、`.sli` 等常见后缀。
3. 把候选名批量传给游戏自身的 `TVPIsExistentStorage()`。
4. 让原游戏的 PackinOne/Hxv4 hasher 计算 hash。
5. 用 hook 记录 `DirectoryHash.log` 和 `FileNameHash.log`。
6. 再和 XP3 解出的 `.alst` 包索引合并，得到“真实文件名 -> 包内 hash 条目”的映射。

优点：

- 不需要完整模拟剧情逻辑。
- 不需要人工跑路线。
- 一次能探测大量文件名。
- 对 BGM、背景、立绘、UI、主系统资源效果明显。
- 当前已经稳定产出 `150268` 个唯一文件名 hash。注意这里包含大量候选名 hash，真实有效覆盖率以 manifest 与 `.alst` 的交集为准。

缺点：

- 依赖“候选名是否能被静态收集或推断出来”。
- 对运行时拼接名、条件分支名、语音编号规律、特殊包内部资源覆盖不完整。
- 候选变体多时会产生大量无效探测。

### 0.2 方案 B：剧情流快速遍历 + 分支展开 + 资源调用截断

这是用户提出并已初步验证的补充方案。

核心思路：

1. 反编译 `.ks.scn` 为 JSON。
2. 从剧情起点开始遍历 `nexts`、`selects` 等显式剧情边。
3. 遇到选择分支时不等待人工选择，而是把所有分支都加入队列继续走。
4. 遇到资源调用时只取资源名，不实际加载资源。
5. 将新发现的资源名交给同一套原始 hasher 探针。

实测结果：

- 使用 `E:\Galgame_Tools\Ulysses-FreeMoteToolkit-v4.5.1\PsbDecompile.exe` 可成功反编译已恢复的 32 个 `.ks.scn`。
- 可读取脚本数从 `75` 增加到 `107`。
- missing target 从 `16` 降到 `4`。
- 剧情流额外发现 `727` 个未进入 hash 日志的候选。
- 探针后新增唯一文件名 hash `558` 个。
- 但最终 `file_mapped` 仅从 `8242` 提升到 `8254`，恢复文件从 `2158` 提升到 `2168`。

优点：

- 能发现静态候选生成器漏掉的剧情路径资源。
- 对选择分支、地图分支、CG/BGM 显式调用有补充价值。
- 理论上可以比人工跑路线快几个数量级。

缺点：

- 需要更完整的剧情解释器。
- 当前只跟随显式 `nexts/selects`，不能完全理解宏、变量条件、地图选择、角色路线锁、运行时跳转。
- 本轮实测的边际收益有限，新增 hash 多，但能映射到 `.alst` 的真实文件较少。

### 0.3 两个方案的联系

两个方案并不是互斥路线，而是上下游关系：

- 方案 A 负责“生成候选并批量探测 hash”，是底层主干。
- 方案 B 负责“从剧情执行路径中发现更多候选”，是候选来源之一。
- 两者最终都依赖同一个关键机制：调用原游戏的 PackinOne/Hxv4 hasher。
- 两者最终都需要和 `.alst` 静态包索引合并，才能判断哪些 hash 真能恢复为包内文件。

换句话说，方案 B 不替代方案 A；它只是给方案 A 提供更接近真实剧情执行的候选名。

### 0.4 继续探索方向判断

当前不建议立刻放弃现有方案另开全新路线。

原因：

- XP3 文件表本身不保存真实文件名，继续从 XP3 index 硬挖真实名的收益很低。
- 现有 hasher hook 已经被验证可用，是最确定的核心能力。
- 方案 B 实测能补充候选，但新增映射只有 `+12`，说明“单纯更快地跑显式剧情边”不是主要瓶颈。
- 当前真正的瓶颈是候选质量和脚本语义理解，而不是探测速度。

建议后续路线：

1. 继续保留方案 A 作为主方案。
2. 把方案 B 并入方案 A，作为“剧情流候选来源”。
3. 优先增强现有候选生成器和剧情解释器：
   - 解析宏展开。
   - 解析条件跳转。
   - 解析地图选择。
   - 建立语音编号推断规则。
   - 针对 `evimage`、`voice`、`data_hgl` 做包级命名规律分析。
4. 只有当上述增强后仍无法覆盖关键资源，再探索新方案，例如：
   - EXE/DLL 字符串扫描与编码修复。
   - 对 TJS/插件二进制做更深反编译。
   - 动态插桩截获更高层资源调用 API。
   - 建立资源 hash 反查字典或命名模板爆破。

结论：  
短期应继续在现有方案上扩展，而不是另起一套完全新方案。更准确地说，下一阶段应从“批量枚举候选”升级为“脚本语义驱动的高质量候选生成”。

### 0.5 追加探索后的最佳路线

继续深入后，最有效路线已经比较明确：不是单一“动态跑流程”，也不是单一“静态枚举”，而是分层混合方案。

最佳流程：

1. 先用 `.alst` 得到 XP3 内真实 hash 条目。
2. 再从脚本 JSON、已恢复文本、UI INI/FUNC、PIMG 结构和二进制 trace 里收集真实文件名候选。
3. 对不同包使用不同命名模型：
   - `video`：按目录样本生成序列帧名。
   - `evimage` / `data_hgl`：按 `evNNNN[a-z]`、`evNNNN[aa-zz]` 差分模式生成。
   - `uipsd`：直接读取未命名 INI/FUNC 内容中的 `psd/inc/file` 字段反推 UI 文件名。
   - `voice`：以脚本显式 `voice` 字段为主，普通补行号收益低。
4. 将候选批量交给原游戏 PackinOne/Hxv4 hasher。
5. 合并 hash 日志和 `.alst`，重建 manifest。
6. 对 UI 图片，不强求所有 XP3 文件名映射，直接用 FreeMote 从已恢复 `.pimg` 中导出 PNG 图层。

截至本轮，整体 `.alst` 文件名覆盖率为：

```text
13700 / 36829 = 37.20%
```

重点包覆盖率：

| 包 | 最新覆盖率 | 说明 |
| --- | ---: | --- |
| `bgm` | 81/82 = 98.78% | 基本完成 |
| `video` | 512/537 = 95.34% | 序列帧命名模型效果极高 |
| `evimage` | 559/644 = 86.80% | CG 主体已高度覆盖 |
| `fgimage` | 1211/1541 = 78.59% | 立绘覆盖较高 |
| `uipsd` | 118/155 = 76.13% | 从 UI 文本内容反推后大幅提升 |
| `main` | 42/59 = 71.19% | 系统主资源可用 |
| `bgimage` | 79/153 = 51.63% | 背景仍需脚本语义/运行时补充 |
| `data` | 684/1426 = 47.97% | 日期图和系统资源有所提升 |
| `voice` | 8327/21479 = 38.77% | 继续盲补行号收益很低 |
| `scn` | 112/294 = 38.10% | 可读剧情脚本仍依赖 SCN 反编译 |
| `data_hgl` | 1975/10459 = 18.88% | 包很大，混合 HCG 与附加语音，仍是最大缺口 |

当前判断：

- 对迁移天神 UI 到 Slapstick，最关键的 UI 视觉资源已经够用：`uipsd` 的主要 `.pimg/.ini/.func` 已恢复，且 FreeMote 已可从 16 个 `.pimg` 导出 810 张 PNG 图层。
- 对完整还原天神资源名，继续提高总体覆盖率的瓶颈主要在 `voice` 和 `data_hgl`。这两包体量大，但对“借用 UI 框架”不是第一优先级。
- 后续若仍要追求更完整，应优先做运行时 UI/回想/语音鉴赏页面触发，并在 `TVPGetPlacedPath` / `TVPCreateIStream` 层抓真实请求，而不是继续扩大盲目编号爆破。

## 1. 结论摘要

该游戏的 XP3 包内并不保存真实文件名。GARbro 或普通 XP3 解析只能看到“伪文件名”或 hash 化条目，无法直接从 XP3 文件表还原出 `bgm01.ogg`、`school_gate_a.png`、`option.pimg` 这类真实资源名。

当前可行方案是：

1. 使用游戏自身的 PackinOne/Hxv4 hasher 计算真实文件名对应的 hash。
2. 从已解出的脚本 JSON、系统脚本、INI/FUNC 等文本中静态收集候选资源名。
3. 将候选名批量传给游戏运行时的存储查询接口 `TVPIsExistentStorage()`，触发原始 hasher。
4. 通过 hook 的 `CxdecStringDumper.dll` 记录 `DirectoryHash.log` 和 `FileNameHash.log`。
5. 将 hash 日志与 `CxdecExtractor` 解出的 `.alst` 文件表合并，得到真实文件名到包内 hash 条目的映射。

该方案不需要手动跑完整游戏流程，也不依赖“进入某条剧情后才调用资源”的原始流程。只要脚本或配置中能静态收集到资源名，就可以主动批量触发 hasher。

## 2. 为什么不能只靠 GARbro

此游戏使用 Wamsoft Hxv4 / PackinOne 体系，XP3 内部文件表保存的是：

- 目录 hash，通常 8 字节，显示为 16 位十六进制；
- 文件名 hash，通常 32 字节，显示为 64 位十六进制；
- 文件 key；
- ordinal / fake name 信息。

GARbro 能打开包并显示条目，但显示出的 CJK 伪文件名本质上来自 ordinal，并不是真实文件名。真实文件名并没有以明文形式存在于 XP3 index 中。

因此，单独补 GARbro 解密方式只能解决“能否打开/解密流”的问题，不能解决“hash 对应的真实文件名是什么”的问题。

## 3. 真实文件名的来源

真实文件名主要散落在：

- 剧情脚本 JSON：`E:\Galgame\天神乱漫 Happy GO Lucky!!\Extractor_Output\scn`
- 系统 UI 脚本：`uipsd` 包中还原出的 `ini/*.ini`、`func/*.func`
- 游戏运行时脚本/系统逻辑
- 少量资源名可能只在 EXE/TJS 逻辑、宏展开或运行时拼接中出现

例如：

- BGM 脚本里可能写 `bgm04`，实际资源为 `bgm04.ogg` 和 `bgm04.ogg.sli`。
- CG 脚本里可能写 `cg_0815`，实际资源可能在 `evimage` 包中。
- UI 逻辑会引用 `option.pimg`、`backlog.pimg`、`extra.pimg` 及其 `ini/func`。

由于这些字符串只有在游戏运行到对应逻辑时才会传给 hasher，单纯启动游戏只能捕获很少一部分 hash。

## 4. 当前实现方案

### 4.1 Hook 原始 hasher

修改位置：

- `E:\Galgame_Tools\KrkrExtractForCxdecV2-main\CxdecStringDumper\HashCore.cpp`
- `E:\Galgame_Tools\KrkrExtractForCxdecV2-main\CxdecStringDumper\HashCore.h`

核心做法：

1. 注入 `CxdecStringDumper.dll`。
2. 在 PackinOne storage media 创建后取得：
   - `PathNameHasher`
   - `FileNameHasher`
3. 替换其虚表中的 `Calculate()`。
4. 调用原始 `Calculate()` 得到真实 hash。
5. 将字符串和 hash 写入：
   - `StringHashDumper_Output\DirectoryHash.log`
   - `StringHashDumper_Output\FileNameHash.log`

日志格式：

```text
真实字符串##YSig##HASH
```

空目录使用：

```text
%EmptyString%##YSig##...
```

### 4.2 批量主动触发 hasher

新增逻辑：

如果游戏目录下存在：

```text
E:\Galgame\天神乱漫 Happy GO Lucky!!\StringHashDumper_Output\HashProbeCandidates.txt
```

则 `CxdecStringDumper.dll` 在 hasher hook 安装完成后启动线程，逐行读取候选路径，并调用：

```cpp
TVPIsExistentStorage(tTJSString(candidate.c_str()));
```

这会让游戏内部正常走 PackinOne 文件存在性检查，从而触发目录名和文件名 hash 计算。这样就绕开了“必须手动跑到剧情调用点”的限制。

探测日志：

```text
StringHashDumper_Output\HashProbe.log
```

示例：

```text
HashProbeCandidates:25445
HashProbeDone:25445
```

### 4.3 候选资源名生成

脚本：

```text
C:\Users\羽濑川小鸢\Documents\Codex\2026-06-20\new-chat\work\tenshin_hgl\collect_filename_candidates.py
```

输入：

- `Extractor_Output\scn\*.json`
- `Extractor_Output\*\*.ini`
- `Extractor_Output\*\*.func`
- `Extractor_Output\*\*.csv`
- 其他可按文本读取的脚本/配置文件

输出：

- `filename_candidates.json`
- `candidate_file_names.txt`
- `candidate_dir_names.txt`
- `hash_probe_candidates.txt`

候选扩展规则包括：

- BGM：`bgm04` -> `bgm04.ogg`、`bgm/bgm04.ogg`
- 语音：`aoi001_001` -> `aoi001_001.ogg`、`voice/aoi001_001.ogg`
- 背景：`school_gate_a` -> `school_gate_a.png`、`bgimage/school_gate_a.png`
- 立绘：角色资源名 -> `fgimage/*.tlg`、`fgimage/*.pimg`
- CG：`cg_*` -> `evimage/*.png`、`evimage/*.pimg`
- 脚本：`ru03_05` -> `ru03_05.ks`、`scn/ru03_05.ks.scn`
- UI：`option` -> `option.pimg`、`ini/option.ini`、`func/option.func`

生成候选时会过滤已知 `FileNameHash.log` 中已经捕获过的文件名，减少重复探测。

### 4.4 启动方式注意事项

不能使用：

```text
E:\Galgame\天神乱漫 Happy GO Lucky!!\tenshin_hgl.exe
```

原因：该 EXE 导入缺失的 `Mai@KF.dll`，会报错：

```text
由于找不到 Mai@KF.dll，无法继续执行代码
```

应使用：

```text
E:\Galgame\天神乱漫 Happy GO Lucky!!\天神乱漫 Happy GO Lucky!!.exe
```

该 EXE 导入的是目录中存在的 `ShiraYukiNoa.dll`。

正确启动示例：

```powershell
$loader='E:\Galgame_Tools\KrkrExtractForCxdecV2-main\Release\CxdecExtractorLoader.exe'
$game='E:\Galgame\天神乱漫 Happy GO Lucky!!\天神乱漫 Happy GO Lucky!!.exe'
Start-Process -FilePath $loader -ArgumentList ('"{0}" --hash' -f $game) -WindowStyle Hidden
```

注意：

- 参数要拼成带引号的字符串，不要用 PowerShell 数组拆开，否则 loader 可能进入 GUI 路径。
- 每轮探测前必须备份旧日志，因为 `CxdecStringDumper` 初始化时会重新创建日志文件。
- 探测结束后应优雅关闭游戏进程，再合并日志；过早强杀可能造成日志未刷盘。

## 5. `.alst` 文件表获取

hash 日志只能告诉我们“真实文件名 hash 是什么”，还需要 `.alst` 告诉我们“某个 XP3 包里有哪些目录 hash / 文件 hash 条目”。

使用 `CxdecExtractor.dll` 的 `ExtractPackage()` 可获得：

- 解出的 hash 文件；
- 对应包的 `.alst` 文件表。

已对 `CxdecExtractorUI.dll` 自动模式做增强：

- 环境变量 `KRKR_EXTRACT_TARGET` 指定目标 XP3；
- 自动调用 `ExtractPackage()`；
- 完成后写入 `Extractor_Output\<包名>.xp3.done`；
- 自动退出游戏进程，便于批处理。

示例：

```powershell
$env:KRKR_EXTRACT_TARGET='bgm.xp3'
Start-Process -FilePath $loader -ArgumentList ('"{0}" --extract' -f $game) -WindowStyle Hidden
```

已成功生成 `.alst` 的包：

- `bgimage.alst`
- `bgm.alst`
- `data.alst`
- `data_hgl.alst`
- `evimage.alst`
- `fgimage.alst`
- `main.alst`
- `scn.alst`
- `uipsd.alst`
- `video.alst`
- `voice.alst`

`tenshin_chs.xp3` 自动流程运行完成但未生成 `.alst`，推测可能不是同一套 Hxv4 index，或不走当前 `CxCreateIndex` 接口。

## 6. 映射合并与恢复

脚本：

```text
C:\Users\羽濑川小鸢\Documents\Codex\2026-06-20\new-chat\work\tenshin_hgl\build_hash_manifest.py
```

功能：

1. 读取 `DirectoryHash.log`。
2. 读取 `FileNameHash.log`。
3. 读取 `Extractor_Output\*.alst`。
4. 将包内目录 hash / 文件 hash 对照为真实路径。
5. 输出 manifest：
   - `hash_manifest.json`
   - `hash_manifest.tsv`
   - `hash_manifest_stats.json`
6. 恢复部分高价值资源到真实路径视图：
   - `work\tenshin_hgl\restored\bgimage`
   - `work\tenshin_hgl\restored\bgm`
   - `work\tenshin_hgl\restored\data`
   - `work\tenshin_hgl\restored\evimage`
   - `work\tenshin_hgl\restored\fgimage`
   - `work\tenshin_hgl\restored\main`
   - `work\tenshin_hgl\restored\scn`
   - `work\tenshin_hgl\restored\uipsd`

当前不批量恢复 `voice` 和 `data_hgl`，避免大量复制。需要时可以按 manifest 精确恢复。

## 7. 本轮实测效果

### 7.1 Hash 捕获量

本轮探测前：

- `FileNameHash.log` 唯一文件名：32730
- `DirectoryHash.log` 唯一目录名：161

本轮批量探测：

- 候选路径：25445
- 新日志内唯一文件名：8090
- 合并后唯一文件名：40349
- 净新增唯一文件名：7619
- 合并后唯一目录名：162

也就是说，单轮静态候选 + 主动触发 hasher，使文件名 hash 知识库从 32730 增加到 40349，提升约 23.3%。

### 7.2 包内映射效果

当前整体统计：

- 已统计条目：41364
- `.alst` 条目：36829
- 已映射真实文件名：8242
- `.alst` 文件名映射率：22.38%
- 真实路径恢复文件：2158

重点包效果：

| 包 | 条目数 | 已映射 | 映射率 |
|---|---:|---:|---:|
| `fgimage` | 1541 | 1211 | 78.59% |
| `bgm` | 82 | 60 | 73.17% |
| `main` | 59 | 41 | 69.49% |
| `bgimage` | 153 | 73 | 47.71% |
| `data` | 1426 | 580 | 40.67% |
| `scn` | 294 `.alst` | 109 | 37.07% |
| `uipsd` | 155 | 46 | 29.68% |
| `video` | 537 | 124 | 23.09% |
| `voice` | 21479 `.alst` | 5503 | 25.62% |
| `evimage` | 644 | 115 | 17.86% |

恢复结果示例：

- `restored\bgm\bgm01.ogg`
- `restored\bgm\bgm04.ogg`
- `restored\bgimage\school_gate_a.png`
- `restored\bgimage\school_classroom_a.png`
- `restored\fgimage\庵\庵_ポーズＡ_1_10.tlg`
- `restored\uipsd\option.pimg`
- `restored\uipsd\backlog.pimg`
- `restored\uipsd\extra.pimg`

## 8. 剧情流快速遍历方案实测

用户提出的方案是：不按人工路线慢速运行游戏，而是解析剧情脚本；遇到选择分支时拆分路径继续；遇到资源调用时只触发文件名 hash，不实际加载资源，以百倍或千倍速度跑完整剧情。

### 8.1 工具测试

原 `E:\Galgame_Tools\krkr_FreeMoteToolkit\PsbDecompile.exe` 在反编译 `.ks.scn` 时失败，原因是运行时 DLL 版本冲突：

- 缺失或不匹配 `System.Runtime.CompilerServices.Unsafe, Version=5.0.0.0`
- 报错位置在 `FreeMote.Psb.PsbExtension.UnzipUInt()`

随后测试 `E:\Galgame_Tools\Ulysses-FreeMoteToolkit-v4.5.1\PsbDecompile.exe`，结果可用：

- 成功反编译 `ao_map01.ks.scn`
- 成功反编译 `0716_sel.ks.scn`
- 批量反编译已恢复的 32 个 `.ks.scn`
- 生成 32 个正文 JSON 和 32 个空资源表 JSON

使用命令示例：

```powershell
& 'E:\Galgame_Tools\Ulysses-FreeMoteToolkit-v4.5.1\PsbDecompile.exe' `
  -t Scn -e SHIFT-JIS -indent -o <output_dir> <input.ks.scn>
```

### 8.2 剧情流遍历结果

将原有 `Extractor_Output\scn` 的 75 个 JSON 与 Ulysses 新反编译的 32 个 JSON 合并后，重新遍历剧情图：

| 指标 | 旧结果 | 新结果 |
| --- | ---: | ---: |
| 可读取脚本数 | 75 | 107 |
| scene 总数 | 210 | 298 |
| 从开头可达 scene | 85 | 97 |
| 显式边数量 | 87 | 111 |
| missing target | 16 | 4 |
| 资源候选路径 | 11537 | 12267 |
| 未进入 hash 日志的候选 | 0 | 727 |

剩余 4 个 missing target 为：

- `0429_sel.ks:*0429_aoi`
- `0429_sel.ks:*0429_sak`
- `0429_sel.ks:*0429_san`
- `0429_sel.ks:*0429_ano`

### 8.3 Hash 探针结果

把这 727 个剧情流新增候选交给 Cxdec hash 探针后：

- `HashProbeCandidates:727`
- `HashProbeDone:727`
- `FileNameHash.log` 从 40349 增加到 40907
- 净新增唯一文件名 hash：558
- `DirectoryHash.log` 无新增，仍为 162

重跑剧情流遍历后：

- `probe_paths_not_in_hash_log` 从 727 降为 0

说明这批由剧情流发现的候选已经全部被 hash 日志吸收。

### 8.4 对实际映射覆盖率的影响

重建 manifest 后，关键变化如下：

| 指标 | 探测前 | 探测后 | 增量 |
| --- | ---: | ---: | ---: |
| FileNameHash 唯一名 | 40349 | 40907 | +558 |
| overall file_mapped | 8242 | 8254 | +12 |
| restored_files | 2158 | 2168 | +10 |
| BGM 映射 | 60/82 | 62/82 | +2 |
| data 映射 | 580/1426 | 581/1426 | +1 |
| evimage 映射 | 115/644 | 122/644 | +7 |

更新后的主要覆盖率：

- `fgimage`: 1211/1541 = 78.59%
- `bgm`: 62/82 = 75.61%
- `main`: 41/59 = 69.49%
- `bgimage`: 73/153 = 47.71%
- `data`: 581/1426 = 40.74%
- `scn`: 109/294 = 37.07%
- `uipsd`: 46/155 = 29.68%
- `voice`: 5503/21479 = 25.62%
- `evimage`: 122/644 = 18.94%
- overall `.alst` 文件名覆盖率：8254/36829 = 22.41%

### 8.5 方案可行性评价

该方案技术上可行，并且比手动跑路线高效得多。它能从脚本结构中展开选择分支，并快速触发候选资源名 hash。

但本次实测说明，它对当前阶段的边际收益有限：

- 新增 hash 数不少：+558。
- 直接映射到 XP3 `.alst` 的文件较少：+12。
- 原因是许多新增候选只是无扩展名、扩展名变体或实际包内不存在的路径。
- 另一个限制是剧情图并非完全由显式 `nexts/selects` 串起来，仍有宏、地图选择、变量跳转、条件跳转需要进一步模拟。

结论：  
“快速剧情流遍历”适合作为补充方案，尤其适合补 CG、BGM、脚本显式资源；但不能单独解决完整 hash 映射。下一步若继续提高覆盖率，应增强剧情解释器对宏、条件跳转、地图选择和语音编号规律的理解，而不是只增加遍历速度。

### 8.6 覆盖率优化追加实测

在上述剧情流实验之后，继续对文件名覆盖率做了三类优化：

1. 扩展 `collect_filename_candidates.py`
   - 将 `work\tenshin_hgl\ulysses_scn_json` 纳入常规扫描。
   - 跳过 `.resx.json` 空资源表。
   - 增加 `.sli`、`.pbd`、`.stage`、`.stand` 等扩展名识别。
   - BGM 裸名自动补 `.ogg.sli`。
   - 立绘/差分裸名自动补 `.pbd` 和 `.stand`。

2. 新增 `generate_pattern_candidates.py`
   - 对 `bgm01` 到 `bgm99` 及少量字母后缀生成 `.ogg` / `.ogg.sli`。
   - 对 `ev0001a` 到 `ev0999h` 生成 `.pimg` / `.png` / `.tlg`。
   - 从已知背景名生成 `_m` / `_p` 差分候选。
   - 从已知语音名推断同一场景内后续行号。
   - 生成少量 `xxxNNN_r001.ogg` 形式的回想/附加语音候选。

3. 多轮 hash 探针
   - 第一轮：常规候选 + 编号候选，`91370` 个探测项。
   - 第二轮：基于新日志继续补语音编号边界，`9871` 个探测项。
   - 第三轮：再次补边界，`11287` 个探测项。

最终日志与 manifest 结果：

| 指标 | 优化前 | 优化后 | 增量 |
| --- | ---: | ---: | ---: |
| FileNameHash 唯一名 | 40907 | 150268 | +109361 |
| overall file_mapped | 8254 | 10716 | +2462 |
| overall `.alst` 覆盖率 | 22.41% | 29.10% | +6.69 个百分点 |
| BGM | 62/82 | 81/82 | +19 |
| evimage | 122/644 | 274/644 | +152 |
| voice | 5503/21479 | 7168/21479 | +1665 |
| data_hgl | 382/10459 | 1004/10459 | +622 |
| bgimage | 73/153 | 74/153 | +1 |
| scn | 109/294 | 112/294 | +3 |

优化后主要覆盖率：

- `bgm`: 81/82 = 98.78%
- `fgimage`: 1211/1541 = 78.59%
- `main`: 41/59 = 69.49%
- `bgimage`: 74/153 = 48.37%
- `evimage`: 274/644 = 42.55%
- `data`: 581/1426 = 40.74%
- `scn`: 112/294 = 38.10%
- `voice`: 7168/21479 = 33.37%
- `uipsd`: 46/155 = 29.68%
- `video`: 124/537 = 23.09%
- `data_hgl`: 1004/10459 = 9.60%
- overall `.alst` 文件名覆盖率：10716/36829 = 29.10%

第三轮增量已经明显下降：

- 第一轮将 overall file_mapped 提升到 `10022`。
- 第二轮提升到 `10550`，新增 `+528`。
- 第三轮提升到 `10716`，新增 `+166`。

因此，继续用同样的“语音编号向后外推 60 行”方式仍可能有收益，但性价比已经下降。下一步更值得做的是分析剩余未映射资源的命名结构，例如 `voice` / `data_hgl` 的路线号、角色号、回想语音编号和特殊 SE 名称，而不是单纯扩大编号爆破范围。

### 8.7 上游 storage API 探索

为验证“原始文件名到底在运行时哪里出现”，继续改造 `CxdecStringDumper.dll`，从 hasher hook 往上游推进。

新增日志：

- `UpstreamTrace.log`

新增记录类型：

- `DIR`：目录名 hasher 调用。
- `FILE`：文件名 hasher 调用。
- `API_EXISTS`：`TVPIsExistentStorage()` 的上游请求。
- `API_PLACED`：`TVPGetPlacedPath()` 的上游请求。
- `API_STREAM`：`TVPCreateIStream()` 的上游请求。

日志格式：

```text
类型##YSig##文件名或storage路径##YSig##模块+偏移调用栈
```

实现要点：

- 在 `HashCore.cpp` 中用 `TVPGetImportFuncPtr()` 取得 KiriKiri storage API 地址。
- 对 `TVPIsExistentStorage`、`TVPGetPlacedPath`、`TVPCreateIStream` 做 inline hook。
- 对批量 hash probe 线程设置 `g_InHashProbeThread` 标志，避免把主动爆破候选误记为真实游戏调用。
- 对真实运行线程记录 `CaptureStackBackTrace()` 调用栈，并将地址格式化为 `module+offset`。

短跑实测：

- 总日志：`2470` 条。
- `API_STREAM`: `319`
- `API_PLACED`: `45`
- `DIR`: `1139`
- `FILE`: `967`

样例：

```text
API_STREAM##YSig##arc://./title_bg.pimg
API_STREAM##YSig##file://./.../data.xp3>儮
API_STREAM##YSig##file://./.../uipsd.xp3>傗
API_PLACED##YSig##title_bg.pimg
```

这说明原始资源名确实在 storage API 层出现，例如 `title_bg.pimg`；而 `data.xp3>儮` 这类是 PackinOne 已经进入包内索引后的伪路径，不再包含原始文件名。

模块定位结果：

- 随机名核心 DLL 位于 `%TEMP%\krkr_*\*.dll`，实测复制为：
  - `work\tenshin_hgl\krkr_temp_core_063cc948c078.dll`
- 关键模块：
  - `PackinOne.dll`
  - `KAGParserEx.dll`
  - `psbfile.dll`
  - `ShiraYukiNoa.dll`
  - `天神乱漫 Happy GO Lucky!!.exe`

API trace 候选提取：

- 新增 `collect_api_trace_candidates.py`。
- 从 `UpstreamTrace*.log` 提取 `API_PLACED` / `API_STREAM` / `FILE` 中的真实 storage name。
- 自动过滤 `*.xp3>伪名`、保存数据、EXE、插件路径等无效项。
- 启动阶段样本提取 `662` 个候选，其中只有 `41` 个尚未在 hash 日志中出现。
- 探针后新增 `19` 个唯一文件名 hash，但 manifest 覆盖率没有变化。

二进制字符串扫描：

- 新增 `scan_binary_strings_for_candidates.py`。
- 扫描 EXE、临时核心 DLL、`ShiraYukiNoa.dll`、`PackinOne.dll`、`KAGParserEx.dll`、`psbfile.dll` 等模块的 ASCII / UTF-16 字符串。
- 严格过滤后仅剩 `25` 个未见候选，多数仍像误报，暂不作为主力覆盖率来源。

结论：

- 上游 API hook 是有效的，已经可以证明并捕获真实 storage 请求。
- 仅启动到标题阶段的 API trace 对覆盖率提升有限，因为标题阶段资源大多已经覆盖。
- 真正有价值的是在剧情运行、路线选择、CG/语音播放阶段持续记录 `API_PLACED` / `API_STREAM`，这样能捕获脚本解释器实际拼出的资源名。
- 下一步应将 API trace 与快速剧情遍历结合：自动推进剧情时不只抓 hasher，还抓 storage API 层的真实请求路径和调用栈来源。

### 8.8 最新覆盖率

经过 EV 单字母扩展、HCG 双字母差分扩展、语音编号外推、API trace 候选合并后，最新 manifest 为：

| 包 | 覆盖率 |
| --- | ---: |
| `bgm` | 81/82 = 98.78% |
| `fgimage` | 1211/1541 = 78.59% |
| `evimage` | 447/644 = 69.41% |
| `main` | 41/59 = 69.49% |
| `bgimage` | 74/153 = 48.37% |
| `data` | 581/1426 = 40.74% |
| `scn` | 112/294 = 38.10% |
| `voice` | 7525/21479 = 35.03% |
| `uipsd` | 46/155 = 29.68% |
| `video` | 124/537 = 23.09% |
| `data_hgl` | 1269/10459 = 12.13% |

总体 `.alst` 文件名覆盖率：

```text
11511 / 36829 = 31.26%
```

### 8.9 深入上游与显式候选优化

在 31.26% 覆盖率基础上，继续做了三类上游探索：

1. API trace 调用栈聚类。
2. 对 `PackinOne.dll`、`psbfile.dll`、临时 KRKR 核心 DLL 的关键 RVA 做反汇编窗口分析。
3. 针对脚本 JSON / 已恢复文本资源中的显式字段补充候选并批量探测。

新增工具：

- `analyze_upstream_trace.py`
  - 解析 `UpstreamTrace.log`。
  - 按 `API_STREAM` / `API_PLACED` / `DIR` / `FILE`、资源名类别、调用栈签名聚类。
  - 当前标题阶段 trace 共 `2470` 行、`25` 类调用栈、`294` 个唯一可用真实名事件。

- `disasm_pe_offsets.py`
  - 使用 `pefile + capstone` 本地反汇编，不依赖 `dumpbin`。
  - 已确认 `PackinOne.dll` 运行时解析并调用：
    - `ttstr ::TVPGetPlacedPath(const ttstr &)`
    - `IStream * ::TVPCreateIStream(const ttstr &,tjs_uint32)`
    - `bool ::TVPIsExistentStorage(const ttstr &)`
    - `ttstr ::TVPNormalizeStorageName(const ttstr &)`
  - `psbfile.dll` 也直接调用 `TVPGetPlacedPath` / `TVPCreateIStream`，这说明 UI `.pimg` 名称更多来自 PSB/PIMG 结构或进入对应 UI 页面时的运行时调用。

- `collect_explicit_voice_candidates.py`
  - 专门扫描脚本 JSON 的 `voice` 字段。
  - 补齐旧规则遗漏的 `kamsel_001`、`sansel_001`、`suo7se_001`、`bgv205_01`、`60x008_001` 等变体。
  - 生成 `7165` 个语音 stem、`28338` 个候选路径、`16700` 个待探测路径。
  - 探测后覆盖率提升最明显：
    - `voice`: `7525/21479 = 35.03%` -> `8326/21479 = 38.76%`
    - `data_hgl`: `1269/10459 = 12.13%` -> `1470/10459 = 14.05%`

- `collect_explicit_visual_candidates.py`
  - 扫描脚本 JSON 的 `file` / `filename` / `image` / `bg` / `rule` / `storage` / `movie` / `video` 等字段。
  - 针对裸资源名补充大小写、目录和扩展名变体。
  - 生成 `671` 个显式值、`26473` 个候选路径、`25271` 个待探测路径。
  - 收益较小，主要新增：
    - `bgimage`: `74/153 = 48.37%` -> `79/153 = 51.63%`
    - `data`: `581/1426 = 40.74%` -> `595/1426 = 41.73%`

- `collect_filename_candidates.py` 扩展扫描 `work/tenshin_hgl/restored`
  - 将已恢复的 `main` / `data` / `uipsd` 文本、`.asd`、`.stage`、`.stand` 纳入候选来源。
  - 过滤二进制噪声后探测 `1038` 条。
  - 主要新增：
    - `data`: `595/1426 = 41.73%` -> `608/1426 = 42.64%`
    - `main`: `41/59 = 69.49%` -> `42/59 = 71.19%`

最新覆盖率为：

| 包 | 覆盖率 |
| --- | ---: |
| `bgm` | 81/82 = 98.78% |
| `fgimage` | 1211/1541 = 78.59% |
| `main` | 42/59 = 71.19% |
| `evimage` | 447/644 = 69.41% |
| `bgimage` | 79/153 = 51.63% |
| `data` | 608/1426 = 42.64% |
| `voice` | 8326/21479 = 38.76% |
| `scn` | 112/294 = 38.10% |
| `uipsd` | 46/155 = 29.68% |
| `video` | 124/537 = 23.09% |
| `data_hgl` | 1470/10459 = 14.05% |

总体 `.alst` 文件名覆盖率：

```text
12546 / 36829 = 34.07%
```

本轮结论：

- 文件名确实大量保存在脚本 JSON 的显式字段中，而不是 XP3 文件表中。
- 语音覆盖率的最大缺口不是 hash 算法，而是命名规则遗漏；补齐 `sel` / `7se` / `bgv` / 数字前缀语音后收益明显。
- `uipsd` 覆盖率几乎不变，说明剩余 UI 文件名很可能在 PSB/PIMG 内部结构、UI 运行时状态或特定界面打开流程中，不在普通剧情 JSON 字段里。
- `video` 覆盖率也没有提升，说明视频名可能来自二进制、特定系统脚本流程，或需要实际播放/打开回想/标题动画等界面才会传给 storage API。
- 下一阶段若继续提高覆盖率，优先方向应从“静态候选生成”转为“更高价值的运行时触发”：自动进入 CG/回想/BGM/系统设置/存读档/标题动画等 UI 页面，并在 `TVPGetPlacedPath` / `TVPCreateIStream` 层记录真实名。

### 8.10 进一步探索：包级模型与 UI 内容反推

在 34.07% 基础上继续探索后，有三项方法被验证为高价值。

#### 8.10.1 视频序列帧模型

新增 `generate_video_sequence_candidates.py`，从已映射视频目录样本中建立序列规律：

- `fure_l/`
- `fure_r/`
- `火災/`
- `花火フレア/`

生成 `35504` 个候选后，`video` 从：

```text
124 / 537 = 23.09%
```

提升到：

```text
512 / 537 = 95.34%
```

结论：  
对“目录名已知、文件名是连续帧号”的包，基于少量样本做有界序列生成，是目前收益最高的方法之一。

#### 8.10.2 `data_hgl` / `evimage` 定向候选

新增 `generate_targeted_gap_candidates.py`，生成 `307059` 个候选，重点覆盖：

- HCG 双字母差分：`evNNNNaa.png` 到更宽后缀范围。
- 已知 HCG 编号的完整双字母后缀。
- `data_hgl` 中的 `701/702/703/704` 附加语音。
- 回想语音：`xxxNNN_r001.ogg`、`xxxres_r001.ogg`、`xxxsel_r001.ogg`。
- 日期图与部分系统缩略图候选。

探测后整体 `.alst` 覆盖从：

```text
12934 / 36829 = 35.12%
```

提升到：

```text
13628 / 36829 = 37.00%
```

主要增量：

| 包 | 探测前 | 探测后 | 增量 |
| --- | ---: | ---: | ---: |
| `data` | 608/1426 | 684/1426 | +76 |
| `data_hgl` | 1470/10459 | 1975/10459 | +505 |
| `evimage` | 447/644 | 559/644 | +112 |
| `voice` | 8326/21479 | 8327/21479 | +1 |

结论：  
这证明 `evimage` / HCG 类资源适合包级命名模型；但普通 `voice` 不适合继续靠“已知场景补行号”硬扩，收益几乎耗尽。

#### 8.10.3 `uipsd` 内容反推

对 `uipsd` 剩余未映射文件检查内容后发现：

- 未命名 `ini/`、`func/` 文件多数是 UTF-16 文本。
- 文本中明文包含 `psd,cgviewlist`、`psd,&GetUIPSD("option_9gamepad")`、`incl,file.func`、`UI_PAGE,save` 等字段。
- 这些字段可以反推自身或伴生文件名，例如：
  - `cgviewlist.ini`
  - `option_9gamepad.pimg`
  - `file_save.ini`
  - `qconf_file_load.ini`
  - `scnchart.pimg`

新增脚本：

- `collect_uipsd_content_candidates.py`
- `uipsd_manual_family_candidates.txt`

两轮探测结果：

| 阶段 | `uipsd` 覆盖率 |
| --- | ---: |
| 原始 | 46/155 = 29.68% |
| 自动读取 UI 文本字段后 | 102/155 = 65.81% |
| 人工补充 UI 名族后 | 118/155 = 76.13% |

结论：  
对 `uipsd`，最佳方法不是跑剧情，也不是扩大随机候选，而是“解出 hash 文件内容 -> 从 INI/FUNC 内部明文字段反推出文件名 -> 交给原 hasher 验证”。这条路线确定性强，候选少，收益高。

#### 8.10.4 FreeMote PIMG 图片提取

继续测试 `E:\Galgame_Tools\Ulysses-FreeMoteToolkit-v4.5.1`：

```powershell
PsbDecompile.exe image -t Pimg <file.pimg> -o <out>
```

结果：

- 已恢复的 16 个 `.pimg` 可成功处理。
- 共导出 810 张 PNG 图层。
- 输出目录：`work\tenshin_hgl\pimg_png`

结论：  
PIMG 内部 JSON/图层名更适合用于 UI 视觉还原，不适合作为 XP3 文件名映射主来源。对 Slapstick Ren'Py 迁移而言，这反而是好事：UI 使用时主要需要 PNG 图层和布局逻辑，未必需要还原所有原始 XP3 文件名。

#### 8.10.5 最新覆盖率

最终本轮 manifest：

| 包 | 覆盖率 |
| --- | ---: |
| `bgm` | 81/82 = 98.78% |
| `video` | 512/537 = 95.34% |
| `evimage` | 559/644 = 86.80% |
| `fgimage` | 1211/1541 = 78.59% |
| `uipsd` | 118/155 = 76.13% |
| `main` | 42/59 = 71.19% |
| `bgimage` | 79/153 = 51.63% |
| `data` | 684/1426 = 47.97% |
| `voice` | 8327/21479 = 38.77% |
| `scn` | 112/294 = 38.10% |
| `data_hgl` | 1975/10459 = 18.88% |

总体：

```text
13700 / 36829 = 37.20%
```

本轮最终判断：

- 继续扩大无差别候选爆破，性价比已经下降。
- 最好的方法是“包级模型 + 内容反推 + 原 hasher 验证 + `.alst` 合并”。
- 对剩余缺口，下一步真正值得做的是运行时触发特定系统页面，例如 CG 鉴赏、音乐鉴赏、语音收藏、存读档、流程图，并继续在 `TVPGetPlacedPath` / `TVPCreateIStream` 层抓真实 storage name。

## 9. 复杂度评估

### 9.1 实现复杂度：中高

原因：

- 必须理解 Hxv4/PackinOne 的运行时 hash 机制。
- 静态 XP3 文件表不含真实名，不能靠普通解包器解决。
- 需要 DLL 注入和虚表 hook。
- 需要调用游戏自身 `TVPIsExistentStorage()` 来触发原始 hasher。
- 需要将动态日志和 `.alst` 静态索引二次合并。
- 自动化提取还需要处理游戏进程启动、退出、日志备份和编码问题。

但一旦工具改造完成，后续复用成本较低。

### 9.2 操作复杂度：中

稳定流程为：

1. 解出可读脚本/配置。
2. 运行 `collect_filename_candidates.py`。
3. 复制 `hash_probe_candidates.txt` 到游戏 `StringHashDumper_Output`。
4. 用 `--hash` 启动游戏并等待 `HashProbeDone`。
5. 合并新旧 hash 日志。
6. 用 `--extract` 批量抽 XP3 生成 `.alst`。
7. 运行 `build_hash_manifest.py`。

流程需要多步，但已可脚本化。

### 9.3 效果：高价值但非 100%

该方案的价值很高，因为它能主动触发大量原本需要剧情流程才能调用的资源名，尤其对以下资源非常有效：

- BGM
- 背景
- 立绘
- 系统 UI
- 部分脚本
- 部分视频

但它不能保证 100% 映射，原因包括：

- 有些文件名可能由运行时逻辑拼接，不直接出现在脚本文本中。
- 有些资源名可能只在 EXE 或插件二进制里。
- 语音资源数量巨大，脚本中未必包含所有实际语音文件名。
- `data_hgl` 这类包可能包含大量内部资源、差分资源、临时资源或非显式路径资源。
- `tenshin_chs.xp3` 可能不是同一索引路径，仍需单独分析。

因此，该方案适合作为“高覆盖自动化映射主方案”，剩余未映射资源再用定向候选生成、二进制字符串扫描、脚本宏分析或人工确认补齐。

## 10. 后续优化建议

优先级从高到低：

1. 增强候选生成器  
   从 JSON 结构中进一步识别宏参数、角色别名、语音编号范围、视频名、CG 差分名。

2. 针对 `voice` 建立编号推断  
   例如从已知 `aoi001_001` 推断连续编号，并批量生成 `aoi001_001.ogg` 到更高范围。

3. 分析 `tenshin_chs.xp3`  
   确认它是否是普通 XP3、补丁包、不同加密包，或是否需要另一个 index 创建入口。

4. 对 EXE / DLL 做 Unicode / Shift-JIS 字符串扫描  
   捕获没有出现在脚本 JSON 里的系统资源名。

5. 将批量 hash 探测和日志合并做成单命令脚本  
   目前流程已稳定，但仍由多个脚本/命令组成。

6. 将恢复目录移动到游戏所在 E 盘  
   当前 `work\tenshin_hgl\restored` 在 C 盘，跨盘不能硬链接，只能复制。若恢复大量资源，放在 E 盘可节省空间和时间。

## 11. 总体评价

该方案不是传统“解密 XP3 后直接得到文件名”的路线，而是“让原游戏运行时代算 hash，再和包索引合并”的路线。

它的复杂度明显高于普通 GARbro 适配，但非常适合当前这种真实文件名缺失、文件名只在脚本运行时传入 hasher 的游戏。实测中，一轮批量探测就新增 7619 个唯一文件名，并使 BGM、立绘、背景、主系统资源达到较高映射率，已经足以支持后续 Ren'Py 迁移中的 UI、BGM、背景、立绘资源接入。

后续若要继续提高完整度，重点不应再放在 XP3 文件表本身，而应放在“生成更完整候选文件名”和“补齐特殊包/语音包的资源命名规律”上。

## 12. 覆盖率提升流水账（补记校准版）

本节以 `.alst` 验证后的真实文件名覆盖率为准，而不是单纯以 `FileNameHash.log` 行数为准。`FileNameHash.log` 中包含大量候选探测记录，只有和 `.alst` 里的文件 hash 对上，才计入有效覆盖率。

当前最新结果：

```text
36092 / 36829 = 98.00%
```

当前按包覆盖率：

| 包 | 最新覆盖率 |
| --- | ---: |
| `bgimage` | 150/153 = 98.04% |
| `bgm` | 81/82 = 98.78% |
| `data` | 1044/1426 = 73.21% |
| `data_hgl` | 10324/10459 = 98.71% |
| `evimage` | 643/644 = 99.84% |
| `fgimage` | 1531/1541 = 99.35% |
| `main` | 49/59 = 83.05% |
| `scn` | 293/294 = 99.66% |
| `uipsd` | 118/155 = 76.13% |
| `video` | 512/537 = 95.34% |
| `voice` | 21347/21479 = 99.39% |

### 12.1 总览表

| 阶段 | 覆盖率变化 | 映射数变化 | 主要动作 |
| --- | ---: | ---: | --- |
| 初始主动探测 | 0.00% -> 22.38% | 0 -> 8242 | 静态候选 + 原始 hasher 批量探测 |
| 剧情流遍历 | 22.38% -> 22.41% | 8242 -> 8254 | Ulysses 反编译 SCN，展开显式剧情边 |
| 编号/模式候选 | 22.41% -> 29.10% | 8254 -> 10716 | BGM、EV、voice、data_hgl 编号模型 |
| API trace 与显式资源扩展 | 29.10% -> 31.26% | 10716 -> 11511 | 上游 storage API trace、EV/voice 显式字段 |
| 显式语音/视觉/恢复文本扫描 | 31.26% -> 34.07% | 11511 -> 12546 | `voice` 字段、`file/bg/storage` 字段、restored 文本 |
| 视频序列帧模型 | 34.07% -> 35.12% | 12546 -> 12934 | `video` 包目录序列帧名 |
| HCG/data_hgl 定向模型 | 35.12% -> 37.00% | 12934 -> 13628 | HCG 双字母差分、附加语音、日期图 |
| UI 内容反推 | 37.00% -> 37.16% | 13628 -> 13684 | 从未命名 `uipsd` INI/FUNC 内部字段反推 |
| UI 家族人工补全 | 37.16% -> 37.20% | 13684 -> 13700 | 补齐 `option/qconf/file/scnchart` 等 UI 家族名 |
| 伴生文件逻辑 | 37.20% -> 43.11% | 13700 -> 15877 | `.ogg.sli`、`.stage/.asd -> .stand` |
| SCN JSON 内部名恢复 | 43.11% -> 95.52% | 15877 -> 35178 | 反编译 hash SCN，抽内部脚本名、语音、背景、CG |
| 立绘 imagemulti/stand | 95.52% -> 96.39% | 35178 -> 35498 | `imagemulti.txt`、`.stand`、立绘差分 |
| 修复脚本音频名 | 96.39% -> 96.53% | 35498 -> 35550 | 修复 SCN 中编码异常/变体音频名 |
| 主文本资源扫描 | 96.53% -> 96.88% | 35550 -> 35680 | `main/data` 文本中缩略图、EV、系统资源 |
| data_hgl 列表扫描 | 96.88% -> 96.99% | 35680 -> 35719 | HCG/list 表中补 `data_hgl` 文件名 |
| PSB 逻辑缺口 | 96.99% -> 97.19% | 35719 -> 35793 | 未命名 PSB 内部事件组反推 `thum_ev*.psb` |
| 背景缩略图前缀 | 97.19% -> 97.50% | 35793 -> 35907 | `bgthum_<背景stem>.jpg` 命名规则 |
| 背景顺序与脚本精确字段 | 97.50% -> 98.00% | 35907 -> 36092 | 背景 alst 顺序缺口、SCN 精确语音字段 |

### 12.2 初始主动探测：0.00% -> 22.38%

提升前：

```text
0 / 36829 = 0.00%
```

提升后：

```text
8242 / 36829 = 22.38%
```

详细步骤：

1. 改造 `CxdecStringDumper.dll`，hook PackinOne/Hxv4 的 `PathNameHasher` 和 `FileNameHasher`。
2. 让游戏自身计算文件名 hash，而不是在外部重写 hash 算法。
3. 从剧情 JSON、INI、FUNC、CSV、TJS 等文本中静态收集资源候选名。
4. 将候选写入 `HashProbeCandidates.txt`。
5. 用 `CxdecExtractorLoader.exe "<game.exe>" --hash` 启动游戏。
6. DLL 逐行调用 `TVPIsExistentStorage()`，触发原始 hasher。
7. 合并 `DirectoryHash.log`、`FileNameHash.log`。
8. 用 `build_hash_manifest.py` 和 `.alst` 文件表交叉验证。

主要收益：

- 首次建立真实文件名 hash 库。
- `fgimage`、`bgm`、`main`、`bgimage`、`data` 得到基础覆盖。
- 验证了“原游戏 hasher + `.alst` 合并”是可行主路线。

### 12.3 剧情流遍历：22.38% -> 22.41%

提升前：

```text
8242 / 36829 = 22.38%
```

提升后：

```text
8254 / 36829 = 22.41%
```

详细步骤：

1. 使用 `Ulysses-FreeMoteToolkit-v4.5.1\PsbDecompile.exe` 反编译 `.ks.scn`。
2. 将可读脚本从 75 个扩展到 107 个。
3. 从脚本 JSON 中读取 `nexts`、`selects`、显式 target。
4. 遇到选择分支时将所有分支都加入遍历队列。
5. 只抽取资源名候选，不实际加载资源。
6. 生成 727 个此前未进入 hash 日志的剧情流候选。
7. 探测后新增 558 个唯一文件名 hash。
8. 重建 manifest 后，实际 `.alst` 命中新增 12 个。

主要收益：

- 证明快速剧情遍历方案可行。
- 但边际收益较低，说明单纯跑显式剧情边不是主要瓶颈。

### 12.4 编号/模式候选：22.41% -> 29.10%

提升前：

```text
8254 / 36829 = 22.41%
```

提升后：

```text
10716 / 36829 = 29.10%
```

详细步骤：

1. 扩展 `collect_filename_candidates.py`，纳入 Ulysses 反编译出的 SCN JSON。
2. 跳过 `.resx.json` 空资源表，降低噪声。
3. 增加 `.sli`、`.pbd`、`.stage`、`.stand` 等扩展名识别。
4. 对 BGM 裸名自动补 `.ogg` 和 `.ogg.sli`。
5. 新增 `generate_pattern_candidates.py`。
6. 生成 `bgm01` 到 `bgm99`、`ev0001a` 到 `ev0999h`、语音编号、回想语音等候选。
7. 多轮探测并合并日志。
8. 重建 manifest。

主要收益：

- `voice`: 5503/21479 -> 7168/21479。
- `data_hgl`: 382/10459 -> 1004/10459。
- `evimage`: 122/644 -> 274/644。
- `bgm`: 62/82 -> 81/82。

### 12.5 API trace 与显式资源扩展：29.10% -> 31.26%

提升前：

```text
10716 / 36829 = 29.10%
```

提升后：

```text
11511 / 36829 = 31.26%
```

详细步骤：

1. 在 `CxdecStringDumper.dll` 中继续向上游 hook storage API。
2. 记录 `TVPIsExistentStorage()`、`TVPGetPlacedPath()`、`TVPCreateIStream()` 的真实请求。
3. 生成 `UpstreamTrace.log`。
4. 用 `collect_api_trace_candidates.py` 提取真实 storage name。
5. 合并 EV 单字母扩展、HCG 双字母差分扩展、语音编号外推候选。
6. 探测后合并日志并重建 manifest。

主要收益：

- `evimage`: 274/644 -> 447/644。
- `voice`: 7168/21479 -> 7525/21479。
- `data_hgl`: 1004/10459 -> 1269/10459。

### 12.6 显式语音/视觉/恢复文本扫描：31.26% -> 34.07%

提升前：

```text
11511 / 36829 = 31.26%
```

提升后：

```text
12546 / 36829 = 34.07%
```

详细步骤：

1. 新增 `collect_explicit_voice_candidates.py`。
2. 专门扫描脚本 JSON 中的 `voice` 字段。
3. 补齐 `sel`、`7se`、`bgv`、数字前缀语音、`ref` 变体。
4. 新增 `collect_explicit_visual_candidates.py`。
5. 扫描 `file`、`filename`、`image`、`bg`、`rule`、`storage`、`movie`、`video` 字段。
6. 对裸资源名补 `.png`、`.pimg`、`.tlg`、`.stage`、`.stand` 等扩展。
7. 将 `work\tenshin_hgl\restored` 里的已恢复文本纳入扫描。
8. 探测后合并日志并重建 manifest。

主要收益：

- `voice`: 7525/21479 -> 8326/21479。
- `data_hgl`: 1269/10459 -> 1470/10459。
- `bgimage`: 74/153 -> 79/153。
- `data`: 581/1426 -> 608/1426。

### 12.7 视频序列帧模型：34.07% -> 35.12%

提升前：

```text
12546 / 36829 = 34.07%
```

提升后：

```text
12934 / 36829 = 35.12%
```

详细步骤：

1. 新增 `generate_video_sequence_candidates.py`。
2. 从已映射视频目录中识别序列帧命名：
   - `fure_l/`
   - `fure_r/`
   - `火災/`
   - `花火フレア/`
3. 根据目录内已有样本生成连续编号候选。
4. 保留实际出现过的目录 hash，不扩大到无关目录。
5. 批量探测候选并合并日志。
6. 重建 manifest。

主要收益：

- `video`: 124/537 -> 512/537。
- 视频包覆盖率从 23.09% 提升到 95.34%。

### 12.8 HCG/data_hgl 定向模型：35.12% -> 37.00%

提升前：

```text
12934 / 36829 = 35.12%
```

提升后：

```text
13628 / 36829 = 37.00%
```

详细步骤：

1. 新增 `generate_targeted_gap_candidates.py`。
2. 对 HCG 生成 `evNNNNaa` 到更宽双字母后缀范围。
3. 对已知 HCG 编号补完整差分名。
4. 对 `data_hgl` 生成 `701/702/703/704` 等附加语音候选。
5. 生成 `xxxNNN_r001.ogg`、`xxxres_r001.ogg`、`xxxsel_r001.ogg` 等回想语音。
6. 补日期图、系统缩略图等定向候选。
7. 探测后合并日志并重建 manifest。

主要收益：

- `data`: 608/1426 -> 684/1426。
- `data_hgl`: 1470/10459 -> 1975/10459。
- `evimage`: 447/644 -> 559/644。

### 12.9 UI 内容反推：37.00% -> 37.16%

提升前：

```text
13628 / 36829 = 37.00%
```

提升后：

```text
13684 / 36829 = 37.16%
```

详细步骤：

1. 检查 `uipsd` 包中仍未命名的 hash 文件内容。
2. 发现多数 `ini/`、`func/` 是 UTF-16 文本。
3. 从文本中抽取 `psd,...`、`incl,...`、`UI_PAGE,...`、`GetUIPSD(...)` 等字段。
4. 由内部字段反推自身文件名或伴生文件名。
5. 新增 `collect_uipsd_content_candidates.py`。
6. 探测生成的 UI 候选并合并日志。
7. 重建 manifest。

主要收益：

- `uipsd`: 46/155 -> 102/155。
- overall 增加 56 个 `.alst` 命中。

### 12.10 UI 家族人工补全：37.16% -> 37.20%

提升前：

```text
13684 / 36829 = 37.16%
```

提升后：

```text
13700 / 36829 = 37.20%
```

详细步骤：

1. 根据已恢复 UI 文件族整理 `option`、`qconf`、`file`、`extra`、`scnchart`、`quickmenu` 等基名。
2. 为每个基名补 `.pimg`、`ini/<name>.ini`、`func/<name>.func`。
3. 写入 `uipsd_manual_family_candidates.txt`。
4. 探测后合并日志。
5. 重建 manifest。

主要收益：

- `uipsd`: 102/155 -> 118/155。
- overall 增加 16 个 `.alst` 命中。

### 12.11 伴生文件逻辑：37.20% -> 43.11%

提升前：

```text
13700 / 36829 = 37.20%
```

提升后：

```text
15877 / 36829 = 43.11%
```

详细步骤：

1. 新增 `generate_companion_logic_candidates.py`。
2. 从当前 manifest 中读取已经成功映射的真实文件名。
3. 对所有 `.ogg` 自动追加 `.ogg.sli`，模拟 WaveLoopManager 的 sidecar 规则。
4. 对 `.asd` 自动生成 `.stand`。
5. 对 `.stage` 自动生成 `.stand`。
6. 同时保留 basename 和带目录形态，让 storage normalization 走真实路径。
7. 过滤已经在 `FileNameHash.log` 中出现过的候选。
8. 批量探测后合并日志并重建 manifest。

主要收益：

- `voice`: 8327/21479 -> 9887/21479。
- `data_hgl`: 1975/10459 -> 2563/10459。
- `data`: 684/1426 -> 713/1426。
- overall 增加 2177 个 `.alst` 命中。

### 12.12 SCN JSON 内部名恢复：43.11% -> 95.52%

提升前：

```text
15877 / 36829 = 43.11%
```

提升后：

```text
35178 / 36829 = 95.52%
```

详细步骤：

1. 对未映射的 `scn` hash 文件继续使用 FreeMote/Ulysses 反编译。
2. 将结果保存到 `work\tenshin_hgl\scn_hash_json`。
3. 新增 `collect_scn_hash_json_candidates.py`。
4. 从每个 JSON 根节点读取内部 `name`，恢复 `.ks` / `.ks.scn` 脚本名。
5. 遍历 JSON 结构中的 `voice` 字段，生成 `.ogg` 和 `.ogg.sli`。
6. 遍历 `file`、`filename`、`image`、`bg`、`rule`、`movie`、`video`、`storage` 字段。
7. 对 BGM、EV、背景、脚本引用分别补对应扩展名。
8. 批量探测候选后合并日志。
9. 重建 manifest。

主要收益：

- `voice`: 9887/21479 -> 21325/21479。
- `data_hgl`: 2563/10459 -> 10150/10459。
- `scn`: 112/294 -> 293/294。
- `bgimage`: 79/153 -> 120/153。
- `evimage`: 559/644 -> 586/644。
- overall 增加 19301 个 `.alst` 命中。

结论：

- 这一步证明大量文件名实际保存在已 hash 化的 SCN/PSB 脚本内部，而不是 XP3 index。
- 解出并解析 SCN JSON 是覆盖率从中等水平跃迁到高覆盖的关键。

### 12.13 立绘 imagemulti/stand：95.52% -> 96.39%

提升前：

```text
35178 / 36829 = 95.52%
```

提升后：

```text
35498 / 36829 = 96.39%
```

详细步骤：

1. 新增 `collect_imagemulti_fg_candidates.py`。
2. 读取已恢复立绘相关文本与 `imagemulti.txt`。
3. 解析立绘多层组合、差分名、`.stage`、`.stand` 关系。
4. 生成 `fgimage` 可能的 `.tlg`、`.pimg`、`.stage`、`.stand` 候选。
5. 过滤已知 hash 后批量探测。
6. 合并日志并重建 manifest。

主要收益：

- `fgimage`: 1211/1541 -> 1531/1541。
- overall 增加 320 个 `.alst` 命中。

### 12.14 修复脚本音频名：96.39% -> 96.53%

提升前：

```text
35498 / 36829 = 96.39%
```

提升后：

```text
35550 / 36829 = 96.53%
```

详细步骤：

1. 新增 `collect_repaired_scn_audio_candidates.py`。
2. 检查 SCN JSON 中疑似乱码、编码异常、后缀不完整的音频名。
3. 对常见 mojibake/编码错位形式做修复。
4. 对修复后的音频名补 `.ogg` 和 `.ogg.sli`。
5. 探测候选并合并日志。
6. 重建 manifest。

主要收益：

- `data`: 740/1426 -> 792/1426。
- overall 增加 52 个 `.alst` 命中。

### 12.15 主文本资源扫描：96.53% -> 96.88%

提升前：

```text
35550 / 36829 = 96.53%
```

提升后：

```text
35680 / 36829 = 96.88%
```

详细步骤：

1. 新增 `collect_main_text_resource_candidates.py`。
2. 扫描已恢复 `main`、`data`、部分系统文本。
3. 提取 CG 列表、缩略图列表、系统配置、回想列表中的资源名。
4. 根据文本内容补 `.txt`、`.csv`、`.ini`、`.tjs`、`.psb`、`.png` 等扩展。
5. 批量探测后合并日志。
6. 重建 manifest。

主要收益：

- `data`: 792/1426 -> 865/1426。
- `evimage`: 586/644 -> 643/644。
- overall 增加 130 个 `.alst` 命中。

### 12.16 data_hgl 列表扫描：96.88% -> 96.99%

提升前：

```text
35680 / 36829 = 96.88%
```

提升后：

```text
35719 / 36829 = 96.99%
```

详细步骤：

1. 新增 `collect_data_hgl_list_candidates.py`。
2. 扫描 `data_hgl` 相关 HCG/list 表。
3. 提取 HCG 编号、缩略图、附加资源名。
4. 生成 `evNNNNxx`、`thum_evNNNNxx`、`.png`、`.psb` 等候选。
5. 探测后合并日志。
6. 重建 manifest。

主要收益：

- `data_hgl`: 10150/10459 -> 10189/10459。
- overall 增加 39 个 `.alst` 命中。

### 12.17 无增量但保留的图像伴生/背景缩略图初探

`image_companion` 和第一版 `bg_thumbnail` 两轮探测都产生了新的 `FileNameHash.log` 行，但没有增加 `.alst` 命中。

记录结果：

```text
image_companion: 35680 / 36829 = 96.88% -> 35680 / 36829 = 96.88%
bg_thumbnail:    35719 / 36829 = 96.99% -> 35719 / 36829 = 96.99%
```

保留原因：

- 它们验证了部分候选方向无效，避免后续重复投入。
- 背景缩略图初探虽未直接增加覆盖率，但为后续确认 `bgthum_<背景stem>.jpg` 命名规则提供了线索。

### 12.18 PSB 逻辑缺口：96.99% -> 97.19%

提升前：

```text
35719 / 36829 = 96.99%
```

提升后：

```text
35793 / 36829 = 97.19%
```

详细步骤：

1. 新增 `collect_logic_gap_candidates.py`。
2. 对剩余未命名 PSB/PIMG 做 FreeMote 反编译。
3. 从 PSB JSON 内部收集 `evNNNNxx` 事件组。
4. 发现 `data/thum/cgthum` 的真实命名不是普通 PNG/JPG，而是 `thum_<cg_stem>.psb`。
5. 从事件组第一个 CG 名推断外层 PSB 文件名，例如：
   - `ev0316aa` -> `thum_ev0316aa.psb`
   - `ev0901aa` -> `thum_ev0901aa.psb`
6. 同时补充 main 自描述文件名和少量 UI 家族名。
7. 探测 6495 个候选。
8. 合并日志并重建 manifest。

主要收益：

- `data`: 865/1426 -> 930/1426。
- `main`: 42/59 -> 49/59。
- `data_hgl`: 10189/10459 -> 10191/10459。
- overall 增加 74 个 `.alst` 命中。

### 12.19 背景缩略图前缀：97.19% -> 97.50%

提升前：

```text
35793 / 36829 = 97.19%
```

提升后：

```text
35907 / 36829 = 97.50%
```

详细步骤：

1. 新增 `collect_bgthumb_prefix_candidates.py`。
2. 读取已经映射的 `bgimage` stem。
3. 生成 `thum_`、`thumb_`、`bgthum_`、`bgthumb_` 等前缀候选。
4. 与 `bgthumb_visual_matches.json` 的视觉匹配结果交叉验证。
5. 确认实际规则主要是：

```text
bgthum_<bgimage_stem>.jpg
```

6. 探测 3332 个候选。
7. 合并日志并重建 manifest。

主要收益：

- `data`: 930/1426 -> 1044/1426。
- `data/thum/bgthum` 大量补齐。
- overall 增加 114 个 `.alst` 命中。

### 12.20 背景顺序与脚本精确字段：97.50% -> 98.00%

提升前：

```text
35907 / 36829 = 97.50%
```

提升后：

```text
36092 / 36829 = 98.00%
```

详细步骤：

1. 刷新当前缺口分类，确认 `bgimage` 仍有 33 个未映射。
2. 检查 `bgimage.alst` 顺序，发现缺口集中在背景家族中：
   - `god_c` 后的 `god_d`
   - `home_sana_a` 到 `home_sana_d`
   - `school_classroom_*`
   - `school_gate_*`
   - `school_way_*`
   - `station_*`
   - `store_out_*`
3. 新增 `collect_scn_file_field_candidates.py`。
4. 从 SCN JSON 精确提取 `file/storage/voice/sound` 字段，补未覆盖语音候选。
5. 新增 `generate_bg_sequence_gap_candidates.py`。
6. 基于 alst 相邻已知名生成有界背景候选，而不是大范围枚举。
7. 对课堂、校门、校道等家族建立小型交叉模型。
8. 合并背景候选和 SCN 精确语音候选，共探测 2668 个候选。
9. 合并日志并重建 manifest。

主要收益：

- `bgimage`: 120/153 -> 150/153。
- `data_hgl`: 10191/10459 -> 10324/10459。
- `voice`: 21325/21479 -> 21347/21479。
- overall 增加 185 个 `.alst` 命中。

当前剩余重点缺口：

- `bgimage`: 3 个，其中 1 个是通用缺失 hash，2 个是真实图像。
- `data`: 382 个，主要是 `sound/`、`sysscn/`、`system/`、`thum/bgthum/`、`image/sys/` 等。
- `data_hgl`: 135 个，主要是少量 OGG、PSB、文本/list。
- `voice`: 132 个，主要是极少数编号缺口、特殊语音和若干缺失条目。
- `uipsd`: 37 个，剩余多为特定 UI 页面/状态文件。
- `video`: 25 个，主要是开头视频和少量序列目录缺口。

### 12.21 当前判断

覆盖率从 37.20% 提升到 98.00% 的关键，不是扩大盲目爆破，而是逐步找到“文件名真实保存位置”和“程序调用命名逻辑”：

1. SCN/PSB 内部 JSON 是最大来源。
2. 伴生文件规则能批量补 `.ogg.sli` 和 `.stand`。
3. UI 文件名适合从 INI/FUNC 内容反推。
4. 背景缩略图遵循 `bgthum_<背景stem>.jpg`。
5. 背景本体可用 `.alst` 顺序和家族命名模型补齐大部分。
6. 对剩余 2% 缺口，继续上游探索比扩大候选更重要。

后续最值得继续做的方向：

1. 对剩余 `data/sound` 建立 SE/BGM/环境音命名模型。
2. 对 `data/system`、`sysscn` 的 TJS/PSB 文本做内部类名与文件名反推。
3. 对 `uipsd` 剩余项进入具体 UI 页面，抓 `TVPGetPlacedPath` / `TVPCreateIStream`。
4. 对剩余 `bgimage` 直接结合图像内容、相邻序列和脚本语义定位真实名。
5. 对 `voice/data_hgl` 剩余项用 alst 前后文件名做缺号推断，而不是全范围编号爆破。

### 12.22 历史 Yuzusoft GARbro 文件名迁移：99.55% -> 99.57%

提升前：

```text
36662 / 36829 = 99.55%
```

提升后：

```text
36668 / 36829 = 99.57%
```

详细步骤：

1. 新增 `collect_old_yuzu_garbro_listing_candidates.py`。
2. 从 `DRACU-RIOT`、`Noble Works`、`千恋万花` 等 GARbro 可读列表导出历史 Yuzusoft 文件名。
3. 将旧作中可迁移的 `sound/`、`uipsd/func/` 等路径作为候选。
4. 生成 177948 个候选并用当前游戏 hasher 探测。
5. 合并日志并重建 manifest。

主要收益：

- 命中 `sound/■ざわめき.ogg`、`sound/フラッシュバック.ogg`、`sound/電気.ogg`、`sound/電気２.ogg`。
- 命中 `uipsd/func/search.func`。
- overall 增加 6 个 `.alst` 命中。

结论：

- 同社旧作资源名可作为补充语料，但对末尾缺口提升有限。
- 它适合补通用 SE/UI 名，不适合作为 100% 覆盖主路线。

### 12.23 邻接音频变体：99.57% -> 99.64%

提升前：

```text
36668 / 36829 = 99.57%
```

提升后：

```text
36696 / 36829 = 99.64%
```

详细步骤：

1. 新增 `collect_neighbor_audio_variant_candidates.py`。
2. 对 `voice` / `data_hgl` 中未映射 OGG，读取 alst 前后 4 个已知音频名。
3. 对邻近 stem 生成 `a/b/c`、`_a/_b/_c`、`_ref`、`_sp` 等小范围变体。
4. 同时补 `.ogg` 与 `.ogg.sli`。
5. 生成 34350 个候选并探测。
6. 合并日志并重建 manifest。

主要收益：

- 命中多个结尾字母变体，例如 `aoi005_518b.ogg`、`hon401_437b.ogg`、`ior200_009b.ogg`。
- 命中多条 `kam_re_006b.ogg` 到 `kam_re_013b.ogg`。
- overall 增加 28 个 `.alst` 命中。

结论：

- alst 邻接关系对语音尾部差分非常有效。
- 但对非标准命名或非邻接插入的文件帮助较弱。

### 12.24 Ref 桥接与 san301 四位数探测：99.64% -> 99.66%

提升前：

```text
36696 / 36829 = 99.64%
```

提升后：

```text
36703 / 36829 = 99.66%
```

详细步骤：

1. 新增 `collect_bridge_audio_candidates.py`。
2. 对已知 voice stem 添加 `_ref` 桥接候选。
3. 对 H/ref 语音段生成 `char720_###_ref` 候选。
4. 生成 497230 个候选并探测。
5. 针对命中的 `san301_*_ref` 规律继续生成四位数 ref 候选。
6. 合并日志并重建 manifest。

主要收益：

- 命中 `ref/kam203_030_ref.ogg`。
- 命中 `ref/san301_391_ref.ogg`、`ref/san301_708_ref.ogg`、`ref/san301_1234_ref.ogg`、`ref/san301_1242_ref.ogg`、`ref/san301_1352_ref.ogg`、`ref/san301_1495_ref.ogg`。
- overall 增加 7 个 `.alst` 命中。

结论：

- `_ref` 不是单纯连续编号，存在少量四位数跳号。
- 桥接法适合在已知 stem 周边收尾，但继续扩大范围收益迅速下降。

### 12.25 Dense kam/kot 边界探测：99.66% -> 99.66%

提升前：

```text
36703 / 36829 = 99.66%
```

提升后：

```text
36704 / 36829 = 99.66%
```

详细步骤：

1. 针对 `kam401_378.ogg` 到 `kam501_001.ogg` 的边界缺口生成密集候选。
2. 先生成完整候选，再缩小为 OGG-only 版本以降低 hasher 压力。
3. 合并日志并重建 manifest。

主要收益：

- 命中 `kot/kot204_001.ogg`。
- overall 增加 1 个 `.alst` 命中。

结论：

- 末尾语音缺口并非简单连续编号。
- 对单个未知语音继续密集枚举不划算，应优先回到脚本/调用逻辑或音频内容比对。

### 12.26 高置信缺口候选：99.66% -> 99.68%

提升前：

```text
36704 / 36829 = 99.66%
```

提升后：

```text
36712 / 36829 = 99.68%
```

详细步骤：

1. 新增 `collect_high_confidence_gap_candidates.py`。
2. 从剩余缺口的 alst 邻居关系生成小规模高置信候选。
3. 对视频缺口补 `ed_ruri_low.wmv`。
4. 对 `image/effect` 补 `fox_01/fox_02`、`name_yukari`、`emotion_surprise`。
5. 对 SE 补 `ファンファーレ`、`ボール打つ２`、`車衝突`。
6. 生成 1155 个候选并探测。
7. 合并日志并重建 manifest。

主要收益：

- `data`: 1380/1426。
- `video`: 534/537。
- overall 增加 8 个 `.alst` 命中。

结论：

- 对末尾缺口，少量“邻居 + 内容类型”候选仍有稳定收益。
- 视频低清文件可由宏逻辑 `movieQualitySelect ? "" : "_low"` 直接推导。

### 12.27 内容驱动恢复：99.68% -> 99.72%

提升前：

```text
36712 / 36829 = 99.68%
```

提升后：

```text
36726 / 36829 = 99.72%
```

详细步骤：

1. 新增 `collect_content_driven_gap_candidates.py`。
2. 直接打开未知 PNG/JPG/PSB contact sheet 观察内容。
3. 从 `fgimage` 未知 `.stand` 内部 UTF-16 字段读取 `filename`。
4. 恢复 `春樹.stand`、`若葉.stand`、`蘇芳.stand`。
5. 根据内部立绘基名补 `春樹_ポーズa.sinfo`、`若葉_ポーズa/b.sinfo`、`蘇芳_ポーズＡ/Ｂ.sinfo`。
6. 从图片文字恢复 `name_mikio.png`。
7. 从文件签名恢复 `krmovie.dll.sig`。
8. 从音效邻居恢复 `■蝉２【遠い】.ogg` 及 `.sli`。
9. 从 `data_hgl` 邻接恢复 `yuk111_r001.ogg`。
10. 从 UI 内容恢复 `ini/search.ini`。
11. 生成 6123 个候选并探测。
12. 合并日志并重建 manifest。

主要收益：

- `fgimage`: 1532/1541 -> 1540/1541，只剩 index 0 缺失哨兵。
- `data`: 1380/1426 -> 1384/1426。
- `data_hgl`: 10421/10459 -> 10422/10459。
- `uipsd`: 145/155 -> 146/155。
- overall 增加 14 个 `.alst` 命中。

结论：

- 剩余视觉类文件不能只靠命名模型；直接读内容/内部字段更有效。
- `fgimage` 的 `.stand` / `.sinfo` 文件名可由内部 `filename` 和角色名强相关恢复。

### 12.28 SCN voice 全量复扫与窄候选复验：99.72% -> 99.72%

提升前：

```text
36726 / 36829 = 99.72%
```

提升后：

```text
36726 / 36829 = 99.72%
```

详细步骤：

1. 新增 `collect_all_scn_voice_candidates.py`。
2. 遍历 `scn_hash_json` 全部 JSON，重新提取所有 `voice` 字段。
3. 对每个 voice stem 补 `.ogg`、`.ogg.sli`、`_ref.ogg`、`_ref.ogg.sli`。
4. 生成 17288 个当前 hash 表未包含的候选并探测。
5. 新增 `collect_narrow_remaining_candidates.py`。
6. 对剩余背景雨天/夜景、UI 配置、PIMG 名称做 424 个窄候选复验。
7. 合并日志并重建 manifest。

主要收益：

- 无新增 `.alst` 命中。

结论：

- 当前剩余 `data_hgl` 缺口并非简单由 SCN `voice` 字段直接派生。
- 剩余 `bgimage/uipsd/data sound` 需要更上游的调用栈、资源管理器注册逻辑、或内容级人工/自动识别。
- 内容哈希比对发现少量未知 `.sli` 与已知 `.sli` 完全同内容，说明部分剩余项可能是同资源别名，而不是独立新素材。

### 12.29 当前最新覆盖率

```text
36726 / 36829 = 99.72%
```

当前剩余真实缺口重点：

- `bgimage`: 2 个真实背景，分别是雨天教室 PNG、夜晚操场 JPG。
- `data`: 41 个真实缺口，集中在 `sound/`、`thum/bgthum/`、`image/effect/`、少量脚本/签名文件。
- `data_hgl`: 36 个真实缺口，主要是 H/ref 语音别名簇。
- `uipsd`: 8 个真实缺口，主要是短 INI/FUNC 和 2 个未知 PIMG。
- `video`: 2 个真实缺口，均为序列目录控制脚本。
- `voice`: 1 个真实 `kam/` OGG 缺口，其余多为 index 0 或缺失实体。
