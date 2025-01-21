# 迭代

在 Web 应用程序中，无论是列出待办事项、显示表格，还是展示产品图片，遍历列表项都是一种常见任务。处理不断变化的数据集合的差异，也是框架需要解决的最棘手的问题之一。

Leptos 支持两种不同的方式来遍历列表项：

1. 对于静态视图: `Vec<_>`
2. 对于动态列表: `<For/>`

## 使用 `Vec<_>` 创建静态视图

有时需要重复显示一个项目，但数据列表本身并不经常改变。在这种情况下，需要了解可以将任何 `Vec<IV> where IV: IntoView` 插入到视图中。换句话说，如果可以渲染 `T`，就可以渲染 `Vec<T>`。

```rust
let values = vec![0, 1, 2];
view! {
    // 这将渲染为 "012"
    <p>{values.clone()}</p>
    // 或者将它们包裹在 <li> 标签中
    <ul>
        {values.into_iter()
            .map(|n| view! { <li>{n}</li>})
            .collect::<Vec<_>>()}
    </ul>
}
```

Leptos 还提供了一个 `.collect_view()` 辅助函数，它允许将任何实现了 `T: IntoView` 的迭代器收集到 `Vec<View>` 中。

```rust
let values = vec![0, 1, 2];
view! {
    // 这将渲染为 "012"
    <p>{values.clone()}</p>
    // 或者将它们包裹在 <li> 标签中
    <ul>
        {values.into_iter()
            .map(|n| view! { <li>{n}</li>})
            .collect_view()}
    </ul>
}
```

即使 _列表_ 是静态的，界面仍然可以是动态的。你可以在静态列表中渲染动态项目。

```rust
// 创建一个包含 5 个信号的列表
let length = 5;
let counters = (1..=length).map(|idx| RwSignal::new(idx));
```

注意，这里没有调用 `signal()` 来获取包含 reader 和 writer 的元组，而是使用了 `RwSignal::new()` 来获取一个单独的读写信号。这在需要传递元组的情况下更方便。

```rust
// 每个项目管理一个响应式视图
// 但列表本身永远不会改变
let counter_buttons = counters
    .map(|(count, set_count)| {
        view! {
            <li>
                <button
                    on:click=move |_| *set_count.write() += 1
                >
                    {count}
                </button>
            </li>
        }
    })
    .collect_view();

view! {
    <ul>{counter_buttons}</ul>
}
```

