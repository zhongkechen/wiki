# Zhongke's Personal Wiki

本仓库保存个人 Wiki 的内容与构建配置，使用 [Quarto](https://quarto.org/) 生成静态网站，并通过 GitHub Pages 自动部署。

## 网站入口

[访问 Zhongke's Personal Wiki](https://gw.ch3n2k.com/)

## 仓库内容

- `index.md`：网站首页。
- `wiki/`：当前维护的 Wiki 页面。
- `old/`：从旧版 Wiki 迁移的历史页面。
- `_quarto.yml`：网站结构与 Quarto 构建配置。
- `.github/workflows/pages.yml`：GitHub Pages 自动构建和部署流程。

在本地安装 Quarto 后，可以使用以下命令预览或构建网站：

```bash
quarto preview
quarto render
```

构建产物保存在 `_site/` 目录。

## 版权与许可

除另有说明以及引用的第三方内容外，本仓库的原创内容采用
[知识共享署名-非商业性使用-相同方式共享 4.0 国际许可协议](LICENSE.md)
（CC BY-NC-SA 4.0）发布。

转载或改编时必须注明来源，不得用于商业目的；公开发布改编内容时，必须继续采用相同许可协议。第三方内容的权利仍归其原权利人所有。
