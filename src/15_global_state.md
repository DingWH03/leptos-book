# 全局状态管理

到目前为止，我们只处理了组件中的局部状态，并学习了如何在父组件和子组件之间协调状态。在某些情况下，人们会寻找一种更通用的全局状态管理解决方案，可以在整个应用程序中使用。

一般来说，**你并不需要本章内容**。典型的模式是将应用程序分解为组件，每个组件管理自己的局部状态，而不是将所有状态存储在全局结构中。然而，在某些场景下（比如主题管理、保存用户设置或在 UI 的不同部分之间共享数据），你可能需要某种全局状态管理方法。

管理全局状态的三种最佳方法是：

1. 使用路由器通过 URL 驱动全局状态  
2. 通过上下文传递信号  
3. 使用存储（stores）创建全局状态结构  

---

## 选项 1：将 URL 作为全局状态

从某种意义上说，URL 实际上是存储全局状态的最佳方式之一。它可以从树中的任何组件访问。还有原生的 HTML 元素（例如 `<form>` 和 `<a>`）专门用于更新 URL。此外，URL 状态可以跨页面刷新和设备之间保持一致。你可以将 URL 分享给朋友，或从手机发送到笔记本电脑，URL 中存储的任何状态都将被复制。

本教程的接下来的部分会详细介绍路由器相关的主题，因此我们会深入讨论这些内容。

现在，我们只讨论选项 2 和选项 3。

---

## 选项 2：通过上下文传递信号

在 [父子通信](view/08_parent_child.md) 部分中，我们看到可以使用 `provide_context` 将信号从父组件传递到子组件，并使用 `use_context` 在子组件中读取该信号。而 `provide_context` 的作用范围不受距离限制。如果你想创建一个可以在应用程序任意位置访问的全局信号，可以使用上下文提供它并通过上下文读取。

通过上下文提供的信号只会在读取的地方引发响应式更新，而不会影响中间的任何组件，因此即使跨组件传递信号，也能保持精细粒度的响应式更新能力。

我们从在应用程序根组件中创建信号开始，然后通过 `provide_context` 提供该信号，让其可被所有子组件和后代组件访问。

```rust
#[component]
fn App() -> impl IntoView {
    // 在根组件中创建信号，可在应用的任何地方使用
    let (count, set_count) = signal(0);
    // 我们会将 setter 传递给特定的组件，
    // 但通过上下文将 count 提供给整个应用
    provide_context(count);

    view! {
        // SetterButton 组件可以修改 count
        <SetterButton set_count/>
        // 以下组件只读该信号
        // 如果需要，也可以通过传递 `set_count` 给予写入权限
        <FancyMath/>
        <ListItems/>
    }
}
```

`<SetterButton/>` 是我们之前多次编写的计数器组件类型（请参阅下面的沙箱示例以了解更多）。

`<FancyMath/>` 和 `<ListItems/>` 都会通过 `use_context` 消费我们通过上下文提供的信号，并对其执行某些操作。

```rust
/// 一个使用全局计数进行“复杂”数学运算的组件
#[component]
fn FancyMath() -> impl IntoView {
    // 通过 `use_context` 消费全局信号
    let count = use_context::<ReadSignal<u32>>()
        // 我们知道刚刚在父组件中提供了这个信号
        .expect("需要有一个 `count` 信号被提供");
    let is_even = move || count.get() & 1 == 0;

    view! {
        <div class="consumer blue">
            "数字 "
            <strong>{count}</strong>
            {move || if is_even() {
                " 是"
            } else {
                " 不是"
            }}
            " 偶数。"
        </div>
    }
}
```

---

## 选项 3：创建全局状态存储（Store）

> 部分内容与关于复杂迭代中存储的章节 [此处](../view/04b_iteration.md#方案-4stores存储) 重叠。由于这两部分都是中级/可选内容，因此一些重复不会有太大影响。

存储是 Leptos 0.7 中提供的新型响应式原语，通过伴随的 `reactive_stores` crate 提供。（目前该 crate 独立发布，以便可以在不影响整个框架版本的情况下继续开发。）

存储允许你包装整个结构体，并对个别字段进行响应式读取和更新，而不会跟踪其他字段的更改。

你可以通过在结构体上添加 `#[derive(Store)]` 来使用存储。（导入宏时需要使用 `use reactive_stores::Store;`。）这会为结构体创建一个扩展 trait，当结构体被包裹在 `Store<_>` 中时，该 trait 提供每个字段的 getter 方法。

```rust
#[derive(Clone, Debug, Default, Store)]
struct GlobalState {
    count: i32,
    name: String,
}
```

这会创建一个名为 `GlobalStateStoreFields` 的 trait，为 `Store<GlobalState>` 添加 `count` 和 `name` 方法。每个方法返回一个响应式存储字段。

```rust
#[component]
fn App() -> impl IntoView {
    provide_context(Store::new(GlobalState::default()));

    // 等等
}

/// 一个更新全局状态中计数的组件
#[component]
fn GlobalStateCounter() -> impl IntoView {
    let state = expect_context::<Store<GlobalState>>();

    // 这让我们能响应式访问 `count` 字段
    let count = state.count();

    view! {
        <div class="consumer blue">
            <button
                on:click=move |_| {
                    *count.write() += 1;
                }
            >
                "增加全局计数"
            </button>
            <br/>
            <span>"计数为: " {move || count.get()}</span>
        </div>
    }
}
```

点击按钮时只会更新 `state.count`。如果我们在其他地方读取了 `state.name`，点击按钮不会通知它。这让你能够结合自上而下的数据流和精细粒度的响应式更新的优势。

查看代码库中的 [`stores` 示例](https://github.com/leptos-rs/leptos/blob/main/examples/stores/src/lib.rs)，了解更详细的示例内容。
