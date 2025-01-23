# Leptos 中文手册(Book)

- [Leptos 中文手册](#leptos-中文手册book)
  - [简介](#简介)
  - [构建手册](#构建手册)
  - [可选：VSCode 开发容器](#可选vscode-开发容器)

## 简介

本项目包含了一份关于 Leptos 的全新入门指南的核心内容，原手册为英文版，本项目将其翻译成中文并`folk`到个人仓库，中文版手册静态页面由[vercel](https://vercel.com/)提供支持。欢迎提交任何拼写错误、内容澄清或改进的 Pull Request。

您可以在 [Leptos 网站](https://book.leptos.dev/) 上找到本手册的在线英文版本，中文版本在 [Leptos 中文手册](https://book.leptos.cxhap.top/) 上。

> 英文版README文件备份[如下](./README_en.md)。

## 构建手册

该手册使用 [`mdbook`](https://crates.io/crates/mdbook) 构建。您可以通过 Cargo 安装 `mdbook` 后在本地查看手册。

```sh
cargo install mdbook --version 0.4.*
```

本手册还使用了一个名为 [`mdbook-admonish`](https://crates.io/crates/mdbook-admonish) 的 mdbook 预处理器，用于美化文本块，例如注释、警告等。

```sh
cargo install mdbook-admonish --version 1.*
```

然后运行以下命令启动手册：

```sh
mdbook serve
```

此时，手册应可通过 [`http://localhost:3000`](http://localhost:3000) 访问。

## 可选：VSCode 开发容器

您还可以选择在示例 [VSCode 开发容器](https://code.visualstudio.com/docs/devcontainers/containers) 中构建并运行手册，该容器将自动安装所有依赖项、构建手册并在 [`http://localhost:3000`](http://localhost:3000) 提供实时重新加载的服务。

安装 Docker 和官方的 [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) 扩展，然后在 VSCode 中打开项目，并在提示时选择“在开发容器中重新打开”。

更多信息，请参考：https://code.visualstudio.com/remote/advancedcontainers/use-docker-kubernetes

要在开发容器内运行 Docker 命令，请参考：https://code.visualstudio.com/remote/advancedcontainers/use-docker-kubernetes 
