# Brotato · 以撒角色与道具

为 Brotato 制作的非官方《以撒的结合》主题模组。当前版本 **0.43.0**，适配 Steam 版 **Brotato 1.2.0.1**（史前惧兽更新），包含 **8 个角色、67 件道具、34 个武器品质条目和 8 个自定义武器套装**，提供简体中文、繁体中文和英文文本。

包含天使房、恶魔房、宠物、炸弹与石头机制。0.43 新增山羊头、二元性、作孽双子、嗜血腥风，并调整好朋友一辈子与亚巴顿宝宝。完整变化见 [CHANGELOG.md](CHANGELOG.md)。

本仓库与 Release 不包含游戏本体、DLC、第三方前置安装包、玩家存档或个人配置；源码不能作为完整 Godot 游戏项目直接启动。

## 运行环境与前置

**0.42.0 起已直接使用新版游戏的内容注册接口，并由以撒自身提供所需属性分页；当前版本没有第三方 Mod 必要前置。** 没有把 NewContentLoader、MoreStatsContainer、Brotils 或 BFX 的完整代码打包进以撒。

0.41.x 及更早版本使用下面两个前置。需要旧版时，请自行去 Steam 创意工坊订阅下载；本项目不会在 Release 附带它们，也不要把旧版前置作为当前 1.2.0.1 版的安装步骤：

- [NewContentLoader](https://steamcommunity.com/sharedfiles/filedetails/?id=3657905142)（`Yoko-NewContentLoader`）
- [MoreStatsContainer](https://steamcommunity.com/sharedfiles/filedetails/?id=3771724268)（`Yoko-MoreStatsContainer`）

以后若版本确实需要第三方前置，会在此列出所需版本和工坊链接，仍由玩家自行订阅。请按各自说明选择与游戏版本兼容的其他 Mod。

DLC 内容与诅咒机制由玩家自己的正版游戏和相应 DLC 提供，本模组不解锁付费 DLC。

## 安装 0.43.0（Windows / Steam）

Steam 版默认扫描工坊订阅目录。本项目提供一个小型本地加载脚本，使以撒 ZIP 可以放在游戏的 `mods` 文件夹，同时保留工坊加载。

1. 从 [v0.43.0 Release](https://github.com/fanfanfan91666/brotato-isaac/releases/tag/v0.43.0) 下载 `Local-Isaac-0.43.0.zip` 和 `Local-Isaac-0.43.0.zip.sha256`。**保持 ZIP 压缩状态**；Release 的 **Source code** 与 **Code → Download ZIP** 是源码，不能直接安装。
2. 下载本模组自己的 [install.ps1](https://raw.githubusercontent.com/fanfanfan91666/brotato-isaac/v0.43.0/tools/install.ps1) 和 [isaac-local-loader.gd](https://raw.githubusercontent.com/fanfanfan91666/brotato-isaac/v0.43.0/tools/isaac-local-loader.gd)。将这四个文件放在同一个文件夹，脚本保存为原文件名。
3. 在 Steam 库中右键 **Brotato → 管理 → 浏览本地文件**，确认含有 `Brotato.exe` 的游戏目录，然后退出游戏。
4. 在下载文件夹打开 PowerShell，运行下方命令，把 `-GameRoot` 后面的路径改为自己的游戏目录：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -GameRoot "D:\SteamLibrary\steamapps\common\Brotato"
```

5. 从 Steam 启动游戏，在 MOD 菜单确认 **Local-Isaac** 已启用，按游戏提示重启。

安装后的 ZIP 位置为：

```text
<Brotato 游戏目录>/mods/Local-Isaac-0.43.0.zip
```

安装器核对 ZIP 校验值，将旧的本地以撒 ZIP 和原配置备份到下载目录中的 `backups/`，配置本地加载脚本，并保留已有工坊条目和当前 MOD 配置。若已有其他自定义 ModLoader 覆盖，安装器会停止并提示，不覆盖它。

手动安装过旧版时，请先移出其他位置的旧 Local-Isaac ZIP，避免重复加载。**0.43.0 不再使用旧的 `workshop/content/1942280/3657905142/` 前置载体安装方式。** 跨游戏大版本升级前，建议另行备份需要保留的旧局。

仅想检查文件和目标目录、不执行安装，可在命令末尾加 `-CheckOnly`。构建安装 ZIP 见 [BUILD.md](BUILD.md)。

## 更新与卸载

更新时下载同一版本的 ZIP、校验文件和两个脚本，再按上述步骤安装。安装不会启动游戏。

卸载以撒时退出游戏，移出游戏 `mods` 目录内的 Local-Isaac ZIP，并在 MOD 菜单停用对应项目。若还要移除本地加载脚本，仅删除 `override.cfg` 中指向 `isaac-local-loader.gd` 的 ModLoader 设置，再移出该脚本；保留配置中的其他设置和其他 Mod 文件。

## 源码结构

```text
mods-unpacked/Local-Isaac/
  manifest.json             版本与依赖
  mod_main.gd               Mod Loader 扩展与 helper 注册
  NewContentData.tres        本模组原生 ItemSetData 内容清单
  extensions/               原生类扩展入口
  content/                  角色、道具、武器、套装、PNG 与导入映射
  effects/                  描述和数据适配
  rooms/                    特殊房间商店
  world/                    弹体、宠物、状态与特效
  translations/             简中、繁中、英文
.import/                    仅本模组 PNG 对应的运行纹理
tools/build.ps1             仅构建以撒模组 ZIP
tools/install.ps1           本地安装与配置备份
tools/isaac-local-loader.gd  本模组的本地 ZIP 加载扩展
```

仅做相关代码、数据和包完整性检查；游戏内试玩与表现确认由玩家完成。反馈请使用 [Issues](https://github.com/fanfanfan91666/brotato-isaac/issues)，注明游戏版本、地图、角色、装备与报错线索。

## 许可与素材

本仓库作者享有权利的原创代码按 [MIT 许可](LICENSE) 发布。**图片、导入纹理以及第三方原有代码和资源不在该 MIT 授权范围内。** 来源与权利范围见 [ASSETS.md](ASSETS.md) 和 [THIRD_PARTY.md](THIRD_PARTY.md)。这是非官方爱好者项目，与 Brotato 或《以撒的结合》的权利人没有官方关联。
