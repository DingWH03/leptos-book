# 介绍 `cargo-leptos`

到目前为止，我们只是运行代码在浏览器中，并使用 Trunk 来协调构建过程和运行本地开发流程。如果我们要添加服务端渲染 (SSR)，还需要在服务器上运行应用代码。这意味着需要构建两个单独的二进制文件：一个编译为本地代码并运行服务器，另一个编译为 WebAssembly (WASM) 并在用户的浏览器中运行。此外，服务器需要知道如何将这个 WASM 版本（以及初始化它所需的 JavaScript）提供给浏览器。

虽然这不是一个不可逾越的任务，但确实增加了一些复杂性。为了方便开发并简化开发体验，我们创建了 [`cargo-leptos`](https://github.com/leptos-rs/cargo-leptos) 构建工具。`cargo-leptos` 主要用于协调应用的构建过程，处理在代码更改时重新编译服务器和客户端部分，并内置支持如 Tailwind、SASS 和测试等功能。

开始使用非常简单。只需运行以下命令安装：

```bash
cargo install cargo-leptos
```

然后可以通过以下命令创建新项目：

```bash
# Actix 模板
cargo leptos new --git https://github.com/leptos-rs/start-actix
```

或者

```bash
# Axum 模板
cargo leptos new --git https://github.com/leptos-rs/start-axum
```

确保你已经添加了 `wasm32-unknown-unknown` 目标，以便 Rust 可以将代码编译为在浏览器中运行的 WebAssembly：

```bash
rustup target add wasm32-unknown-unknown
```

现在进入你创建的项目目录并运行：

```bash
cargo leptos watch
```

当你的应用程序编译完成后，你可以打开浏览器访问 [`http://localhost:3000`](http://localhost:3000) 查看。

`cargo-leptos` 还有许多额外功能和内置工具。你可以在它的 [README 文档](https://github.com/leptos-rs/cargo-leptos/blob/main/README.md) 中了解更多。

但是，当你打开浏览器访问 `localhost:3000` 时，究竟发生了什么呢？继续阅读以了解更多！
