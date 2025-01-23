# `<Form/>` 组件

链接（`<a>`）和表单（`<form>`）有时看起来完全无关，但实际上它们的工作方式非常相似。

在纯 HTML 中，有三种方式可以导航到另一个页面：

1. 使用 `<a>` 元素链接到另一个页面：通过其 `href` 属性的 URL 使用 `GET` HTTP 方法导航。
2. 使用 `<form method="GET">`：通过其 `action` 属性的 URL 使用 `GET` HTTP 方法导航，同时将表单输入数据编码到 URL 查询字符串中。
3. 使用 `<form method="POST">`：通过其 `action` 属性的 URL 使用 `POST` HTTP 方法导航，同时将表单输入数据编码到请求体中。

由于我们有客户端路由器，因此可以实现客户端的链接导航，无需重新加载页面，即无需往返服务器。这也意味着，我们可以以类似的方式在客户端实现表单导航。

路由器提供了一个 [`<Form>`](https://docs.rs/leptos_router/latest/leptos_router/components/fn.Form.html) 组件，它的功能类似于 HTML 的 `<form>` 元素，但使用客户端导航而不是完全重新加载页面。`<Form/>` 支持 `GET` 和 `POST` 请求。当设置 `method="GET"` 时，它会导航到包含表单数据编码的 URL；而设置 `method="POST"` 时，它会发起一个 `POST` 请求并处理服务器的响应。

`<Form/>` 是一些组件（如 `<ActionForm/>` 和 `<MultiActionForm/>`，将在后续章节中看到）的基础。但它本身也支持一些非常强大的模式。

例如，假设你想创建一个搜索框，用户在搜索时可以实时更新搜索结果而无需重新加载页面，同时将搜索结果存储在 URL 中，这样用户可以复制并将其分享给其他人。

实际上，我们已经学到的模式可以轻松实现这一需求：

```rust
async fn fetch_results() {
    // 一个异步函数，用于获取搜索结果
}

#[component]
pub fn FormExample() -> impl IntoView {
    // 对 URL 查询字符串的响应式访问
    let query = use_query_map();
    // 将搜索存储为 ?q=
    let search = move || query.read().get("q").unwrap_or_default();
    // 基于搜索字符串的资源
    let search_results = Resource::new(search, |_| fetch_results());

    view! {
        <Form method="GET" action="">
            <input type="search" name="q" value=search/>
            <input type="submit"/>
        </Form>
        <Transition fallback=move || ()>
            /* 渲染搜索结果 */
            {todo!()}
        </Transition>
    }
}
```

每次点击 `Submit` 时，`<Form/>` 会“导航”到 `?q={search}`。但由于这种导航在客户端完成，因此没有页面闪烁或重新加载。URL 查询字符串发生变化后会触发 `search` 更新。因为 `search` 是 `search_results` 资源的源信号，这会进一步触发 `search_results` 重新加载其资源。`<Transition/>` 会在新结果加载完成前继续显示当前搜索结果，加载完成后会切换显示新结果。

这是一个很好的模式，数据流非常清晰：所有数据从 URL 流向资源再流向 UI。应用程序的当前状态存储在 URL 中，这意味着你可以刷新页面或将链接发给朋友，它们会看到你期望的结果。一旦引入服务器端渲染，这种模式会变得非常健壮：因为它在底层使用 `<form>` 元素和 URL，即使不加载客户端的 WASM，也能很好地工作。

我们还可以更进一步，做一些有趣的优化：

```rust
view! {
    <Form method="GET" action="">
        <input type="search" name="q" value=search
            oninput="this.form.requestSubmit()"
        />
    </Form>
}
```

你会注意到，这个版本去掉了 `Submit` 按钮。相反，我们在输入框中添加了一个 `oninput` 属性。需要注意的是，这里是 **`oninput`** 而不是 **`on:input`**，后者会监听 `input` 事件并运行一些 Rust 代码。而没有冒号的 `oninput` 是普通的 HTML 属性，因此其值是一个 JavaScript 字符串。`this.form` 获取到输入框所属的表单，`requestSubmit()` 会触发 `<form>` 的 `submit` 事件，就像点击了一个 `Submit` 按钮一样。现在，这个表单会在每次输入时“导航”，让 URL（因此也包括搜索）始终与用户的输入保持同步。

```admonish sandbox title="Live example" collapsible=true

[Click to open CodeSandbox.](https://codesandbox.io/p/devbox/20-form-0-7-m73jsz)

<noscript>
  Please enable JavaScript to view examples.
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/20-form-0-7-m73jsz" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox Source</summary>

```rust
use leptos::prelude::*;
use leptos_router::components::{Form, Route, Router, Routes};
use leptos_router::hooks::use_query_map;
use leptos_router::path;

#[component]
pub fn App() -> impl IntoView {
    view! {
        <Router>
            <h1><code>"<Form/>"</code></h1>
            <main>
                <Routes fallback=|| "Not found.">
                    <Route path=path!("") view=FormExample/>
                </Routes>
            </main>
        </Router>
    }
}

#[component]
pub fn FormExample() -> impl IntoView {
    // reactive access to URL query
    let query = use_query_map();
    let name = move || query.read().get("name").unwrap_or_default();
    let number = move || query.read().get("number").unwrap_or_default();
    let select = move || query.read().get("select").unwrap_or_default();

    view! {
        // read out the URL query strings
        <table>
            <tr>
                <td><code>"name"</code></td>
                <td>{name}</td>
            </tr>
            <tr>
                <td><code>"number"</code></td>
                <td>{number}</td>
            </tr>
            <tr>
                <td><code>"select"</code></td>
                <td>{select}</td>
            </tr>
        </table>
        // <Form/> will navigate whenever submitted
        <h2>"Manual Submission"</h2>
        <Form method="GET" action="">
            // input names determine query string key
            <input type="text" name="name" value=name/>
            <input type="number" name="number" value=number/>
            <select name="select">
                // `selected` will set which starts as selected
                <option selected=move || select() == "A">
                    "A"
                </option>
                <option selected=move || select() == "B">
                    "B"
                </option>
                <option selected=move || select() == "C">
                    "C"
                </option>
            </select>
            // submitting should cause a client-side
            // navigation, not a full reload
            <input type="submit"/>
        </Form>
        // This <Form/> uses some JavaScript to submit
        // on every input
        <h2>"Automatic Submission"</h2>
        <Form method="GET" action="">
            <input
                type="text"
                name="name"
                value=name
                // this oninput attribute will cause the
                // form to submit on every input to the field
                oninput="this.form.requestSubmit()"
            />
            <input
                type="number"
                name="number"
                value=number
                oninput="this.form.requestSubmit()"
            />
            <select name="select"
                onchange="this.form.requestSubmit()"
            >
                <option selected=move || select() == "A">
                    "A"
                </option>
                <option selected=move || select() == "B">
                    "B"
                </option>
                <option selected=move || select() == "C">
                    "C"
                </option>
            </select>
            // submitting should cause a client-side
            // navigation, not a full reload
            <input type="submit"/>
        </Form>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>
