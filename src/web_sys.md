# 与 JavaScript 集成：`wasm-bindgen`、`web_sys` 和 `HtmlElement`

Leptos 提供了多种工具，让你能够构建声明式 Web 应用，而无需离开框架的世界。像反应式系统、`component` 和 `view` 宏以及路由器等工具，可以让你直接用 Rust 构建用户界面，这非常棒——假设你喜欢 Rust。（如果你已经读到了本书的这个部分，我们假设你确实喜欢 Rust。）

像 [`leptos-use`](https://leptos-use.rs/) 提供的一整套出色的工具，可以更进一步，为许多 Web API 提供针对 Leptos 的反应式封装。

然而，在许多情况下，你仍然需要直接访问 JavaScript 库或 Web API。本章将为你提供帮助。

## 使用 `wasm-bindgen` 调用 JavaScript 库

你的 Rust 代码可以被编译为 WebAssembly (WASM) 模块并在浏览器中运行。然而，WASM 无法直接访问浏览器的 API。Rust/WASM 生态系统依赖于从 Rust 代码生成绑定，以与 JavaScript 浏览器环境交互。

[`wasm-bindgen`](https://rustwasm.github.io/docs/wasm-bindgen/) 是该生态系统的核心。它提供了用于标记 Rust 代码部分的接口，这些标记可以告诉编译器如何调用 JavaScript，以及一个 CLI 工具，用于生成必要的 JavaScript glue 代码。事实上，你一直在不知不觉中使用它：`trunk` 和 `cargo-leptos` 都在底层依赖 `wasm-bindgen`。

如果你想从 Rust 中调用某个 JavaScript 库，可以参考 `wasm-bindgen` 的文档 [导入 JavaScript 函数](https://rustwasm.github.io/docs/wasm-bindgen/examples/import-js.html)。它可以让你轻松地从 JavaScript 导入函数、类或值，并在 Rust 应用中使用。

但将 JavaScript 库直接集成到应用中并不总是简单的。特别是那些依赖于特定 JavaScript 框架（如 React）的库可能难以集成。那些以某种方式操作 DOM 状态的库（如富文本编辑器）也需要小心使用，因为 Leptos 和 JavaScript 库可能都认为自己是应用状态的最终真相来源，因此需要注意分离它们的职责。

## 使用 `web-sys` 访问 Web API

如果你只是需要访问一些浏览器 API，而不需要引入单独的 JavaScript 库，可以使用 [`web_sys`](https://docs.rs/web-sys/latest/web_sys/) crate。它为浏览器提供的所有 Web API 提供了绑定，将浏览器的类型和函数 1:1 映射到 Rust 的结构体和方法。

通常，如果你在问“如何用 Leptos **做某事**”，其中“做某事”是指访问某些 Web API，那么查找一个纯 JavaScript 解决方案并通过 [`web-sys` 文档](https://docs.rs/web-sys/latest/web_sys/) 将其翻译为 Rust 是一个不错的选择。

> 你可能会发现 [`wasm-bindgen` 指南关于 `web-sys` 的章节](https://rustwasm.github.io/docs/wasm-bindgen/web-sys/index.html) 对进一步阅读很有帮助。

### 启用特性(features)

`web_sys` 使用了大量功能标志来降低编译时间。如果你想使用它的某些 API，可能需要启用相应的功能。

文档中会列出使用某个项目所需的功能。例如，要使用 [`Element::get_bounding_rect_client`](https://docs.rs/web-sys/latest/web_sys/struct.Element.html#method.get_bounding_client_rect)，你需要启用 `DomRect` 和 `Element` 功能。

Leptos 已经启用了 [很多功能](https://github.com/leptos-rs/leptos/blob/main/leptos_dom/Cargo.toml#L41)，如果所需功能已经在这里启用，你就不需要在自己的应用中启用它了。否则，只需在你的 `Cargo.toml` 中添加它即可：

```toml
[dependencies.web-sys]
version = "0.3"
features = ["DomRect"]
```

然而，随着 JavaScript 标准的演变，可能会出现尚未完全稳定的浏览器功能（如 [WebGPU](https://docs.rs/web-sys/latest/web_sys/struct.Gpu.html)）。`web_sys` 将跟随这一标准，这意味着不提供稳定性保证。

要使用这些功能，你需要添加 `RUSTFLAGS=--cfg=web_sys_unstable_apis` 作为环境变量。这可以通过每次运行命令时添加，或者将其添加到你的项目的 `.cargo/config.toml` 中。

作为命令的一部分：

```sh
RUSTFLAGS=--cfg=web_sys_unstable_apis cargo # ...
```

在 `.cargo/config.toml` 中：

```toml
[env]
RUSTFLAGS = "--cfg=web_sys_unstable_apis"
```

## 从 `view` 中访问原始 `HtmlElement`

框架的声明式风格意味着你不需要直接操作 DOM 节点来构建用户界面。然而，在某些情况下，你可能希望直接访问表示视图部分的底层 DOM 元素。书中关于 [“非受控输入”](/view/05_forms.html?highlight=NodeRef#uncontrolled-inputs) 的部分介绍了如何使用 [`NodeRef`](https://docs.rs/leptos/latest/leptos/tachys/reactive_graph/node_ref/struct.NodeRef.html) 类型实现这一点。

`NodeRef::get` 返回一个经过正确类型化的 `web-sys` 元素，可以直接操作。

例如，以下代码：

```rust
#[component]
pub fn App() -> impl IntoView {
    let node_ref = NodeRef::<Input>::new();

    Effect::new(move |_| {
        if let Some(node) = node_ref.get() {
            leptos::logging::log!("value = {}", node.value());
        }
    });

    view! {
        <input node_ref=node_ref/>
    }
}
```

在这里的 Effect 中，`node` 是一个 `web_sys::HtmlInputElement`。这使得我们可以调用任何适当的方法。

（注意，`.get()` 在这里返回一个 `Option`，因为在 DOM 元素实际创建之前，`NodeRef` 是空的。Effects 在组件运行后延迟一个周期运行，因此在大多数情况下，当 Effect 运行时，`<input>` 已经被创建。）
