# Brotato · 以撒角色与道具

为 Brotato 制作的非官方《以撒的结合》主题模组。当前版本 **0.41.0**，包含 **8 个角色、51 件道具、34 个武器品质条目和 7 个自定义武器套装**，提供简体中文、繁体中文和英文文本。

0.41 开放死神之触（紫/橙）和命运之矛（蓝/紫/橙）。它们可概率造成 2 秒恐惧：敌人停止移动、受到的最终伤害增加 30%，并显示紫色效果。死神之触发射旋转镰刀；新增战争套装，愤怒套装改为伤害与暴击率。

这是模组源码仓库，不包含 Brotato 游戏本体、反编译游戏项目、DLC、前置模组、玩家存档或个人配置。运行需要自行取得正版游戏及前置；本目录不能作为完整 Godot 游戏项目直接启动。

## 运行环境

本版本适配 Brotato **1.1.15.4**、Mod Loader **6.3.0**，使用以下两个前置（当前适配版本均为 **1.2.0**）：

- [NewContentLoader](https://steamcommunity.com/sharedfiles/filedetails/?id=3657905142)（`Yoko-NewContentLoader`）
- [MoreStatsContainer](https://steamcommunity.com/sharedfiles/filedetails/?id=3771724268)（`Yoko-MoreStatsContainer`）

需要诅咒机制时，按原版要求拥有并启用 Abyssal Terrors DLC。普通内容不附带 DLC。

## 安装

1. 先订阅并下载上面两个前置。
2. 打开[本仓库 Releases](https://github.com/fanfanfan91666/brotato-isaac/releases)，在 **v0.41.0** 下载 `Local-Isaac-0.41.0.zip`。GitHub 的 **Code → Download ZIP** 和 Release 的 **Source code** 是源码包，不能直接作为模组安装。开发者可按 [BUILD.md](BUILD.md) 自行构建安装 ZIP。
3. 等两个前置下载完毕，退出游戏。把 `Local-Isaac-0.41.0.zip` **保持压缩状态**，放入**该游戏所在 Steam 库**的 `steamapps/workshop/content/1942280/3657905142/`。保留目录内 Steam 原有文件，不覆盖或另放重复的前置。NewContentLoader 必须保持订阅且已实际下载；单独建立数字目录不会使 Steam 挂载它。
4. 此前手动安装过旧版时，先移出旧的 Local-Isaac ZIP，避免重复加载。从 Steam 启动游戏，在 MOD 菜单确认 **Local-Isaac、Yoko-NewContentLoader、Yoko-MoreStatsContainer** 三项启用，并按提示重启。

寻找正确位置：在 Steam 库中右键 **Brotato → 管理 → 浏览本地文件**，从打开的游戏文件夹返回到 `steamapps`，再进入 `workshop/content/1942280/3657905142/`。使用游戏所在的同一个 Steam 库，不要照抄别人的盘符。例如：

```text
D 盘 Steam 库：D:/SteamLibrary/steamapps/workshop/content/1942280/3657905142/
C 盘常见位置：C:/Program Files (x86)/Steam/steamapps/workshop/content/1942280/3657905142/
```

不要解压 `Local-Isaac-0.41.0.zip`，不要把它放入游戏目录的 `mods` 文件夹；本包只含以撒模组，不附带两个前置。

卸载时关闭游戏并移出 Local-Isaac ZIP。更新前备份需要保留的旧局，再替换同名模组的旧包。

## 源码结构

```text
mods-unpacked/Local-Isaac/
  manifest.json             版本与依赖
  mod_main.gd               Mod Loader 扩展与 helper 注册
  NewContentData.tres        NewContentLoader 内容注册
  extensions/               原生类扩展入口
  content/                  角色、道具、武器、套装、PNG 与导入映射
  effects/                  描述和数据适配
  rooms/                    特殊房间商店
  world/                    弹体、宠物、状态与特效
  translations/             简中、繁中、英文
.import/                    仅本模组 PNG 对应的 Godot 3 .stex 纹理
tools/build.ps1             仅构建本模组，不启动游戏
```

后续内容更新从 `manifest.json` 读取版本。修改 PNG 时同时更新相邻的 `.png.import` 和对应的 `.import/*.stex`；本仓库保留原 PNG。代码通过 Mod Loader 与原生 API 协作，原生资源路径由玩家自己的游戏提供，不应把游戏资源复制进仓库。

0.41 已进行相关代码、数据和包完整性检查；游戏内试玩与表现确认由玩家完成。构建脚本不启动游戏，也不修改存档、配置或游戏安装目录。

## 许可与素材

本仓库作者享有权利的原创代码按 [MIT 许可](LICENSE) 发布。**图片、导入纹理以及第三方原有代码和资源不在该 MIT 授权范围内。** 素材来源与权利范围见 [ASSETS.md](ASSETS.md)，原生 API、代码改写与第三方说明见 [THIRD_PARTY.md](THIRD_PARTY.md)。这是爱好者制作的非官方模组，与 Brotato 或《以撒的结合》的权利人没有官方关联。
