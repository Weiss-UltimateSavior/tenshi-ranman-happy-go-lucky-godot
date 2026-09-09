# Title Screen 复刻依据

来源：

- `work\tenshin_hgl\decompiled_pimg\data\image\sys\title_bg.json`
- `work\tenshin_hgl\decompiled_pimg\uipsd\title.json`
- `work\tenshin_hgl\restored\uipsd\ini\title.ini`
- `work\tenshin_hgl\restored\uipsd\func\title.func`

## 坐标体系

- 原始 PIMG 画布：1920x1080。
- Godot 目标画布：1280x720。
- 缩放比例：`2 / 3`。
- 当前实现文件：`scripts/ui/title_screen.gd`。

## 背景图层

按底到顶顺序：

| 图层 | PIMG ID | 原始坐标 |
|---|---:|---|
| base | 2256 | `(-4,-4,1928,1088)` |
| waka | 2546 | `(-28,-188,989,1167)` |
| aoisana | 2679 | `(425,-58,1046,1195)` |
| ruri | 2678 | `(-76,377,860,923)` |
| hime | 2676 | `(105,232,1401,1068)` |
| logo | 2254 | `(1234,48,667,375)` |

## 菜单按钮

按钮命中框来自 `title.json` 的 `##btn` 透明区域：

| 动作 | 文本 | 原始命中框 |
|---|---|---|
| start | はじめから | `(1415,476,397,65)` |
| load | つづきから | `(1415,544,397,65)` |
| continue | 前回のつづきから | `(1415,612,397,65)` |
| flowchart | フローチャート | `(1415,680,397,65)` |
| extra | エクストラモード | `(1415,748,397,65)` |
| system | システム設定 | `(1415,816,397,65)` |
| exit | ゲームの終了 | `(1415,884,397,65)` |

按钮背景三态：

| 状态 | PIMG ID | 原始坐标 |
|---|---:|---|
| off | 2628 | `(1428,481,371,55)` |
| over | 2632 | `(1428,481,371,55)` |
| on | 2636 | `(1428,481,371,55)` |

## 功能逻辑

来自 `title.func`：

- `start`：`title.ks -> *game`
- `load`：`title.ks -> *load`
- `continue`：`custom.ks -> *continue`
- `flowchart`：`custom.ks -> *flowchart`
- `extra`：`custom.ks -> *extra`
- `system`：`title.ks -> *option`
- `exit`：`kag.close()`
- `sysse,title`：标题按钮音效组来自系统 SE 配置。

## 当前状态

- 已完成背景图层和右侧菜单按钮三态的 Godot 初版拼装。
- 尚未做原版截图逐像素校准。
- 尚未接入按钮音效和真实跳转目标。
