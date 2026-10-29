# Sketchfab 鱼类模型候选清单

核对日期：2026-10-19。以下是网页授权、下载标记、三角形数与动画数量的核对结果，尚未取得模型压缩包，尚未接入运行时。面数和动画数据来自作者页面，不代表已完成 Unity 导入或平板性能验收。

## 用户指定合集

https://sketchfab.com/oonedesign/collections/beca6c97acae4415bb2f2ef568505a2e-2144a8f5ec8642b4b181e9de13916866

已核对全部 29 项，28 项 downloadType=no，只有 School of Herring 为 free。其余模型不纳入下载计划。

## 可免费下载候选

| 鱼类 | 模型与作者 | 三角形数 | 动画数 | 建议用途 |
| --- | --- | ---: | ---: | --- |
| 鲈鱼 | [Bass - Fish](https://sketchfab.com/3d-models/bass-fish-2d664e9899ad46a787d5549ed8c42241) — Šimon Ustal | 9,856 | 1 | 少量大型鱼，纹理需压缩 |
| 银鱼 | [Silver Fish](https://sketchfab.com/3d-models/silver-fish-6da1c8fa1b574f6c8a531ef829dd7740) — Šimon Ustal | 24,944 | 1 | 少量大型鱼，纹理需压缩 |
| 孔雀鱼 | [Guppy Fish](https://sketchfab.com/3d-models/guppy-fish-21e14e4b961e406385539f79eacdb1dc) — BlueMesh | 1,689 | 1 | 普通游鱼，优先 |
| 霓虹灯鱼 | [Paracheirodon Innesi _ Tetra Neon](https://sketchfab.com/3d-models/paracheirodon-innesi---tetra-neon-2fabf5db754746b7b81ebfa0bbe99161) — BlueMesh | 1,498 | 1 | 普通游鱼，优先 |
| 海鲷 | [Bream Fish ( Dorade Royale)](https://sketchfab.com/3d-models/bream-fish-dorade-royale-a3d0e1a597794a9bb74739a13cfc8b77) — BlueMesh | 3,707 | 1 | 普通游鱼，优先 |
| 斗鱼 | [Betta Splendens](https://sketchfab.com/3d-models/betta-splendens-f4eeb7f50ad24873842bd954ad27d23b) — BlueMesh | 10,668 | 1 | 少量大型鱼，纹理需压缩 |
| 彗星金鱼 | [Comet goldfish](https://sketchfab.com/3d-models/comet-goldfish-5adcbf784df540a0b46dae8950bd3ec6) — somitsu | 10,916 | 1 | 少量大型鱼，纹理需压缩 |
| 鲱鱼群 | [School of Herring](https://sketchfab.com/3d-models/school-of-herring-9805dabc1d3f4cc1a09367fb5afad980) — radiator | 39,392 | 1 | 背景鱼群，不能直接当单条竞争鱼使用 |
| 金枪鱼 | [Tuna Fish](https://sketchfab.com/3d-models/tuna-fish-642c6515d893474a8fc8f129491efcac) — GoldenZtuff | 7,944 | 1 | 少量大型鱼，纹理需压缩 |

所有入选项页面授权为 CC BY 4.0，允许修改和商用，发布时须注明作者、模型名称、原始链接、授权链接和修改情况。https://creativecommons.org/licenses/by/4.0/

已排除 Firefly squid (glowing)：CC BY-NC，限制商用。

## 获取与接入

1. 在 Sketchfab 登录，通过模型页面的 Download 3D Model 下载原始格式，优先 FBX；保留 textures 和 license 文件。
2. 将压缩包放到 UnityFishGame/AssetDownloads/，或提供本地路径。不要把文件名改成其他鱼名。
3. 取得文件后逐项检查模型、动画、贴图、朝向和尺寸；压缩贴图并补充项目署名，再生成 Resources/OpenSea/Fish 预制件、接入随机鱼种。
4. 候选条目只有完成上述导入后才标记 imported=true。当前未构建。
