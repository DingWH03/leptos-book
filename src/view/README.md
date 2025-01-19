# 第1部分：构建用户界面

在本书的第一部分，我们将探讨如何使用 Leptos 在客户端构建用户界面。在底层，Leptos 和 Trunk 会打包一段 JavaScript 代码，这段代码将加载已编译为 WebAssembly 的 Leptos UI，并驱动您 CSR（客户端渲染）网站实现交互性。

第1部分将介绍构建由 Leptos 和 Rust 驱动的响应式用户界面所需的基本工具。在第1部分结束时，您应该能够： 构建一个流畅的同步网站，该网站在浏览器中渲染，并且可以部署到任何静态网站托管服务，例如 Github Pages 或 Vercel。

```admonish info
为了充分利用本书的内容，我们鼓励您跟随提供的示例一起编写代码。
在[入门](https://book.leptos.cxhap.top/getting_started/)和[优化 Leptos 开发体验](https://book.leptos.cxhap.top/getting_started/leptos_dx.html)章节中，我们向您展示了如何使用 Leptos 和 Trunk 设置一个基本项目，包括在浏览器中处理 WASM 错误的方式。
这个基础设置已经足以让您开始使用 Leptos 进行开发了。

如果您更倾向于使用一个功能更全面的模板来开始，它可以演示如何设置一些实际 Leptos 项目中的基础功能，例如路由（将在本书后面介绍）、向页面的 <head> 中注入 `<Title>` 和 `<Meta>` 标签，以及其他一些实用功能，那么您可以使用[leptos-rs start-trunk 模板仓库](https://github.com/leptos-rs/start-trunk)快速启动您的项目。

`start-trunk` 模板要求您安装 `Trunk` 和 `cargo-generate`，您可以通过命令`cargo install trunk` 和 `cargo install cargo-generate`安装它们。

你只需要使用下面的命令来使用模板配置你的初始项目：

`cargo generate --git https://github.com/leptos-community/start-csr`

然后运行命令：

`trunk serve --port 3000 --open`

在新创建的应用程序目录中开始开发您的应用程序。Trunk 服务器会在文件发生更改时自动重新加载您的应用程序，使开发过程相对更加流畅。

```
