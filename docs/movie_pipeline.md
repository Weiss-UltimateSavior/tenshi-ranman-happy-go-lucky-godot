# 影片管线:WMV → OGV(Theora)

原版影片为 Windows Media Video (`.wmv`),Godot 只内置 **Theora**(`VideoStreamTheora`)
解码,**不支持 WebM**(实测本机 Godot 4.6.3 构建 `ClassDB.class_exists("VideoStreamWebm") == false`),
因此统一转成 `.ogv`(Theora + Vorbis)。

## 1. 编码器要求

Homebrew 的 `ffmpeg` formula **不含 `libtheora`**(实测 `-encoders` 无 theora,
转码报 `Unknown encoder 'libtheora'`)。需安装带完整编解码器的版本:

```sh
brew install ffmpeg-full
# 二进制位于 /opt/homebrew/opt/ffmpeg-full/bin/ffmpeg
```

## 2. 转换命令

```sh
FF=/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg
for f in assets/video/*.wmv; do
  base=$(basename "$f" .wmv)
  "$FF" -v error -y -i "$f" \
      -c:v libtheora -q:v 7 -c:a libvorbis -q:a 5 \
      "assets/video/${base}.ogv"
done
```

- `-q:v 7`:Theora 质量档(0–10),7 在体积与画质间平衡
- 输出与源同名、仅换扩展名——`story_player._resolve_movie_stream()` 按
  storage 名解析,命名一致即可

## 3. 资产清单

| 类别 | 已有 ogv | 待转 wmv |
|---|---|---|
| OP | `ＯＰ.ogv` | `ＯＰ_low.wmv` |
| ED(角色曲) | — | `ed_{aoi,hime,mahiro,ruri,sana,wakaba,yukari}*.wmv`(7×2) |
| 影片场景 | 花火 / 葵フュージョン / 佐奈リフレイン / 卯ノ花姫の消失 / るりコムローイ | 同名 `_low` 变体 |

`_low` 为低分辨率变体(原版 `movieQualitySelect` 宏选择);两者都转,
`_resolve_movie_stream()` 已有回退逻辑。

## 4. 运行时

`story_player._apply_sysmovie()` 已实现:

1. 解析 `storage`/`file` 属性 → `_resolve_movie_stream()` 找 `.ogv`
2. 在独立黑底 `ColorRect` overlay + `VideoStreamPlayer` 播放
3. `movie_can_skip` 为真时点击/按键跳过 → `_finish_movie()` 续播剧情

验证:`tools/qa_story_movie.gd`(无头断言资源可解析)+ 人工确认 OP 播放与跳过。

## 5. 验收记录

- Godot 解码能力实测:`res://assets/video/ＯＰ.ogv` 被识别为
  `VideoStreamTheora`,1920×1080 / 105 秒,可加载
- 转换后的 wmv 派生文件需通过同一断言(见 `qa_story_movie.gd`)
