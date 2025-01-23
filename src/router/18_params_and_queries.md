# 参数和查询

静态路径对于区分不同的页面很有用，但几乎每个应用程序都需要通过 URL 传递数据。

有两种方法可以实现：

1. 使用命名路由**参数**，例如 `/users/:id` 中的 `id`
2. 使用命名路由**查询**，例如 `/search?q=Foo` 中的 `q`

由于 URL 的构造方式，你可以从**任何** `<Route/>` 视图访问查询（query）。而对于路由参数（params），你可以从定义它们的 `<Route/>` 或它的任何嵌套子路由中访问。

通过几个钩子函数，可以很简单地访问参数和查询：

- [`use_query`](https://docs.rs/leptos_router/latest/leptos_router/hooks/fn.use_query.html) 或 [`use_query_map`](https://docs.rs/leptos_router/latest/leptos_router/hooks/fn.use_query_map.html)
- [`use_params`](https://docs.rs/leptos_router/latest/leptos_router/hooks/fn.use_params.html) 或 [`use_params_map`](https://docs.rs/leptos_router/latest/leptos_router/hooks/fn.use_params_map.html)

这些函数分别提供了类型化选项（`use_query` 和 `use_params`）和非类型化选项（`use_query_map` 和 `use_params_map`）。

非类型化版本会返回一个简单的键值映射。而对于类型化版本，可以在结构体上派生 [`Params`](https://docs.rs/leptos_router/latest/leptos_router/params/trait.Params.html) 特性。

> `Params` 是一个非常轻量级的特性，用于通过对每个字段应用 `FromStr` 将字符串的扁平键值映射转换为结构体。由于路由参数和 URL 查询的扁平结构，它比类似 `serde` 的工具灵活性低得多，但也大大减少了对二进制文件的负担。

```rust
use leptos::Params;
use leptos_router::params::Params;

#[derive(Params, PartialEq)]
struct ContactParams {
    id: Option<usize>,
}

#[derive(Params, PartialEq)]
struct ContactSearch {
    q: Option<String>,
}
```

> 注意：`Params` 派生宏位于 `leptos_router::params::Params`。
>
> 如果使用稳定版，你只能在参数中使用 `Option<T>`。如果启用了 `nightly` 特性，你可以使用 `T` 或 `Option<T>`。

现在可以在组件中使用它们。假设一个同时包含参数和查询的 URL，例如 `/contacts/:id?q=Search`。

类型化版本返回 `Memo<Result<T, _>>`。它是一个 `Memo`，因此会响应 URL 的变化。同时，它是一个 `Result`，因为参数或查询需要从 URL 中解析，解析结果可能有效也可能无效。

```rust
use leptos_router::hooks::{use_params, use_query};

let params = use_params::<ContactParams>();
let query = use_query::<ContactSearch>();

// id: || -> usize
let id = move || {
    params
        .read()
        .as_ref()
        .ok()
        .and_then(|params| params.id)
        .unwrap_or_default()
};
```

非类型化版本返回 `Memo<ParamsMap>`。同样，它是 `Memo`，用于响应 URL 的变化。[`ParamsMap`](https://docs.rs/leptos_router/latest/leptos_router/params/struct.ParamsMap.html) 的行为类似于其他映射类型，提供 `.get()` 方法来返回 `Option<String>`。

```rust
use leptos_router::hooks::{use_params_map, use_query_map};

let params = use_params_map();
let query = use_query_map();

// id: || -> Option<String>
let id = move || params.read().get("id");
```

这样做可能会显得有些繁琐：派生一个信号来封装 `Option<_>` 或 `Result<_>` 可能需要一些步骤。但这样做是值得的，原因有两点：

1. **正确性**：它迫使你考虑以下情况，“如果用户没有为查询字段传递值怎么办？如果传递了无效值怎么办？”
2. **性能**：具体来说，当你在匹配相同 `<Route/>` 的路径之间导航时，仅参数或查询发生变化时，可以对应用程序的不同部分进行细粒度更新，而无需重新渲染。例如，在联系人列表示例中，在不同联系人之间导航时，会针对性地更新名称字段（以及联系信息），而无需替换或重新渲染整个 `<Contact/>` 组件。这正是细粒度响应式的用途所在。

> 这实际上是上一节的示例。由于路由器系统是一个整体，所以提供了一个单一示例来展示多个特性，即使我们还没有全部解释清楚，也不必惊讶。

```admonish sandbox title="Live example" collapsible=true

[Click to open CodeSandbox.](https://codesandbox.io/p/devbox/16-router-0-7-csm8t5?file=%2Fsrc%2Fmain.rs)

<noscript>
  Please enable JavaScript to view examples.
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/16-router-0-7-csm8t5?file=%2Fsrc%2Fmain.rs" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox Source</summary>

```rust
use leptos::prelude::*;
use leptos_router::components::{Outlet, ParentRoute, Route, Router, Routes, A};
use leptos_router::hooks::use_params_map;
use leptos_router::path;

#[component]
pub fn App() -> impl IntoView {
    view! {
        <Router>
            <h1>"Contact App"</h1>
            // this <nav> will show on every routes,
            // because it's outside the <Routes/>
            // note: we can just use normal <a> tags
            // and the router will use client-side navigation
            <nav>
                <a href="/">"Home"</a>
                <a href="/contacts">"Contacts"</a>
            </nav>
            <main>
                <Routes fallback=|| "Not found.">
                    // / just has an un-nested "Home"
                    <Route path=path!("/") view=|| view! {
                        <h3>"Home"</h3>
                    }/>
                    // /contacts has nested routes
                    <ParentRoute
                        path=path!("/contacts")
                        view=ContactList
                      >
                        // if no id specified, fall back
                        <ParentRoute path=path!(":id") view=ContactInfo>
                            <Route path=path!("") view=|| view! {
                                <div class="tab">
                                    "(Contact Info)"
                                </div>
                            }/>
                            <Route path=path!("conversations") view=|| view! {
                                <div class="tab">
                                    "(Conversations)"
                                </div>
                            }/>
                        </ParentRoute>
                        // if no id specified, fall back
                        <Route path=path!("") view=|| view! {
                            <div class="select-user">
                                "Select a user to view contact info."
                            </div>
                        }/>
                    </ParentRoute>
                </Routes>
            </main>
        </Router>
    }
}

#[component]
fn ContactList() -> impl IntoView {
    view! {
        <div class="contact-list">
            // here's our contact list component itself
            <h3>"Contacts"</h3>
            <div class="contact-list-contacts">
                <A href="alice">"Alice"</A>
                <A href="bob">"Bob"</A>
                <A href="steve">"Steve"</A>
            </div>

            // <Outlet/> will show the nested child route
            // we can position this outlet wherever we want
            // within the layout
            <Outlet/>
        </div>
    }
}

#[component]
fn ContactInfo() -> impl IntoView {
    // we can access the :id param reactively with `use_params_map`
    let params = use_params_map();
    let id = move || params.read().get("id").unwrap_or_default();

    // imagine we're loading data from an API here
    let name = move || match id().as_str() {
        "alice" => "Alice",
        "bob" => "Bob",
        "steve" => "Steve",
        _ => "User not found.",
    };

    view! {
        <h4>{name}</h4>
        <div class="contact-info">
            <div class="tabs">
                <A href="" exact=true>"Contact Info"</A>
                <A href="conversations">"Conversations"</A>
            </div>

            // <Outlet/> here is the tabs that are nested
            // underneath the /contacts/:id route
            <Outlet/>
        </div>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>
