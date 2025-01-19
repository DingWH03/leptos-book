# 入门

使用 Leptos 框架有下面两种基本途径：

1. **使用 [Trunk](https://trunkrs.dev/)进行客户端渲染（CSR）** - 如果您只想用 Leptos 快速创建一个轻量网站，或与已有的服务器或 API 一起工作，Trunk 是一个不错的选择。
   在 CSR 模式下，Trunk 将您的 Leptos 应用程序编译为 WebAssembly (WASM)，并像典型的 Javascript 单页面应用程序 (SPA) 一样在浏览器中运行。
    Leptos 使用 CSR 的优势包括更快的构建时间和更快的迭代开发周期，以及更简单的开发过程和更多部署应用程序的选项。
    CSR 应用程序具有以下的缺点: 与服务器端渲染方法相比，最终用户的初始加载时间较慢，并且Leptos CSR 应用会像传统 JS 单页应用模型那样在 SEO 方面带来更多的麻烦。
    请注意，在底层，会使用自动生成的 JavaScript 代码片段来加载 Leptos 的 WASM 包，因此客户端设备上必须启用 JavaScript，您的 CSR 应用才能正确显示。正如所有软件工程一样，这里也存在需要权衡的取舍。

2. **使用 [`cargo-leptos`](https://github.com/leptos-rs/cargo-leptos)进行的全栈的服务端渲染（SSR）** - 如果你想使用 Rust 来同时构建应用程序的前端和后端，那么 SSR 是构建 CRUD 风格网站和自定义 Web 应用程序的绝佳选择。
   使用 Leptos 服务器渲染的方式，您的应用程序将在服务端被呈现为 HTML，并发送到浏览器来显示；然后，WebAssembly 用于检测 HTML，使应用变得具有交互性 - 此过程称为“hydration”。
   在服务端, Leptos SSR 应用程序与您选择的 [Actix-web](https://docs.rs/leptos_actix/latest/leptos_actix/) 或 [Axum](https://docs.rs/leptos_axum/latest/leptos_axum/) 服务器库紧密集成，所以您可以利用这些社区的 crate 来帮助构建您的 Leptos 服务端。
   使用 Leptos 进行 SSR（服务端渲染）有以下优势：它可以帮助您的 Web 应用实现最快的初始加载时间和最佳的 SEO 效果。此外，SSR 应用通过 Leptos 的一个名为“服务器函数”（server functions）的特性，可以显著简化跨越服务器和客户端的交互。该特性允许您从客户端代码中透明地调用服务器上的函数（稍后会详细介绍此功能）。然而，全栈 SSR 并非尽善尽美——它的缺点包括较慢的开发迭代周期（因为在修改 Rust 代码时需要同时重新编译服务器和客户端），以及与状态复用（hydration）相关的一些额外复杂性。

读完本书后，您应该对根据项目需求做出哪些权衡以及采取哪条路线（CSR 还是 SSR）有一个很好的了解。

在本书的第1部分，我们将从使用客户端渲染的 Leptos 网站开始，构建响应式用户界面（UI），并使用 Trunk 将 JavaScript 和 WASM 包提供给浏览器。

在本书的第2部分，我们将介绍 `cargo-leptos`，全面讲解 Leptos 如何在全栈 SSR 模式下充分发挥其强大功能。

```admonish note
如果您熟悉 JavaScript ，但对像客户端渲染（CSR）和服务端渲染（SSR）这样的术语感到陌生，那么理解它们差异的最简单方法是通过下面的类比：

Leptos 的客户端渲染（CSR）模式类似于使用 React（或类似 SolidJS 的“信号”框架），重点是生成一个客户端渲染的用户界面（UI），可以与任何服务器端技术栈配合使用。

使用 Leptos 的服务端渲染（SSR）模式类似于在 React 领域使用像 Next.js 这样的全栈框架（或 Solid 的 “SolidStart” 框架）。SSR 可以帮助您构建在服务器上渲染后发送到客户端的站点和应用程序。SSR 有助于提升网站的加载性能和可访问性，同时让开发者可以轻松地在客户端和服务器端*共同*进行开发，而无需在前后端不同的编程语言之间频繁切换。

Leptos 框架既可以以客户端渲染（CSR）模式使用，仅用于构建用户界面（类似于 React）；也可以以全栈服务端渲染（SSR）模式使用（类似于 Next.js），让您可以使用一种语言——Rust，同时构建用户界面和服务器端。

```

## 准备好，进入 Leptos CSR 的世界

首先，请确保您已经安装了最新的Rust语言套件。 ([查看 Rust 安装指南？](https://www.rust-lang.org/tools/install)).

如果你是第一次进行安装配置，你首先应该使用下面的命令来安装进行 Leptos CSR 页面客户端渲染的"Trunk"工具：

```bash
cargo install trunk
```

之后，创建一个基础的 Rust 工程项目：

```bash
cargo init leptos-tutorial
```

`cd` 进入新创建的 `leptos-tutorial` 项目中 然后添加 `leptos` 作为一个依赖项。

```bash
cargo add leptos --features=csr
```

确保您已添加 `wasm32-unknown-unknown` 构建目标（target），以便 Rust 能将您的代码编译为可在浏览器中运行的 WebAssembly。

```bash
rustup target add wasm32-unknown-unknown
```

创建一个最简单的 `index.html` 在项目 `leptos-tutorial` 的根路径下（./index.html）

```html
<!DOCTYPE html>
<html>
  <head></head>
  <body></body>
</html>
```

添加一个最简单的显示 “Hello, world!” 的代码到您的 `main.rs` 代码中。

```rust
use leptos::prelude::*;

fn main() {
    leptos::mount::mount_to_body(|| view! { <p>"Hello, world!"</p> })
}
```

您目前的目录结构应该和下面所展示的一致：

```
leptos_tutorial
├── src
│   └── main.rs
├── Cargo.toml
├── index.html
```

现在从项目`leptos-tutorial`的根目录使用终端运行 `trunk serve --open`。
Trunk 会自动编译您的应用程序并在您的默认浏览器中打开它。
如果您对`main.rs`进行编辑，Trunk 将重新编译您的源代码并实时重新加载页面。

欢迎进入由 Rust 和 WebAssembly (WASM) 驱动的 UI 开发世界，由 Leptos 和 Trunk 提供支持！

```admonish note
如果您正在使用Windows操作系统，`trunk serve --open`可能不会奏效。如果您使用`--open`无法自动打开默认浏览器，
那么只需要使用`trunk serve`来启动服务，然后手动打开浏览器即可。
```

---

在开始使用 Leptos 构建您的第一个实际应用之前，有一些事情您可能需要了解，这将帮助您更轻松地使用 Leptos。
