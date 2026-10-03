# imd

极简 macOS Markdown 阅读 / 编辑器。单窗口多标签，左侧目录、右侧预览/源码双视图，黑白主题跟随系统。

- 主页: https://github.com/TK700
- 协议: MIT

## 特性

- 单窗口多标签，点击标签切换文件，支持同时打开多个文件
- 左侧自动生成目录（TOC），点击跳转；源码视图跳转后标题置顶
- 右侧双视图：渲染预览（marked.js，完整 GFM：表格/引用/列表/代码块/删除线/任务列表）与可编辑源码
- 黑白主题随系统自动切换
- 全文搜索/替换（⌘F）：计数、上/下个匹配、替换、全部替换、区分大小写；源码与预览双高亮
- 支持 txt：txt 为整窗编辑模式（无目录、无预览切换）；md / txt 混合多标签
- 新建文档可选 Markdown / 纯文本 (txt) 类型
- 界面随系统语言自适应中文 / 英文（zh-Hans / en 本地化）
- 拖拽 `.md` 到窗口即可打开；⌘O 多选打开；最近文件菜单
- 代码围栏内的 `#` 注释不会误入目录
- 无需 App Store，直接安装 `.app`

## 系统要求

- macOS 14.0 及以上（Apple Silicon / Intel）

## 安装

1. 下载 Releases 中的 `imd-1.2.0.dmg`
2. 双击挂载，把 `imd` 拖到 `Applications`
3. 首次打开若被 Gatekeeper 拦截：右键 `imd.app` → 打开；或执行 `xattr -cr /Applications/imd.app`

## 从源码构建

```bash
./build.sh          # 编译并打包 build/imd.app
./make_dmg.sh       # 生成可分发安装包 dist/imd-1.2.0.dmg (含图标/背景/布局)
```

依赖：Xcode Command Line Tools（swiftc / hdiutil / iconutil / sips）与 Python 3（dmgbuild：`pip3 install --user dmgbuild`）。

## 项目结构

```
App.swift        SwiftUI/AppKit 主程序（目录解析、预览 WKWebView、源码编辑、标签栏）
Info.plist       应用清单（版权年份构建时注入）
build.sh         编译脚本
make_icon.swift  生成应用图标
make_bg.swift    生成 DMG 背景（含拖拽箭头）
make_dmg.py      dmgbuild 配置（窗口/图标布局）
make_dmg.sh      打包 DMG 安装程序
Resources/       marked.min.js (GFM 渲染)
```

## 第三方

- [marked](https://github.com/markedjs/marked) (MIT) — Markdown → HTML 渲染

## 许可

MIT © 2026 Thinking
