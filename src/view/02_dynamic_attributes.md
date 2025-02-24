# 视图(`view`)：动态类、样式和属性

到目前为止，我们已经了解了如何使用 `view` 宏来创建事件监听器，以及如何通过将函数（例如信号）传递到 `view` 来创建动态文本。

但当然，您可能还想在用户界面中更新其他内容。在本节中，我们将介绍如何动态更新类(classes)、样式(styles)和属性(attributes)，并介绍派生信号(**derived signal**)的概念。

让我们从一个应该熟悉的简单组件开始：单击一个按钮来增加计数器。

```rust
#[component]
fn App() -> impl IntoView {
    let (count, set_count) = signal(0);

    view! {
        <button
            on:click=move |_| {
                *set_count.write() += 1;
            }
        >
            "Click me: "
            {count}
        </button>
    }
}
```

到目前为止，我们在上一章中已经介绍了代码中涉及到的所有内容。

## 动态类(class)

现在假设我想动态更新该元素列表上的 CSS 类。  
例如，我想在 `count` 为奇数时添加 `red` 类。可以使用 `class:` 语法来实现这一点。

```rust
class:red=move || count.get() % 2 == 1
```

`class:` 属性接受：

1. 类名，紧跟在冒号后面（如 `red`）。
2. 一个值，可以是 `bool` 或一个返回 `bool` 的函数。

当值为 `true` 时，类会被添加。当值为 `false` 时，类会被移除。如果值是一个访问信号的函数，当信号变化时，类会响应性地更新。

现在，每次点击按钮时，随着数字在偶数和奇数之间变换，文本的颜色应在红色和黑色之间切换。

```rust
<button
    on:click=move |_| {
        *set_count.write() += 1;
    }
    // the class: syntax reactively updates a single class
    // here, we'll set the `red` class when `count` is odd
    class:red=move || count.get() % 2 == 1
>
    "Click me"
</button>
```

> 如果您正在跟随我们一起操作，请确保在您的 `index.html` 中添加以下内容：
>
> ```html
> <style>
>   .red {
>     color: red;
>   }
> </style>
> ```

某些 CSS 类名无法通过 `view` 宏直接解析，尤其是当它们包含破折号和数字或其他字符时。在这种情况下，您可以使用元组语法：`class=("name", value)` 仍可直接更新单个类。

```rust
class=("button-20", move || count.get() % 2 == 1)
```

元组语法还允许通过将数组作为第一个元组元素来指定在单个条件下应用多个类。

```rust
class=(["button-20", "rounded"], move || count.get() % 2 == 1)
```

## 动态样式(style)

可以使用类似的 `style:` 语法直接更新单个 CSS 属性。

```rust
let (count, set_count) = signal(0);

view! {
    <button
        on:click=move |_| {
            *set_count.write() += 10;
        }
        // set the `style` attribute
        style="position: absolute"
        // and toggle individual CSS properties with `style:`
        style:left=move || format!("{}px", count.get() + 100)
        style:background-color=move || format!("rgb({}, {}, 100)", count.get(), 100)
        style:max-width="400px"
        // Set a CSS variable for stylesheet use
        style=("--columns", move || count.get().to_string())
    >
        "Click to Move"
    </button>
}
```

## 动态属性(Attributes)

同样的规则也适用于普通属性。为属性传递一个字符串或基本值会赋予它一个静态值。而为属性传递一个函数（包括信号）会使它的值响应式地更新。让我们在视图中添加另一个元素：

```rust
<progress
    max="50"
    // 信号是函数，因此 `value=count` 和 `value=move || count.get()` 是完全相同的。
    value=count
/>
```

现在，每次设置 `count` 时，不仅 `<button>` 的 `class` 会切换，`<progress>` 元素的 `value` 属性也会增加，这意味着进度条将向前移动。

## 派生信号（Derived Signals）

让我们再深入一层，体验一下。

你已经知道，只需将函数传递到 `view` 中就可以创建响应式界面。这意味着我们可以轻松地更改进度条的行为。例如，如果我们想让进度条移动速度加倍，可以这样写：

```rust
<progress
    max="50"
    value=move || count.get() * 2
/>
```

但是，假设我们想在多个地方复用这个计算结果。这时，可以使用 **派生信号**，也就是一个访问信号的闭包：

```rust
let double_count = move || count.get() * 2;

/* 插入其他视图内容 */
<progress
    max="50"
    // 这里使用一次
    value=double_count
/>
<p>
    "Double Count: "
    // 这里再次使用
    {double_count}
</p>
```

派生信号允许你创建响应式的计算值，可以在应用程序的多个地方使用，且开销极小。

注意：像这样使用派生信号意味着每次信号发生变化（当 `count()` 改变时）以及每次访问 `double_count` 时，计算都会运行一次。换句话说，计算会运行两次。由于这是一个非常廉价的计算，这样做没问题。  
在后续章节中，我们会介绍 **memos**，它们专门用来解决高成本计算中的问题。

> #### 进阶话题：注入原始 HTML
>
> `view` 宏支持一个额外的属性 `inner_html`，可以用来直接设置任何元素的 HTML 内容，这会清除该元素中已定义的其他子元素。需要注意的是，提供给 `inner_html` 的 HTML **不会**被转义。  
> 因此，你必须确保内容仅包含可信(trusted)输入，或者对任何 HTML 实体进行转义，以防止跨站脚本攻击 (XSS)。
>
> ```rust
> let html = "<p>This HTML will be injected.</p>";
> view! {
>   <div inner_html=html/>
> }
> ```
>
> [点击此处查看完整的 `view` 宏文档](https://docs.rs/leptos/latest/leptos/macro.view.html)。

```admonish sandbox title="Live example" collapsible=true

[Click to open CodeSandbox.](https://codesandbox.io/p/devbox/2-dynamic-attributes-0-7-wddqfp?file=%2Fsrc%2Fmain.rs%3A1%2C1-58%2C1)

<noscript>
  Please enable JavaScript to view examples.
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/2-dynamic-attributes-0-7-wddqfp?file=%2Fsrc%2Fmain.rs%3A1%2C1-58%2C1" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox Source</summary>

```rust
use leptos::prelude::*;

#[component]
fn App() -> impl IntoView {
    let (count, set_count) = signal(0);

    // a "derived signal" is a function that accesses other signals
    // we can use this to create reactive values that depend on the
    // values of one or more other signals
    let double_count = move || count.get() * 2;

    view! {
        <button
            on:click=move |_| {
                *set_count.write() += 1;
            }
            // the class: syntax reactively updates a single class
            // here, we'll set the `red` class when `count` is odd
            class:red=move || count.get() % 2 == 1
            class=("button-20", move || count.get() % 2 == 1)
        >
            "Click me"
        </button>
        // NOTE: self-closing tags like <br> need an explicit /
        <br/>

        // We'll update this progress bar every time `count` changes
        <progress
            // static attributes work as in HTML
            max="50"

            // passing a function to an attribute
            // reactively sets that attribute
            // signals are functions, so `value=count` and `value=move || count.get()`
            // are interchangeable.
            value=count
        >
        </progress>
        <br/>

        // This progress bar will use `double_count`
        // so it should move twice as fast!
        <progress
            max="50"
            // derived signals are functions, so they can also
            // reactively update the DOM
            value=double_count
        >
        </progress>
        <p>"Count: " {count}</p>
        <p>"Double Count: " {double_count}</p>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>
