# 响应和重定向

提取器（Extractors）为服务器函数提供了一种轻松访问请求数据的方式。而 Leptos 还提供了一种修改 HTTP 响应的方式，通过使用 `ResponseOptions` 类型（查看 [Actix 文档](https://docs.rs/leptos_actix/latest/leptos_actix/struct.ResponseOptions.html) 或 [Axum 文档](https://docs.rs/leptos_axum/latest/leptos_axum/struct.ResponseOptions.html)），以及 `redirect` 辅助函数（查看 [Actix 文档](https://docs.rs/leptos_actix/latest/leptos_actix/fn.redirect.html) 或 [Axum 文档](https://docs.rs/leptos_axum/latest/leptos_axum/fn.redirect.html)）。

## `ResponseOptions`

`ResponseOptions` 在服务器初次渲染响应期间，以及在任何后续的服务器函数调用中，都会通过上下文（context）提供。它允许你轻松设置 HTTP 响应的状态码，或向 HTTP 响应中添加头部（例如设置 cookie）。

```rust
#[server]
pub async fn tea_and_cookies() -> Result<(), ServerFnError> {
    use actix_web::{
        cookie::Cookie,
        http::header::HeaderValue,
        http::{header, StatusCode},
    };
    use leptos_actix::ResponseOptions;

    // 从上下文中获取 ResponseOptions
    let response = expect_context::<ResponseOptions>();

    // 设置 HTTP 状态码
    response.set_status(StatusCode::IM_A_TEAPOT);

    // 在 HTTP 响应中设置一个 cookie
    let cookie = Cookie::build("biscuits", "yes").finish();
    if let Ok(cookie) = HeaderValue::from_str(&cookie.to_string()) {
        response.insert_header(header::SET_COOKIE, cookie);
    }
    Ok(())
}
```

## `redirect`

HTTP 响应中一个常见的修改是重定向到另一个页面。Actix 和 Axum 的集成提供了一个 `redirect` 函数，使这个过程变得非常简单。

```rust
#[server]
pub async fn login(
    username: String,
    password: String,
    remember: Option<String>,
) -> Result<(), ServerFnError> {
    // 从上下文中获取数据库连接池和认证提供者
    let pool = pool()?;
    let auth = auth()?;

    // 检查用户是否存在
    let user: User = User::get_from_username(username, &pool)
        .await
        .ok_or_else(|| {
            ServerFnError::ServerError("User does not exist.".into())
        })?;

    // 检查用户提供的密码是否正确
    match verify(password, &user.password)? {
        // 如果密码正确...
        true => {
            // 登录用户
            auth.login_user(user.id);
            auth.remember_user(remember.is_some());

            // 并重定向到主页
            leptos_axum::redirect("/");
            Ok(())
        }
        // 如果密码不正确，则返回错误
        false => Err(ServerFnError::ServerError(
            "Password does not match.".to_string(),
        )),
    }
}
```

这个服务器函数可以在你的应用中直接使用。`redirect` 辅助函数与 `<ActionForm/>` 组件的渐进增强功能兼容：在没有 JS/WASM 的情况下，服务器响应会通过状态码和头部完成重定向；而在启用 JS/WASM 的情况下，`<ActionForm/>` 会检测到服务器函数响应中的重定向，并通过客户端导航跳转到新的页面。