# 提取器（Extractors）

上一章的服务器函数展示了如何在服务器上运行代码，并将其与浏览器中渲染的用户界面集成。但它们并没有深入展示如何充分利用服务器的潜力。

## 服务器框架

我们称 Leptos 为“全栈”框架，但“全栈”总是有些夸大（毕竟，它并不意味着覆盖从浏览器到你的电力公司的所有层面）。对我们来说，“全栈”意味着你的 Leptos 应用可以在浏览器中运行，也可以在服务器上运行，并且可以将两者整合在一起，充分利用每一方的独特特性。正如我们在本书中看到的那样，浏览器中的一个按钮点击可以驱动服务器上的数据库读取，而这一切都可以写在同一个 Rust 模块中。但 Leptos 本身并不提供服务器（也不提供数据库、操作系统、固件或电缆...）。

相反，Leptos 提供了与 Rust 最流行的两个 Web 服务器框架的集成：Actix Web（[`leptos_actix`](https://docs.rs/leptos_actix/latest/leptos_actix/)）和 Axum（[`leptos_axum`](https://docs.rs/leptos_axum/latest/leptos_axum/)）。我们为每个服务器的路由器构建了集成，使你可以通过 `.leptos_routes()` 简单地将 Leptos 应用接入现有服务器，并轻松处理服务器函数调用。

> 如果你还没有查看我们的 [Actix 模板](https://github.com/leptos-rs/start) 和 [Axum 模板](https://github.com/leptos-rs/start-axum)，现在是个好时机去看看。

## 使用提取器

Actix 和 Axum 的处理程序基于相同的强大理念：**提取器（extractors）**。提取器从 HTTP 请求中“提取”类型化数据，使你可以轻松访问与服务器相关的数据。

Leptos 提供了 `extract` 辅助函数，允许你在服务器函数中直接使用这些提取器，并提供了类似于每个框架处理程序的便捷语法。

### Actix 提取器

[`leptos_actix` 中的 `extract` 函数](https://docs.rs/leptos_actix/latest/leptos_actix/fn.extract.html) 将处理程序函数作为参数。处理程序遵循与 Actix 处理程序类似的规则：它是一个异步函数，接收从请求中提取的参数，并返回一些值。处理程序函数将提取到的数据作为其参数，并可以在 `async move` 块中对其进行进一步异步操作。函数返回的值会被返回到服务器函数中。

```rust
use serde::Deserialize;

#[derive(Deserialize, Debug)]
struct MyQuery {
    foo: String,
}

#[server]
pub async fn actix_extract() -> Result<String, ServerFnError> {
    use actix_web::dev::ConnectionInfo;
    use actix_web::web::Query;
    use leptos_actix::extract;

    let (Query(search), connection): (Query<MyQuery>, ConnectionInfo) = extract().await?;
    Ok(format!("search = {search:?}\nconnection = {connection:?}",))
}
```

### Axum 提取器

[`leptos_axum::extract`](https://docs.rs/leptos_axum/latest/leptos_axum/fn.extract.html) 函数的语法非常类似。

```rust
use serde::Deserialize;

#[derive(Deserialize, Debug)]
struct MyQuery {
    foo: String,
}

#[server]
pub async fn axum_extract() -> Result<String, ServerFnError> {
    use axum::{extract::Query, http::Method};
    use leptos_axum::extract;

    let (method, query): (Method, Query<MyQuery>) = extract().await?;

    Ok(format!("{method:?} and {query:?}"))
}
```

这些是访问服务器基本数据的简单示例。但你可以使用提取器访问诸如请求头、cookies、数据库连接池等内容，使用的方式与上述 `extract()` 模式完全相同。

Axum 的 `extract` 函数仅支持状态为 `()` 的提取器。如果你需要一个使用 `State` 的提取器，可以使用 [`extract_with_state`](https://docs.rs/leptos_axum/latest/leptos_axum/fn.extract_with_state.html)。这需要你提供状态，可以通过使用 Axum 的 `FromRef` 模式扩展现有的 `LeptosOptions` 状态，并在渲染和服务器函数期间通过上下文提供状态。

```rust
use axum::extract::FromRef;

/// 使用 Axum 的子状态模式派生 FromRef，以允许状态包含多个条目。
#[derive(FromRef, Debug, Clone)]
pub struct AppState{
    pub leptos_options: LeptosOptions,
    pub pool: SqlitePool
}
```

[点击这里查看在自定义处理程序中提供上下文的示例](https://github.com/leptos-rs/leptos/blob/19ea6fae6aec2a493d79cc86612622d219e6eebb/examples/session_auth_axum/src/main.rs#L24-L44)。

#### Axum 状态

Axum 的典型依赖注入模式是提供一个 `State`，然后在路由处理程序中提取它。Leptos 提供了一种通过上下文进行依赖注入的方法。上下文通常可以代替 `State` 来提供共享的服务器数据（例如，一个数据库连接池）。

```rust
let connection_pool = /* 一些共享状态 */;

let app = Router::new()
    .leptos_routes_with_context(
        &app_state,
        routes,
        move || provide_context(connection_pool.clone()),
        App,
    )
    // 其他配置
```

然后可以在服务器函数中使用简单的 `use_context::<T>()` 来访问此上下文。

如果在服务器函数中**必须**使用 `State`——例如，你有一个现有的 Axum 提取器需要 `State`——也可以通过 Axum 的 [`FromRef`](https://docs.rs/axum/latest/axum/extract/derive.FromRef.html) 模式和 [`extract_with_state`](https://docs.rs/leptos_axum/latest/leptos_axum/fn.extract_with_state.html) 实现。这需要你同时通过上下文和 Axum 路由状态提供状态：

```rust
#[derive(FromRef, Debug, Clone)]
pub struct MyData {
    pub value: usize,
    pub leptos_options: LeptosOptions,
}

let app_state = MyData {
    value: 42,
    leptos_options,
};

// 构建我们的应用
let app = Router::new()
    .leptos_routes_with_context(
        &app_state,
        routes,
        {
            let app_state = app_state.clone();
            move || provide_context(app_state.clone())
        },
        App,
    )
    .fallback(file_and_error_handler)
    .with_state(app_state);

// ...
#[server]
pub async fn uses_state() -> Result<(), ServerFnError> {
    let state = expect_context::<AppState>();
    let SomeStateExtractor(data) = extract_with_state(&state).await?;
    // todo
}
```

## 关于数据加载模式的说明

因为 Actix 和（尤其是）Axum 是基于单次 HTTP 请求和响应的模型构建的，因此你通常会在应用的“顶部”运行提取器（即在渲染之前），并使用提取到的数据来决定如何渲染。在渲染 `<button>` 之前，你会加载应用可能需要的所有数据。而任何给定的路由处理程序都需要知道该路由需要提取的所有数据。

但 Leptos 同时集成了客户端和服务器，因此能够刷新 UI 的小片段而无需完全重新加载所有数据非常重要。Leptos 更喜欢将数据加载“向下推”，尽量靠近用户界面的叶子节点。当你点击一个 `<button>` 时，它可以只刷新它需要的数据。这正是服务器函数的用途：它们让你能够以细粒度访问需要加载和重新加载的数据。

`extract()` 函数允许你通过在服务器函数中使用提取器，结合这两种模型。你可以获得路由提取器的全部功能，同时将提取需求分散到单个组件，从而更容易重构和重新组织路由，无需提前指定路由所需的所有数据。
