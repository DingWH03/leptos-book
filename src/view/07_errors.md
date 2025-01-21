# 错误处理

[在上一章](./06_control_flow.md)，我们看到可以渲染 `Option<T>`：对于 `None` 情况，它会渲染空内容；对于 `Some(T)` 情况，它会渲染 `T`（前提是 `T` 实现了 `IntoView`）。实际上，你可以对 `Result<T, E>` 做类似的事情。在 `Err(_)` 情况下，它会渲染空内容；在 `Ok(T)` 情况下，它会渲染 `T`。

让我们从一个简单的组件开始，捕获一个数字输入：

```rust
#[component]
fn NumericInput() -> impl IntoView {
    let (value, set_value) = signal(Ok(0));

    view! {
        <label>
            "输入一个整数（或其他内容！）"
            <input type="number" on:input:target=move |ev| {
              // 当输入更改时，尝试从输入中解析一个数字
              set_value.set(ev.target().value().parse::<i32>())
            }/>
            <p>
                "你输入的是 "
                <strong>{value}</strong>
            </p>
        </label>
    }
}
```

每次你更改输入时，`on_input` 都会尝试将其值解析为一个 32 位整数（`i32`），并将结果存储在我们的 `value` 信号中，该信号是一个 `Result<i32, _>`。如果你输入数字 `42`，UI 会显示：

```
你输入的是 42
```

但如果你输入字符串 `foo`，它会显示：

```
你输入的是
```

这不太理想。虽然避免了使用 `.unwrap_or_default()` 或类似的操作，但如果我们可以捕获错误并对其进行处理，效果会更好。

为此，你可以使用 [`<ErrorBoundary/>`](https://docs.rs/leptos/latest/leptos/error/fn.ErrorBoundary.html) 组件来实现。

```admonish note
人们经常指出，`<input type="number">` 可以防止用户输入 `foo` 这样的字符串，或者其他非数字的内容。这在某些浏览器中确实如此，但并非所有浏览器都这样！此外，在普通的数字输入框中，可以输入许多不属于 `i32` 的内容，例如浮点数、大于 32 位的数字、字母 `e` 等等。虽然可以通过设置浏览器来强制执行某些限制，但不同浏览器的行为仍然有所不同。因此，自己解析输入数据是很重要的！
```

## `<ErrorBoundary/>`

`<ErrorBoundary/>` 有点类似于上一章我们看到的 `<Show/>` 组件。如果一切正常（也就是说，如果所有内容都是 `Ok(_)`），它会渲染其子组件。但如果其中有 `Err(_)` 被渲染，它将触发 `<ErrorBoundary/>` 的 `fallback`（备用内容）。  

让我们在这个示例中添加一个 `<ErrorBoundary/>`。

```rust
#[component]
fn NumericInput() -> impl IntoView {
        let (value, set_value) = signal(Ok(0));

    view! {
        <h1>"错误处理"</h1>
        <label>
            "输入一个数字（或者输入非数字的内容！）"
            <input type="number" on:input:target=move |ev| {
                // 当输入发生变化时，尝试从输入中解析一个数字
                set_value.set(ev.target().value().parse::<i32>())
            }/>
            // 如果 `<ErrorBoundary/>` 内部渲染了 `Err(_)`，
            // 那么 `fallback` 会被显示。否则，会显示 `<ErrorBoundary/>` 的子元素。
            <ErrorBoundary
                // `fallback` 接收一个包含当前错误的信号
                fallback=|errors| view! {
                    <div class="error">
                        <p>"不是一个数字！错误信息：" </p>
                        // 我们可以将错误列表渲染为字符串
                        <ul>
                            {move || errors.get()
                                .into_iter()
                                .map(|(_, e)| view! { <li>{e.to_string()}</li>})
                                .collect::<Vec<_>>()
                            }
                        </ul>
                    </div>
                }
            >
                <p>
                    "你输入了 "
                    // 因为 `value` 是 `Result<i32, _>`，
                    // 如果它是 `Ok`，它会渲染 `i32`；
                    // 如果它是 `Err`，它不会渲染任何内容，而是触发错误边界。
                    // 这是一个信号（signal），所以当 `value` 变化时，它会动态更新。
                    <strong>{value}</strong>
                </p>
            </ErrorBoundary>
        </label>
    }
}
```

现在，如果你输入 `42`，`value` 变为 `Ok(42)`，你会看到：

```
你输入了 42
```

如果你输入 `foo`，`value` 变为 `Err(_)`，`fallback` 将会被渲染。  
我们选择将错误列表渲染为 `String`，所以你会看到类似以下的内容：

```
不是一个数字！错误信息：
- cannot parse integer from empty string
```

如果你修正输入，错误消息会消失，而 `<ErrorBoundary/>` 包裹的内容将再次出现。

```admonish sandbox title="Live example" collapsible=true

[Click to open CodeSandbox.](https://codesandbox.io/p/devbox/7-errors-0-7-qqywqz?file=%2Fsrc%2Fmain.rs%3A5%2C1-46%2C6&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb)

<noscript>
  Please enable JavaScript to view examples.
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/7-errors-0-7-qqywqz?file=%2Fsrc%2Fmain.rs%3A5%2C1-46%2C6&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>
```

<details>
<summary>CodeSandbox Source</summary>

```rust
use leptos::prelude::*;

#[component]
fn App() -> impl IntoView {
    let (value, set_value) = signal(Ok(0));

    view! {
        <h1>"Error Handling"</h1>
        <label>
            "Type a number (or something that's not a number!)"
            <input type="number" on:input:target=move |ev| {
                // when input changes, try to parse a number from the input
                set_value.set(ev.target().value().parse::<i32>())
            }/>
            // If an `Err(_) had been rendered inside the <ErrorBoundary/>,
            // the fallback will be displayed. Otherwise, the children of the
            // <ErrorBoundary/> will be displayed.
            <ErrorBoundary
                // the fallback receives a signal containing current errors
                fallback=|errors| view! {
                    <div class="error">
                        <p>"Not a number! Errors: "</p>
                        // we can render a list of errors
                        // as strings, if we'd like
                        <ul>
                            {move || errors.get()
                                .into_iter()
                                .map(|(_, e)| view! { <li>{e.to_string()}</li>})
                                .collect::<Vec<_>>()
                            }
                        </ul>
                    </div>
                }
            >
                <p>
                    "You entered "
                    // because `value` is `Result<i32, _>`,
                    // it will render the `i32` if it is `Ok`,
                    // and render nothing and trigger the error boundary
                    // if it is `Err`. It's a signal, so this will dynamically
                    // update when `value` changes
                    <strong>{value}</strong>
                </p>
            </ErrorBoundary>
        </label>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>
