# fgimage 资产错配与归位

记录 2026-09-10 发现的 `.pbd` 资产错配、归位规则与后续路径。
完整逐文件清单见 [fgimage_relocation_manifest.json](fgimage_relocation_manifest.json)。

## 1. 现象

`assets/fgimage/<角色>/<prefix>_<变体>.pbd` 在 Godot 资产树中有两种互斥内容:

| 内容 | 数量 | 体积 | 实际用途 |
|---|---:|---:|---|
| `TJS/4s0` 二进制 | 4(仅まひろ) | 2.6–3.8 KB | **立绘图层元数据**(图层名→layer_id+坐标) |
| `TLG5.0` 图像 | 60 | 45 MB | **整身合成图**(身体+脸+服装已合成的大图) |

原版归档 `extracted_final/fgimage/*/*.pbd` 中**全部 64 个都是 TJS/4s0 元数据**
(1.9–5.0 KB)。

## 2. 成因

提取/恢复管线在重建 `fgimage` 时,把整身合成图(TLG)写到了元数据应有的
`.pbd` 名位;仅まひろ 4 个保留了原始元数据。这不会破坏原版归档——元数据在
原版侧完好。

## 3. 影响

- **立绘渲染不可用**:`story_player._stand_pbd_layers()` 需要"图层名→layer_id+
  坐标",拿到 TLG 大图无法解析,导致 `.stand` 角色缺层
- 整身合成图本身是**有价值的素材**(可用于降级立绘),不能被丢弃

## 4. 归位规则(已完成)

| 原位置 | 新位置 | 内容 |
|---|---|---|
| `assets/fgimage/<角色>/*.pbd`(60 个 TLG) | `assets/fgimage/<角色>/<name>_body.png` | 整身合成图(经 `tools/tlg2png` 转换) |
| 原版归档 `extracted_final/fgimage/<角色>/*.pbd` | `assets/fgimage/pbd_meta/<角色>/*.pbd` | 原始 TJS/4s0 元数据(未转换,保留字节) |

结果:元数据 64 个(197 KB)、整身图 60 张(323 MB),与清单一一对应。

### 为什么保留 `.pbd` 原始字节而不直接转 JSON

`TJS/4s0` 不是 PSB,也不是简单 XOR/zlib(已实测:非 PSB 签名、非 zlib 流、
固定密钥 XOR 不成立)。它是柚子社自有序列化容器,解码需要引擎自身的
`Scripts.loadDataPack()`(Windows 端 `krkr_pbd2json.exe` 已验证可 64/64 解析)。
因此本地只做**字节归位**,解码见
[plan/PLAN_P1_SCN_JSON_AND_STANDS.md §3](plan/PLAN_P1_SCN_JSON_AND_STANDS.md)。

### 消费方约定

`story_player._stand_pbd_layers()` 的候选路径依次为:

1. `user://pbd_json/<角色>/<prefix>_<变体>.json`
2. `user://pbd_json/<prefix>_<变体>.json`
3. `assets/fgimage/<角色>/<prefix>_<变体>.pbd.json`
4. `assets/fgimage/<角色>/<prefix>_<变体>.json`

元数据 JSON 一旦产出(Windows dump 或本地解码器),放到第 3 条路径即可被
立绘链路直接消费——**不需要改代码**。

## 5. 后续路径与最终结果

| 路线 | 前置 | 产出 | 保真度 | 状态 |
|---|---|---|---|---|
| A. Windows `krkr_pbd2json.exe` | 一次 Windows 会话 | 64 个 JSON → 路径 3 | 100% | 不再需要 |
| **B. 本地解码器** | 逆向 TJS/4s0 | 同上 | 100% | **已完成(2026-09-10)** |
| C. 降级立绘 | 无 | `<name>_body.png` + `.stand` 偏移 | 部分 | 未采用 |

**路线 B 已落地**:`tools/pbd_to_json.py` 解出全部 68 个元数据(64+4)为
`assets/fgimage/<角色>/<prefix>_<变体>.pbd.json`,即上方"消费方约定"的
第 3 条候选路径——立绘链路无需改代码即可工作。算法与验证过程见
[plan/PLAN_P1_SCN_JSON_AND_STANDS.md §6](plan/PLAN_P1_SCN_JSON_AND_STANDS.md)。
回归:`tools/qa_stand_render.gd`(立绘合成断言)。

---

## 6. 更严重的错配:TLG 文件名编号错乱(2026-09-10 修复)

### 现象

立绘拼接后**颜色异常**(佐奈呈青蓝色)且**部件散架**(五官/服装错位)。

### 根因(两项,均已修复)

**A. `tlg2png` 的 R/B 通道互换**

TLG 解码产出的是 krkrz 规范 ARGB dword,在 little-endian 上字节序为
`B,G,R,A`,而 PNG 要求 `RGBA`。转换器直接按 `RGBA` 写出,导致所有立绘
红蓝互换(金发→青发、肤色→青蓝)。

修复:`tools/tlg2png/tlg2png.c` 的 `png_write` 按像素交换第 0/2 字节。
验证:与 Windows 端产出的参照图 `qa/stand_probe/佐奈_ポーズa_1_26.png`
**逐像素 100% 一致**(此前 same=62%/swap=37%)。

**B. `assets/fgimage/*/` 的 TLG 文件名编号系统性错乱**

全量对账(以原版归档 `extracted_final/fgimage` 为权威):
**15 个角色、1344 个 TLG 的文件名与内容不符**,仅まひろ 74/78 正确。

例:本地 `佐奈_ポーズa_1_3.tlg`(184×142)的内容实际是原版
`佐奈_ポーズa_1_26.tlg`;而 PBD 层表的 `layer_id=26` 指向"通常１"表情
(184×142)。文件名错位使 `_stand_layer_pngs()` 按 `layer_id` 取到完全
无关的图层 —— 这正是"立绘被拆散"的直接原因。

修复:从原版归档重新提取 1426 个 TLG 覆盖本地(按名字一一对应),
逐角色哈希验证同名同内容;原文件备份于 `/tmp/fgimage_backup_before_fix`。

### 对账方法(可复现)

```python
# 同名文件的 sha256 比较:同名同内容 / 同名不同内容(错位) / 本地独有
for role in assets/fgimage/*/:
    for tlg in role/*.tlg:
        compare sha256(assets/.../x.tlg) with sha256(original/.../x.tlg)
```

结果:(修复前)同名同内容 82 / 错位 1344 / 本地独有 0。

### 教训

资源恢复管线的"文件名重建"步骤曾按**文件系统枚举顺序**写名,而非按
XP3/alst 记录的真实名。**PBD 的 `layer_id` 是编号的权威定义**,任何
fgimage 文件名重建都必须以其为准,并做一次全量哈希对账。

### 顺带修复:陈旧 `.complete` 标记

`user://godot_cache/fgimage/<角色>/.complete` 在转换器尚不可用时也会写入,
导致后续跳过重转、留下空缓存。现在 `_stand_cache_is_complete()` 要求
**缓存 PNG 数 ≥ 源 TLG 数**才认为完成,否则强制重转。
