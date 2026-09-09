# krkrZ / HGL UI 组装机制分析

本文件先于截图校准，用于约束 Godot 复刻方向。

## 1. krkrZ 层级模型

krkrZ 的 UI 基础是 `Layer` 树。

关键源码：

- `F:\Galgame\krkrZ\visual\LayerIntf.h`
- `F:\Galgame\krkrZ\visual\LayerIntf.cpp`
- `F:\Galgame\krkrZ\visual\LayerManager.cpp`

核心属性：

- `parent` / `children`：父子层级。
- `left` / `top`：相对父层坐标。
- `width` / `height`：层尺寸。
- `visible`：可见性；父层不可见时子层也不可见。
- `opacity`：透明度。
- `absoluteOrderIndex`：绝对层级顺序。
- `hitType` / `hitThreshold` / `onHitTest`：命中判断。

源码结论：

- `Join(parent)` 会把 Layer 加入父层 `Children` 数组。
- 绘制时父层负责先绘制自身，再遍历子层叠加。
- 命中测试从最前面的子层倒序查找，先命中最上层。
- 坐标判断先把父坐标减去当前层 `Rect.left/top`，所以子层坐标永远是相对父层。

## 2. HGL UI 不是 C++ 写死

HGL UI 的具体屏幕不在 krkrZ C++ 里写死，而在这些资源/脚本中声明：

- `uipsd/*.pimg`：PSD/PIMG 图层树。
- `uipsd/ini/*.ini`：把 PIMG 路径映射到运行时 UI 对象。
- `uipsd/func/*.func`：定义按钮、跳转、系统 SE、开关、滑条等行为。
- `main/custom.tjs`：定义 `GetUIPSD` / `GetUIFile` 等资源选择逻辑。

例如 `title.ini`：

```text
psd,&GetUIPSD("title")
ui,btn/text/off/はじめから, @_btn:f_start
ui,btn/bg/off,             @_btn:off
ui,##btn/1,                @start/cp:_btn
BDS,start,start,           _btn
```

含义：

1. `psd,&GetUIPSD("title")` 选择 `title.pimg`。
2. `ui,<PIMG路径>,@<对象>:<槽位>` 把 PIMG 图层绑定到 UI 对象的槽位。
3. `@start/cp:_btn` 从 `_btn` 原型复制一个按钮对象，并用当前 `##btn/n` 作为命中区域。
4. `BDS,start,start,_btn` 使用 `_btneff.ini` 里的宏，生成按钮状态映射。

## 3. `_btneff.ini` 按钮宏

`_btneff.ini` 中最重要的宏：

```text
begin,BDS
    DSTEXT,${_3},${_2}
    func,${_1}, overlay,000:f_${_2}|002:v_${_2}|001:n_${_2}|004:d_${_2}
end,BDS
```

对标题按钮 `BDS,start,start,_btn` 来说：

- normal/off 状态使用 `f_start`
- hover/over 状态使用 `v_start`
- pressed/on 状态使用 `n_start`
- disabled 状态使用 `d_start`

其中 `d_start` 通常来自 `DSTEXT`，即复制 `f_start` 并附加灰度/颜色处理。

## 4. 对 Godot 的复刻规则

Godot 侧不应继续为每个屏幕手写坐标，而应模拟 HGL 的 UI 管线：

1. 读取 PIMG 反编译 JSON，恢复图层树和每个叶子图层的原始坐标。
2. 读取 INI，将 `ui,<path>,@<object>:<slot>` 编译为 UI 对象槽位。
3. 处理 `cp:<prototype>`，生成具体按钮/控件。
4. 读取 `_btneff.ini` / 当前 INI 的宏调用，生成状态机。
5. 在 Godot 中用 `Control` 节点模拟 krkrZ `Layer`：
   - `position = left/top * scale`
   - `size = width/height * scale`
   - `visible = visible`
   - `modulate.a = opacity / 255`
   - 子节点顺序模拟 krkrZ Children 顺序。
6. 命中区域优先使用 `##btn` / `#rect` / `area` 图层，而不是图片透明区域。

## 5. 当前标题屏结论

标题屏原始 PIMG 是 1920x1080，Godot 目标是 1280x720，因此缩放比例为 `2/3`。

标题背景来自 `data/image/sys/title_bg.json`：

- `base`
- `waka`
- `aoisana`
- `ruri`
- `hime`
- `logo`

标题菜单来自 `uipsd/title.json + title.ini + _btneff.ini`：

- `start`
- `load`
- `continue`
- `flowchart`
- `extra`
- `system`
- `exit`

下一步应优先用编译出的 `assets/ui/compiled/title_screen.json` 驱动 Godot 标题界面，再截图校准。

## 6. Godot 当前对应实现

