# 计划文档目录

所有前瞻性实施计划(P0/P1/…)统一放在本目录,命名规范:
`PLAN_<优先级>_<主题>.md`(如 `PLAN_P0_BRANCH_ENGINE.md`)。

- `docs/` 根目录保留:环境说明、迁移任务总表、兼容性验收方法、资产清单、
  工具文档等**长期参考**文档。
- 计划完成后,把"已完成"标记写回计划文档本身;若产生新的后续计划
  (如 P1/P2),在对应新文件中维护,不回写旧计划。

## 现有计划

- [PLAN_P0_BRANCH_ENGINE.md](PLAN_P0_BRANCH_ENGINE.md) — 选择支与分支引擎
  (选择支 UI、CheckBranchFlags/SetBranchFlags 状态机、跨文件跳转、存档 v2)
  **已完成并验证(2026-09-10)**
- [PLAN_P1_SCN_JSON_AND_STANDS.md](PLAN_P1_SCN_JSON_AND_STANDS.md) — 本地
  PSB v3 → SCN JSON 转换器(解锁 216 个剧本)、整身立绘素材与 PBD 元数据归位、
  Windows 最小补缺清单(2 个加密 scn + 64 个 PBD)与降级立绘决策
