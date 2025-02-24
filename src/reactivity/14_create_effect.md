# 用 Effects 响应变化

我们已经走到了这一步，却还没有提到反应式系统的一半内容：**Effects（效果）**。

反应性由两部分组成：更新单个反应性值（“信号”）会通知依赖于它们的代码片段（“效果”）需要重新运行。这两部分是相互依赖的。没有效果，信号可以在反应式系统中发生变化，但无法被外界观察到，也无法与外界交互。没有信号，效果只会运行一次，之后再也不会运行，因为没有可观察的值可以订阅。**效果实际上是反应式系统的“副作用”**：它们的存在是为了将反应式系统与外部的非反应式世界同步。

渲染器使用效果来根据信号的变化更新 DOM 的某些部分。你也可以创建自己的效果，以其他方式将反应式系统与外界同步。

[`Effect::new`](https://docs.rs/leptos/latest/leptos/reactive/effect/struct.Effect.html) 接受一个函数作为参数。它会在反应式系统的下一个“tick”中运行该函数。（例如，如果在组件中使用它，它会在组件渲染后**立即**运行。）如果你在这个函数中访问了任何反应性信号，效果会记录下该效果依赖于这些信号的事实。只要效果依赖的信号之一发生变化，效果就会再次运行。

```rust
let (a, set_a) = signal(0);
let (b, set_b) = signal(0);

Effect::new(move |_| {
  // 立即打印 "Value: 0"，并订阅 `a`
  logging::log!("Value: {}", a.get());
});
```

效果函数会接收一个参数，参数包含效果上次运行时返回的值。在初次运行时，这个值为 `None`。

默认情况下，效果**不会在服务器端运行**。这意味着你可以在效果函数中调用浏览器特定的 API 而不会引发问题。如果需要效果在服务器端运行，可以使用 [`Effect::new_isomorphic`](https://docs.rs/leptos/latest/leptos/reactive/effect/struct.Effect.html#method.new_isomorphic)。

## 自动追踪和动态依赖

如果你熟悉像 React 这样的框架，你可能会注意到一个关键的区别。React 和类似框架通常需要你提供一个“依赖数组”，明确指定哪些变量决定效果何时重新运行。

由于 Leptos 源自同步反应式编程的传统，我们不需要这个显式的依赖列表。相反，我们会根据效果中访问的信号自动追踪依赖。

这种方式有两个效果（不是双关）：

1. **自动化**：你无需维护一个依赖列表，也不用担心哪些应该或不应该被包括。框架会自动追踪哪些信号可能导致效果重新运行，并处理这些依赖。
2. **动态化**：依赖列表会在每次效果运行时清除并更新。如果效果包含条件语句（例如），只有当前分支中使用的信号会被追踪。这意味着效果只会以绝对最小的次数重新运行。

> 如果这听起来像是魔法，并且你想深入了解自动依赖追踪的原理，可以[观看这个视频](https://www.youtube.com/watch?v=GWB3vTWeLd4)。（音量较低，请见谅！）

## Effects 作为接近零成本的抽象

从技术上讲，效果并非完全“零成本抽象”——它们需要一些额外的内存，并在运行时存在等。然而，从更高层次的视角来看，对于你在其中进行的任何昂贵的 API 调用或其他操作，效果可以视为零成本抽象。它们只会以必要的最小次数重新运行。

假设我正在创建某种聊天软件，我希望用户可以显示全名或仅显示名字，并在名字更改时通知服务器：

```rust
let (first, set_first) = signal(String::new());
let (last, set_last) = signal(String::new());
let (use_last, set_use_last) = signal(true);

// 每当一个源信号发生变化，这段代码会将名字记录到日志中
Effect::new(move |_| {
    logging::log!(
        "{}", if use_last.get() {
            format!("{} {}", first.get(), last.get())
        } else {
            first.get()
        },
    )
});
```

如果 `use_last` 是 `true`，效果会在 `first`、`last` 或 `use_last` 发生变化时重新运行。但如果我将 `use_last` 切换为 `false`，`last` 的变化将不会触发全名的变化。实际上，`last` 会从依赖列表中移除，直到 `use_last` 再次切换为 `true`。这避免了在 `use_last` 为 `false` 时多次更改 `last` 导致的多余 API 请求。

## 是否创建效果？

效果的目的是将反应式系统与外部的非反应式世界同步，而不是在不同的反应式值之间同步。换句话说：使用效果从一个信号读取值并将其设置到另一个信号中总是次优的。

如果需要定义一个依赖于其他信号值的信号，可以使用派生信号或 [`Memo`](https://docs.rs/leptos/latest/leptos/reactive/computed/struct.Memo.html)。在效果中写入信号不会引发灾难（例如，电脑不会着火），但派生信号或 `memo` 总是更好的选择——不仅因为数据流清晰，而且性能更好。

```rust
let (a, set_a) = signal(0);

// ⚠️ 不太好
let (b, set_b) = signal(0);
Effect::new(move |_| {
    set_b.set(a.get() * 2);
});

// ✅ 更优选择！
let b = move || a.get() * 2;
```

如果需要将某个反应式值与外部的非反应式世界（例如 Web API、控制台、文件系统或 DOM）同步，在效果中写入信号是可以接受的。然而在很多情况下，你实际上是在事件监听器或其他地方写入信号，而不是在效果中。在这些情况下，可以查看 [`leptos-use`](https://leptos-use.rs/) 是否已经提供了一个反应式封装原语来完成这一任务！

> 如果你想进一步了解何时应该或不应该使用 `create_effect`，[可以观看这个视频](https://www.youtube.com/watch?v=aQOFJQ2JkvQ)，以获得更深入的理解！

## Effects 与渲染

我们已经讨论了这么多，却几乎没有提到效果，因为它们被内置到了 Leptos 的 DOM 渲染器中。我们已经看到，你可以创建一个信号并将其传递到 `view!` 宏中，信号变化时相关的 DOM 节点会更新：

```rust
let (count, set_count) = signal(0);

view! {
    <p>{count}</p>
}
```

这之所以有效，是因为框架实际上为这个更新创建了一个效果。你可以想象 Leptos 将这个视图翻译成如下代码：

```rust
let (count, set_count) = signal(0);

// 创建一个 DOM 元素
let document = leptos::document();
let p = document.create_element("p").unwrap();

// 创建一个效果以反应式更新文本
Effect::new(move |prev_value| {
    // 首先，访问信号的值并将其转换为字符串
    let text = count.get().to_string();

    // 如果与之前的值不同，则更新节点
    if prev_value != Some(text) {
        p.set_text_content(&text);
    }

    // 返回此值，以便对下一次更新进行记忆
    text
});
```

每次 `count` 更新时，这个效果都会重新运行。这是实现对 DOM 进行细粒度更新的关键。

## 使用 `Effect::watch()` 进行显式追踪

除了 `Effect::new()`，Leptos 还提供了 [`Effect::watch()`](https://docs.rs/leptos/latest/leptos/reactive/effect/struct.Effect.html#method.watch) 方法，可以通过显式传递值集来分离追踪和响应变化。

`watch` 有三个参数。其中`deps`参数是反应式追踪的，然而`callback`和`immediate`不是。每当 `deps` 参数中的反应式值发生变化时，`callback` 就会运行。如果`immediate`的值是`false`，callback只有在检测到任何在`deps`中访问的信号发生第一次变化后才会运行。`watch` 返回一个 `Effect`，可以通过 `.stop()` 停止追踪依赖。

```rust
let (num, set_num) = signal(0);

let effect = Effect::watch(
    move || num.get(),
    move |num, prev_num, _| {
        leptos::logging::log!("Number: {}; Prev: {:?}", num, prev_num);
    },
    false,
);

set_num.set(1); // 输出： "Number: 1; Prev: Some(0)"

effect.stop(); // 停止追踪

set_num.set(2); // （没有输出）
```

```admonish sandbox title="Live example" collapsible=true

[Click to open CodeSandbox.](https://codesandbox.io/p/devbox/14-effect-0-7-fxpy2d?file=%2Fsrc%2Fmain.rs%3A21%2C28&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb)

<noscript>
  Please enable JavaScript to view examples.
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/14-effect-0-7-fxpy2d?file=%2Fsrc%2Fmain.rs%3A21%2C28&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox Source</summary>

```rust
use leptos::html::Input;
use leptos::prelude::*;

#[derive(Copy, Clone)]
struct LogContext(RwSignal<Vec<String>>);

#[component]
fn App() -> impl IntoView {
    // Just making a visible log here
    // You can ignore this...
    let log = RwSignal::<Vec<String>>::new(vec![]);
    let logged = move || log.get().join("\n");

    // the newtype pattern isn't *necessary* here but is a good practice
    // it avoids confusion with other possible future `RwSignal<Vec<String>>` contexts
    // and makes it easier to refer to it
    provide_context(LogContext(log));

    view! {
        <CreateAnEffect/>
        <pre>{logged}</pre>
    }
}

#[component]
fn CreateAnEffect() -> impl IntoView {
    let (first, set_first) = signal(String::new());
    let (last, set_last) = signal(String::new());
    let (use_last, set_use_last) = signal(true);

    // this will add the name to the log
    // any time one of the source signals changes
    Effect::new(move |_| {
        log(if use_last.get() {
            let first = first.read();
            let last = last.read();
            format!("{first} {last}")
        } else {
            first.get()
        })
    });

    view! {
        <h1>
            <code>"create_effect"</code>
            " Version"
        </h1>
        <form>
            <label>
                "First Name"
                <input
                    type="text"
                    name="first"
                    prop:value=first
                    on:change:target=move |ev| set_first.set(ev.target().value())
                />
            </label>
            <label>
                "Last Name"
                <input
                    type="text"
                    name="last"
                    prop:value=last
                    on:change:target=move |ev| set_last.set(ev.target().value())
                />
            </label>
            <label>
                "Show Last Name"
                <input
                    type="checkbox"
                    name="use_last"
                    prop:checked=use_last
                    on:change:target=move |ev| set_use_last.set(ev.target().checked())
                />
            </label>
        </form>
    }
}

#[component]
fn ManualVersion() -> impl IntoView {
    let first = NodeRef::<Input>::new();
    let last = NodeRef::<Input>::new();
    let use_last = NodeRef::<Input>::new();

    let mut prev_name = String::new();
    let on_change = move |_| {
        log("      listener");
        let first = first.get().unwrap();
        let last = last.get().unwrap();
        let use_last = use_last.get().unwrap();
        let this_one = if use_last.checked() {
            format!("{} {}", first.value(), last.value())
        } else {
            first.value()
        };

        if this_one != prev_name {
            log(&this_one);
            prev_name = this_one;
        }
    };

    view! {
        <h1>"Manual Version"</h1>
        <form on:change=on_change>
            <label>"First Name" <input type="text" name="first" node_ref=first/></label>
            <label>"Last Name" <input type="text" name="last" node_ref=last/></label>
            <label>
                "Show Last Name" <input type="checkbox" name="use_last" checked node_ref=use_last/>
            </label>
        </form>
    }
}

fn log(msg: impl std::fmt::Display) {
    let log = use_context::<LogContext>().unwrap().0;
    log.update(|log| log.push(msg.to_string()));
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>