- `scripts/ui/hgl_ui_screen.gd`：公共 HGL UI 运行层。
  - `source_size` / `target_size` / `ui_scale` 对应 HGL 的 1920x1080 源坐标到 Godot 1280x720 目标坐标。
  - `add_texture` 使用 `TextureRect` 模拟 krkrZ 中带位图的 Layer。
  - `slot_position` 使用原型 `rect` 计算 `cp:_btn` 复制后的相对偏移。
  - `layer_path` 处理 Godot JSON 数字读成浮点后的 `2628.0.png` 问题，保证图层编号回到原始 PNG 文件名。
- `scripts/ui/title_screen.gd`：标题屏专用装配。
  - 读取 `assets/ui/compiled/title_screen.json`。
  - 先按 `background` 顺序加入 `title_bg` 图层。
  - 再按 `title_ui.buttons` 加入 7 个按钮。
  - 按钮命中框使用 `##btn/n` 的 rect，显示图层使用 `_btn` 原型中的 `bg/text` slot。
  - `off` / `over` / `on` 三态会同步更新贴图、位置和尺寸。

## 11. 设置页运行层继续恢复

2026-06-21 继续推进时发现 `option_6dialog`、`option_7mouse`、`option_8keyboard1/2` 编译为 0 对象，并不是 INI 语法不支持，而是这些 INI 为 UTF-16LE。旧 `read_text()` 在 `utf-16` 前先尝试 `cp932`，`cp932` 会错误“成功”解码 BOM/NUL 字节，导致 `ui,` 行无法匹配。

已修复 `tools/compile_hgl_ui_screens.py`：

- 优先识别 UTF-16 BOM。
- 对高 NUL 比例文本回退为 UTF-16LE。
- 重新编译后恢复：
  - `option_6dialog`: `97 bindings / 72 objects / 21 typed_controls`。
  - `option_7mouse`: `66 bindings / 57 objects`。
  - `option_8keyboard1`: `104 bindings / 93 objects / 31 typed_controls`。
  - `option_8keyboard2`: `14 bindings / 63 objects`，仍有 61 个 unresolved 需要继续追 include/跨 PSD 引用。

Godot 运行层新增：

- `option_5sound`: 解析 `option_5sound1.ini` 后实例化 `chsel` 角色语音列表、`chview` 角色预览、音量数值底图和 `100` 数字图层。
- `option_6dialog`: 支持 `<onoff>` 成对 ON/OFF 控件，使用 `_cfon/_cfoff` 原始槽位，并支持顶部 `btn5` 的全部 ON/OFF 按钮。
- `option_8keyboard1`: 支持 `<key>` 键位按钮骨架，按钮背景使用原始 `btn4/btn_bg` 三态图层；键位字符串目前为 Godot 侧占位，后续需要追原版配置/脚本来源。

已刷新验证图：

- `qa/screenshots/option_5sound_current.png`
- `qa/screenshots/option_6dialog_current.png`
- `qa/screenshots/option_8keyboard1_current.png`

仍待补齐：

- `_btneff.ini` 中的 `disabled` 灰度/染色。
- `title.func` 中的系统 SE、实际跳转行为和退出确认。
- PIMG 图层的不透明度、混合模式和部分动画命令。
- 与原版截图逐像素校准。

## 7. 标题系统 SE 映射

`title.func` 末尾的：

```text
sysse,title
```

会进入 `main/sysse.ini` 的标题段。当前已接入 Godot：

- `title.*.click = @chg2`
- `title.exit.click = @ok1`
- `title.start.click = @ok3`
- `title.load.click = @ok3`
- `title.extra.click = @ok1`
- `title.continue.click = @ok2`
- `*.enter = @sel1`

对应原版音频已复制到 `assets/audio/sysse/`：

- `ok1.ogg` / `ok2.ogg` / `ok3.ogg`
- `chg1.ogg` / `chg2.ogg`
- `sel1.ogg` / `sel2.ogg`
- `cancel.ogg`

Godot 侧实现为 `scripts/autoload/audio_manager.gd`，按原版通道号分配播放器。

## 8. 标题 BGM

标题默认 BGM 来源：

- `main/default.tjs`: `.TitleBGM = .DefaultTitleBGM = "bgm54";`
- `main/custom.ks`: `*title_bgm` 中 `[updatebgm sflag storage=&SystemConfig.TitleBGM start=start]`

当前 Godot 实现：

- 原版 `bgm54.ogg` 已复制到 `assets/audio/bgm/bgm54.ogg`。
- `AudioManager.play_bgm("bgm54")` 在 `title_screen.gd` 的 `_ready` 中调用。
- 目前先使用 Godot OGG 循环；后续要继续解析 `.sli` loop 点以还原原版无缝循环。

