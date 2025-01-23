# `<ActionForm/>`

[`<ActionForm/>`](https://docs.rs/leptos/latest/leptos/form/fn.ActionForm.html) 是一个特殊的 `<Form/>`，可以接收服务器操作，并在表单提交时自动调用它。这使得你可以直接从 `<form>` 调用服务器函数，即使没有启用 JS/WASM 也能运行。

实现过程非常简单：

1. 使用 [`#[server]` 宏](https://docs.rs/leptos/latest/leptos/attr.server.html) 定义一个服务器函数（详见 [服务器函数](../server/25_server_functions.md)）。
2. 使用 [`ServerAction::new()`](https://docs.rs/leptos/latest/leptos/server/struct.ServerAction.html) 创建一个操作，指定你定义的服务器函数的类型。
3. 创建一个 `<ActionForm/>`，并在 `action` 属性中提供服务器操作。
4. 将服务器函数的命名参数作为表单字段，并确保名称一致。

> **注意：** `<ActionForm/>` 仅支持服务器函数默认的 URL 编码 `POST` 格式，以确保作为 HTML 表单的正常行为和优雅降级。

```rust
#[server]
pub async fn add_todo(title: String) -> Result<(), ServerFnError> {
    todo!()
}

#[component]
fn AddTodo() -> impl IntoView {
    let add_todo = ServerAction::<AddTodo>::new();
    // 保存服务器返回的最新值
    let value = add_todo.value();
    // 检查服务器是否返回错误
    let has_error = move || value.with(|val| matches!(val, Some(Err(_))));

    view! {
        <ActionForm action=add_todo>
            <label>
                "Add a Todo"
                // `title` 参数名称应与 `add_todo` 的参数一致
                <input type="text" name="title"/>
            </label>
            <input type="submit" value="Add"/>
        </ActionForm>
    }
}
```

就是这么简单！如果启用了 JS/WASM，表单会在不重新加载页面的情况下提交，将最近一次的提交值存储在操作的 `.input()` 信号中，并通过 `.pending()` 获取提交状态等。（如果需要，可以查看 [`Action`](https://docs.rs/leptos/latest/leptos/reactive/actions/struct.Action.html) 文档以了解更多内容。）如果没有 JS/WASM，表单将通过页面刷新提交。如果调用了 `redirect` 函数（来自 `leptos_axum` 或 `leptos_actix`），它会正确跳转到指定页面。默认情况下，表单会重定向回当前页面。HTML、HTTP 和同构渲染的强大功能使得 `<ActionForm/>` 即使没有 JS/WASM 也能正常工作。

## 客户端验证

因为 `<ActionForm/>` 只是一个 `<form>`，它会触发 `submit` 事件。你可以使用 HTML 验证，或者通过 `on:submit` 添加自定义客户端验证逻辑。调用 `ev.prevent_default()` 可以阻止提交。

[`FromFormData`](https://docs.rs/leptos/latest/leptos/form/trait.FromFormData.html) trait 可以帮助解析提交表单中的服务器函数参数类型。

```rust
let on_submit = move |ev| {
	let data = AddTodo::from_event(&ev);
	// 简单的验证示例：如果任务为 "nope!"，则阻止提交
	if data.is_err() || data.unwrap().title == "nope!" {
		// ev.prevent_default() 会阻止表单提交
		ev.prevent_default();
	}
}
```

```admonish warning
此模式在 0.7 版本中由于事件委托的更改暂时不可用。如果你需要使用此功能，可以在 `Cargo.toml` 中为 `leptos` crate 启用 `delegation` 功能。[阅读此问题](https://github.com/leptos-rs/leptos/issues/3457)以获取更多背景信息。
```

## 复杂输入

服务器函数的参数如果是具有嵌套可序列化字段的结构体，应使用 `serde_qs` 的索引表示法。

```rust
#[derive(serde::Serialize, serde::Deserialize, Debug, Clone)]
struct HeftyData {
    first_name: String,
    last_name: String,
}

#[component]
fn ComplexInput() -> impl IntoView {
    let submit = ServerAction::<VeryImportantFn>::new();

    view! {
      <ActionForm action=submit>
        <input type="text" name="hefty_arg[first_name]" value="leptos"/>
        <input
          type="text"
          name="hefty_arg[last_name]"
          value="closures-everywhere"
        />
        <input type="submit"/>
      </ActionForm>
    }
}

#[server]
async fn very_important_fn(hefty_arg: HeftyData) -> Result<(), ServerFnError> {
    assert_eq!(hefty_arg.first_name.as_str(), "leptos");
    assert_eq!(hefty_arg.last_name.as_str(), "closures-everywhere");
    Ok(())
}
```
