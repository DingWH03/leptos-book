# 指南：Islands（岛屿架构）

Leptos 0.5 引入了新的 `islands` 功能。本指南将带你了解岛屿架构的核心概念，并通过一个示例应用来实现这一架构。

## 岛屿架构（Islands Architecture）

主流的 JavaScript 前端框架（如 React、Vue、Svelte、Solid、Angular）最初都是为构建客户端渲染的单页应用（SPA）而设计的。初始页面加载时渲染为 HTML，随后进行“hydration”（状态复原），之后的导航全部由客户端处理。（因此称为“单页”：所有内容都基于从服务器加载的一页，即使后来有客户端路由。）这些框架后来都增加了服务器端渲染（SSR），以改善初始加载时间、SEO 和用户体验。

这意味着默认情况下，整个应用都是交互式的。同时也意味着整个应用必须作为 JavaScript 文件发送到客户端以进行 hydration。Leptos 也遵循了这一模式。

> 你可以在[服务器端渲染章节](./ssr/22_life_cycle.md)中了解更多相关内容。

但我们也可以反过来工作。与其构建一个完全交互式的应用、在服务器上渲染为 HTML 并在浏览器中进行 hydration，不如从一个纯 HTML 页面开始，在页面中添加小块交互区域。这是 2010 年之前任何网站或应用的传统形式：浏览器向服务器发出一系列请求，并为每个新页面返回 HTML。在“单页应用”（SPA）兴起后，这种方法有时被称为“多页应用”（MPA）。

近年来，“岛屿架构”（Islands Architecture）这一术语被用来描述从“服务器渲染的 HTML 页面海洋”开始，并在页面中添加“交互岛屿”的方法。

