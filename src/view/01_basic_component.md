# 基本组件

那个“Hello, world!”是一个非常*简单*的例子。让我们继续讨论更像普通应用程序的东西。

首先，让我们修改`main`函数，使其不再渲染整个应用程序，而只是渲染一个 `<App/>` 组件。组件是大多数 Web 框架中组合和设计的基本单位，Leptos 也不例外。在概念上，它们类似于 HTML 元素：它们表示 DOM 的某个部分，并具有自包含且定义明确的行为。与 HTML 元素不同的是，组件采用 `PascalCase` 命名方式，因此大多数 Leptos 应用程序通常会从一个 `<App/>` 组件开始。

```rust
use leptos::mount::mount_to_body;

fn main() {
    mount_to_body(App);
}
```

现在让我们来定义 `App` 组件自身。因为它相对简单，所以我先介绍一下整个过程，然后再逐行讲解。

```rust
use leptos::prelude::*;

#[component]
fn App() -> impl IntoView {
    let (count, set_count) = signal(0);

    view! {
        <button
            on:click=move |_| set_count.set(3)
        >
            "Click me: "
            {count}
        </button>
        <p>
            "Double count: "
            {move || count.get() * 2}
        </p>
    }
}
```

## 导入 `Prelude` 包

```rust
use leptos::prelude::*;
```

Leptos 提供了一个包含常用特征和函数的 prelude。如果您更喜欢使用单独的导入，请随意使用；编译器将为每个导入提供有用的建议。

## 组件签名

```rust
#[component]
```

