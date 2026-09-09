# tlg2png — 跨平台 TLG 转换器

Kirikiri TLG 图片(TLG5 / TLG6 / TLG0.0 SDS)→ PNG 的转换工具。解码逻辑按 krkrZ
官方 `visual/LoadTLG.cpp`、`visual/tvpgl.c` 逐行移植,输出与 Windows 环境的
`Tlg2Png.exe` 契约一致,供 `scripts/story/story_player.gd` 运行时立绘/舞台特效
的 TLG 资产转换使用。

## 使用

```sh
# 单文件
tlg2png <file.tlg> <output-dir>

# 目录批量(递归保持目录结构,所有 *.tlg -> *.png)
tlg2png <source-dir> <output-dir>
```

输出写到 `<output-dir>/<相对路径>.png`。失败或无法识别的文件会跳过并在 stderr
报告(不影响批量中的其余文件)。

## 各平台构建

### macOS / Linux

```sh
cc -O2 -o tlg2png tlg2png.c
```

放在 `tools/tlg2png/tlg2png`(即仓库内默认路径),`story_player.gd` 会自动发现。
二进制不入库(gitignore),每个开发者本地构建一次即可。

### Windows

沿用既有环境:`AppConfig.CODEX_WORK_ROOT + "/tlg2png/Tlg2Png.exe"`。
`story_player.gd` 在 Windows 上优先使用该 exe,本工具不需要参与;
如需在 Windows 重建,可用任意 C 编译器编译本文件,行为一致。

## 解析选择规则(`_tlg2png_path()`)

1. 非 Windows 且存在 `res://tools/tlg2png/tlg2png` → 用本地构建产物;
2. 存在 Windows 的 `Tlg2Png.exe` → 用它(保持旧环境完全不变);
3. 都没有 → 立绘 TLG 部件静默降级为缺层,游戏继续运行。

## 已知限制

- `TJS/4s0` 魔数的文件(krkr2 时代的 TJS 结构数据,约 64 个 `.tlg`、若干
  `.pbd`)不是图像,本工具跳过。立绘合成所需的 `pbd_json` 图层元数据在
  Windows 环境来自游戏运行时 dump(`tools/dump_one_pbd.tjs`),跨平台复刻
  属于立绘管线的后续工作。
- TLG6 的 Golomb/滤波解码为标量实现(无 SSE),大图转换速度足够离线使用。

## 验证记录

- TLG5:佐奈立绘部件(含半透明眼睛贴片)解码正确;
- TLG6 / SDS:`video/火災` 全部 110 帧经 PIL/`sips` 双重校验且渲染正确;
- 批量:`fgimage/佐奈` 87/91 转换成功,4 个 `TJS/4s0` 文件按设计跳过。
