# 子节点投影（Projecting Children）

在构建组件时，你可能会遇到需要通过多层组件“投影”子节点的情况。

## 问题

考虑以下代码：

```rust
pub fn NestedShow<F, IV>(fallback: F, children: ChildrenFn) -> impl IntoView
where
    F: Fn() -> IV + Send + Sync + 'static,
    IV: IntoView + 'static,
{
    view! {
        <Show
            when=|| todo!()
            fallback=|| ()
        >
            <Show
                when=|| todo!()
                fallback=fallback
            >
                {children()}
            </Show>
        </Show>
    }
}
```

这段代码很直观：如果内部条件为 `true`，我们希望显示 `children`；如果不是，则显示 `fallback`。如果外部条件为 `false`，我们渲染 `()`（即什么都不显示）。

换句话说，我们希望将 `<NestedShow/>` 的子节点通过外部的 `<Show/>` 组件传递，成为内部 `<Show/>` 的子节点。这就是所谓的“投影”。

但是，这段代码无法编译。

```
error[E0525]: expected a closure that implements the `Fn` trait, but this closure only implements `FnOnce`
```

每个 `<Show/>` 需要多次构造其 `children`。第一次构造外部 `<Show/>` 的子节点时，它会移动 `fallback` 和 `children` 到内部 `<Show/>` 的调用中，但之后这些值无法用于构造未来的外部 `<Show/>` 子节点。

## 细节

> 如果你只想知道解决方案，可以直接跳到下一节。

为了真正理解这里的问题，可以查看 `view` 宏的展开形式。以下是简化版：

```rust
Show(
    ShowProps::builder()
        .when(|| todo!())
        .fallback(|| ())
        .children({
            // 这里将 `children` 和 `fallback` 移动到闭包中
            ::leptos::children::ToChildren::to_children(move || {
                Show(
                    ShowProps::builder()
                        .when(|| todo!())
                        // 这里消费了 `fallback`
                        .fallback(fallback)
                        .children({
                            // 这里捕获了 `children`
                            ::leptos::children::ToChildren::to_children(
                                move || children(),
                            )
                        })
                        .build(),
                )
            })
        })
        .build(),
)
```

所有组件都拥有它们的 props；因此在这种情况下 `<Show/>` 无法调用，因为它仅捕获了 `fallback` 和 `children` 的引用。

## 解决方案

`<Suspense/>` 和 `<Show/>` 都接受 `ChildrenFn`，即它们的 `children` 应该实现 `Fn` 类型，这样它们可以通过不可变引用多次调用。这意味着我们不需要拥有 `children` 或 `fallback` 的所有权，只需要能够传递 `'static` 引用即可。

我们可以通过使用 [`StoredValue`](https://docs.rs/leptos/latest/leptos/reactive/owner/struct.StoredValue.html) 原语解决这个问题。`StoredValue` 本质上是将值存储在反应式系统中，将所有权交给框架，并提供类似信号的 `Copy` 和 `'static` 引用，供我们通过特定方法访问或修改。

以下是改进后的代码：

```rust
pub fn NestedShow<F, IV>(fallback: F, children: ChildrenFn) -> impl IntoView
where
    F: Fn() -> IV + Send + Sync + 'static,
    IV: IntoView + 'static,
{
    let fallback = StoredValue::new(fallback);
    let children = StoredValue::new(children);

    view! {
        <Show
            when=|| todo!()
            fallback=|| ()
        >
            <Show
                when=move || todo!()
                fallback=move || fallback.read_value()()
            >
                {children.read_value()()}
            </Show>
        </Show>
    }
}
```

在顶层，我们将 `fallback` 和 `children` 存储在 `NestedShow` 的反应式作用域中。然后，我们可以将这些引用传递到 `<Show/>` 组件的其他层中，并在那里调用它们。

## 最后一点

这种方法之所以有效，是因为 `<Show/>` 只需要它们子节点的不可变引用（`.read_value()` 可以提供），而不需要所有权。

在某些情况下，你可能需要通过一个接收 `ChildrenFn` 的函数投影具有所有权的 props，并且该函数需要被多次调用。这种情况下，你可以使用 `view` 宏中的 `clone:` 帮助方法。

以下是一个示例：

```rust
#[component]
pub fn App() -> impl IntoView {
    let name = "Alice".to_string();
    view! {
        <Outer>
            <Inner>
                <Inmost name=name.clone()/>
            </Inner>
        </Outer>
    }
}

#[component]
pub fn Outer(children: ChildrenFn) -> impl IntoView {
    children()
}

#[component]
pub fn Inner(children: ChildrenFn) -> impl IntoView {
    children()
}

#[component]
pub fn Inmost(name: String) -> impl IntoView {
    view! {
        <p>{name}</p>
    }
}
```

即使使用了 `name=name.clone()`，也会报错：

```
cannot move out of `name`, a captured variable in an `Fn` closure
```

这是因为它通过多层子节点传递，而子节点需要多次运行，并且没有明显的方法将其克隆到子节点中。

这种情况下，`clone:` 语法非常有用。调用 `clone:name` 会在将 `name` 移动到 `<Inner/>` 的子节点之前先克隆它，从而解决所有权问题。

```rust
view! {
    <Outer>
        <Inner clone:name>
            <Inmost name=name.clone()/>
        </Inner>
    </Outer>
}
```

由于 `view` 宏的复杂性，这类问题可能会让人难以理解或调试。但总体来说，总有解决方法。