与所有组件定义一样，它以 [`#[component]`](https://docs.rs/leptos/latest/leptos/attr.component.html) 宏开头。`#[component]` 注释一个函数，以便它可以用作 Leptos 应用程序中的组件。我们将在后面几章中看到此宏的一些其他功能。

```rust
fn App() -> impl IntoView
```

每个组件都是一个具有以下特征的函数

1. 它接受零个或多个任意类型的参数。
2. 它返回 `impl IntoView`，这是一个不透明类型，包含您可以从 Leptos `view` 返回的任何内容。

> 组件函数参数被聚集到一个单独的 props 结构中，该结构由 `view` 宏根据需要构建。

## 组件主体

组件函数的主体是只运行一次的设置函数，而不是多次重复运行的呈现函数。 您通常会用它来创建几个响应变量，定义响应这些值变化而运行的任何效果，并描述用户界面。

```rust
let (count, set_count) = signal(0);
```

[`signal`](https://docs.rs/leptos/latest/leptos/reactive/signal/fn.signal.html)
用于创建信号，这是 Leptos 中响应式变化和状态管理的基本单元。
它返回一个 `(getter, setter)` 元祖。要访问当前值，可以使用 `count.get()` (或者在 `nightly` Rust版本中，可以简写为 `count()`)。要设置当前值，则需要调用 `set_count.set(...)` (或者在 `nightly` 版本中可以简写为 `set_count(...)`)。

> `.get()` 会克隆信号的值，而 `.set()` 会覆盖它。在许多情况下，使用 `.with()` 或 `.update()` 会更加高效。如果您想了解这些方法之间的权衡，可以查阅 [`ReadSignal`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.ReadSignal.html) 和 [`WriteSignal`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.WriteSignal.html) 的文档。

## 视图

Leptos 通过 [`view`](https://docs.rs/leptos/latest/leptos/macro.view.html) 宏使用类似 JSX 的格式定义用户界面。

```rust
view! {
    <button
        // define an event listener with on:
        on:click=move |_| set_count.set(3)
    >
        // text nodes are wrapped in quotation marks
        "Click me: "

        // blocks include Rust code
        // in this case, it renders the value of the signal
        {count}
    </button>
    <p>
        "Double count: "
        {move || count.get() * 2}
    </p>
}
```

这段代码大致上是易于理解的：它看起来像 HTML，其中有一个特殊的 `on:click` 用于定义一个 `click` 事件监听器，还有一些看起来像 Rust 字符串的文本节点(text node)，以及两个用大括号包裹的值：
第一个 `{count}` 很容易理解（就是我们信号的值），而另一个则是：

```rust
{move || count.get() * 2}
```

这是什么？

有人开玩笑说，他们在第一次使用 Leptos 开发应用程序时写的闭包比他们人生中写的所有闭包还多。确实如此。

将一个函数传递给视图(`view`)相当于告诉框架：“嘿，这是一个可能会发生变化的东西。”

当我们点击按钮并调用 `set_count` 时，`count` 信号会被更新。而这个 `move || count.get() * 2` 闭包的值依赖于 `count` 的值，因此会重新运行。
框架会对与此闭包相关的特定文本节点进行精准更新，而不会影响(touch)应用中的其他部分。正是这种机制实现了对 DOM 的极高效更新。

记住——这一点***非常重要***——只有信号和函数在视图中被视为响应式值。

这意味着 `{count}` 和 `{count.get()}` 在视图中做的事情是非常不同的。  
`{count}` 传递一个信号，告诉框架每当 `count` 发生变化时更新视图。  
`{count.get()}` 只会访问一次 `count` 的值，并将一个 `i32` 值传递到视图中，进行一次性渲染，不会响应更新。

以同样的方式，`{move || count.get() * 2}` 和 `{count.get() * 2}` 的行为也不同。  
第一个是一个函数，因此它会响应式地渲染。第二个是一个值，所以它只会渲染一次，并且在 `count` 变化时不会更新。

你可以在下面的 `CodeSandbox` 中查看到不同之处。

让我们做最后一次修改。`set_count.set(3)` 对于点击处理来说是一个相当无用的操作。我们将“将这个值设为 3”替换为“将这个值增加 1”：

```rust
move |_| {
    *set_count.write() += 1;
}
```

你可以看到，在这里，`set_count` 只是设置值，而 `set_count.write()` 给我们一个可变引用，并在原地修改值。无论哪种方式都会触发 UI 中的响应式更新。

> 在本教程中，我们将使用 CodeSandbox 展示交互式示例。  
> 悬停在任何变量上以显示 Rust-Analyzer 详细信息和文档，了解发生了什么。  
> 随时可以folk这些示例，自己动手玩一下！

```admonish sandbox title="Live example" collapsible=true

[Click to open CodeSandbox.](https://codesandbox.io/p/devbox/1-basic-component-0-7-qvgdxs?file=%2Fsrc%2Fmain.rs%3A1%2C1-59%2C2&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb)

<noscript>
  Please enable JavaScript to view examples.
</noscript>

> To show the browser in the sandbox, you may need to click `Add DevTools >
Other Previews > 8080.`

<template>
  <iframe src="https://codesandbox.io/p/devbox/1-basic-component-0-7-qvgdxs?file=%2Fsrc%2Fmain.rs%3A1%2C1-59%2C2&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox 源代码</summary>

```rust
use leptos::prelude::*;

// The #[component] macro marks a function as a reusable component
// Components are the building blocks of your user interface
// They define a reusable unit of behavior
#[component]
fn App() -> impl IntoView {
    // here we create a reactive signal
    // and get a (getter, setter) pair
    // signals are the basic unit of change in the framework
    // we'll talk more about them later
    let (count, set_count) = signal(0);

    // the `view` macro is how we define the user interface
    // it uses an HTML-like format that can accept certain Rust values
    view! {
        <button
            // on:click will run whenever the `click` event fires
            // every event handler is defined as `on:{eventname}`

            // we're able to move `set_count` into the closure
            // because signals are Copy and 'static

            on:click=move |_| *set_count.write() += 1
        >
            // text nodes in RSX should be wrapped in quotes,
            // like a normal Rust string
            "Click me: "
            {count}
        </button>
        <p>
            <strong>"Reactive: "</strong>
            // you can insert Rust expressions as values in the DOM
            // by wrapping them in curly braces
            // if you pass in a function, it will reactively update
            {move || count.get()}
        </p>
        <p>
            <strong>"Reactive shorthand: "</strong>
            // you can use signals directly in the view, as a shorthand
            // for a function that just wraps the getter
            {count}
        </p>
        <p>
            <strong>"Not reactive: "</strong>
            // NOTE: if you just write {count.get()}, this will *not* be reactive
            // it simply gets the value of count once
            {count.get()}
        </p>
    }
}

// This `main` function is the entry point into the app
// It just mounts our component to the <body>
// Because we defined it as `fn App`, we can now use it in a
// template as <App/>
fn main() {
    leptos::mount::mount_to_body(App)
}
```
</details>
