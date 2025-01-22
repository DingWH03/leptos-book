# `<Suspense/>`

在上一章中，我们展示了如何创建一个简单的加载屏幕，在资源加载时显示一个备用内容：

```rust
let (count, set_count) = signal(0);
let once = Resource::new(move || count.get(), |count| async move { load_a(count).await });

view! {
    <h1>"My Data"</h1>
    {move || match once.get() {
        None => view! { <p>"Loading..."</p> }.into_view(),
        Some(data) => view! { <ShowData data/> }.into_view()
    }}
}
```

但是，如果我们有两个资源，想要等它们都加载完毕怎么办？

```rust
let (count, set_count) = signal(0);
let (count2, set_count2) = signal(0);
let a = Resource::new(move || count.get(), |count| async move { load_a(count).await });
let b = Resource::new(move || count2.get(), |count| async move { load_b(count).await });

view! {
    <h1>"My Data"</h1>
    {move || match (a.get(), b.get()) {
        (Some(a), Some(b)) => view! {
            <ShowA a/>
            <ShowA b/>
        }.into_view(),
        _ => view! { <p>"Loading..."</p> }.into_view()
    }}
}
```

这虽然不是特别糟糕，但有些麻烦。如果我们能够反转控制流会怎么样呢？

[`<Suspense/>`](https://docs.rs/leptos/latest/leptos/suspense/fn.Suspense.html) 组件正是为此而设计的。你可以给它一个 `fallback` 属性和子节点，子节点中通常会读取某些资源。在 `<Suspense/>` 内读取资源会自动将该资源注册到 `<Suspense/>` 中。如果资源仍在加载中，它会显示 `fallback`，当所有资源加载完成后，它会显示子节点。

```rust
let (count, set_count) = signal(0);
let (count2, set_count2) = signal(0);
let a = Resource::new(count, |count| async move { load_a(count).await });
let b = Resource::new(count2, |count| async move { load_b(count).await });

view! {
    <h1>"My Data"</h1>
    <Suspense
        fallback=move || view! { <p>"Loading..."</p> }
    >
        <h2>"My Data"</h2>
        <h3>"A"</h3>
        {move || {
            a.get()
                .map(|a| view! { <ShowA a/> })
        }}
        <h3>"B"</h3>
        {move || {
            b.get()
                .map(|b| view! { <ShowB b/> })
        }}
    </Suspense>
}
```

每次其中一个资源重新加载时，`"Loading..."` 的备用内容会再次显示。

这种反转的控制流使得添加或移除单个资源更加简单，因为你不需要自己手动匹配。同时，它在服务器端渲染中也带来了巨大的性能提升（稍后章节会详细讨论）。

使用 `<Suspense/>` 还提供了一种直接对资源 `.await` 的便捷方式，这可以减少嵌套的复杂性。`Suspend` 类型允许我们创建一个可渲染的 `Future`，并将其用于视图中：

```rust
view! {
    <h1>"My Data"</h1>
    <Suspense
        fallback=move || view! { <p>"Loading..."</p> }
    >
        <h2>"My Data"</h2>
        {move || Suspend::new(async move {
            let a = a.await;
            let b = b.await;
            view! {
                <h3>"A"</h3>
                <ShowA a/>
                <h3>"B"</h3>
                <ShowB b/>
            }
        })}
    </Suspense>
}
```

`Suspend` 让我们不必对每个资源进行空值检查，同时简化了代码。

## `<Await/>`

如果你只是想等待某个 `Future` 解析后再渲染，可以使用 `<Await/>` 组件来减少样板代码。`<Await/>` 实际上是一个 `OnceResource` 和不带备用内容的 `<Suspense/>` 的组合。

换句话说：

1. 它只会轮询 `Future` 一次，不响应任何反应式变化。
2. 在 `Future` 解析之前不会渲染任何内容。
3. 当 `Future` 解析后，会将数据绑定到你选择的变量名，并在该变量范围内渲染其子节点。

```rust
async fn fetch_monkeys(monkey: i32) -> i32 {
    // 可能不需要异步，但作为示例
    monkey * 2
}
view! {
    <Await
        // `future` 提供要解析的 `Future`
        future=fetch_monkeys(3)
        // 数据会绑定到你提供的变量名
        let:data
    >
        // 你可以在这里通过引用使用该数据
        <p>{*data} " little monkeys, jumping on the bed."</p>
    </Await>
}
```

```admonish sandbox title="Live example" collapsible=true

[Click to open CodeSandbox.](https://codesandbox.io/p/devbox/11-suspense-0-7-sr2srk?file=%2Fsrc%2Fmain.rs%3A1%2C1-55%2C1)

<noscript>
  Please enable JavaScript to view examples.
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/11-suspense-0-7-sr2srk?file=%2Fsrc%2Fmain.rs%3A1%2C1-55%2C1" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox Source</summary>

```rust
use gloo_timers::future::TimeoutFuture;
use leptos::prelude::*;

async fn important_api_call(name: String) -> String {
    TimeoutFuture::new(1_000).await;
    name.to_ascii_uppercase()
}

#[component]
pub fn App() -> impl IntoView {
    let (name, set_name) = signal("Bill".to_string());

    // this will reload every time `name` changes
    let async_data = LocalResource::new(move || important_api_call(name.get()));

    view! {
        <input
            on:change:target=move |ev| {
                set_name.set(ev.target().value());
            }
            prop:value=name
        />
        <p><code>"name:"</code> {name}</p>
        <Suspense
            // the fallback will show whenever a resource
            // read "under" the suspense is loading
            fallback=move || view! { <p>"Loading..."</p> }
        >
            // Suspend allows you use to an async block in the view
            <p>
                "Your shouting name is "
                {move || Suspend::new(async move {
                    async_data.await
                })}
            </p>
        </Suspense>
        <Suspense
            // the fallback will show whenever a resource
            // read "under" the suspense is loading
            fallback=move || view! { <p>"Loading..."</p> }
        >
            // the children will be rendered once initially,
            // and then whenever any resources has been resolved
            <p>
                "Which should be the same as... "
                {move || async_data.get().as_deref().map(ToString::to_string)}
            </p>
        </Suspense>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>
