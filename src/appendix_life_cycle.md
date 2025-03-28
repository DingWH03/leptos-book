# 附录：信号的生命周期

在使用 Leptos 时，中级开发者经常会遇到以下三个问题：

1. 如何连接到组件的生命周期，在组件挂载（mount）或卸载（unmount）时运行某些代码？
2. 我如何知道信号（signal）何时被销毁？为什么有时在尝试访问被销毁的信号时会出现 panic？
3. 信号是如何实现 `Copy` 的，并且可以在闭包和其他结构中移动而无需显式克隆？

这三个问题的答案密切相关，而且每个问题的答案都比较复杂。本附录将为你提供理解这些答案的上下文，帮助你正确地推理应用的代码及其运行方式。

## 组件树 vs 决策树

考虑以下简单的 Leptos 应用：

```rust
use leptos::logging::log;
use leptos::prelude::*;

#[component]
pub fn App() -> impl IntoView {
    let (count, set_count) = signal(0);

    view! {
        <button on:click=move |_| *set_count.write() += 1>"+1"</button>
        {move || if count.get() % 2 == 0 {
            view! { <p>"Even numbers are fine."</p> }.into_any()
        } else {
            view! { <InnerComponent count/> }.into_any()
        }}
    }
}

#[component]
pub fn InnerComponent(count: ReadSignal<usize>) -> impl IntoView {
    Effect::new(move |_| {
        log!("count is odd and is {}", count.get());
    });

    view! {
        <OddDuck/>
        <p>{count}</p>
    }
}

#[component]
pub fn OddDuck() -> impl IntoView {
    view! {
        <p>"You're an odd duck."</p>
    }
}
```

这个应用只显示一个计数按钮，然后根据计数是否为偶数显示不同的消息。如果是奇数，还会在控制台中记录值。

一种映射这个简单应用的方法是绘制嵌套组件的树：
```
App 
|_ InnerComponent
   |_ OddDuck
```

另一种方法是绘制决策点的树：
```
root
|_ is count even?
   |_ yes
   |_ no
```

如果将两者结合起来，会发现它们并不完全对应。决策树将我们在 `InnerComponent` 中创建的视图分为三个部分，并将 `InnerComponent` 的一部分与 `OddDuck` 组件合并：
```
DECISION            COMPONENT           DATA    SIDE EFFECTS
root                <App/>              (count) render <button>
|_ is count even?   <InnerComponent/>
   |_ yes                                       render even <p>
   |_ no                                        start logging the count 
                    <OddDuck/>                  render odd <p> 
                                                render odd <p> (in <InnerComponent/>!)
```

通过观察这张表，我注意到以下几点：

1. 组件树和决策树并不匹配：“计数是否为偶数？”的决策将 `<InnerComponent/>` 分为三个部分（一个永远不变，一个在计数为偶时渲染，一个在计数为奇时渲染），并将其中一个部分与 `<OddDuck/>` 组件合并。
2. 决策树和副作用列表完全对应：每个副作用都在特定的决策点创建。
3. 决策树和数据树也一致。虽然表中只有一个信号，但可以看出，与组件可以包含多个决策或不包含决策不同，信号始终在决策树中的特定位置创建。

关键是：**数据的结构和副作用的结构决定了应用程序的实际功能**。组件的结构只是为了方便书写。你不需要，也不应该关心哪个组件渲染了哪个 `<p>` 标签，或哪个组件创建了记录值的副作用。重要的是，这些操作发生在正确的时间点。

在 Leptos 中，**组件是不存在的**。也就是说：你可以将应用程序写成一个组件树，因为这很方便；我们也提供了一些围绕组件的调试工具和日志记录，因为这也很方便。但你的组件在运行时并不存在：组件不是变更检测或渲染的单位。它们只是函数调用。你可以将整个应用写在一个大组件里，也可以拆分成一百个组件，这不会影响运行时的行为，因为组件本质上并不存在。

另一方面，**决策树确实存在**，而且非常重要！

## 决策树、渲染与所有权

每个决策点都是某种类型的反应式语句：一个信号或一个随时间变化的函数。当你将一个信号或函数传递给渲染器时，渲染器会自动将它包裹在一个订阅信号的 effect 中，并随时间更新视图。

