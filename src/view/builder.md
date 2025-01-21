# 无宏：视图构建器语法（View Builder Syntax）

> 如果你对目前为止介绍的 `view!` 宏语法感到满意，可以跳过本章。本节描述的构建器语法始终可用，但并非必须使用。

出于各种原因，许多开发者希望避免使用宏。也许你不喜欢 `rustfmt` 对宏的有限支持（不过，你可以试试 [`leptosfmt`](https://github.com/bram209/leptosfmt)，这是一个很棒的工具！）。也许你担心宏对编译时间的影响。也许你更喜欢纯 Rust 语法的美感，或者在 HTML 样式的语法和 Rust 代码之间切换时感到困难。或者你希望比 `view` 宏提供的功能更灵活地创建和操作 HTML 元素。

如果你属于上述任何一种情况，那么构建器语法可能适合你。

`view` 宏会将 HTML 样式的语法展开为一系列 Rust 函数和方法调用。如果你不想使用 `view` 宏，也可以直接使用这种展开后的语法。实际上，这种方式也相当简洁！

首先，如果你愿意，甚至可以不使用 `#[component]` 宏：一个组件只是一个用于创建视图的设置函数，因此你可以将组件定义为一个简单的函数调用：

```rust
pub fn counter(initial_value: i32, step: u32) -> impl IntoView { }
```

元素是通过调用与 HTML 元素同名的函数创建的：

```rust
p()
```

可以通过 [`.child()`](https://docs.rs/leptos/latest/leptos/html/trait.ElementChild.html#tymethod.child) 为元素添加子节点，该方法可以接收一个子节点、一个元组或一个实现 [`IntoView`](https://docs.rs/leptos/latest/leptos/trait.IntoView.html) 的数组。

```rust
p().child((em().child("Big, "), strong().child("bold "), "text"))
```

属性通过 [`.attr()`](https://docs.rs/leptos/latest/leptos/attr/custom/trait.CustomAttribute.html#method.attr) 添加。该方法可以接收与 `view` 宏中属性支持的相同类型（实现了 [`Attribute`](https://docs.rs/leptos/latest/leptos/attr/trait.Attribute.html) 的类型）。

```rust
p().attr("id", "foo")
    .attr("data-count", move || count.get().to_string())
```

属性也可以通过特定的属性方法添加，这些方法适用于所有内置的 HTML 属性名称：

```rust
p().id("foo")
    .attr("data-count", move || count.get().to_string())
```

类似地，`class:`、`prop:` 和 `style:` 语法分别对应于 [`.class()`](https://docs.rs/leptos/latest/leptos/attr/global/trait.ClassAttribute.html#tymethod.class)、[`.prop()`](https://docs.rs/leptos/latest/leptos/attr/global/trait.PropAttribute.html#tymethod.prop) 和 [`.style()`](https://docs.rs/leptos/latest/leptos/attr/global/trait.StyleAttribute.html#tymethod.style) 方法。

事件监听器可以通过 [`.on()`](https://docs.rs/leptos/latest/leptos/attr/global/trait.OnAttribute.html#tymethod.on) 添加。在 [`leptos::ev`](https://docs.rs/leptos/latest/leptos/tachys/html/event/index.html) 中定义的类型化事件可以防止事件名称中的拼写错误，并允许在回调函数中正确推断类型。

```rust
button()
    .on(ev::click, move |_| set_count.set(0))
    .child("Clear")
```

所有这些功能加起来，如果你喜欢这种风格，它可以让你以一种非常“Rust 风格”的语法构建功能齐全的视图。

```rust
/// 一个简单的计数器视图。
// 组件本质上只是一个函数调用：它运行一次，用于创建 DOM 和响应式系统
pub fn counter(initial_value: i32, step: i32) -> impl IntoView {
    let (count, set_count) = signal(initial_value);
    div().child((
        button()
            // leptos::ev 中的类型化事件
            // 1) 防止事件名称中的拼写错误
            // 2) 允许在回调函数中正确推断类型
            .on(ev::click, move |_| set_count.set(0))
            .child("清零"),
        button()
            .on(ev::click, move |_| *set_count.write() -= step)
            .child("-1"),
        span().child(("值: ", move || count.get(), "!")),
        button()
            .on(ev::click, move |_| *set_count.write() += step)
            .child("+1"),
    ))
}
```
