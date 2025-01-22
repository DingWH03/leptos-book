# 使用 Actions 修改数据

我们已经讨论了如何使用资源（resources）加载 `async` 数据。资源会立即加载数据，并与 `<Suspense/>` 和 `<Transition/>` 组件紧密配合，显示应用程序中的数据加载状态。但如果你只想调用一些任意的 `async` 函数并跟踪它的状态，该怎么办？

当然，你可以使用 [`spawn_local`](https://docs.rs/leptos/latest/leptos/task/fn.spawn_local.html)。它允许你在同步环境中启动一个 `async` 任务，将 `Future` 提交给浏览器（或服务器上的 Tokio 或其他运行时）。但是，你怎么知道任务是否仍在进行中呢？你可以设置一个信号来显示加载状态，再设置另一个信号来存储结果……

这些当然可以做到。但你也可以使用最后一个异步原语：[`Action`](https://docs.rs/leptos/latest/leptos/reactive/actions/struct.Action.html)。

**Actions** 和资源看起来相似，但它们本质上是不同的。如果你试图通过运行 `async` 函数加载数据（无论是一次性还是随着某个值的变化），你可能需要用资源。如果你试图响应用户点击按钮等事件偶尔运行 `async` 函数，那么你可能需要用 Action。

假设我们有一个 `async` 函数需要运行：

```rust
async fn add_todo_request(new_title: &str) -> Uuid {
    /* 在服务器上添加一个新的 todo */
}
```

`Action::new()` 接受一个 `async` 函数作为参数，该函数需要一个引用作为输入（“输入类型”）。

> 输入总是一个单一类型。如果需要传递多个参数，可以使用结构体或元组。
>
> ```rust
> // 单一参数
> let action1 = Action::new(|input: &String| {
>    let input = input.clone();
>    async move { todo!() }
> });
>
> // 无参数
> let action2 = Action::new(|input: &()| async { todo!() });
>
> // 多个参数
> let action3 = Action::new(
>   |input: &(usize, String)| async { todo!() }
> );
> ```
>
> 因为 Action 函数接受引用，但 `Future` 需要 `'static` 生命周期，所以通常需要克隆值以传递给 `Future`。虽然这有些麻烦，但它解锁了一些强大的功能，比如乐观 UI。我们将在后续章节中详细介绍。

在这个例子中，我们可以这样创建一个 Action：

```rust
let add_todo_action = Action::new(|input: &String| {
    let input = input.to_owned();
    async move { add_todo_request(&input).await }
});
```

与直接调用 `add_todo_action` 不同，我们会使用 `.dispatch()` 调用它，例如：

```rust
add_todo_action.dispatch("Some value".to_string());
```

你可以在事件监听器、定时器或任何地方调用它；因为 `.dispatch()` 不是一个异步函数，所以可以在同步上下文中调用。

**Actions 提供了一些信号，可以在调用异步操作和同步反应式系统之间进行同步：**

```rust
let submitted = add_todo_action.input(); // RwSignal<Option<String>>
let pending = add_todo_action.pending(); // ReadSignal<bool>
let todo_id = add_todo_action.value(); // RwSignal<Option<Uuid>>
```

这些信号让你可以轻松跟踪请求的当前状态、显示加载指示器或基于提交成功的假设实现“乐观 UI”。

```rust
let input_ref = NodeRef::<Input>::new();

view! {
    <form
        on:submit=move |ev| {
            ev.prevent_default(); // 阻止页面刷新
            let input = input_ref.get().expect("input to exist");
            add_todo_action.dispatch(input.value());
        }
    >
        <label>
            "What do you need to do?"
            <input type="text"
                node_ref=input_ref
            />
        </label>
        <button type="submit">"Add Todo"</button>
    </form>
    // 显示加载状态
    <p>{move || pending.get().then_some("Loading...")}</p>
}
```

也许你觉得这一切有些复杂，或者过于受限。我在这里介绍 Actions，与资源一起补全了反应式系统的功能拼图。在一个真正的 Leptos 应用中，你会经常将 Actions 与服务器函数 [`ServerAction`](https://docs.rs/leptos/latest/leptos/server/struct.ServerAction.html) 以及 [`<ActionForm/>`](https://docs.rs/leptos/latest/leptos/form/fn.ActionForm.html) 组件结合使用，从而创建功能强大的渐进增强表单。如果你现在觉得这个原语没什么用……不用担心！以后你可能会理解它的价值。（或者现在就查看我们的 [`todo_app_sqlite`](https://github.com/leptos-rs/leptos/blob/main/examples/todo_app_sqlite/src/todo.rs) 示例。）

```admonish sandbox title="Live example" collapsible=true

[Click to open CodeSandbox.](https://codesandbox.io/p/devbox/13-action-0-7-g73rl9?file=%2Fsrc%2Fmain.rs)

<noscript>
  Please enable JavaScript to view examples.
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/13-action-0-7-g73rl9?file=%2Fsrc%2Fmain.rs" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox Source</summary>

```rust
use gloo_timers::future::TimeoutFuture;
use leptos::{html::Input, prelude::*};
use uuid::Uuid;

// Here we define an async function
// This could be anything: a network request, database read, etc.
// Think of it as a mutation: some imperative async action you run,
// whereas a resource would be some async data you load
async fn add_todo(text: &str) -> Uuid {
    _ = text;
    // fake a one-second delay
    // SendWrapper allows us to use this !Send browser API; don't worry about it
    send_wrapper::SendWrapper::new(TimeoutFuture::new(1_000)).await;
    // pretend this is a post ID or something
    Uuid::new_v4()
}

#[component]
pub fn App() -> impl IntoView {
    // an action takes an async function with single argument
    // it can be a simple type, a struct, or ()
    let add_todo = Action::new(|input: &String| {
        // the input is a reference, but we need the Future to own it
        // this is important: we need to clone and move into the Future
        // so it has a 'static lifetime
        let input = input.to_owned();
        async move { add_todo(&input).await }
    });

    // actions provide a bunch of synchronous, reactive variables
    // that tell us different things about the state of the action
    let submitted = add_todo.input();
    let pending = add_todo.pending();
    let todo_id = add_todo.value();

    let input_ref = NodeRef::<Input>::new();

    view! {
        <form
            on:submit=move |ev| {
                ev.prevent_default(); // don't reload the page...
                let input = input_ref.get().expect("input to exist");
                add_todo.dispatch(input.value());
            }
        >
            <label>
                "What do you need to do?"
                <input type="text"
                    node_ref=input_ref
                />
            </label>
            <button type="submit">"Add Todo"</button>
        </form>
        <p>{move || pending.get().then_some("Loading...")}</p>
        <p>
            "Submitted: "
            <code>{move || format!("{:#?}", submitted.get())}</code>
        </p>
        <p>
            "Pending: "
            <code>{move || format!("{:#?}", pending.get())}</code>
        </p>
        <p>
            "Todo ID: "
            <code>{move || format!("{:#?}", todo_id.get())}</code>
        </p>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>
