# Web 部署指南

本项目支持导出为 HTML5/Web 版本，可在浏览器中运行。

## 一次性准备：安装 Web 导出模板

Godot Web 导出需要导出模板（约 1.2GB，全局只需装一次）。

### 方式 A：编辑器内安装（推荐）
1. 用 Godot 4.6.1 打开本项目
2. 顶部菜单 `Editor → Manage Export Templates`
3. 点击 `Download from mirror`（或若已下载 `.tpz` 文件，点 `Install from file`）
   - 下载地址：https://github.com/godotengine/godot/releases/tag/4.6.1-stable
   - 文件：`Godot_v4.6.1-stable_export_templates.tpz`

### 方式 B：命令行安装
```bash
# 下载模板（1.2GB，可能需要梯子或镜像）
curl -L -o /tmp/templates.tpz \
  "https://github.com/godotengine/godot/releases/download/4.6.1-stable/Godot_v4.6.1-stable_export_templates.tpz"

# 解压到 Godot 模板目录
mkdir -p ~/Library/Application\ Support/Godot/export_templates/4.6.1.stable
cd ~/Library/Application\ Support/Godot/export_templates/4.6.1.stable
unzip /tmp/templates.tpz
# 会解压出 templates/ 目录，把里面的文件移到当前目录
mv templates/* .
rmdir templates
```

## 导出 Web 版本

模板安装完成后，执行：

```bash
cd /Users/zbf/ws/godot-vampire
godot --headless --export-release "Web (HTML)"
```

生成的文件在 `export/web/` 目录：
- `index.html` — 入口页面
- `index.js` — 游戏主脚本
- `index.wasm` — WebAssembly 引擎
- `index.pck` — 游戏资源包
- `.png` 图标等

## 本地预览

Web 导出需要通过 HTTP 服务器访问（不能直接双击 html 打开）：

```bash
cd /Users/zbf/ws/godot-vampire/export/web
python3 -m http.server 8080
# 浏览器打开 http://localhost:8080
```

## 部署到线上

把 `export/web/` 目录下的所有文件上传到任意静态托管服务：
- GitHub Pages
- Netlify / Vercel（拖拽上传即可）
- itch.io（创建新项目，类型选 HTML，上传 web zip）
- 腾讯云/阿里云 OSS 静态网站
- Nginx / Apache

### itch.io 示例
1. 把 `export/web/` 整个目录打成 zip
2. 登录 itch.io → Create new project
3. Kind of project 选 `HTML`
4. 上传 zip
5. 勾选 "This file will be played in the browser"
6. 保存即可获得可分享链接

### GitHub Pages 示例
```bash
cd /Users/zbf/ws/godot-vampire
# 导出到 docs/web 或 gh-pages 分支
godot --headless --export-release "Web (HTML)"
# 把 export/web 内容推到 gh-pages 分支
```

## 注意事项

- Web 版本需要支持 WebAssembly + WebGL2 的现代浏览器
- 移动端浏览器性能可能受限
- 中文字体内置在 pck 中，无需额外配置
- 游戏存档（排行榜）使用浏览器的 localStorage / IndexedDB
