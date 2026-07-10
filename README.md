# Codex Desktop Model Menu Unfilter

一个非官方、可回滚的 Windows 本地工具，用于解除 Codex Desktop 模型选择器的远程白名单过滤，让本地模型目录中标记为可见的模型正常出现在菜单里。

> Unofficial, reversible Windows utility that shows locally available models in the Codex Desktop model picker.

## 重要说明

这个工具**不会添加模型，也不会赋予模型权限**。

它只负责显示 Codex 本地模型目录中已经存在、且标记为可见的条目。安装后是否能看到 GPT-5.6 Sol、Terra、Luna，取决于使用者安装的 Codex 版本、本地模型目录、账号和模型服务商。

它不会：

- 下载或附带模型目录。
- 修改 `config.toml`、API 地址或 API Key。
- 绕过账号、套餐、服务商或模型权限。
- 保证任何特定模型一定可调用。

本项目不是 OpenAI 官方功能，也不受 OpenAI 支持。

## 功能

- 不修改 Microsoft Store 中的官方签名包。
- 在用户目录创建独立、可回滚的 Codex Desktop 副本。
- 使用等长字节补丁解除本地模型菜单过滤。
- 官方 Codex 更新后，在临时目录完成复制和补丁，成功后才替换旧副本。
- 提供安装、修复、更新和卸载脚本。
- 不收集数据，不发送网络请求，不包含作者的个人配置。

## 系统要求

- Windows 10 或 Windows 11，x64。
- 已从 Microsoft Store 安装官方 Codex Desktop。
- 建议先在 Microsoft Store 中更新到最新版。
- 安装或更新时，系统盘至少有 2.5 GB 空闲空间。
- Windows PowerShell 5.1 和 .NET Framework 4.x（Windows 10/11 通常自带）。

当前版本于 2026-07-10 在 Codex Desktop `26.707.3748.0` 上完成验证。

## 下载

打开 [v1.0.0 Release](https://github.com/I-am-gation/codex-desktop-model-menu-unfilter/releases/tag/v1.0.0)，在 **Assets** 中下载 GitHub 自动生成的 `Source code (zip)`。

完整解压后运行 `Install.cmd`。不要只下载单个脚本，安装器需要保留项目目录结构。

如果 Windows 因网络下载标记而阻止脚本，可以在确认下载来源是本仓库后，右键 ZIP -> `属性` -> `解除锁定`，再重新解压。不要关闭 Windows Defender。

## 安装

1. 完整解压 Release ZIP，不要直接在压缩包预览窗口中运行。
2. 双击 `Install.cmd`。
3. 首次安装会从本机 Store 包复制约 1.8 GB 文件，不需要管理员权限。
4. 复制阶段没有详细进度条，窗口可能看起来暂时没有变化，请不要关闭。
5. 出现安装成功提示后，使用桌面的 `Codex Model Menu` 快捷方式启动。
6. 如果官方 Codex 正在运行，启动器会显示它的真实可执行路径，并询问是否关闭后切换。

原来的 Microsoft Store Codex 图标仍会启动完全未修改的官方版本。

## 更新与修复

启动器会比较 Microsoft Store Codex 的版本。检测到新版本时，它会：

1. 将新版本复制到独立临时目录。
2. 应用补丁并验证关键文件。
3. 仅在全部成功后替换旧副本。
4. 如果补丁不兼容，保留上一份可用副本并显示错误。

手动修复时，先关闭 `Codex Model Menu`，然后在解压目录中双击：

`Repair-or-Update.cmd`

## 卸载

请保留解压目录，或从相同 Release 重新下载后，双击：

`Uninstall.cmd`

卸载器只删除补丁副本、启动器和相关快捷方式，不会删除或修改：

- Microsoft Store 官方 Codex。
- `%USERPROFILE%\.codex`。
- `config.toml`。
- 登录信息、项目、任务或聊天数据。

## 常见问题

### 安装后没有出现 GPT-5.6

补丁不会添加模型。请确认启动的是 `Codex Model Menu`，并确认当前 Codex 本地模型目录或模型服务商确实提供相应模型。

### 菜单有模型，但调用时报错

模型菜单可见不等于拥有调用权限。请检查账号、套餐、自定义模型服务商和对应模型 ID。

### 提示找不到 Microsoft Store Codex

先从 Microsoft Store 安装官方 Codex Desktop，并至少正常启动一次，再重新运行安装器。

### 提示找不到 .NET Framework C# compiler

安装或修复 Windows 自带的 .NET Framework 4.x，然后重新运行 `Install.cmd`。

### 提示 patch target was not found uniquely

当前 Codex 版本修改了前端过滤代码。本工具会保留旧副本。请查看仓库 Issues 或等待兼容更新，不要手动关闭安全检查。

### 提示磁盘空间或 Robocopy 错误

确认系统盘至少有 2.5 GB 空闲空间，并关闭正在运行的补丁版 Codex。仍失败时，请提交：

`%LOCALAPPDATA%\Codex-5.6-Launcher\launcher.log`

提交日志前请自行检查并隐藏不希望公开的信息。

## 安全与隐私

- 安装器和启动器均为可阅读源码。
- 安装过程不会从网络下载可执行文件。
- 不读取或上传 API Key、账号、任务或聊天内容。
- `ExecutionPolicy Bypass` 只应用于当前安装/启动进程，不修改系统全局策略。
- 不修改 `C:\Program Files\WindowsApps` 中的官方 Store 包。
- 本项目不附带官方 Codex 文件、Logo 或图标。

## 工作原理

官方 Store 应用目录是只读签名包。工具从本机安装包复制用户目录副本，在副本的 `app.asar` 中查找一个精确且唯一的模型过滤表达式，并以相同字节长度的表达式替换它，因此不需要重建 ASAR 索引。

更新使用 staging 和 rollback 目录：新版本在 staging 中完成复制和补丁，成功后再切换；失败时不会覆盖当前可用版本。

## 开发

欢迎提交兼容性报告和 Pull Request。请勿提交：

- 官方 Codex 二进制文件或资源。
- API Key、Token、账号或个人配置。
- 绕过模型权限、计费或访问控制的代码。

## 许可证

本仓库中的原创脚本和文档使用 MIT License。OpenAI、Codex 及相关名称属于其各自权利人。本项目与 OpenAI 无隶属、授权或背书关系。