也可以响应式地渲染一个 `Fn() -> Vec<_>`。但需要注意，这是一次非键控列表更新：它将复用现有的 DOM 元素，并按照新 `Vec<_>` 中的顺序更新它们的值。如果只是向列表末尾添加或移除项目，这种方式效果很好；但如果移动项目位置或在列表中间插入项目，浏览器将比正常工作进行更多的操作，并可能对输入状态和 CSS 动画产生意想不到的影响。（关于“键控”与“非键控”列表的区别以及一些实际示例，可以阅读[这篇文章](https://www.stefankrause.net/wp/?p=342)。）

幸运的是，也有一种高效的方式来进行键控列表迭代。

## 使用 `<For/>` 组件进行动态渲染

[`<For/>`](https://docs.rs/leptos/latest/leptos/control_flow/fn.For.html) 组件是一个带键控的动态列表。它接受以下三个属性：

- `each`：一个返回要迭代的项目 `T` 的响应式函数。
- `key`：一个从 `&T` 中提取稳定且唯一键或 ID 的函数。
- `children`：将每个 `T` 渲染为视图。

`key` 是这个组件的关键。你可以在列表中添加、移除和移动项目。只要每个项目的键在时间上是稳定的，框架就不需要重新渲染任何项目，除非是新增的项目，并且可以非常高效地添加、移除和移动这些项目。这使得在列表发生变化时，能够以极高的效率更新列表，且额外工作量极少。

创建一个好的 `key` 可能会有点棘手。通常 _不_ 应该使用索引作为键，因为它并不稳定——当移除或移动项目时，它们的索引会改变。

一个很好的做法是，在生成每一行时为其生成一个唯一 ID，并将其用作键函数的 ID。

请参考下面的 `<DynamicList/>` 组件示例，了解具体用法。

```admonish sandbox title="Live example" collapsible=true

[Click to open CodeSandbox.](https://codesandbox.io/p/devbox/4-iteration-0-7-dw4dfl?file=%2Fsrc%2Fmain.rs%3A1%2C1-159%2C1&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb)

<noscript>
  Please enable JavaScript to view examples.
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/4-iteration-0-7-dw4dfl?file=%2Fsrc%2Fmain.rs%3A1%2C1-159%2C1&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox Source</summary>

```rust
use leptos::prelude::*;

// Iteration is a very common task in most applications.
// So how do you take a list of data and render it in the DOM?
// This example will show you the two ways:
// 1) for mostly-static lists, using Rust iterators
// 2) for lists that grow, shrink, or move items, using <For/>

#[component]
fn App() -> impl IntoView {
    view! {
        <h1>"Iteration"</h1>
        <h2>"Static List"</h2>
        <p>"Use this pattern if the list itself is static."</p>
        <StaticList length=5/>
        <h2>"Dynamic List"</h2>
        <p>"Use this pattern if the rows in your list will change."</p>
        <DynamicList initial_length=5/>
    }
}

/// A list of counters, without the ability
/// to add or remove any.
#[component]
fn StaticList(
    /// How many counters to include in this list.
    length: usize,
) -> impl IntoView {
    // create counter signals that start at incrementing numbers
    let counters = (1..=length).map(|idx| RwSignal::new(idx));

    // when you have a list that doesn't change, you can
    // manipulate it using ordinary Rust iterators
    // and collect it into a Vec<_> to insert it into the DOM
    let counter_buttons = counters
        .map(|count| {
            view! {
                <li>
                    <button
                        on:click=move |_| *count.write() += 1
                    >
                        {count}
                    </button>
                </li>
            }
        })
        .collect::<Vec<_>>();

    // Note that if `counter_buttons` were a reactive list
    // and its value changed, this would be very inefficient:
    // it would rerender every row every time the list changed.
    view! {
        <ul>{counter_buttons}</ul>
    }
}

/// A list of counters that allows you to add or
/// remove counters.
#[component]
fn DynamicList(
    /// The number of counters to begin with.
    initial_length: usize,
) -> impl IntoView {
    // This dynamic list will use the <For/> component.
    // <For/> is a keyed list. This means that each row
    // has a defined key. If the key does not change, the row
    // will not be re-rendered. When the list changes, only
    // the minimum number of changes will be made to the DOM.

    // `next_counter_id` will let us generate unique IDs
    // we do this by simply incrementing the ID by one
    // each time we create a counter
    let mut next_counter_id = initial_length;

    // we generate an initial list as in <StaticList/>
    // but this time we include the ID along with the signal
    // see NOTE in add_counter below re: ArcRwSignal
    let initial_counters = (0..initial_length)
        .map(|id| (id, ArcRwSignal::new(id + 1)))
        .collect::<Vec<_>>();

    // now we store that initial list in a signal
    // this way, we'll be able to modify the list over time,
    // adding and removing counters, and it will change reactively
    let (counters, set_counters) = signal(initial_counters);

    let add_counter = move |_| {
        // create a signal for the new counter
        // we use ArcRwSignal here, instead of RwSignal
        // ArcRwSignal is a reference-counted type, rather than the arena-allocated
        // signal types we've been using so far.
        // When we're creating a collection of signals like this, using ArcRwSignal
        // allows each signal to be deallocated when its row is removed.
        let sig = ArcRwSignal::new(next_counter_id + 1);
        // add this counter to the list of counters
        set_counters.update(move |counters| {
            // since `.update()` gives us `&mut T`
            // we can just use normal Vec methods like `push`
            counters.push((next_counter_id, sig))
        });
        // increment the ID so it's always unique
        next_counter_id += 1;
    };

    view! {
        <div>
            <button on:click=add_counter>
                "Add Counter"
            </button>
            <ul>
                // The <For/> component is central here
                // This allows for efficient, key list rendering
                <For
                    // `each` takes any function that returns an iterator
                    // this should usually be a signal or derived signal
                    // if it's not reactive, just render a Vec<_> instead of <For/>
                    each=move || counters.get()
                    // the key should be unique and stable for each row
                    // using an index is usually a bad idea, unless your list
                    // can only grow, because moving items around inside the list
                    // means their indices will change and they will all rerender
                    key=|counter| counter.0
                    // `children` receives each item from your `each` iterator
                    // and returns a view
                    children=move |(id, count)| {
                        // we can convert our ArcRwSignal to a Copy-able RwSignal
                        // for nicer DX when moving it into the view
                        let count = RwSignal::from(count);
                        view! {
                            <li>
                                <button
                                    on:click=move |_| *count.write() += 1
                                >
                                    {count}
                                </button>
                                <button
                                    on:click=move |_| {
                                        set_counters
                                            .write()
                                            .retain(|(counter_id, _)| {
                                                counter_id != &id
                                            });
                                    }
                                >
                                    "Remove"
                                </button>
                            </li>
                        }
                    }
                />
            </ul>
        </div>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>
