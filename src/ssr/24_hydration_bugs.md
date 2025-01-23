# Hydration Bugs _(以及如何避免它们)_

## 一个思维实验

让我们做个实验来测试你的直觉。打开一个使用 `cargo-leptos` 进行服务器渲染的应用。（如果你之前只是使用 `trunk` 来运行示例，现在可以[克隆一个 `cargo-leptos` 模板](./21_cargo_leptos.md)来完成这个练习。）

在你的根组件中放一个日志。（我通常将它命名为 `<App/>`，但任何名称都可以。）

```rust
#[component]
pub fn App() -> impl IntoView {
	logging::log!("where do I run?");
	// ... 其他代码
}
```

然后启动它：

```bash
cargo leptos watch
```

你认为 `where do I run?` 会在哪里打印日志？

- 在运行服务器的命令行中？
- 在加载页面时的浏览器控制台中？
- 都不会？
- 两个地方都打印？

试试看。

...

...

...

好的，以下是答案提示。

你会注意到它当然会在两个地方打印日志（假设一切正常）。实际上，在服务器上会打印两次——第一次是在服务器启动时，Leptos 渲染你的应用以提取路由树；第二次是在你发送请求时。每次你重新加载页面时，`where do I run?` 会在服务器和客户端各打印一次日志。

如果你思考一下前几节的描述，希望这会有意义。你的应用程序会在服务器上运行一次，构建一棵 HTML 树，并将其发送到客户端。在这次初始渲染期间，`where do I run?` 会在服务器上打印日志。

一旦 WASM 二进制文件加载到浏览器中，你的应用会第二次运行，遍历同一用户界面树并添加交互性。

> 这听起来像是浪费吗？从某种意义上来说确实是。但减少这种浪费是一个真正困难的问题。这正是一些 JS 框架（例如 Qwik）试图解决的问题，尽管目前判断它是否比其他方法在性能上有净增益可能还为时过早。

## 潜在的 Bug

好了，希望以上内容都让你理解了。但这些内容和本章标题“Hydration Bugs（及其避免方法）”有什么关系呢？

记住，应用程序需要同时运行在服务器和客户端上。这会产生一些潜在的问题，你需要知道如何避免。

### 服务器和客户端代码的不匹配

一个常见的 Bug 来源是服务器发送的 HTML 和客户端渲染的内容之间的不匹配。这种问题其实几乎不小心就发生（至少从我收到的 Bug 报告来看是这样的）。但想象我做了这样的事情：

```rust
#[component]
pub fn App() -> impl IntoView {
    let data = if cfg!(target_arch = "wasm32") {
        vec![0, 1, 2]
    } else {
        vec![]
    };
    data.into_iter()
        .map(|value| view! { <span>{value}</span> })
        .collect_view()
}
```

换句话说，如果被编译成 WASM，就会有三个元素；否则它是空的。

当我在浏览器中加载页面时，我什么都看不到。如果我打开控制台，会看到一个 panic：

```
ssr_modes.js:423 panicked at /.../tachys/src/html/element/mod.rs:352:14:
called `Option::unwrap()` on a `None` value
```

运行在浏览器中的 WASM 版本应用程序期望找到一些元素（事实上它期望找到三个元素！），但服务器发送的 HTML 中却没有这些内容。

#### 解决方案

