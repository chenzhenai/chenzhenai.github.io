# chen.zhen

公开笔记，分成三栏：从 0 到 1 AI Infra、从 0 到 1 Agent、大模型论文研读。Hugo + PaperMod，页面输出在 `docs/`。

## 本地预览

```bash
hugo server
```

## 发布

GitHub Pages 现在发布的是 `main` 分支的仓库根目录。设置页里把文件夹改成 `/docs` 时，保存按钮可能没有反应。

```powershell
./publish.ps1
```

这会先构建到 `docs/`，再把页面同步到仓库根目录。`assets/css/extended/` 是样式源文件，同步时不会删掉。

## 新笔记

```bash
hugo new posts/note-name.md
```

`stage` 对应目录里的一步：`gpu`、`train`、`infer`、`model`、`tools`、`memory`、`eval`。写好后把标题和路径补进 `data/catalog.yaml` 的对应条目，目录里才会变成链接。
