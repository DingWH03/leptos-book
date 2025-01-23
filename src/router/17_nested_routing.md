# 嵌套路由

我们刚刚定义了一组路由：

```rust
<Routes fallback=|| "Not found.">
  <Route path=path!("/") view=Home/>
  <Route path=path!("/users") view=Users/>
  <Route path=path!("/users/:id") view=UserProfile/>
  <Route path=path!("/*any") view=|| view! { <h1>"Not Found"</h1> }/>
</Routes>
```

这里有一点重复：`/users` 和 `/users/:id`。对于一个小应用来说，这样写没问题，但你可能已经意识到它的可扩展性并不好。如果我们能把这些路由做一个嵌套，会不会更好呢？

答案是：当然可以！

```rust
<Routes fallback=|| "Not found.">
  <Route path=path!("/") view=Home/>
  <ParentRoute path=path!("/users") view=Users>
    <Route path=path!(":id") view=UserProfile/>
  </ParentRoute>
  <Route path=path!("/*any") view=|| view! { <h1>"Not Found"</h1> }/>
</Routes>
```

我们可以把一个 `<Route/>` 放在 `<ParentRoute/>` 里面。看上去很直接。

但是要注意，这样做已经悄悄地改变了我们的应用行为。

接下来的内容是整个路由章节里最重要的部分之一。请仔细阅读，如果有任何不理解的地方，欢迎提问。

# 将嵌套路由视为布局

嵌套路由是一种布局（layout）方式，而不是定义路由的一种手段。

换句话说：定义嵌套路由的主要目的，并不是为了在路由定义里少写一点重复的路径字符串，而是为了告诉路由器在页面上同时、并列地显示多个 `<Route/>` 组件。

让我们再看一下之前的例子。

```rust
<Routes fallback=|| "Not found.">
  <Route path=path!("/users") view=Users/>
  <Route path=path!("/users/:id") view=UserProfile/>
</Routes>
```

这意味着：

- 当我访问 `/users` 时，会匹配 `<Users/>` 组件。
- 当我访问 `/users/3` 时，会匹配 `<UserProfile/>` 组件（并将 `id` 参数设置为 `3`，后面会详细介绍如何获取参数）。

如果我用嵌套路由来替换它：

```rust
<Routes fallback=|| "Not found.">
  <ParentRoute path=path!("/users") view=Users>
    <Route path=path!(":id") view=UserProfile/>
  </ParentRoute>
</Routes>
```

这意味着：

- 当我访问 `/users/3` 时，路径实际上会匹配两个 `<Route/>`：`<Users/>` 和 `<UserProfile/>`。
- 当我访问 `/users` 时，其实并没有被匹配到任何路由。

所以，我需要添加一个回退路由（fallback）：

```rust
<Routes>
  <Route path="/users" view=Users>
    <Route path=":id" view=UserProfile/>
    <Route path="" view=NoUser/>
  </Route>
</Routes>
```

这样一来：

- 当我访问 `/users/3` 时，会匹配到 `<Users/>` 和 `<UserProfile/>`。
- 当我访问 `/users` 时，会匹配到 `<Users/>` 和 `<NoUser/>`。

换句话说，当使用嵌套路由时，每个**路径**可能会匹配到多个**路由**：同一个 URL 可以同时渲染多个 `<Route/>` 组件提供的视图，并且它们会在同一个页面上一起显示。

这可能有些反直觉，但是它在某些场景中非常强大，原因你很快就会见到。

## 为什么要使用嵌套路由？

这么折腾是为了什么？

大多数 Web 应用都有层级式的导航结构，对应不同的布局区域。比如，在一个电子邮件应用中，可能有一个 URL `/contacts/greg`，用来在屏幕左侧显示联系人列表，右侧显示名为 Greg 的联系人的详情。联系人列表和联系人的详细信息应该始终同时显示在屏幕上。如果没有选择任何联系人，你或许想在右侧显示一段提示文字。

使用嵌套路由，可以很轻松地实现：

```rust
<Routes fallback=|| "Not found.">
  <ParentRoute path=path!("/contacts") view=ContactList>
    <Route path=path!(":id") view=ContactInfo/>
    <Route path=path!("") view=|| view! {
      <p>"Select a contact to view more info."</p>
    }/>
  </ParentRoute>
</Routes>
```

你还可以继续深入嵌套。假设你想在某个联系人详情页里再分标签页，比如地址、邮箱/电话、以及与该联系人的会话记录。可以在 `:id` 下再添加**另一层**嵌套路由：