虽然你很少会有意这样做，但通过某种方式在服务器和浏览器中运行不同的逻辑，这种问题还是有可能发生。如果你看到类似的警告，并且认为不是你的问题，很可能是 `<Suspense/>` 或其他功能的 Bug。欢迎前往 [GitHub 提交 issue](https://github.com/leptos-rs/leptos/issues) 或 [参与讨论](https://github.com/leptos-rs/leptos/discussions) 寻求帮助。

### 无效/边缘情况的 HTML，以及 HTML 与 DOM 的不匹配

服务器通过 HTML 响应请求，浏览器然后将该 HTML 解析为称为文档对象模型（DOM）的树。在 Hydration 过程中，Leptos 会遍历应用程序的视图树：先 Hydrate 一个元素，然后进入它的子元素，Hydrate 第一个子元素，再移动到它的兄弟节点，以此类推。这假设应用程序在服务器上生成的 HTML 树与浏览器解析这些 HTML 后生成的 DOM 树完全对应。

以下是一些需要注意的情况，这些情况下由你的 `view` 创建的 HTML 树和 DOM 树可能并不完全对应，从而导致 Hydration 错误。

#### 无效的 HTML

以下是一个会引发 Hydration 错误的简单应用：

```rust
#[component]
pub fn App() -> impl IntoView {
    let count = RwSignal::new(0);

    view! {
        <p>
            <div class:blue=move || count.get() == 2>
                 "First"
            </div>
        </p>
    }
}
```

这会显示如下错误信息：

```
A hydration error occurred while trying to hydrate an element defined at src/app.rs:6:14.

The framework expected a text node, but found this instead:  <p></p>

The hydration mismatch may have occurred slightly earlier, but this is the first time the framework found a node of an unexpected type.
```

（在大多数浏览器的开发者工具中，你可以右键单击 `<p></p>`，查看它在 DOM 中的位置，非常方便。）

如果你查看 DOM 检查器，会发现 `<p>` 中没有 `<div>`，而是显示为：

```html
<p></p>
<div>First</div>
<p></p>
```

这是因为这是无效的 HTML！`<div>` 不能放在 `<p>` 中。当浏览器解析到 `<div>` 时，它会自动关闭前面的 `<p>`，然后打开 `<div>`；随后，当它看到未匹配的 `</p>` 时，会将其视为一个新的、空的 `<p>`。

因此，我们的 DOM 树不再匹配预期的视图树，进而导致 Hydration 错误。

目前，使用现有模型在编译时确保 HTML 的有效性是困难的，因为这会对整体编译时间造成影响。对于这种问题，可以考虑将 HTML 输出通过验证器进行检查。（如上例，W3C HTML Validator 的确会报告错误！）

```admonish info
你可能会注意到，从 Leptos 0.6 迁移到 0.7 时，会出现一些相关的 Bug。这是因为 Hydration 的工作方式发生了变化。

Leptos 0.1-0.6 使用了一种通过为每个 HTML 元素分配唯一 ID 的 Hydration 方法，然后通过该 ID 在 DOM 中找到元素。而 Leptos 0.7 改为直接遍历 DOM，按顺序 Hydrate 每个元素。这种方法具有更好的性能特点（HTML 输出更简洁，Hydration 时间更短），但对上述无效或边缘情况的 HTML 例子更敏感。更重要的是，这种方法还修复了许多 *其他* Hydration 中的边缘情况和 Bug，使框架在整体上更为健壮。
```

#### 没有 `<tbody>` 的 `<table>`

还有一个边缘情况，即 *有效* 的 HTML 会生成与视图树不同的 DOM 树，这种情况出现在 `<table>` 中。当（大多数）浏览器解析 HTML 的 `<table>` 时，无论你是否包含 `<tbody>`，它们都会在 DOM 中插入一个 `<tbody>`。

```rust
#[component]
pub fn App() -> impl IntoView {
    let count = RwSignal::new(0);

    view! {
        <table>
            <tr>
                <td class:blue=move || count.get() == 0>"First"</td>
            </tr>
        </table>
    }
}
```

再次运行时，这会生成一个 Hydration 错误，因为浏览器在 DOM 树中插入了一个额外的 `<tbody>`，而这个 `<tbody>` 并没有出现在视图树中。

解决方法非常简单：添加 `<tbody>`：
```rust
#[component]
pub fn App() -> impl IntoView {
    let count = RwSignal::new(0);

    view! {
        <table>
            <tbody>
                <tr>
                    <td class:blue=move || count.get() == 0>"First"</td>
                </tr>
            </tbody>
        </table>
    }
}
```

（未来可以探索是否可以更轻松地为这个特殊的情况添加 lint，而不是为所有有效 HTML 添加 lint。）

#### 一般建议

这类不匹配问题可能会很棘手。一般来说，我的调试建议如下：

1. 右键单击错误信息中的元素，查看框架首次 *发现* 问题的位置。
2. 对比该位置及其上方的 DOM，检查是否与视图树存在不匹配的情况。是否有多余的元素？是否缺少某些元素？

### 并非所有客户端代码都能在服务器上运行

假设你愉快地导入了一个像 `gloo-net` 这样的依赖库，之前你习惯用它来在浏览器中发起请求，并在一个服务器渲染的应用中将其用于 `create_resource`。

你可能会立刻看到令人头痛的消息：

```
panicked at 'cannot call wasm-bindgen imported functions on non-wasm targets'
```

糟糕。

不过，这其实是可以理解的。我们刚刚提到，应用需要同时运行在客户端和服务器端。

#### 解决方案

以下是一些避免这种问题的方法：

1. **只使用可以同时运行在服务器和客户端上的库**。例如，[`reqwest`](https://docs.rs/reqwest/latest/reqwest/) 可以在这两种环境下发起 HTTP 请求。
2. **在服务器和客户端使用不同的库**，并使用 `#[cfg]` 宏进行区分。（[点击此处查看示例](https://github.com/leptos-rs/leptos/blob/main/examples/hackernews/src/api.rs)。）
3. **将仅客户端代码包装在 `Effect::new` 中**。因为 Effects 只会在客户端运行，这是一种访问浏览器 API（且这些 API 在初始渲染时不需要）的有效方式。

例如，如果我想在信号变化时将某些内容存储到浏览器的 `localStorage` 中：

```rust
#[component]
pub fn App() -> impl IntoView {
    use gloo_storage::Storage;
	let storage = gloo_storage::LocalStorage::raw();
	logging::log!("{storage:?}");
}
```

这段代码会 panic，因为在服务器渲染期间无法访问 `LocalStorage`。

但如果我将其包装在一个 Effect 中：

```rust
#[component]
pub fn App() -> impl IntoView {
    use gloo_storage::Storage;
    Effect::new(move |_| {
        let storage = gloo_storage::LocalStorage::raw();
		log!("{storage:?}");
    });
}
```

这样就没问题了！这段代码会在服务器上正确渲染，忽略仅客户端的代码，然后在浏览器中访问存储并打印日志消息。

---

### 并非所有服务器代码都能在客户端运行

运行在浏览器中的 WebAssembly 是一个非常受限的环境。你无法访问文件系统或许多标准库可能会用到的功能。并非所有的 crate 都能被编译为 WASM，更不用说在 WASM 环境中运行了。

尤其是，有时你会看到关于 `mio` crate 或缺少 `core` 中某些内容的错误。这通常表明你尝试将某些无法编译为 WASM 的代码编译成 WASM。如果你正在添加仅服务器使用的依赖，请在 `Cargo.toml` 中将它们标记为 `optional = true`，然后在 `ssr` 功能定义中启用它们。（可以查看模板的 `Cargo.toml` 文件获取更多详情。）

你可以使用 `create_effect` 来指定某些内容只在客户端运行，而不在服务器上运行。那么，有没有办法指定某些内容只在服务器上运行，而不在客户端运行呢？

事实上，有办法。下一章将详细介绍服务器函数的主题。（同时，你也可以查看它们的[文档](https://docs.rs/leptos/latest/leptos/attr.server.html)。）
