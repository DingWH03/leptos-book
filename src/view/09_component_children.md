# 组件子节点（Component Children）

在组件中传递子节点（children）是一个非常常见的需求，就像你可以将子节点传递给 HTML 元素一样。例如，假设有一个 `<FancyForm/>` 组件，用来增强 HTML 的 `<form>`。你需要一种方法将其所有的输入传递进去。

```rust
view! {
    <FancyForm>
        <fieldset>
            <label>
                "Some Input"
                <input type="text" name="something"/>
            </label>
        </fieldset>
        <button>"Submit"</button>
    </FancyForm>
}
```

在 Leptos 中如何实现这一点？基本上有两种方式将子组件传递给其他组件：

1. **渲染属性（render props）**：属性是返回视图的函数。
2. **`children` 属性**：一个特殊的组件属性，用于包含传递给组件的任何子节点。

事实上，你已经在 [`<Show/>`](/view/06_control_flow.html#show) 组件中看到过这两种方式：

```rust
view! {
  <Show
    // `when` 是一个普通属性
    when=move || value.get() > 5
    // `fallback` 是一个“渲染属性”：一个返回视图的函数
    fallback=|| view! { <Small/> }
  >
    // `<Big/>`（以及这里的其他任何内容）
    // 将被传递给 `children` 属性
    <Big/>
  </Show>
}
```

现在我们定义一个组件，该组件可以接收一些子节点和一个渲染属性。

```rust
/// 在标记中显示一个 `render_prop` 和一些子节点。
#[component]
pub fn TakesChildren<F, IV>(
    /// 接收一个函数（类型 F），返回任何可以
    /// 转换为视图（类型 IV）的内容
    render_prop: F,
    /// `children` 可以接收多种不同类型，每种类型
    /// 都是返回某种视图类型的函数
    children: Children,
) -> impl IntoView
where
    F: Fn() -> IV,
    IV: IntoView,
{
    view! {
        <h1><code>"<TakesChildren/>"</code></h1>
        <h2>"渲染属性"</h2>
        {render_prop()}
        <hr/>
        <h2>"子节点"</h2>
        {children()}
    }
}
```

`render_prop` 和 `children` 都是函数，因此我们可以调用它们以生成相应的视图。特别是 `children` 是 `Box<dyn FnOnce() -> AnyView>` 的别名。（很高兴我们将它命名为 `Children`，对吧？）这里返回的 `AnyView` 是一个不透明的、类型擦除的视图：你不能对其进行任何检查。还有多种其他类型的子节点，例如 `ChildrenFragment` 将返回一个 `Fragment`，它是一个可以迭代其子节点的集合。

> 如果需要多次调用 `children`，因此需要一个 `Fn` 或 `FnMut`，我们还提供了 `ChildrenFn` 和 `ChildrenMut` 的别名。

我们可以像下面这样使用这个组件：

```rust
view! {
    <TakesChildren render_prop=|| view! { <p>"Hi, there!"</p> }>
        // 这些内容将被传递给 `children`
        "Some text"
        <span>"A span"</span>
    </TakesChildren>
}
```

## 操作子节点（Manipulating Children）

[`Fragment`](https://docs.rs/leptos/latest/leptos/tachys/view/fragment/struct.Fragment.html) 类型本质上是 `Vec<AnyView>` 的一个封装。你可以在视图中的任何位置插入它。

但你也可以直接访问这些内部视图来操作它们。例如，下面是一个组件，它接收子节点并将它们转换为一个无序列表（`<ul>`）。

```rust
/// 将每个子节点包装在 `<li>` 中，并嵌套在 `<ul>` 内。
#[component]
pub fn WrapsChildren(children: ChildrenFragment) -> impl IntoView {
    // children() 返回一个 `Fragment`，它包含一个 `nodes` 字段，
    // 其中存储了一个 `Vec<View>`。
    // 这意味着我们可以遍历子节点来创建新的内容！
    let children = children()
        .nodes
        .into_iter()
        .map(|child| view! { <li>{child}</li> })
        .collect::<Vec<_>>();

    view! {
        <h1><code>"<WrapsChildren/>"</code></h1>
        // 将包装后的子节点放入一个 UL 中
        <ul>{children}</ul>
    }
}
```

这样调用该组件会创建一个列表：

```rust
view! {
    <WrapsChildren>
        "A"
        "B"
        "C"
    </WrapsChildren>
}
```

```admonish sandbox title="Live example" collapsible=true

[Click to open CodeSandbox.](https://codesandbox.io/p/devbox/9-component-children-0-7-736s9r?file=%2Fsrc%2Fmain.rs%3A1%2C1-90%2C2&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb)

<noscript>
  Please enable JavaScript to view examples.
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/9-component-children-0-7-736s9r?file=%2Fsrc%2Fmain.rs%3A1%2C1-90%2C2&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox Source</summary>

```rust
use leptos::prelude::*;

// Often, you want to pass some kind of child view to another
// component. There are two basic patterns for doing this:
// - "render props": creating a component prop that takes a function
//   that creates a view
// - the `children` prop: a special property that contains content
//   passed as the children of a component in your view, not as a
//   property

#[component]
pub fn App() -> impl IntoView {
    let (items, set_items) = signal(vec![0, 1, 2]);
    let render_prop = move || {
        let len = move || items.read().len();
        view! {
            <p>"Length: " {len}</p>
        }
    };

    view! {
        // This component just displays the two kinds of children,
        // embedding them in some other markup
        <TakesChildren
            // for component props, you can shorthand
            // `render_prop=render_prop` => `render_prop`
            // (this doesn't work for HTML element attributes)
            render_prop
        >
            // these look just like the children of an HTML element
            <p>"Here's a child."</p>
            <p>"Here's another child."</p>
        </TakesChildren>
        <hr/>
        // This component actually iterates over and wraps the children
        <WrapsChildren>
            <p>"Here's a child."</p>
            <p>"Here's another child."</p>
        </WrapsChildren>
    }
}

/// Displays a `render_prop` and some children within markup.
#[component]
pub fn TakesChildren<F, IV>(
    /// Takes a function (type F) that returns anything that can be
    /// converted into a View (type IV)
    render_prop: F,
    /// `children` takes the `Children` type
    /// this is an alias for `Box<dyn FnOnce() -> Fragment>`
    /// ... aren't you glad we named it `Children` instead?
    children: Children,
) -> impl IntoView
where
    F: Fn() -> IV,
    IV: IntoView,
{
    view! {
        <h1><code>"<TakesChildren/>"</code></h1>
        <h2>"Render Prop"</h2>
        {render_prop()}
        <hr/>
        <h2>"Children"</h2>
        {children()}
    }
}

/// Wraps each child in an `<li>` and embeds them in a `<ul>`.
#[component]
pub fn WrapsChildren(children: ChildrenFragment) -> impl IntoView {
    // children() returns a `Fragment`, which has a
    // `nodes` field that contains a Vec<View>
    // this means we can iterate over the children
    // to create something new!
    let children = children()
        .nodes
        .into_iter()
        .map(|child| view! { <li>{child}</li> })
        .collect::<Vec<_>>();

    view! {
        <h1><code>"<WrapsChildren/>"</code></h1>
        // wrap our wrapped children in a UL
        <ul>{children}</ul>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>
