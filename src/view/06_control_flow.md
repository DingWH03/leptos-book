# 控制流（Control Flow）

在大多数应用程序中，你有时需要做出决策：是否应该渲染视图的这一部分？应该渲染 `<ButtonA/>` 还是 `<WidgetB/>`？这就是 **控制流（Control Flow）**。

## 一些提示

在考虑如何用 Leptos 实现控制流时，记住以下几点是很重要的：

1. **Rust 是一种面向表达式的语言**：像 `if x() { y } else { z }` 和 `match x() { ... }` 这样的控制流表达式会返回值。这使得它们在声明式用户界面中非常有用。
2. **任何实现了 `IntoView` 的类型都可以渲染**——换句话说，任何 Leptos 知道如何渲染的类型，`Option<T>` 和 `Result<T, impl Error>` **也** 实现了 `IntoView`。而且，就像 `Fn() -> T` 会渲染一个响应式 `T` 一样，`Fn() -> Option<T>` 和 `Fn() -> Result<T, impl Error>` 也是响应式的。
3. **Rust 提供了许多方便的工具函数**，比如 [Option::map](https://doc.rust-lang.org/std/option/enum.Option.html#method.map)、[Option::and_then](https://doc.rust-lang.org/std/option/enum.Option.html#method.and_then)、[Option::ok_or](https://doc.rust-lang.org/std/option/enum.Option.html#method.ok_or)、[Result::map](https://doc.rust-lang.org/std/result/enum.Result.html#method.map)、[Result::ok](https://doc.rust-lang.org/std/result/enum.Result.html#method.ok) 和 [bool::then](https://doc.rust-lang.org/std/primitive.bool.html#method.then)。这些工具函数允许你以声明式的方式在不同的标准类型之间转换，而这些类型都可以被渲染。特别是，花时间学习 `Option` 和 `Result` 的文档是提升你 Rust 技能的最佳方式之一。
4. **始终记住：为了保持响应性，值必须是函数**。你会发现我在下面的示例中经常用 `move ||` 闭包包裹内容。这是为了确保它们在依赖的信号发生变化时重新运行，从而保持 UI 的响应性。

## 那么，这意味着什么？

简单来说，这意味着你实际上可以使用 **原生 Rust 代码** 来实现大部分控制流，而无需依赖专门的控制流组件或特殊的知识。

例如，我们可以从一个简单的信号和一个派生信号开始：

```rust
let (value, set_value) = signal(0);
let is_odd = move || value.get() % 2 != 0;
```

我们可以利用这些信号以及普通的 Rust 语法来构建大部分的控制流。

### `if` 语句

假设我们想要在数字为奇数时渲染一些文本，而在数字为偶数时渲染另一些文本。那么，可以这样做：

```rust
view! {
    <p>
        {move || if is_odd() {
            "Odd"
        } else {
            "Even"
        }}
    </p>
}
```

`if` 表达式会返回一个值，而 `&str` 实现了 `IntoView`，所以 `Fn() -> &str` 也实现了 `IntoView`，因此，这样的写法……**就能直接工作！**

### `Option<T>`

假设我们想在数字为奇数时渲染一些文本，而在偶数时不渲染任何内容。

```rust
let message = move || {
    if is_odd() {
        Some("Ding ding ding!")
    } else {
        None
    }
};

view! {
    <p>{message}</p>
}
```

这可以正常工作。我们还可以使用 `bool::then()` 让代码更简洁：

```rust
let message = move || is_odd().then(|| "Ding ding ding!");
view! {
    <p>{message}</p>
}
```

你甚至可以将其内联到 `view!` 中，不过从 `view!` 之外提取逻辑有时会带来更好的 `cargo fmt` 和 `rust-analyzer` 支持，所以根据需要选择最合适的方式。

### `match` 语句

我们仍然只是在编写普通的 Rust 代码，对吧？所以你可以充分利用 Rust 的 **模式匹配** 机制。

```rust
let message = move || {
    match value.get() {
        0 => "Zero",
        1 => "One",
        n if is_odd() => "Odd",
        _ => "Even"
    }
};
view! {
    <p>{message}</p>
}
```

为什么不这样做呢？反正 **YOLO**（你只活一次），对吧？

## 防止过度渲染

并不是那么 **YOLO**（随心所欲）。

我们刚才做的一切基本上都是可以的，但有一件事你需要记住并注意。到目前为止，我们创建的每个控制流函数本质上都是一个 **派生信号（derived signal）**，它会在 `value` 发生变化时重新运行。在上面的示例中，由于 `value` 每次都会在 **奇数** 和 **偶数** 之间切换，这没有问题。

但请考虑以下示例：

```rust
let (value, set_value) = signal(0);

let message = move || if value.get() > 5 {
    "Big"
} else {
    "Small"
};

view! {
    <p>{message}</p>
}
```

这 **确实** 能正常工作。但如果你添加了一条日志，你可能会感到惊讶：

```rust
let message = move || if value.get() > 5 {
    logging::log!("{}: rendering Big", value());
    "Big"
} else {
    logging::log!("{}: rendering Small", value());
    "Small"
};
```

当用户点击按钮时，你可能会看到类似这样的日志输出：

```
1: rendering Small
2: rendering Small
3: rendering Small
4: rendering Small
5: rendering Small
6: rendering Big
7: rendering Big
8: rendering Big
... ad infinitum
```

每次 `value` 发生变化时，`if` 语句都会重新运行。这在响应式编程的工作方式下是合理的。但它也有一个 **缺点**。对于一个简单的文本节点来说，重新运行 `if` 语句并重新渲染 **问题不大**。但如果代码是这样的呢？

```rust
let message = move || if value.get() > 5 {
    <Big/>
} else {
    <Small/>
};
```

在 `value` 从 **0 增加到 5** 的过程中，它会 **重复渲染 `<Small/>` 五次**，然后在 `value > 5` 之后 **无限次渲染 `<Big/>`**。如果这些组件涉及 **加载资源、创建信号，甚至只是创建 DOM 节点**，那么每次都重新渲染就是 **不必要的性能开销**。

### `<Show/>`

[`<Show/>`](https://docs.rs/leptos/latest/leptos/control_flow/fn.Show.html) 组件是解决方案。你可以传递一个 `when` 条件函数，一个当 `when` 函数返回 `false` 时显示的 `fallback`，以及当 `when` 返回 `true` 时渲染的子节点。

```rust
let (value, set_value) = signal(0);

view! {
  <Show
    when=move || { value.get() > 5 }
    fallback=|| view! { <Small/> }
  >
    <Big/>
  </Show>
}
```

`<Show/>` 会对 `when` 条件进行 **缓存（memoize）**，因此它只会渲染一次 `<Small/>`，并持续显示该组件，直到 `value` 大于 5；然后只渲染一次 `<Big/>`，并持续显示它，除非 `value` 再次小于 5，此时会重新渲染 `<Small/>`。

这是一种有效的工具，可以在使用动态 `if` 表达式时避免不必要的重新渲染。但需要注意的是，这也有一定的开销：对于非常简单的节点（比如更新单个文本节点或更新类名、属性），使用 `move || if ...` 会更高效。但如果渲染任何一个分支的开销较大，优先选择 `<Show/>`。

## 注意：类型转换

在这一部分，还有最后一个重要的事情需要说明。

Leptos 使用 **静态类型的视图树**。`view!` 宏对于不同类型的视图会返回不同的类型。

下面的代码 **不会**成功编译，因为不同的 HTML 元素属于不同的类型：

```rust,compile_error
view! {
    <main>
        {move || match is_odd() {
            true if value.get() == 1 => {
                view! { <pre>"One"</pre> }
            },
            false if value.get() == 2 => {
                view! { <p>"Two"</p> }
            }
            // 返回 HtmlElement<Textarea>
            _ => view! { <textarea>{value.get()}</textarea> }
        }}
    </main>
}
```

这种 **强类型** 机制非常强大，因为它允许进行各种 **编译时优化**。但在像这样的 **条件逻辑** 中，它可能会有些麻烦，因为 **Rust 不允许不同分支返回不同的类型**。要解决这个问题，你可以使用以下两种方法：

1. 使用 `Either`（以及 `EitherOf3`、`EitherOf4` 等）将不同类型转换为相同类型。
2. 使用 `.into_any()` 将多个类型转换为 **类型擦除（type-erased）** 的 `AnyView`。

下面是修正后的示例，添加了类型转换，这样，所有分支的返回类型都被转换为 AnyView，从而使代码可以正常编译：

```rust,compile_error
view! {
    <main>
        {move || match is_odd() {
            true if value() == 1 => {
                // 返回 HtmlElement<Pre>
                view! { <pre>"One"</pre> }.into_any()
            },
            false if value() == 2 => {
                // 返回 HtmlElement<P>
                view! { <p>"Two"</p> }.into_any()
            }
            // 返回 HtmlElement<Textarea>
            _ => view! { <textarea>{value()}</textarea> }.into_any()
        }}
    </main>
}
```

```admonish sandbox title="Live example" collapsible=true

[Click to open CodeSandbox.](https://codesandbox.io/p/devbox/6-control-flow-0-7-3m4c9j?file=%2Fsrc%2Fmain.rs%3A1%2C1-91%2C2&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb)

<noscript>
  Please enable JavaScript to view examples.
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/6-control-flow-0-7-3m4c9j?file=%2Fsrc%2Fmain.rs%3A1%2C1-91%2C2&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox Source</summary>

```rust
use leptos::prelude::*;

#[component]
fn App() -> impl IntoView {
    let (value, set_value) = signal(0);
    let is_odd = move || value.get() & 1 == 1;
    let odd_text = move || if is_odd() {
        Some("How odd!")
    } else {
        None
    };

    view! {
        <h1>"Control Flow"</h1>

        // Simple UI to update and show a value
        <button on:click=move |_| *set_value.write() += 1>
            "+1"
        </button>
        <p>"Value is: " {value}</p>

        <hr/>

        <h2><code>"Option<T>"</code></h2>
        // For any `T` that implements `IntoView`,
        // so does `Option<T>`

        <p>{odd_text}</p>
        // This means you can use `Option` methods on it
        <p>{move || odd_text().map(|text| text.len())}</p>

        <h2>"Conditional Logic"</h2>
        // You can do dynamic conditional if-then-else
        // logic in several ways
        //
        // a. An "if" expression in a function
        //    This will simply re-render every time the value
        //    changes, which makes it good for lightweight UI
        <p>
            {move || if is_odd() {
                "Odd"
            } else {
                "Even"
            }}
        </p>

        // b. Toggling some kind of class
        //    This is smart for an element that's going to
        //    toggled often, because it doesn't destroy
        //    it in between states
        //    (you can find the `hidden` class in `index.html`)
        <p class:hidden=is_odd>"Appears if even."</p>

        // c. The <Show/> component
        //    This only renders the fallback and the child
        //    once, lazily, and toggles between them when
        //    needed. This makes it more efficient in many cases
        //    than a {move || if ...} block
        <Show when=is_odd
            fallback=|| view! { <p>"Even steven"</p> }
        >
            <p>"Oddment"</p>
        </Show>

        // d. Because `bool::then()` converts a `bool` to
        //    `Option`, you can use it to create a show/hide toggled
        {move || is_odd().then(|| view! { <p>"Oddity!"</p> })}

        <h2>"Converting between Types"</h2>
        // e. Note: if branches return different types,
        //    you can convert between them with
        //    `.into_any()` (for different HTML element types)
        //    or `.into_view()` (for all view types)
        {move || match is_odd() {
            true if value.get() == 1 => {
                // <pre> returns HtmlElement<Pre>
                view! { <pre>"One"</pre> }.into_any()
            },
            false if value.get() == 2 => {
                // <p> returns HtmlElement<P>
                // so we convert into a more generic type
                view! { <p>"Two"</p> }.into_any()
            }
            _ => view! { <textarea>{value.get()}</textarea> }.into_any()
        }}
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>
