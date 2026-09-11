# 流程图与立ち絵鑑賞界面修复记录（2026-09-11）

修复用户报告的两屏问题：「FLOWCHART（`scnchart`）与 EXTRA/立ち絵鑑賞（`extra_stand`）
UI 错位和缺少」。

四个独立根因，全部落在**导出/装配管线**而非手写坐标上：

---

## 1. `same_image` 别名图层没有 PNG（"缺少"的主因）

PIMG→PSD→PNG 的 FreeMote 流程中，复用另一图层像素的图层只写一个
`same_image: <源图层 id>` 字段；PNG 导出器只为**源图层**写文件，别名图层在
`assets/ui/exported/<screen>/layers/` 里没有对应 PNG。

`scnchart.ini` / `extra_stand.ini` 把这些别名绑定给了对象槽位，于是运行时
`_add_slot_texture()` 拿不到贴图 —— 按钮只剩文字、没有底板。

实测缺失（6 屏 32 个）：

| 屏 | 缺失图层 |
|---|---|
| `dialog` | 5952 / 5956 / 5961 |
| `extra` | 9145 |
| `extra_stand` | 10227 / 10231 / 10233（`btn_control/bg/off|over|on`） |
| `keyboard_jp109` | 7435 / 7464 |
| `option_5sound` | 10 个（`radio_btn`/`slider` 状态图） |
| `qconf_popup` | 13 个 |

**修复**

- 新增 `tools/export_pimg_shared_images.py`：直接读 `assets/ui/uipsd/*.pimg`
  （纯 PSB v3 容器，用现成的 `tools/psb_to_json.py` 解析），对每个
  `same_image` 别名把源 PNG 复制成别名 PNG。幂等，`--check` 模式可做回归门。
- `tools/compile_hgl_ui_screens.py::copy_png_layers()` 内置同一规则
  （`shared_image_pairs()`），保证 Windows 侧重跑编译不会再丢；
  `stats.png_aliases` 记录补了几个。

## 2. 1440 高度画布被压扁（"错位"的主因）

`scnchart.pimg` 画布是 **1920×1440**，而 `window` / `window_h` 同样是 1440。
编译产物 `source_size` 直接取了 PIMG 高度，运行时 `ui_scale()` 于是算出
`720/1440 = 0.5` 的 y 缩放 —— 整屏纵向压到一半。

原始依据（`assets/main/config.tjs`）：

```text
if (FullHDMode) {
    ;scWidth = 1920;
    ;scHeight = 1080;
    ;exHeight = 1440;   // 扩展画布高度：装饰可以画到屏幕下方
}
```

即屏幕是 **1920×1080**，1440 只是作者多留的 360px 出血区 —— 所以正确的
presentation 缩放两个轴都是 `1280/1920 = 0.667`。

**修复**

- `tools/compile_hgl_ui_screens.py::presentation_size()`：画布宽 1920 且高
  > 1080 时，presentation 高度按 1080 计；真正的小面板（`file_data` 265×259、
  `gesture_help` 450×450、`touchuibar` 337×175）保持自己的框。
- 就地修正 3 个已生成 JSON 的 `source_size`（`scnchart`/`window`/`window_h`），
  原值记在 `stats.source_size_normalized_from`。
- `tools/qa_scnchart_layout.gd` 增加全屏比例一致性断言，防止复发。

## 3. `func,visible,false` 设计样板层被当成实图绘制

`scnchart.func` 里每类图表元素都有一行：

```text
func,section,      visible,false
func,subsection,   visible,false
func,branch,       visible,false
func,select,       visible,false
func,update,       visible,false
...
```

原版 `scnchart_ui.tjs` 按 `scnchartUiItemConsts` **克隆**这些样板；PSD 里留着
可见的样板仅供设计对位，运行时**不该**画出来。之前静态层照单全画，于是右侧
「Update」弹窗和左下的图表节点样板同时显示、互相叠压。

