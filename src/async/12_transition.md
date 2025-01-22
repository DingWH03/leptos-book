# `<Transition/>`

在 `<Suspense/>` 的示例中，如果你不断重新加载数据，界面会反复闪回到 `"Loading..."`。有时这没问题，但在某些情况下，可以使用 [`<Transition/>`](https://docs.rs/leptos/latest/leptos/suspense/fn.Transition.html)。

`<Transition/>` 的行为与 `<Suspense/>` 完全相同，但不同之处在于，它只在第一次加载时显示备用内容。在后续加载时，它会继续显示旧数据，直到新数据加载完成。这对于避免闪烁效果并允许用户继续与应用程序交互非常有用。

以下示例展示了如何使用 `<Transition/>` 创建一个简单的选项卡式联系人列表。当你选择一个新选项卡时，界面会继续显示当前联系人，直到新数据加载完成。这比反复显示加载消息提供了更好的用户体验。

```admonish sandbox title="Live example" collapsible=true

[Click to open CodeSandbox.](https://codesandbox.io/p/devbox/12-transition-0-7-ln2hgd?file=%2Fsrc%2Fmain.rs%3A1%2C1-69%2C1&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb)

<noscript>
  Please enable JavaScript to view examples.
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/12-transition-0-7-ln2hgd?file=%2Fsrc%2Fmain.rs%3A1%2C1-69%2C1&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox Source</summary>

```rust
use gloo_timers::future::TimeoutFuture;
use leptos::prelude::*;

async fn important_api_call(id: usize) -> String {
    TimeoutFuture::new(1_000).await;
    match id {
        0 => "Alice",
        1 => "Bob",
        2 => "Carol",
        _ => "User not found",
    }
    .to_string()
}

#[component]
fn App() -> impl IntoView {
    let (tab, set_tab) = signal(0);
    let (pending, set_pending) = signal(false);

    // this will reload every time `tab` changes
    let user_data = LocalResource::new(move || important_api_call(tab.get()));

    view! {
        <div class="buttons">
            <button
                on:click=move |_| set_tab.set(0)
                class:selected=move || tab.get() == 0
            >
                "Tab A"
            </button>
            <button
                on:click=move |_| set_tab.set(1)
                class:selected=move || tab.get() == 1
            >
                "Tab B"
            </button>
            <button
                on:click=move |_| set_tab.set(2)
                class:selected=move || tab.get() == 2
            >
                "Tab C"
            </button>
        </div>
        <p>
            {move || if pending.get() {
                "Hang on..."
            } else {
                "Ready."
            }}
        </p>
        <Transition
            // the fallback will show initially
            // on subsequent reloads, the current child will
            // continue showing
            fallback=move || view! { <p>"Loading initial data..."</p> }
            // this will be set to `true` whenever the transition is ongoing
            set_pending
        >
            <p>
                {move || user_data.read().as_deref().map(ToString::to_string)}
            </p>
        </Transition>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>
