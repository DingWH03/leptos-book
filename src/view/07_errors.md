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
People often try to point out that `<input type="number">` prevents you from typing a string
like `foo`, or anything else that's not a number. This is true in some browsers, but not in all!
Moreover, there are a variety of things that can be typed into a plain number input that are not an
`i32`: a floating-point number, a larger-than-32-bit number, the letter `e`, and so on. The browser
can be told to uphold some of these invariants, but browser behavior still varies: Parsing for yourself
is important!
```

## `<ErrorBoundary/>`

An `<ErrorBoundary/>` is a little like the `<Show/>` component we saw in the last chapter.
If everything’s okay—which is to say, if everything is `Ok(_)`—it renders its children.
But if there’s an `Err(_)` rendered among those children, it will trigger the
`<ErrorBoundary/>`’s `fallback`.

Let’s add an `<ErrorBoundary/>` to this example.

```rust
#[component]
fn NumericInput() -> impl IntoView {
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
```

Now, if you type `42`, `value` is `Ok(42)` and you’ll see

```
You entered 42
```

If you type `foo`, value is `Err(_)` and the `fallback` will render. We’ve chosen to render
the list of errors as a `String`, so you’ll see something like

```
Not a number! Errors:
- cannot parse integer from empty string
```

If you fix the error, the error message will disappear and the content you’re wrapping in
an `<ErrorBoundary/>` will appear again.

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
