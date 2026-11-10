# FloatClaude

一个常驻置顶、毛玻璃风格的 Claude 浮窗（macOS）。按 **⌥ Space** 随时呼出，看视频、刷网页的时候不用切换应用就能问 Claude。

[English](README.md)

> **非官方项目**：FloatClaude 是个人做的小工具，与 Anthropic 无关，也没有得到 Anthropic 的认可或支持。它只是在一个浮动窗口里加载 [claude.ai](https://claude.ai) 网页，你用自己的 Claude 账号登录，应用本身不收集、不上传任何数据。

## 功能

- **⌥ Space 呼出 / 收起**，**Esc** 也能收起
- **始终置顶**：浮在所有窗口上面，包括全屏的 Netflix / YouTube，而且不会把全屏视频切出来
- **原生毛玻璃背景**：跟随 Claude 的深色 / 浅色主题，可选「墨绿」色调
- **外观独立切换**：跟随系统 / 浅色 / 深色，不影响你 Claude 账号本身的设置
- 对话内容在标题栏下方和输入框上方柔和地淡入淡出，没有硬线
- 自动隐藏「已用 xx% 周限额」的提醒横幅（真正用完时的提示不受影响）
- 不占 Dock，只在菜单栏有一个 ✦ 图标；菜单跟随系统语言（中文 / English）

实现细节（怎么做到不抢焦点地浮在全屏视频上、怎么把网页变成毛玻璃、踩过哪些坑）写在[英文 README 的 How it works](README.md#how-it-works) 里。

## 系统要求

- macOS 13 或更新
- **Apple 芯片的 Mac（M1 及以后）**，Intel Mac 暂不支持

## 安装

1. 到 [Releases](../../releases) 下载最新的 `FloatClaude.zip`，解压得到 `FloatClaude.app`，拖进「应用程序」文件夹
2. **第一次打开**：这个应用没有经过 Apple 公证，直接双击会提示「无法验证开发者」。二选一：
   - 在 Finder 里**右键点 FloatClaude → 打开**，弹窗里再点「打开」
   - 或者先双击一次，然后去 **系统设置 → 隐私与安全性**，往下找到 FloatClaude，点「仍要打开」

   如果提示「已损坏，无法打开」，在终端运行一次下面这行再打开：
   ```bash
   xattr -dr com.apple.quarantine /Applications/FloatClaude.app
   ```
3. 在浮窗里登录你的 Claude 账号，之后会一直记住

## 从源码编译

需要先装 Xcode 命令行工具（`xcode-select --install`）：

```bash
git clone <这个仓库的地址>
cd FloatClaude
./build.sh        # 编译并安装到 ~/Applications/FloatClaude.app
```

## 小提示

- **快捷键冲突**：如果按 ⌥ Space 弹出来的是 Claude 桌面版的 Quick Entry 或 ChatGPT，把它们的快捷键改掉或关掉就行。想给 FloatClaude 换快捷键，改 `Sources/Config.swift` 再运行 `./build.sh`
- **开机自启动**：系统设置 → 通用 → 登录项与扩展 → 点 ＋ 添加 FloatClaude
- **内存**：主要是 claude.ai 网页本身占用，大约 600–700 MB，和在浏览器里开一个 claude.ai 标签页差不多；空闲时几乎不耗电