这意味着当你的应用被渲染时，它会创建一个嵌套 effect 的树，与决策树完美对应。伪代码如下：

```rust
// root
let button = /* 渲染一次 <button> */;

// 渲染器为 `move || if count() ...` 包裹了一个 effect
Effect::new(|_| {
    if count.get() % 2 == 0 {
        let p = /* 渲染偶数的 <p> */;
    } else {
        // 用户创建了一个记录计数的 effect
        Effect::new(|_| {
            log!("count is odd and is {}", count.get());
        });

        let p1 = /* 渲染 OddDuck 的 <p> */;
        let p2 = /* 渲染第二个 <p> */;

        // 渲染器创建了一个更新第二个 <p> 的 effect
        Effect::new(|_| {
            // 使用信号更新 <p> 的内容
            p2.set_text_content(count.get());
        });
    }
})
```

每个反应式值都包裹在自己的 effect 中，用于更新 DOM 或处理信号变化的其他副作用。但这些 effects 不需要永远运行。例如，当 `count` 从奇数切换回偶数时，第二个 `<p>` 不再存在，因此用于更新它的 effect 不再有用。与其让这些 effects 永远运行，不如在创建它们的决策发生变化时取消它们。更具体地说：effects 在创建它们的 effect 重新运行时会被取消。如果它们是在一个条件分支中创建的，而重新运行时经过了相同的分支，则会重新创建 effect；否则不会。

从反应式系统的角度来看，你的应用的“决策树”实际上是一个反应式的“所有权树”。简单来说，一个反应式“所有者”是当前正在运行的 effect 或 memo。它拥有在其中创建的 effects，这些 effects 拥有它们自己的子级，依此类推。当一个 effect 即将重新运行时，它会首先“清理”它的子级，然后再运行。

到目前为止，这种模型与 JavaScript 框架（如 S.js 或 Solid）中的反应式系统共享，它们中的所有权概念用于自动取消 effects。

Leptos 的独特之处在于，所有权在这里具有双重含义：反应式所有者不仅拥有其子级 effects，以便能够取消它们；它还拥有其信号（memos 等），以便能够销毁它们。

## 所有权与 `Copy` Arena

这是使 Leptos 能够作为 Rust UI 框架使用的创新点。传统上，在 Rust 中管理 UI 状态是困难的，因为 UI 本质上涉及共享的可变性。（即使是一个简单的计数按钮也足以暴露问题：你需要不可变的访问来设置显示计数值的文本节点，同时在点击事件处理程序中需要可变的访问。而 Rust 恰恰是为了防止这种情况而设计的！）传统上，在 Rust 中使用事件处理程序依赖于以下两种方式之一：通过共享内存和内部可变性（如 `Rc<RefCell<_>>`，`Arc<Mutex<_>>`）进行通信，或通过通道共享内存进行通信。这两种方式通常都需要显式 `.clone()` 才能将状态移动到事件监听器中。这种方法虽然可行，但非常不便。

Leptos 始终使用一种基于 arena 分配的信号机制。信号本质上是一个指向数据结构的索引，而该数据结构存储在其他地方。信号是一种轻量级的整数类型，本身不会进行引用计数，因此可以自由地被复制、移动到事件监听器中等，而无需显式克隆。

这些信号的生命周期不是由 Rust 的生命周期或引用计数决定的，而是由所有权树决定的。

就像所有的 effect 都属于一个拥有的父级 effect，并且当父级重新运行时会取消子级一样，所有的信号也属于一个所有者，并且当所有者重新运行时会被销毁。

在大多数情况下，这完全没问题。比如在上面的例子中，`<OddDuck/>` 可能创建了其他信号，用于更新其 UI 的一部分。在大多数情况下，该信号只会用于组件的本地状态，或者作为 prop 传递给另一个组件。通常，它不会被提升到决策树之外的地方并用于应用的其他部分。当 `count` 切换回偶数时，该信号不再需要，可以被销毁。

然而，这种机制可能会导致两个潜在问题。

### 信号在被销毁后仍然可以被使用