同类规则也适用于 `cgviewlist`（`cursor`）、`quickmenu`（`help_base`/`fbar`）、
`extra_stand`（`chidx_mask`/`chsel_mask`/`curchar_mask`）。

**修复**

- `hgl_static_screen.gd::_func_template_layer_path()`：凡 `func,<名>,visible,false`
  的对象的槽位来源路径，一律不进静态层；结果缓存在 `_func_template_sources`。
- `tools/qa_compose_ui_preview.py::func_template_sources()` 同步该规则，
  离线设计稿合成才与运行时一致。

## 4. 流程图节点区此前是手写坐标

旧实现把节点行画在 `Rect2(640, 185 + i*92, ...)`，与 ini 里 `section`/`subsection`
的 (889,459) 无关，行距也是凭感觉给的 92。

**修复（全部改为数据驱动）**

- 行矩形 = `section`/`subsection` 的 `rect` 槽位，行距 = `SCNCHART_ITEM_STEP`
  (100) × `ui_scale().y` —— 出自 `default.tjs` `.scnchartUiItemConsts`
  的 `section/subsection step:(100)`。
- 行栈在 `#scroll` 视口 (576,0,896,982) 内垂直居中，并 `clip_contents`，
  与原版滚动视口一致；超出视口的行不生成点击区。
- 行间连接线用 `scnchartUiLineConsts` 的 `normal` 色 (`0xFFa987c8`)。
- 路线页签改用 `_route` 原型槽位 (`n_ipage*`/`f_ipage*`/`n_tpage*`/`f_tpage*` +
  `on`/`off`)，落在 `page0..page7` 各自的 rect 上；此前只有一个
  `chara_btn/bg/*` + 手写文字。
- 滑块行程改用 `slider:rect`（原版 `scrollbar/#arrow`）；此前是
  `lerp(160, 760)` 的臆测值。
- 预览文本与标题改用 `playback:text:rect` / `separator:text:rect`。
- 分支标记改画在分支行右侧（`branch` 在 `scnchart_ui.tjs` 是 `spread` 独立项，
  PSD 里的单个样板只是设计摆位，重叠在行首三分之一处）。
- 删掉运行时重复添加的 `page*` / `top|pageup|pagedown|end` 点击区
  （`_build_static_action_widgets()` 已按 `STATIC_ACTION_OBJECTS` 加过一层，
  两层会导致点击双触发音效）。
- 移除我一度加上的合成 minimap 色条：`drawMiniMap()` 在 `scnchart_ui.tjs` 里
  **从未被调用**（`uichart.tjs` 字节码里也没有 `minimap` 字样），属于继承自
  Yuzusoft 公共库的死代码；右侧面板底图 `bg/minimap` 本身就是可见的静态层。

---

## 验证

- 新增 `tools/qa_scnchart_layout.gd`：全屏比例一致性、行位置/行距与
  `section`/`subsection` 模板对账、行与点击区不越出 `#scroll`、8 个页签各就
  其位、可见行都有点击区。
- 新增 `tools/qa_compose_ui_preview.py`：把编译产物里的静态层离线合成为
  1280×720 设计稿，用于与运行时截图逐像素对账（`--all` 可含运行时接管层）。
- 两屏截图：`qa/screenshots/scnchart_current*.png`、
  `qa/screenshots/extra_stand_current*.png`；
  设计稿 `qa/screenshots/scnchart_expected.png`、`extra_stand_expected.png`。
- 全量 `tools/qa_*.gd` 回归 + 双轨迹基线（opening 32 / branch 201）。
- `tools/qa_story_typewriter.gd` 的存档续显断言原本在无头环境下取到
  **亚字符**进度（`reveal_progress ≈ 0.01`，`int()` 后为 0），断言随机失败；
  改为等到 ≥2 个字符再快照，并加「续显不超过存档进度」断言。
