# 使用 Resources 加载数据

**Resources** 是用于异步任务的反应式封装，可以将异步的 `Future` 集成到同步的反应式系统中。它允许你加载异步数据，并以同步或异步的方式访问这些数据。你可以像普通的 `Future` 一样对资源使用 `.await`，这会对其进行追踪。你也可以使用 `.get()` 或其他信号访问方法访问资源，就像资源是一个返回 `Some(T)`（表示已完成）或 `None`（表示仍在等待）的信号一样。

Resources 主要有两种类型：`Resource` 和 `LocalResource`。如果你使用服务器端渲染（SSR，本书稍后会讨论），应默认使用 `Resource`。如果你使用的是仅客户端渲染（CSR）并依赖 `!Send` API（例如许多浏览器 API），或者尽管使用 SSR 但有些异步任务只能在浏览器上完成（例如访问异步浏览器 API），应使用 `LocalResource`。

## 本地资源（Local Resources）

`LocalResource::new()` 接受一个参数：一个返回 `Future` 的“fetcher”函数。

该 `Future` 可以是一个 `async` 块、`async fn` 调用的结果，或任何其他 Rust `Future`。其行为类似于派生信号或其他我们已见过的反应式闭包：你可以在其中读取信号，并且每当信号发生变化时，该函数都会重新运行，创建一个新的 `Future` 来执行。

```rust
// `count` 是我们的同步本地状态
let (count, set_count) = signal(0);

// 追踪 `count`，每当 `count` 变化时调用 `load_data`
let async_data = LocalResource::new(move || load_data(count.get()));
```

创建资源时会立即调用其 fetcher 并开始轮询 `Future`。在异步任务完成之前，读取资源会返回 `None`；任务完成后会通知其订阅者，返回 `Some(value)`。

你还可以对资源使用 `.await`。这看起来似乎没什么意义——为什么要创建一个 `Future` 的封装，然后再对它 `.await`？在接下来的章节中我们会看到原因。

## 资源（Resources）

如果你使用 SSR，大多数情况下应使用 `Resource` 而非 `LocalResource`。

此 API 略有不同。`Resource::new()` 接受两个函数作为参数：

1. **源函数**：包含输入内容。该输入会被 memoized（记忆化），每当其值变化时，会调用 fetcher。
2. **fetcher 函数**：从源函数中获取数据并返回一个 `Future`。

与 `LocalResource` 不同，`Resource` 会将其值从服务器序列化到客户端。随后，在客户端首次加载页面时，初始值会被反序列化，而不是重新运行异步任务。这非常重要且有用：这意味着在客户端 WASM 包加载并开始运行应用程序之前，数据加载已经在服务器上开始。（稍后章节会对此进行更多讨论。）

这也是 API 分为两部分的原因：*源函数*中的信号会被追踪，而 *fetcher* 中的信号不会被追踪，因为这允许资源在保持反应性的同时，在客户端首次加载时不需要重新运行 fetcher。

以下是使用 `Resource` 替代 `LocalResource` 的相同示例：

```rust
// `count` 是我们的同步本地状态
let (count, set_count) = signal(0);

// 我们的资源
let async_data = Resource::new(
    move || count.get(),
    // 每次 `count` 变化时运行此函数
    |count| load_data(count) 
);
```

Resources 还提供了一个 `refetch()` 方法，允许你手动重新加载数据（例如响应按钮点击）。

如果只需要运行一次的资源，可以使用 `OnceResource`，它接受一个 `Future` 并对只加载一次的情况进行了优化。

```rust
let once = OnceResource::new(load_data(42));
```

## 访问 Resources

`LocalResource` 和 `Resource` 都实现了多种信号访问方法（`.read()`、`.with()`、`.get()`），但返回的是 `Option<T>` 而不是 `T`；在异步数据加载完成之前，它们会返回 `None`。

`LocalResource` 实际上会返回一个 `Option<SendWrapper<T>>`，这是出于线程安全的要求；可以使用 `.as_deref()` 来访问内部类型（见下例）。

```admonish sandbox title="Live example" collapsible=true

[Click to open CodeSandbox.](https://codesandbox.io/p/devbox/10-resource-0-7-q5xr9m?file=%2Fsrc%2Fmain.rs%3A7%2C30)

<noscript>
  Please enable JavaScript to view examples.
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/10-resource-0-7-q5xr9m?file=%2Fsrc%2Fmain.rs%3A7%2C30" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox Source</summary>

```rust
use gloo_timers::future::TimeoutFuture;
use leptos::prelude::*;

// Here we define an async function
// This could be anything: a network request, database read, etc.
// Here, we just multiply a number by 10
async fn load_data(value: i32) -> i32 {
    // fake a one-second delay
    TimeoutFuture::new(1_000).await;
    value * 10
}

#[component]
pub fn App() -> impl IntoView {
    // this count is our synchronous, local state
    let (count, set_count) = signal(0);

    // tracks `count`, and reloads by calling `load_data`
    // whenever it changes
    let async_data = LocalResource::new(move || load_data(count.get()));

    // a resource will only load once if it doesn't read any reactive data
    let stable = LocalResource::new(|| load_data(1));

    // we can access the resource values with .get()
    // this will reactively return None before the Future has resolved
    // and update to Some(T) when it has resolved
    let async_result = move || {
        async_data
            .get()
            .as_deref()
            .map(|value| format!("Server returned {value:?}"))
            // This loading state will only show before the first load
            .unwrap_or_else(|| "Loading...".into())
    };

    view! {
        <button
            on:click=move |_| *set_count.write() += 1
        >
            "Click me"
        </button>
        <p>
            <code>"stable"</code>": " {move || stable.get().as_deref().copied()}
        </p>
        <p>
            <code>"count"</code>": " {count}
        </p>
        <p>
            <code>"async_value"</code>": "
            {async_result}
            <br/>
        </p>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>