```rust
<Routes fallback=|| "Not found.">
  <ParentRoute path=path!("/contacts") view=ContactList>
    <ParentRoute path=path!(":id") view=ContactInfo>
      <Route path=path!("") view=EmailAndPhone/>
      <Route path=path!("address") view=Address/>
      <Route path=path!("messages") view=Messages/>
    </ParentRoute>
    <Route path=path!("") view=|| view! {
      <p>"Select a contact to view more info."</p>
    }/>
  </ParentRoute>
</Routes>
```

> 如果你访问 [Remix 官网](https://remix.run/)（由 React Router 的开发者创建的 React 框架），主页有一个非常直观的例子，你往下滚动会看到三层嵌套路由：Sales > Invoices > 具体的 invoice。

## `<Outlet/>`

父路由（`<ParentRoute/>` 或者 `<Route>` 里再嵌套路由）并不会自动渲染它们的嵌套子路由。毕竟，父级只是一个普通组件，不知道确切应该在哪里渲染它的子组件。而“把子组件贴在父组件结尾”也并不是一个好方案。

相反，你需要通过 `<Outlet/>` 组件告诉父组件应该在哪里渲染嵌套路由。`<Outlet/>` 的逻辑非常简单：

- 如果没有匹配到任何子路由，就不渲染任何内容
- 如果匹配到了子路由，就渲染该子路由对应的视图

就这么简单！但这点非常重要，也是很多 “为什么渲染不出来？” 问题的来源。如果你没有放一个 `<Outlet/>`，那么对应的嵌套路由自然也不会显示。

```rust
#[component]
pub fn ContactList() -> impl IntoView {
  let contacts = todo!();

  view! {
    <div style="display: flex">
      // 左侧联系人列表
      <For each=contacts
        key=|contact| contact.id
        children=|contact| todo!()
      />
      // 如果有匹配到子路由，就在右侧渲染相应内容
      // 别忘了这个 <Outlet/>！
      <Outlet/>
    </div>
  }
}
```

## 重构路由定义

如果你愿意，不必把所有的路由都定义在同一个地方。任何 `<Route/>` 及其子组件都可以被提取到单独的组件中去。

例如，可以把上面这个示例重构成两个单独的组件：

```rust
#[component]
pub fn App() -> impl IntoView {
    view! {
      <Router>
        <Routes fallback=|| "Not found.">
          <Route path=path!("/contacts") view=ContactList>
            <ContactInfoRoutes/>
            <Route path=path!("") view=|| view! {
              <p>"Select a contact to view more info."</p>
            }/>
          </Route>
        </Routes>
      </Router>
    }
}

#[component(transparent)]
fn ContactInfoRoutes() -> impl MatchNestedRoutes + Clone {
    view! {
      <ParentRoute path=path!(":id") view=ContactInfo>
        <Route path=path!("") view=EmailAndPhone/>
        <Route path=path!("address") view=Address/>
        <Route path=path!("messages") view=Messages/>
      </ParentRoute>
    }
    .into_inner()
}
```

第二个组件使用了 `#[component(transparent)]`，这意味着它仅仅返回数据，而不返回视图；同时，它使用 `.into_inner()` 来去除由 `view` 宏添加的调试信息，只返回 `<ParentRoute/>` 创建的路由定义。

## 嵌套路由与性能

到此为止，概念上都很不错，但它的真正价值在哪里？

答案是：性能。

在像 Leptos 这样基于细粒度响应式的库中，始终要尽量减少渲染的工作量。因为我们直接使用真实的 DOM，而不是对虚拟 DOM 进行 diff，我们希望尽可能少地 “重新渲染” 组件。嵌套路由会让这件事变得非常简单。

想象一下上面的联系人示例：当我在联系人间切换（Greg → Alice → Bob → Greg），右侧的联系人信息需要改变，但 `<ContactList/>` 组件本身却**不需要**重新渲染。这样不仅节省了渲染性能，也能保留 UI 状态。比如在 `<ContactList/>` 顶部可能有个搜索框，切换联系人时也不会清空搜索内容。

实际上，在这种情况下，导航联系人时也不需要让 `<Contact/>` 组件重新渲染。路由器会在导航过程中响应式地更新 `:id` 参数，我们只需进行一些细粒度的更新即可。当在不同联系人间切换时，只会更新文本节点来改变联系人姓名、地址等信息，**而不需要进行额外的任何整体重新渲染**。

> 这里的示例 sandbox 中包含了本节和上一节讨论的一些特性（比如嵌套路由），以及我们在本章后续部分会提到的一些特性。由于路由器系统是一个整体，所以我们选择使用一个示例来综合展示。如果有任何地方你看不太懂，也不用惊讶。可以先了解大概思路，再继续往后看。

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