当前 Godot 截图使用命令：

```powershell
& 'F:\Program Files\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64_console.exe' --path 'F:\Galgame\天神乱漫 Happy GO Lucky!!_godot' --write-movie 'F:\Galgame\天神乱漫 Happy GO Lucky!!_godot\qa\screenshots\title_frame.png' --fixed-fps 1 --quit-after 4
```

Godot 会输出 `title_frame00000000.png` 等帧文件，当前保留的稳定检查图为 `qa/screenshots/title_current.png`。

## 9. PIMG 覆盖状态

2026-06-21 继续推进时发现旧的 PIMG 反编译日志只覆盖了 16 个文件；这是因为当时 UI 文件名映射还没补齐，后续恢复出的 `file`、`option_*`、`scnchart`、`cgviewlist`、`extra_stand` 等没有重新跑 FreeMote。

已重新执行：

```powershell
python work\tenshin_hgl\decompile_restored_pimg.py
python work\tenshin_hgl\extract_restored_pimg_images.py
```

结果：

- PIMG 反编译：35/35 成功。
- PNG 图层导出：2075 个。
- Godot UI 资产清单中的 exported PNG candidates 更新为 2907。
- `tools/compile_hgl_ui_screens.py` 已纳入 `file`、`file_data`、`scnchart`、`cgviewlist`、`extra_stand`、`option_0simple` 到 `option_9gamepad`。

当前可用预览图：

- `qa/screenshots/title_current.png`
- `qa/screenshots/backlog_current.png`
- `qa/screenshots/file_current.png`
- `qa/screenshots/scnchart_current.png`
- `qa/screenshots/option_simple_current.png`

## 10. `option_0simple` 原型实例化

2026-06-21 已将 `option_0simple` 从纯静态叠图推进到初步运行时装配，并将同一套规则扩展到已有对象数据的 `option_1display`、`option_2game1`、`option_3game2`、`option_4text`、`option_9gamepad`。

原始 INI 中的关键声明：

```text
ui,seekbar/knob/off,          $slider@_slider:normal/slider
ui,seekbar/##bar/2,           #slider@_slider:rect
ui,##btn/0,                   @fullscreen_off/cp:_radbtn
ui,##btn_Volume/0,            @wave_mute/cp:_mute
ui,seekbar/##bar/0,           <slider>wave
DSSLIDER,wave_slider
RTX,fullscreen_on,full
RTX,fullscreen_off,win
CTX,mvaudiosample_chk,text
```

Godot 当前实现位于 `scripts/ui/hgl_static_screen.gd`：

- 仅在 `screen_name` 是 `option_*` 且 compiled JSON 已解析出对象时启用，避免破坏 `file`、`scnchart` 等仍处于静态预览阶段的页面。
- 跳过 `_slider`、`_radbtn`、`_mute`、`_jump`、`radio_btn` 等原型状态素材层，防止 PIMG 设计用样例层直接显示在页面上。
- 按 `cp:_radbtn` 生成全屏/窗口、4:3/16:9、未读跳过等单选按钮。
- 按 `cp:_mute` 生成 master/BGM/SE/voice/movie 静音按钮。
- 按通用 `_btn/_btn2/_btn3/_chk` 生成 `RTX` 单选、`TTX/CTX/RDS` 复选、`BTX/BDS` 普通按钮，并按宏参数选择 `f_*/v_*/n_*` 文字槽。
- 按 `<slider>` 和 `_slider` 原型生成可拖动滑条，初始音量类滑条暂置为 100%，文本速度/自动速度暂置为 50%。
- 按 `CTX` 生成 movie 音量 sample 复选按钮。
- hover / press / toggle / radio 状态会切换原始 `on`、`over`、`off` 图层。

已刷新验证图：

- `qa/screenshots/option_simple_current.png`
- `qa/screenshots/option_1display_current.png`
- `qa/screenshots/option_2game1_current.png`
- `qa/screenshots/option_3game2_current.png`
- `qa/screenshots/option_4text_current.png`
- `qa/screenshots/option_9gamepad_current.png`
- `qa/screenshots/nav_system_current.png`

仍待补齐：

- 从原版 SystemConfig/存档读取真实设置值，而不是使用 Godot 侧临时默认值。
- 补齐 `option.func` 的页面切换、初始化、应用、返回标题等行为。
- 继续恢复 `option_7mouse` 的命令板图标、拖拽分配和手势开关行为。
- 继续恢复 `option_8keyboard2` 的跨文件 include/命令列表引用，并替换 `option_8keyboard1` 的临时键位字符串。
- 解析并接入 `sysse.ini` 中尚未复制的 `btn_switch`、`se_test` 等选项页专用 SE。
