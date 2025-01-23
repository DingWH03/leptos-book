# 定义路由

## 入门

使用路由器非常简单。

首先，请确保已将 `leptos_router` 包添加到你的依赖项中。与 `leptos` 不同，该包没有单独的 `csr` 和 `hydrate` 功能；但它确实有一个仅供服务器端使用的 `ssr` 功能，因此请在服务器端构建时激活该功能。

> 路由器是一个独立于 `leptos` 的包，这一点非常重要。这意味着路由器中的所有内容都可以用用户代码定义。如果你想创建自己的路由器，或者根本不使用路由器，完全可以自由地做到这一点！

接着从路由器中导入相关类型，例如：

```rust
use leptos_router::components::{Router, Route, Routes};
```

## 提供 `<Router/>`

路由行为是由 [`<Router/>`](https://docs.rs/leptos_router/latest/leptos_router/components/fn.Router.html) 组件提供的。它通常位于应用程序的根部附近，包裹住应用的其余部分。

> 不应该在应用中使用多个 `<Router/>`。请记住，路由器驱动全局状态：如果有多个路由器，当 URL 发生变化时，哪个路由器来决定行为？

以下是一个使用路由器的简单 `<App/>` 组件示例：

```rust
use leptos::prelude::*;
use leptos_router::components::Router;

#[component]
pub fn App() -> impl IntoView {
    view! {
      <Router>
        <nav>
          /* ... */
        </nav>
        <main>
          /* ... */
        </main>
      </Router>
    }
}
```

## 定义 `<Routes/>`

[`<Routes/>`](https://docs.rs/leptos_router/latest/leptos_router/components/fn.Routes.html) 组件是定义用户在应用程序中可以导航到的所有路由的地方。每个可能的路由由 [`<Route/>`](https://docs.rs/leptos_router/latest/leptos_router/components/fn.Route.html) 组件定义。

你应该将 `<Routes/>` 组件放置在应用程序中希望渲染路由的位置。`<Routes/>` 之外的内容会出现在每个页面上，因此像导航栏或菜单这样的内容可以留在 `<Routes/>` 之外。

```rust
use leptos::prelude::*;
use leptos_router::components::*;

#[component]
pub fn App() -> impl IntoView {
    view! {
      <Router>
        <nav>
          /* ... */
        </nav>
        <main>
          // 所有的路由都会出现在 <main> 中
          <Routes fallback=|| "Not found.">
            /* ... */
          </Routes>
        </main>
      </Router>
    }
}
```

`<Routes/>` 还应该有一个 `fallback`，即一个函数，当没有路由匹配时定义应该显示的内容。

单个路由是通过为 `<Routes/>` 提供子组件 `<Route/>` 来定义的。`<Route/>` 接受一个 `path` 和一个 `view`。当当前的位置匹配 `path` 时，将创建并显示 `view`。

`path` 最简单的定义方式是使用 `path!` 宏，它可以包括：

- 静态路径（例如：`/users`），
- 以冒号开头的动态命名参数（例如：`/:id`），
- 和/或以星号开头的通配符（例如：`/user/*any`）。

`view` 是一个返回视图的函数。任何没有属性的组件或返回视图的闭包都可以在这里使用。

```rust
<Routes fallback=|| "Not found.">
  <Route path=path!("/") view=Home/>
  <Route path=path!("/users") view=Users/>
  <Route path=path!("/users/:id") view=UserProfile/>
  <Route path=path!("/*any") view=|| view! { <h1>"Not Found"</h1> }/>
</Routes>
```

> `view` 接受一个 `Fn() -> impl IntoView`。如果组件没有属性，可以直接传递给 `view`。例如，`view=Home` 是 `|| view! { <Home/> }` 的简写。

现在，如果你导航到 `/` 或 `/users`，将会看到主页或 `<Users/>`。如果你访问 `/users/3` 或 `/blahblah`，将会显示用户简介或 404 页面 (`<NotFound/>`)。每次导航时，路由器都会决定匹配哪个 `<Route/>`，从而在 `<Routes/>` 组件定义的位置显示相应内容。

够简单吧？
