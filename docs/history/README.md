# 历史文档索引

本目录收纳 Windows 端资源恢复工程与早期迁移探索的**原始过程记录**。它们不是
当前工程的运行文档,而是理解 `assets/` 资源来源、`hash_manifest` 体系、以及各
项"为什么这么做"决策的第一手材料。

## 文档清单(按时间线)

| 日期 | 文档 | 内容一句话 |
|---|---|---|
| 2026-06-20 | [天神乱漫_Hxv4_PackinOne_hash获取方案评估](天神乱漫_Hxv4_PackinOne_hash获取方案评估_20260620.md) | 真实文件名不在 XP3 index 里;hook 原游戏 hasher + `.alst` 合并的方案论证与覆盖率提升流水账(0%→37%) |
| 2026-06-20 | [天神乱漫_hash映射流程复盘](天神乱漫_hash映射流程复盘_20260620.md) | 方法论复盘:SCN JSON 内部名恢复是第一主线(43%→95% 的决定性跃迁);16 步执行模板与避坑清单 |
| 2026-06-21 | [天神乱漫_GARbro_XP3预览与串包修复报告](天神乱漫_GARbro_XP3预览与串包修复报告_20260621.md) | GARbro 接入:短 ID(ordinal)规则、namecache、Extractor_Output 旁路预览;串包 bug 修复;全量提取最终归档(36829 条目,缺失 0) |
| 2026-08-28 | [天神乱漫_PlayDRM维护与授权迁移方案](天神乱漫_PlayDRM维护与授权迁移方案_20260828.md) | 发行层合规方案:禁止补丁旧授权;三阶段路径(授权恢复→自建签名发行层→Godot 版长期替代) |
| (总纲) | [【Godot】天神乱漫 Happy Go Lucky!!](【Godot】天神乱漫 Happy Go Lucky!!.md) | 全程经验总结:封包逆向/UI 复刻/SCN 播放器/性能/GDScript 坑/选型/DRM 合规;**1.5 节确认 pbd2json.exe 可 64/64 导出 PBD JSON** |

## 与当前工程的关联

- `assets/` 里的资源即上述流程的产物;`ResourceIndex` autoload 读取的
  `hash_manifest` 体系源自这些文档描述的工具链。
- 剩余约 100 个未命名文件(99.72% 之外)的缺口分类见评估文档 12.29 节。
- 立绘 PBD 元数据:`pbd2json.exe` 产物(64 个 JSON)待入库,详见
  `docs/tlg2png.md` 与 `docs/plan/PLAN_P0_BRANCH_ENGINE.md` 风险表。
- DRM 合规红线以 PlayDRM 方案与总纲第 7 节为准:不分析/不绕过/不伪造授权。

## 放置约定

- 过程记录、复盘、报告 → `docs/history/`
- 前瞻性实施计划 → `docs/plan/`(见该目录 README)
- 长期有效的工程文档(环境、任务总表、验收方法、工具文档)→ `docs/` 根目录