你持有的 `ReadSignal` 或 `WriteSignal` 仅仅是一个整数：例如，如果它是应用中的第 3 个信号，值就是 3。（当然实际情况稍微复杂一些，但差别不大。）你可以随意复制这个数字并使用它，比如说“嘿，给我第 3 个信号。”当其所有者进行清理时，信号 3 的**值**会被失效；但你到处复制的数字 3 是无法被失效的。（除非用垃圾回收机制！）这意味着，如果你将信号“推”回到决策树的更高层，并将其存储在比创建它时更“高”的位置，信号可能在被销毁后仍然可以被访问。

如果你试图在信号被销毁后**更新**它，实际上并不会发生什么坏事。框架只会警告你试图更新一个已经不存在的信号。但如果你试图**访问**它，就只能导致 panic：因为无法返回一个合理的值。（框架提供了 `try_` 版本的 `.get()` 和 `.with()` 方法，如果信号被销毁，它们会返回 `None`。）

### 如果在较高作用域创建信号且从未销毁，信号可能会泄漏

反过来也会发生问题，尤其是在处理信号集合时，比如 `RwSignal<Vec<RwSignal<_>>>`。如果你在更高层级创建一个信号，并将其传递到较低层级的组件中，它不会在上层所有者被清理之前自动销毁。

例如，如果你有一个待办事项应用，每个待办事项创建一个新的 `RwSignal<Todo>`，将其存储在 `RwSignal<Vec<RwSignal<Todo>>>` 中，然后将其传递到 `<Todo/>` 组件中。当你从列表中移除一个待办事项时，该信号不会自动销毁，必须手动销毁，否则会“泄漏”，直到上层的所有者仍然存活为止。（参见 [TodoMVC 示例](https://github.com/leptos-rs/leptos/blob/main/examples/todomvc/src/lib.rs#L77-L85) 的讨论。）

这种问题只会在以下情况下发生：你创建信号，将其存储在集合中，并从集合中移除它时没有手动销毁它。

### 使用引用计数信号解决这些问题

在 0.7 版本中，为每个基于 arena 分配的原语引入了一个引用计数的等价物：每个 `RwSignal` 都有一个 `ArcRwSignal`（包括 `ArcReadSignal`、`ArcWriteSignal`、`ArcMemo` 等）。

这些信号的内存和销毁由引用计数而不是所有权树管理。

这意味着它们可以安全地用于 arena 分配的信号可能会泄漏或被销毁后使用的情况。

这在创建信号集合时尤其有用：例如，你可以创建一个 `ArcRwSignal<_>`，然后在表格的每一行中将其转换为 `RwSignal<_>`。

具体示例请参见 [`counters` 示例](https://github.com/leptos-rs/leptos/blob/main/examples/counters/src/lib.rs) 中对 `ArcRwSignal<i32>` 的使用。

## 总结

现在我们可以回到最初的问题，相信它们的答案应该变得更加清晰了。

### 组件生命周期

**组件没有生命周期**，因为组件实际上并不存在。但存在所有权的生命周期，你可以利用它实现相同的功能：

- **挂载前（before mount）**：直接在组件主体中运行代码会在“组件挂载前”运行它。
- **挂载时（on mount）**：`create_effect` 会在组件其余部分运行之后的一个 tick 执行，因此它适合那些需要等待视图挂载到 DOM 后再运行的 effect。
- **卸载时（on unmount）**：你可以使用 `on_cleanup` 为反应式系统提供需要在当前所有者清理时运行的代码。这会在所有者重新运行之前执行。由于所有者是围绕某个“决策”存在的，这意味着 `on_cleanup` 会在组件卸载时运行：如果某个东西可以被卸载，那么渲染器一定创建了一个 effect 来处理它的卸载。

### 被销毁信号的问题

通常来说，只有当你在所有权树较低的位置创建信号并将其存储在较高的位置时，才会出现问题。如果你遇到了这些问题，应该将信号的创建“提升”到父级，然后将创建的信号传递给子级——如果需要的话，确保在移除时销毁它们！

### `Copy` 信号

整个 `Copy` 包装类型系统（包括信号、`StoredValue` 等）利用所有权树来近似表示 UI 不同部分的生命周期。实际上，它类似于 Rust 基于代码块的生命周期系统，但基于 UI 的不同部分。虽然这不能始终在编译时完美检查，但总体来看，这种设计是一个显著的优势。