> ### 推荐阅读
>
> 本指南接下来的部分将介绍如何在 Leptos 中使用岛屿功能。如果你想了解这一方法的更多背景信息，可以参考以下文章：
>
> - Jason Miller，[《Islands Architecture》](https://jasonformat.com/islands-architecture/)，Jason Miller
> - Ryan Carniato，[《Islands & Server Components & Resumability, Oh My!》](https://dev.to/this-is-learning/islands-server-components-resumability-oh-my-319d)
> - patterns.dev 上的[《Islands Architectures》](https://www.patterns.dev/posts/islands-architecture)
> - [Astro Islands](https://docs.astro.build/en/concepts/islands/)

## 激活 Islands 模式

让我们从一个新的 `cargo-leptos` 应用开始：

```bash
cargo leptos new --git leptos-rs/start-axum
```

> 在这个示例中，Actix 和 Axum 应该没有本质区别。

接下来我会运行：

```bash
cargo leptos build
```

然后打开编辑器继续修改代码。

首先，我会在 `Cargo.toml` 文件中为 `leptos` crate 添加 `islands` 功能：

```toml
leptos = { version = "0.7", features = ["islands"] }
```

接下来，我会修改 `src/lib.rs` 中导出的 `hydrate` 函数。我会移除调用 `leptos::mount::mount_to_body(App)` 的代码，并将其替换为：

```rust
leptos::mount::hydrate_islands();
```

这样，系统不会运行整个应用并对其视图进行 hydration，而是按顺序对每个独立的 island 进行 hydration。

在 `app.rs` 文件中，我们还需要在 `shell` 函数中的 `HydrationScripts` 组件添加 `islands=true`：

```rust
<HydrationScripts options islands=true/>
```

现在，启动 `cargo leptos watch` 并访问 [`http://localhost:3000`](http://localhost:3000)（或其他地址）。

点击按钮，结果是……

什么也没发生！

完美。

```admonish note
初始模板在 `hydrate()` 函数定义中包含了 `use app::*;`。切换到 Islands 模式后，你将不再使用导入的主 `App` 函数，因此你可能认为可以删除这一行代码。（事实上，如果你不删除，Rust 的 lint 工具可能会发出警告！）

然而，如果你在使用 workspace 设置，这可能会引发问题。我们使用 `wasm-bindgen` 为每个函数单独导出一个入口点。根据我的经验，如果你的 `frontend` crate 中没有实际使用 `app` crate 的任何内容，那么这些绑定可能不会正确生成。[更多讨论请见这里](https://github.com/leptos-rs/leptos/issues/2083#issuecomment-1868053733)。
```

## 使用 Islands

目前什么都没发生，因为我们完全颠覆了应用的思维模型。现在，应用默认是静态的 HTML，而不是默认交互式并对所有内容进行 hydration。我们需要主动选择哪些部分实现交互。

这种模式对 WASM 二进制文件大小有很大影响：如果以 release 模式编译，这个应用的 WASM 文件只有 24kb（未压缩），而非 Islands 模式下是 274kb。（274kb 对于“Hello, world!”来说相当大，主要是因为包含了与客户端路由相关的代码，而这些代码在这个示例中并未使用。）

当点击按钮时，什么都没发生，因为整个页面是静态的。

那么，我们如何让它变得交互式呢？

让我们将 `HomePage` 组件转换为一个 Island！

以下是非交互式版本：

```rust
#[component]
fn HomePage() -> impl IntoView {
    // 创建一个反应式值以更新按钮
    let count = RwSignal::new(0);
    let on_click = move |_| *count.write() += 1;

    view! {
        <h1>"Welcome to Leptos!"</h1>
        <button on:click=on_click>"Click Me: " {count}</button>
    }
}
```

以下是交互式版本：

```rust
#[island]
fn HomePage() -> impl IntoView {
    // 创建一个反应式值以更新按钮
    let count = RwSignal::new(0);
    let on_click = move |_| *count.write() += 1;

    view! {
        <h1>"Welcome to Leptos!"</h1>
        <button on:click=on_click>"Click Me: " {count}</button>
    }
}
```

现在，当我点击按钮时，它可以正常工作了！

`#[island]` 宏与 `#[component]` 宏的工作方式完全相同，但在 Islands 模式下，它将这个组件标记为交互式 Island。如果我们再次检查二进制大小，结果是 166kb（release 模式下未压缩），比完全静态版本的 24kb 大得多，但比完全 hydration 的 355kb 小得多。

如果你现在查看页面的源代码，会发现你的 `HomePage` Island 被渲染为一个特殊的 `<leptos-island>` HTML 元素，并指定了用于 hydration 的组件：

```html
<leptos-island data-component="HomePage_7432294943247405892">
  <h1>Welcome to Leptos!</h1>
  <button>
    Click Me:
    <!>0
  </button>
</leptos-island>
```

只有这个 `<leptos-island>` 内的代码会被编译为 WASM，并且仅在 hydration 时运行这些代码。

## 高效使用 Islands

请记住，**只有**标记为 `#[island]` 的代码需要被编译为 WASM 并发送到浏览器。这意味着 Islands 应尽可能小而具体。例如，我的 `HomePage` 会更好地被拆分为一个普通组件和一个 Island：

```rust
#[component]
fn HomePage() -> impl IntoView {
    view! {
        <h1>"Welcome to Leptos!"</h1>
        <Counter/>
    }
}

#[island]
fn Counter() -> impl IntoView {
    // 创建一个反应式值以更新按钮
    let (count, set_count) = signal(0);
    let on_click = move |_| *set_count.write() += 1;

    view! {
        <button on:click=on_click>"Click Me: " {count}</button>
    }
}
```

现在，`<h1>` 不需要包含在客户端包中，也不需要被 hydration。这看起来可能是一个微不足道的优化，但请注意，你现在可以向 `HomePage` 添加任意多的静态 HTML 内容，而 WASM 二进制文件的大小完全不会增加。

在常规的 hydration 模式下，WASM 二进制大小随着应用的规模和复杂性增长而增长。而在 Islands 模式下，WASM 二进制大小则与应用中交互部分的数量成正比。你可以在 Islands 之外添加任意多的非交互内容，它不会增加二进制文件大小。

## 解锁超级能力

将 WASM 二进制文件大小减少 50% 当然很好。但真正的意义是什么呢？

意义在于结合以下两点：

1. `#[component]` 函数内部的代码现在**仅**在服务器上运行，除非你在 Island 中使用它。\*
2. 子节点和 props 可以从服务器传递到 Islands，而无需包含在 WASM 二进制文件中。

这意味着你可以直接在组件的主体中运行仅限服务器的代码，并将结果直接传递给子组件。在完全 hydration 的应用中需要复杂的服务器函数和 `Suspense` 的任务，现在可以直接在 Islands 中完成。

> \* 这里的“除非你在 Island 中使用它”很重要。这并不意味着 `#[component]` 组件只在服务器上运行。实际上，它们是“共享组件”，只有在 Island 的主体中使用时才会被编译进 WASM 二进制文件。但如果你不在 Island 中使用它们，它们不会在浏览器中运行。

在本示例的剩余部分，我们还将依赖以下事实：

3. **上下文可以在原本独立的 Islands 之间传递。**

因此，抛开计数器示例，我们来实现一个更有趣的东西：一个从服务器文件读取数据的标签式界面。

## 将服务器子节点传递给 Islands

Islands 的一个强大之处在于，你可以将服务器渲染的子节点传递给一个 Island，而无需该 Island 了解这些子节点的任何信息。Islands 会对自己的内容进行 hydration，但不会对传递给它的子节点进行 hydration。

正如 React 的 Dan Abramov 在类似的 React Server Components (RSCs) 场景中所说，Islands 其实并不是孤立的“岛屿”，它们更像是“甜甜圈”：你可以将仅限服务器的内容直接传递到“甜甜圈的中心洞”，从而创建交互的“小环礁”，周围被一片“静态服务器 HTML 的海洋”包围。

> 在下面的示例代码中，我添加了一些样式，将所有服务器内容显示为浅蓝色“海洋”，而 Islands 显示为浅绿色“陆地”。希望这能帮助你更直观地理解。

继续我们的示例：我将创建一个 `Tabs` 组件。切换选项卡需要一些交互性，因此这当然会是一个 Island。让我们从一个简单的版本开始：

```rust
#[island]
fn Tabs(labels: Vec<String>) -> impl IntoView {
    let buttons = labels
        .into_iter()
        .map(|label| view! { <button>{label}</button> })
        .collect_view();
    view! {
        <div style="display: flex; width: 100%; justify-content: space-between;">
            {buttons}
        </div>
    }
}
```

哎呀，这会报错：

```
error[E0463]: can't find crate for `serde`
  --> src/app.rs:43:1
   |
43 | #[island]
   | ^^^^^^^^^ can't find crate
```

这很好修复：运行 `cargo add serde --features=derive`。`#[island]` 宏需要引入 `serde`，因为它需要对 `labels` prop 进行序列化和反序列化。

现在更新 `HomePage` 以使用 `Tabs`：

```rust
#[component]
fn HomePage() -> impl IntoView {
	// 我们将读取的文件
    let files = ["a.txt", "b.txt", "c.txt"];
	// 标签的名字就是文件名
	let labels = files.iter().copied().map(Into::into).collect();
    view! {
        <h1>"Welcome to Leptos!"</h1>
        <p>"Click any of the tabs below to read a recipe."</p>
        <Tabs labels/>
    }
}
```

如果你查看 DOM 检查器，你会发现 Island 现在是这样的：

```html
<leptos-island
  data-component="Tabs_1030591929019274801"
  data-props='{"labels":["a.txt","b.txt","c.txt"]}'
>
  <div style="display: flex; width: 100%; justify-content: space-between;;">
    <button>a.txt</button>
    <button>b.txt</button>
    <button>c.txt</button>
    <!---->
  </div>
</leptos-island>
```

我们的 `labels` prop 被序列化为 JSON 并存储在 HTML 属性中，以便用来对 Island 进行 hydration。

现在让我们添加一些选项卡。此时，一个 `Tab` Island 非常简单：

```rust
#[island]
fn Tab(index: usize, children: Children) -> impl IntoView {
    view! {
        <div>{children()}</div>
    }
}
```

目前，每个选项卡只是一个 `<div>` 包裹着它的子节点。

`Tabs` 组件现在也会接收一些子节点：目前我们只是简单地显示它们。

```rust
#[island]
fn Tabs(labels: Vec<String>, children: Children) -> impl IntoView {
    let buttons = labels
        .into_iter()
        .map(|label| view! { <button>{label}</button> })
        .collect_view();
    view! {
        <div style="display: flex; width: 100%; justify-content: space-around;">
            {buttons}
        </div>
        {children()}
    }
}
```

现在回到 `HomePage`，我们将创建选项卡列表并放入 `Tabs` 中。

```rust
#[component]
fn HomePage() -> impl IntoView {
    let files = ["a.txt", "b.txt", "c.txt"];
    let labels = files.iter().copied().map(Into::into).collect();
	let tabs = move || {
        files
            .into_iter()
            .enumerate()
            .map(|(index, filename)| {
                let content = std::fs::read_to_string(filename).unwrap();
                view! {
                    <Tab index>
                        <h2>{filename.to_string()}</h2>
                        <p>{content}</p>
                    </Tab>
                }
            })
            .collect_view()
    };

    view! {
        <h1>"Welcome to Leptos!"</h1>
        <p>"Click any of the tabs below to read a recipe."</p>
        <Tabs labels>
            <div>{tabs()}</div>
        </Tabs>
    }
}
```

嗯……等等？

如果你熟悉 Leptos，你知道这是行不通的。组件主体中的代码必须在服务器上运行（渲染为 HTML）并在浏览器中运行（进行 hydration），因此你不能直接调用 `std::fs`；它会 panic，因为浏览器无法访问本地文件系统（更不用说服务器的文件系统了）。这会成为安全噩梦！

但是……等等。我们现在使用的是 Islands 模式。这个 `HomePage` 组件**确实**只在服务器上运行。因此，我们实际上可以像这样使用普通的服务器端代码。

> **这是不是一个愚蠢的示例？**是的！在 `.map()` 中同步读取三个本地文件在现实场景中并不是一个好选择。这里的重点只是演示这确实是仅限服务器的内容。

接下来，在项目根目录中创建三个文件：`a.txt`、`b.txt` 和 `c.txt`，并填入一些内容。

刷新页面，你应该会在浏览器中看到这些内容。编辑这些文件并再次刷新，内容会更新。

你可以将仅限服务器的内容从 `#[component]` 传递到 `#[island]` 的子节点中，而无需 Island 知道如何访问或渲染这些数据。

**这非常重要。** 将服务器子节点传递给 Islands 意味着你可以保持 Islands 足够小。理想情况下，你不会将整个页面的大块内容都标记为 `#[island]`。你应该将交互部分拆分出来作为 `#[island]`，并将大量额外的服务器内容作为子节点传递给这个 Island，以便将交互区域中的非交互部分排除在 WASM 二进制文件之外。

## 在 Islands 之间传递上下文

目前，这些“选项卡”还不是真正的选项卡：它们总是显示所有内容。因此，让我们为 `Tabs` 和 `Tab` 组件添加一些简单的逻辑。

我们将修改 `Tabs`，创建一个简单的 `selected` 信号。通过上下文提供 `ReadSignal` 的部分，并在用户点击按钮时设置该信号的值。

```rust
#[island]
fn Tabs(labels: Vec<String>, children: Children) -> impl IntoView {
    let (selected, set_selected) = signal(0);
    provide_context(selected);

    let buttons = labels
        .into_iter()
        .enumerate()
        .map(|(index, label)| view! {
            <button on:click=move |_| set_selected.set(index)>
                {label}
            </button>
        })
        .collect_view();
    // ...
    view! {
        <div style="display: flex; width: 100%; justify-content: space-around;">
            {buttons}
        </div>
        {children()}
    }
}
```

然后修改 `Tab` Island，使用上下文来决定是否显示自身：

```rust
#[island]
fn Tab(index: usize, children: Children) -> impl IntoView {
    let selected = expect_context::<ReadSignal<usize>>();
    view! {
        <div
            style:background-color="lightgreen"
            style:padding="10px"
            style:display=move || if selected.get() == index {
                "block"
            } else {
                "none"
            }
        >
            {children()}
        </div>
    }
}
```

现在，选项卡的行为完全符合预期。`Tabs` 通过上下文将信号传递给每个 `Tab`，`Tab` 根据该信号决定是否显示自身。

> 这就是为什么在 `HomePage` 中，我将 `let tabs = move ||` 定义为一个函数，并以 `{tabs()}` 的形式调用它：以这种方式延迟创建选项卡，确保在每个 `Tab` 查找上下文时，`Tabs` Island 已经提供了 `selected` 上下文。

我们的完整选项卡示例大约是 200kb（未压缩）：虽然不是最小的示例，但仍然显著小于我们最初使用客户端路由的“Hello, world”示例！为了测试，我用非 Islands 模式构建了相同的示例，使用 `#[server]` 函数和 `Suspense`，二进制大小超过了 400kb。因此，再次证明 Islands 模式实现了大约 50% 的二进制大小节省。而且这个应用包含的服务器端内容非常少：请记住，当我们添加额外的服务器端组件和页面时，这 200kb 的大小不会增加。

## 概述

这个示例看起来可能很基础，确实如此。但它带来了几个显而易见的收获：

- **50% 的 WASM 二进制大小减少**，这意味着客户端的交互时间和初始加载时间得到了显著改善。
- **降低数据序列化成本**。在客户端创建一个资源并读取它意味着需要序列化数据以用于 hydration。如果你还读取了该数据以在 `Suspense` 中生成 HTML，那么会产生“双重数据”，即相同的数据既被渲染为 HTML，又被序列化为 JSON。这会增加响应大小，从而减慢加载速度。
- **轻松使用服务器专属 API**。在 `#[component]` 中使用服务器端 API，就像运行在服务器上的普通 Rust 函数一样——因为在 Islands 模式中，它确实如此！
- **减少 `#[server]`/`create_resource`/`Suspense` 样板代码**，用于加载服务器数据。

## 未来探索

`islands` 功能反映了当前前端 Web 框架正在探索的最前沿工作。就目前来看，我们的 Islands 方法与 Astro（在最近支持 View Transitions 之前）非常相似：它允许你构建一个传统的服务器渲染多页应用，并几乎无缝地集成交互的 Islands。

以下是一些可以轻松添加的小改进，例如，我们可以引入类似 Astro 的 View Transitions 方法：

- 为 Islands 应用添加客户端路由，通过从服务器获取后续导航并用新 HTML 文档替换旧文档。
- 使用 View Transitions API 在新旧文档之间添加动画过渡。
- 支持显式的持久 Islands，例如，你可以为 Islands 标记唯一 ID（类似于在视图中的组件上使用 `persist:searchbar`），以便将它们从旧文档复制到新文档，而不会丢失当前状态。

同时，还有一些较大的架构更改，但我目前[还未完全认可](https://github.com/leptos-rs/leptos/issues/1830)。

## 附加信息

更多讨论请参考 [`islands` 示例](https://github.com/leptos-rs/leptos/blob/main/examples/islands/src/app.rs)、[路线图](https://github.com/leptos-rs/leptos/issues/1830)、以及 [Hackernews 示例](https://github.com/leptos-rs/leptos/tree/leptos_0.6/examples/hackernews_islands_axum)。

## 示例代码

```rust
use leptos::prelude::*;

#[component]
pub fn App() -> impl IntoView {
    view! {
        <main style="background-color: lightblue; padding: 10px">
            <HomePage/>
        </main>
    }
}

/// Renders the home page of your application.
#[component]
fn HomePage() -> impl IntoView {
    let files = ["a.txt", "b.txt", "c.txt"];
    let labels = files.iter().copied().map(Into::into).collect();
    let tabs = move || {
        files
            .into_iter()
            .enumerate()
            .map(|(index, filename)| {
                let content = std::fs::read_to_string(filename).unwrap();
                view! {
                    <Tab index>
                        <div style="background-color: lightblue; padding: 10px">
                            <h2>{filename.to_string()}</h2>
                            <p>{content}</p>
                        </div>
                    </Tab>
                }
            })
            .collect_view()
    };

    view! {
        <h1>"Welcome to Leptos!"</h1>
        <p>"Click any of the tabs below to read a recipe."</p>
        <Tabs labels>
            <div>{tabs()}</div>
        </Tabs>
    }
}

#[island]
fn Tabs(labels: Vec<String>, children: Children) -> impl IntoView {
    let (selected, set_selected) = signal(0);
    provide_context(selected);

    let buttons = labels
        .into_iter()
        .enumerate()
        .map(|(index, label)| {
            view! {
                <button on:click=move |_| set_selected.set(index)>
                    {label}
                </button>
            }
        })
        .collect_view();
    view! {
        <div
            style="display: flex; width: 100%; justify-content: space-around;\
            background-color: lightgreen; padding: 10px;"
        >
            {buttons}
        </div>
        {children()}
    }
}

#[island]
fn Tab(index: usize, children: Children) -> impl IntoView {
    let selected = expect_context::<ReadSignal<usize>>();
    view! {
        <div
            style:background-color="lightgreen"
            style:padding="10px"
            style:display=move || if selected.get() == index {
                "block"
            } else {
                "none"
            }
        >
            {children()}
        </div>
    }
}
```
