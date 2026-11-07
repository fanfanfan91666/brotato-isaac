# 第三方与原生资源说明

## 游戏与前置

本模组通过游戏内置 Mod Loader 调用 Brotato 原生类与资源。0.42.0 起通过新版 ItemSetData 接口注册内容，由以撒自身提供所需属性分页，没有第三方 Mod 必要前置。旧版使用过 NewContentLoader 与 MoreStatsContainer；它们仍由玩家自行从工坊取得，不随本项目分发。游戏、DLC 和前置的代码与资源属于各自权利人；本仓库不包含它们的完整源码、安装包或资源包，也不对它们另授 MIT 许可。

`extends "res://..."`、`instance=ExtResource(...)`、脚本/场景/音效路径以及原生资源类型字段均为运行依赖。玩家和开发者需要在自己的合法游戏环境中提供这些依赖。资源模板的默认字段与 API 兼容，不代表本项目拥有原生实现。

## 已确认的原生实现改写

以下部分使用了 Brotato 原生实现作为改写基础，**其第三方原有部分不在本仓库 MIT 授权范围内**。本项目对自己新增的逻辑所授许可不改变这些原有权利。

| 本仓库位置 | 原生来源与改动范围 |
| --- | --- |
| `mods-unpacked/Local-Isaac/world/petrify_031.shader` | 基于原生 `resources/shaders/outline.gdshader` 的描边实现改写，用于本模组石化视觉；保留了邻域透明度采样、描边函数及部分多层描边/灰度流程。 |
| `mods-unpacked/Local-Isaac/extensions/weapon_service.gd` 的 `_set_common_ranged_stats` | 计算块适配原生 `singletons/weapon_service.gd` 的同名方法；保留贯通、反弹、场景与弹速计算，加入本模组宠物弹数规则与新版类型处理。 |
| `mods-unpacked/Local-Isaac/extensions/melee_shooting.gd` 的 `shoot` | 启动骨架适配原生 `weapons/shooting_behaviors/melee_weapon_shooting_behavior.gd`，改为使用本模组运动参数。 |

新版内容清单沿用原生 ItemSetData 类型与字段；本地加载脚本继承游戏自己的 ModLoader，只增加本地 ZIP 搜索入口，工坊加载仍委托原生实现。相关原生 API、数据结构和运行代码的权利不因本模组的新增逻辑而改变。本仓库没有打包 NewContentLoader、MoreStatsContainer、Brotils 或 BFX 的完整实现。

其余脚本主要是继承原生 API 的扩展、状态管理及本模组逻辑。公开整理时未发现整份大型原生 GDScript 文件或可确认的其他模组长段代码复制；这是一项源码整理结果，并非对所有上游权利的穷尽保证。

## 美术

图片与导入纹理的单独说明见 [ASSETS.md](ASSETS.md)。本模组为非官方爱好者作品，不代表 Brotato、《以撒的结合》或前置模组作者。
