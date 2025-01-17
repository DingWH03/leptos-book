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

In Part 1 of this book, we'll start with client-side rendering Leptos sites and building reactive UIs using `Trunk` to serve our JS and WASM bundle to the browser.

We’ll introduce `cargo-leptos` in Part 2 of this book, which is all about working with the full power of Leptos in its full-stack, SSR mode.

```admonish note
If you're coming from the Javascript world and terms like client-side rendering (CSR) and server-side rendering (SSR) are unfamiliar to you, the easiest way to understand the difference is by analogy:

Leptos' CSR mode is similar to working with React (or a 'signals'-based framework like SolidJS), and focuses on producing a client-side UI which you can use with any tech stack on the server.

Using Leptos' SSR mode is similar to working with a full-stack framework like Next.js in the React world (or Solid's "SolidStart" framework) - SSR helps you build sites and apps that are rendered on the server then sent down to the client. SSR can help to improve your site's loading performance and accessibility as well as make it easier for one person to work on *both* client- and server-side without needing to context-switch between different languages for frontend and backend.

The Leptos framework can be used either in CSR mode to just make a UI (like React), or you can use Leptos in full-stack SSR mode (like Next.js) so that you can build both your UI and your server with one language: Rust.

```

## Hello World! Getting Set up for Leptos CSR Development

First up, make sure Rust is installed and up-to-date ([see here if you need instructions](https://www.rust-lang.org/tools/install)).

If you don’t have it installed already, you can install the "Trunk" tool for running Leptos CSR sites by running the following on the command-line:

```bash
cargo install trunk
```

And then create a basic Rust project

```bash
cargo init leptos-tutorial
```

`cd` into your new `leptos-tutorial` project and add `leptos` as a dependency

```bash
cargo add leptos --features=csr
```

Make sure you've added the `wasm32-unknown-unknown` target so that Rust can compile your code to WebAssembly to run in the browser.

```bash
rustup target add wasm32-unknown-unknown
```

Create a simple `index.html` in the root of the `leptos-tutorial` directory

```html
<!DOCTYPE html>
<html>
  <head></head>
  <body></body>
</html>
```

And add a simple “Hello, world!” to your `main.rs`

```rust
use leptos::prelude::*;

fn main() {
    leptos::mount::mount_to_body(|| view! { <p>"Hello, world!"</p> })
}
```

Your directory structure should now look something like this

```
leptos_tutorial
├── src
│   └── main.rs
├── Cargo.toml
├── index.html
```

Now run `trunk serve --open` from the root of the `leptos-tutorial` directory.
Trunk should automatically compile your app and open it in your default browser.
If you make edits to `main.rs`, Trunk will recompile your source code and
live-reload the page.

Welcome to the world of UI development with Rust and WebAssembly (WASM), powered by Leptos and Trunk!

```admonish note
If you are using Windows, note that `trunk serve --open` may not work. If you have issues with `--open`,
simply use `trunk serve` and open a browser tab manually.
```

---

Now before we get started building your first real applications with Leptos, there are a couple of things you might want to know to help make your experience with Leptos just a little bit easier.
