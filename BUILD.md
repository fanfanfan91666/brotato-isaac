# 构建与维护

## 构建安装 ZIP

在本仓库根目录使用 Windows PowerShell 5.1 或 PowerShell 7：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build.ps1
```

也可以使用 `pwsh -File ./tools/build.ps1`。输出为 `dist/Local-Isaac-<manifest 版本>.zip`，旁边生成 SHA-256 文件。同名包已存在时默认拒绝覆盖；确认要重建后添加 `-Force`。

脚本只读取本仓库中的模组文件、PNG 导入映射及它们明确引用的 `.import/*.stex`；不下载游戏、前置或其他内容，不启动 Godot/游戏，不查找或修改 Steam 目录。ZIP 保持 Mod Loader 使用的 `mods-unpacked/Local-Isaac/` 和 `.import/` 路径。包内 README 链接到本仓库许可和素材说明。

构建会校验 manifest、允许的文件类型、导入纹理是否齐全，以及模组内部 `res://mods-unpacked/Local-Isaac/` 引用是否存在；它不是完整的 GDScript 编译或游戏兼容性测试。

当前构建要求 manifest 为适配 Brotato 1.2.0.1 的独立版，第三方 Mod 依赖为空。Release 仅提供以撒 ZIP 和校验文件。Windows 本地安装使用仓库内的 `tools/install.ps1` 与 `tools/isaac-local-loader.gd`，获取与安装步骤见 README；它们不属于第三方前置。

## 内容更新

1. 修改 `mods-unpacked/Local-Isaac/` 内的代码或数据，必要时更新 `NewContentData.tres` 和翻译。
2. 在自己的合法 Brotato/Mod Loader 开发环境中检查涉及的原生 API。本仓库不提供原生项目源码或前置源码。
3. 新增或修改 PNG 时，用 Godot **3.x** 的兼容导入环境生成 `.png.import` 与 `.stex`，按本仓库相同的 `res://mods-unpacked/Local-Isaac/` 路径导入；保留用户提供的原 PNG。不要只改原图却继续发布旧导入纹理。
4. 仅做涉及改动的必要语法、数据和最小逻辑检查；游戏内试玩由维护者或玩家在自己的游戏中完成。
5. 更新 `manifest.json` 的 `version_number`、`CHANGELOG.md` 与 README 中的版本摘要，运行构建并核对 SHA-256。

不要提交 Brotato 原生源码、游戏安装目录、其他模组源码/ZIP、存档、日志、个人配置、账号凭据或开发环境的缓存。`.import` 是特例：本仓库明确保留本模组运行必需且由映射引用的 `.stex`。
