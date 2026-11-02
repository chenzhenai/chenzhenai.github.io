# chen.zhen

公开笔记，分成三栏：从 0 到 1 AI Infra、从 0 到 1 Agent、大模型论文研读。Hugo + PaperMod，页面输出在 `docs/`。

## 本地预览

```bash
hugo server
```

## 发布

GitHub Pages 需要发布 `main` 分支的 `/docs` 目录。

```bash
hugo --minify --cleanDestinationDir
```

## 新笔记

```bash
hugo new posts/note-name.md
```

`stage` 对应目录里的一步：`gpu`、`train`、`infer`、`model`、`tools`、`memory`、`eval`。写好后把标题和路径补进 `data/catalog.yaml` 的对应条目，目录里才会变成链接。
