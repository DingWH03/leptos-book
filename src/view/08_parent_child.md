# 父子组件通信

你可以将应用程序看作一个嵌套的组件树。每个组件都处理自己的局部状态并管理用户界面的一部分，因此组件通常是相对独立的。

不过，有时你可能需要在父组件和子组件之间进行通信。例如，假设你定义了一个 `<FancyButton/>` 组件，为 `<button/>` 添加了一些样式、日志记录或其他功能。你希望在 `<App/>` 组件中使用 `<FancyButton/>`。但是，如何在两者之间进行通信呢？

从父组件向子组件传递状态是很简单的。在[组件和属性](./03_components.md)的内容中，我们已经介绍了一些相关内容。基本上，如果你想让父组件与子组件通信，可以将 [`ReadSignal`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.ReadSignal.html)或[`Signal`](https://docs.rs/leptos/latest/leptos/reactive/wrappers/read/struct.Signal.html) 作为属性(Prop)传递给子组件。

但是反过来呢？如何让子组件将事件或状态变化的通知发送回父组件？

在 Leptos 中，父子组件通信有四种基本模式。

## 1. 传递 [`WriteSignal`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.WriteSignal.html)

一种方法是直接将 `WriteSignal` 从父组件传递给子组件，并在子组件中更新它。这样可以让子组件操作父组件的状态。

```rust
#[component]
pub fn App() -> impl IntoView {
    let (toggled, set_toggled) = signal(false);
    view! {
        <p>"是否切换？ " {toggled}</p>
        <ButtonA setter=set_toggled/>
    }
}

#[component]
pub fn ButtonA(setter: WriteSignal<bool>) -> impl IntoView {
    view! {
        <button
            on:click=move |_| setter.update(|value| *value = !*value)
        >
            "切换"
        </button>
    }
}
```

这种模式很简单，但需要谨慎使用：随意传递 `WriteSignal` 可能会让代码变得难以理解。在这个示例中，当你阅读 `<App/>` 组件时，很明显它将 `toggled` 状态的修改权限交给了 `ButtonA`，但具体在何时或如何发生变化并不直观。在这个小型示例中，这种方式很好理解，但如果你在整个代码库中随意传递 `WriteSignal`，就可能导致代码混乱，难以维护。如果你发现自己经常使用这种模式，应该认真考虑它是否会让代码变得过于复杂和难以管理。

## 2. 使用回调函数(Callback)

另一种方法是将一个回调函数传递给子组件，例如 `on_click`。

```rust
#[component]
pub fn App() -> impl IntoView {
    let (toggled, set_toggled) = signal(false);
    view! {
        <p>"是否切换？ " {toggled}</p>
        <ButtonB on_click=move |_| set_toggled.update(|value| *value = !*value)/>
    }
}

#[component]
pub fn ButtonB(on_click: impl FnMut(MouseEvent) + 'static) -> impl IntoView {
    view! {
        <button on:click=on_click>
            "切换"
        </button>
    }
}
```

你会注意到，与 `<ButtonA/>` 接收一个 `WriteSignal` 并决定如何修改它不同，`<ButtonB/>` 仅触发了一个事件：状态的修改发生在 `<App/>` 中。这种方法的优点是可以保持状态的局部性，避免了杂乱的状态修改问题。但这也意味着修改信号的逻辑需要存在于 `<App/>` 中，而不是 `<ButtonB/>` 中。这两种方法各有优劣，并不是简单的对错问题。

## 3. 使用事件监听器

实际上，你可以稍微调整方法 2 的写法。如果回调函数可以直接映射到原生 DOM 事件，你可以在 `<App/>` 的 `view!` 宏中直接为组件添加 `on:` 监听器。

```rust
#[component]
pub fn App() -> impl IntoView {
    let (toggled, set_toggled) = signal(false);
    view! {
        <p>"是否切换？ " {toggled}</p>
        // 注意这里使用的是 on:click，而不是 on_click
        // 这与 HTML 元素的事件监听器语法相同
        <ButtonC on:click=move |_| set_toggled.update(|value| *value = !*value)/>
    }
}

#[component]
pub fn ButtonC() -> impl IntoView {
    view! {
        <button>"切换"</button>
    }
}
```

这样，你在 `<ButtonC/>` 组件中编写的代码比 `<ButtonB/>` 组件要少得多，但仍然能够正确地将事件传递给监听器。其原理是：`on:` 事件监听器会被添加到 `<ButtonC/>` 返回的每个元素上，在本例中就是 `<button>`。

当然，这种方法仅适用于那些可以直接映射到 DOM 事件的情况，也就是你直接将事件传递给组件内部的元素。如果你的逻辑较为复杂，无法直接映射到某个具体的元素（比如创建 `<ValidatedForm/>` 组件，并希望使用 `on_valid_form_submit` 回调），那么你应该使用方法 2。

## 4. 提供上下文（Context）

这种方法实际上是方法 1 的一种变体。假设你有一个深层嵌套的组件树：

```rust
#[component]
pub fn App() -> impl IntoView {
    let (toggled, set_toggled) = signal(false);
    view! {
        <p>"是否切换？ " {toggled}</p>
        <Layout/>
    }
}

#[component]
pub fn Layout() -> impl IntoView {
    view! {
        <header>
            <h1>"我的页面"</h1>
        </header>
        <main>
            <Content/>
        </main>
    }
}

#[component]
pub fn Content() -> impl IntoView {
    view! {
        <div class="content">
            <ButtonD/>
        </div>
    }
}

#[component]
pub fn ButtonD() -> impl IntoView {
    todo!()
}

```

现在 `<ButtonD/>` 不再是 `<App/>` 的直接子组件，因此你无法直接通过属性（prop）将 `WriteSignal` 传递给它。你可以尝试通过每一层组件传递属性（通常被称为“属性钻取(grilling)”）：

```rust
#[component]
pub fn App() -> impl IntoView {
    let (toggled, set_toggled) = signal(false);
    view! {
        <p>"是否切换？ " {toggled}</p>
        <Layout set_toggled/>
    }
}

#[component]
pub fn Layout(set_toggled: WriteSignal<bool>) -> impl IntoView {
    view! {
        <header>
            <h1>"我的页面"</h1>
        </header>
        <main>
            <Content set_toggled/>
        </main>
    }
}

#[component]
pub fn Content(set_toggled: WriteSignal<bool>) -> impl IntoView {
    view! {
        <div class="content">
            <ButtonD set_toggled/>
        </div>
    }
}

#[component]
pub fn ButtonD(set_toggled: WriteSignal<bool>) -> impl IntoView {
    todo!()
}
```

这非常混乱！`<Layout/>` 和 `<Content/>` 并不需要 `set_toggled`，它们只是将它传递给 `<ButtonD/>`。但是我们必须在每一层都声明这个属性。这不仅令人烦恼，而且难以维护：想象一下，我们添加了一个“半切换”选项，并且 `set_toggled` 的类型需要更改为一个 `enum`。我们必须在三个地方进行更改！

难道没有办法跳过中间的层级吗？

答案是：有！

### 4.1 Context API（上下文 API）

你可以通过使用 [`provide_context`](https://docs.rs/leptos/latest/leptos/context/fn.provide_context.html) 和 [`use_context`](https://docs.rs/leptos/latest/leptos/context/fn.use_context.html) 提供数据，从而跳过层级传递（prop drilling）。上下文通过提供的数据类型（在本例中为 `WriteSignal<bool>`）进行识别，并存在于一个从上到下的树结构中，树的结构与 UI 树的层次相对应。在这个例子中，我们可以使用上下文来避免不必要的属性传递。

```rust
#[component]
pub fn App() -> impl IntoView {
    let (toggled, set_toggled) = signal(false);

    // 将 `set_toggled` 共享给该组件的所有子组件
    provide_context(set_toggled);

    view! {
        <p>"是否切换？ " {toggled}</p>
        <Layout/>
    }
}

// 省略 <Layout/> 和 <Content/>
// 在这个版本中，可以去掉每一层中的 `set_toggled` 参数

#[component]
pub fn ButtonD() -> impl IntoView {
    // use_context 会向上搜索上下文树，尝试找到
    // 一个 `WriteSignal<bool>`。
    // 在这里使用 .expect()，因为我知道之前已经提供了它
    let setter = use_context::<WriteSignal<bool>>().expect("找不到提供的 setter");

    view! {
        <button
            on:click=move |_| setter.update(|value| *value = !*value)
        >
            "切换"
        </button>
    }
}
```

与 `<ButtonA/>` 中的警告相同：传递 `WriteSignal` 时要谨慎，因为它允许你从代码中的任意部分修改状态。但是，如果小心使用，这可能是 Leptos 中最有效的全局状态管理技术之一：只需在需要状态的最高层次提供它，并在较低层次的任意位置使用它。

这种方法没有性能上的缺点。因为你传递的是一个细粒度的响应式信号，所以在更新时，中间的组件（如 `<Layout/>` 和 `<Content/>`）_不会发生任何变化_。你实际上是在 `<ButtonD/>` 和 `<App/>` 之间直接通信。事实上——这就是细粒度响应式的强大之处——你是在 `<ButtonD/>` 中的按钮点击事件和 `<App/>` 中的单个文本节点之间直接通信。这种通信方式使得组件本身看起来几乎不存在。而实际上……在运行时，它们确实不存在。它本质上只是信号与响应效果的组合，从头到尾都如此。

请注意，这种方法做出了一个重要的权衡：在 `provide_context` 和 `use_context` 之间，你不再拥有类型安全性。在子组件中接收正确的上下文变成了一个运行时检查（参见 `use_context.expect(...)`）。在重构时，编译器不会像早期的方法那样为你提供指导。

```admonish sandbox title="Live example" collapsible=true

[Click to open CodeSandbox.](https://codesandbox.io/p/devbox/8-parent-child-0-7-cgcgk9?file=%2Fsrc%2Fmain.rs%3A1%2C1-116%2C2&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb)

<noscript>
  Please enable JavaScript to view examples.
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/8-parent-child-0-7-cgcgk9?file=%2Fsrc%2Fmain.rs%3A1%2C1-116%2C2&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox Source</summary>

```rust
use leptos::{ev::MouseEvent, prelude::*};

// This highlights four different ways that child components can communicate
// with their parent:
// 1) <ButtonA/>: passing a WriteSignal as one of the child component props,
//    for the child component to write into and the parent to read
// 2) <ButtonB/>: passing a closure as one of the child component props, for
//    the child component to call
// 3) <ButtonC/>: adding an `on:` event listener to a component
// 4) <ButtonD/>: providing a context that is used in the component (rather than prop drilling)

#[derive(Copy, Clone)]
struct SmallcapsContext(WriteSignal<bool>);

#[component]
pub fn App() -> impl IntoView {
    // just some signals to toggle four classes on our <p>
    let (red, set_red) = signal(false);
    let (right, set_right) = signal(false);
    let (italics, set_italics) = signal(false);
    let (smallcaps, set_smallcaps) = signal(false);

    // the newtype pattern isn't *necessary* here but is a good practice
    // it avoids confusion with other possible future `WriteSignal<bool>` contexts
    // and makes it easier to refer to it in ButtonD
    provide_context(SmallcapsContext(set_smallcaps));

    view! {
        <main>
            <p
                // class: attributes take F: Fn() => bool, and these signals all implement Fn()
                class:red=red
                class:right=right
                class:italics=italics
                class:smallcaps=smallcaps
            >
                "Lorem ipsum sit dolor amet."
            </p>

            // Button A: pass the signal setter
            <ButtonA setter=set_red/>

            // Button B: pass a closure
            <ButtonB on_click=move |_| set_right.update(|value| *value = !*value)/>

            // Button C: use a regular event listener
            // setting an event listener on a component like this applies it
            // to each of the top-level elements the component returns
            <ButtonC on:click=move |_| set_italics.update(|value| *value = !*value)/>

            // Button D gets its setter from context rather than props
            <ButtonD/>
        </main>
    }
}

/// Button A receives a signal setter and updates the signal itself
#[component]
pub fn ButtonA(
    /// Signal that will be toggled when the button is clicked.
    setter: WriteSignal<bool>,
) -> impl IntoView {
    view! {
        <button
            on:click=move |_| setter.update(|value| *value = !*value)
        >
            "Toggle Red"
        </button>
    }
}

/// Button B receives a closure
#[component]
pub fn ButtonB(
    /// Callback that will be invoked when the button is clicked.
    on_click: impl FnMut(MouseEvent) + 'static,
) -> impl IntoView
{
    view! {
        <button
            on:click=on_click
        >
            "Toggle Right"
        </button>
    }
}

/// Button C is a dummy: it renders a button but doesn't handle
/// its click. Instead, the parent component adds an event listener.
#[component]
pub fn ButtonC() -> impl IntoView {
    view! {
        <button>
            "Toggle Italics"
        </button>
    }
}

/// Button D is very similar to Button A, but instead of passing the setter as a prop
/// we get it from the context
#[component]
pub fn ButtonD() -> impl IntoView {
    let setter = use_context::<SmallcapsContext>().unwrap().0;

    view! {
        <button
            on:click=move |_| setter.update(|value| *value = !*value)
        >
            "Toggle Small Caps"
        </button>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>
