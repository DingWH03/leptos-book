# 组件和属性(Props)

到目前为止，我们一直在单个组件中构建整个应用程序。对于非常小的示例来说，这种方式完全没问题，但在任何实际应用中，你都需要将用户界面拆分成多个组件，以便将界面分解为更小、可复用、可组合的部分。

让我们以进度条为例。假设你希望有两个进度条，而不是一个：一个每次点击前进一个刻度，另一个每次点击前进两个刻度。

你可以通过简单地创建两个 `<progress>` 元素来实现：

```rust
let (count, set_count) = signal(0);
let double_count = move || count.get() * 2;

view! {
    <progress
        max="50"
        value=count
    />
    <progress
        max="50"
        value=double_count
    />
}
```

但显然，这种方法并不具有很好的扩展性。如果你想添加第三个进度条，就需要再添加一份代码。而如果你想修改任何与进度条相关的内容，就需要在三个地方分别进行修改。

因此，我们可以创建一个 `<ProgressBar/>` 组件来解决这个问题。

```rust
#[component]
fn ProgressBar() -> impl IntoView {
    view! {
        <progress
            max="50"
            // 但是……这应该从哪里得到呢？
            value=progress
        />
    }
}
```

现在有一个问题：`progress` 尚未定义。那么它应该从哪里来呢？当我们手动定义所有内容时，我们直接使用了局部变量名。但现在，我们需要一种方法将参数传递给组件。

## 组件属性(Props)

我们通过组件属性（properties或称“props”）来实现这一点。如果你使用过其他前端框架，这个概念应该很熟悉。本质上，属性对于组件的作用，就像属性对于 HTML 元素的作用一样：它们允许你向组件传递额外的信息。

在 Leptos 中，可以通过为组件函数添加额外的参数来定义 props。

```rust
#[component]
fn ProgressBar(
    progress: ReadSignal<i32>
) -> impl IntoView {
    view! {
        <progress
            max="50"
            // 现在便正常工作了
            value=progress
        />
    }
}
```

现在我们可以在主要的 `<App/>` 组件的视图中使用我们的组件。

```rust
#[component]
fn App() -> impl IntoView {
    let (count, set_count) = signal(0);
    view! {
        <button on:click=move |_| *set_count.write() += 1>
            "Click me"
        </button>
        // now we use our component!
        <ProgressBar progress=count/>
    }
}
```

在视图中使用组件看起来和使用 HTML 元素非常相似。你会注意到，可以轻松区分元素和组件，因为组件的名称始终是 `PascalCase` 的（帕斯卡命名法）。你可以像设置 HTML 元素属性一样传递 `progress` 属性，非常简单。

### 响应式与静态 Props

在这个示例中，你会注意到 `progress` 接受的是一个响应式的 `ReadSignal<i32>`，而不是一个普通的 `i32`。这一点 **非常重要**。

组件的 props 并没有附加任何特殊意义。组件本质上只是一个函数，用来初始化用户界面。而要让界面对变化做出响应，唯一的方法就是传递一个信号类型。因此，如果你的组件属性会随着时间变化，比如我们的 `progress`，它就应该是一个信号。

### `optional` Props

目前，`max` 设置是硬编码的。我们也可以将它作为一个 prop 来传递。但是让我们将这个 prop 设置为可选。我们可以通过用 `#[prop(optional)]` 标注它来实现这一点。

```rust
#[component]
fn ProgressBar(
    // 将这个 prop 标注为可选
    // 使用 `<ProgressBar/>` 时可以指定该属性，也可以不指定
    #[prop(optional)]
    max: u16,
    progress: ReadSignal<i32>
) -> impl IntoView {
    view! {
        <progress
            max=max
            value=progress
        />
    }
}
```

现在，我们可以使用 `<ProgressBar max=50 progress=count/>`，或者省略 `max` 来使用默认值（即 `<ProgressBar progress=count/>`）。对于 `optional` 属性，其默认值是 `Default::default()` 值，对于 `u16` 类型来说，这个默认值是 `0`。但对于进度条来说，`max` 为 `0` 的值并不太有用。

因此，我们可以为它设置一个特定的默认值。

### `default` props

您可以简单地通过定义 `#[prop(default = ...)` 来指定一个默认值，而不是使用 `Default::default()` 自动确定。

```rust
#[component]
fn ProgressBar(
    #[prop(default = 100)]
    max: u16,
    progress: ReadSignal<i32>
) -> impl IntoView {
    view! {
        <progress
            max=max
            value=progress
        />
    }
}
```

### 泛型属性（Generic Props）

这是很棒的例子。但一开始我们使用了两个计数器，一个由 `count` 驱动，另一个由派生信号 `double_count` 驱动。让我们通过将 `double_count` 用作另一个 `<ProgressBar/>` 的 `progress` 属性来重新创建它。

```rust,compile_fail
#[component]
fn App() -> impl IntoView {
    let (count, set_count) = signal(0);
    let double_count = move || count.get() * 2;

    view! {
        <button on:click=move |_| { set_count.update(|n| *n += 1); }>
            "Click me"
        </button>
        <ProgressBar progress=count/>
        // 添加第二个进度条
        <ProgressBar progress=double_count/>
    }
}
```

嗯……这个代码无法编译。这很容易理解原因：我们声明了 `progress` 属性接受 `ReadSignal<i32>` 类型，而 `double_count` 不是 `ReadSignal<i32>` 类型。正如 rust-analyzer 所提示的，它的类型是 `|| -> i32`，即返回 `i32` 的闭包。

有几种方法可以解决这个问题。我们可以这样说：“嗯，我知道视图要实现响应式，需要接受一个函数或信号。我可以通过将信号包装成闭包来将信号转换成函数……也许我可以直接接受任何函数？”如果你很熟悉，你可能知道这些都实现了 `Fn() -> i32` trait。因此，可以使用泛型组件：

```rust
#[component]
fn ProgressBar(
    #[prop(default = 100)]
    max: u16,
    progress: impl Fn() -> i32 + Send + Sync + 'static
) -> impl IntoView {
    view! {
        <progress
            max=max
            value=progress
        />
        // 添加换行符以避免重叠
        <br/>
    }
}
```

这样写是完全合理的：`progress` 属性现在可以接受任何实现了 `Fn()` trait 的值。

> 泛型属性也可以通过 `where` 子句指定，或者使用内联泛型，比如 `ProgressBar<F: Fn() -> i32 + 'static>`。

泛型需要在组件的属性中某处使用。这是因为属性会被构建成一个结构体，因此所有泛型类型都必须在结构体中使用。这通常可以通过可选的 `PhantomData` 属性轻松实现。然后可以使用表示类型的语法 `<Component<T>/>`（而不是 turbofish 风格 `<Component::<T>/>`）在视图中指定泛型。

```rust
#[component]
fn SizeOf<T: Sized>(#[prop(optional)] _ty: PhantomData<T>) -> impl IntoView {
    std::mem::size_of::<T>()
}

#[component]
pub fn App() -> impl IntoView {
    view! {
        <SizeOf<usize>/>
        <SizeOf<String>/>
    }
}
```

> 请注意，这里有一些限制。例如，我们的视图宏解析器无法处理嵌套泛型，比如 `<SizeOf<Vec<T>>/>`。

### `into` 属性

还有一种方法可以实现上述功能，就是使用 `#[prop(into)]`。
这个属性会自动对传递给属性的值调用 `.into()` 方法，从而让你轻松传递不同类型的值作为属性。

在这种情况下，了解 [`Signal`](https://docs.rs/leptos/latest/leptos/reactive/wrappers/read/struct.Signal.html) 类型会很有帮助。
`Signal` 是一种枚举类型，表示任何可读的响应式信号或普通值。在定义组件 API 时，如果希望组件能够接受不同类型的信号，`Signal` 会非常有用。

```rust
#[component]
fn ProgressBar(
    #[prop(default = 100)]
    max: u16,
    #[prop(into)]
    progress: Signal<i32>
) -> impl IntoView
{
    view! {
        <progress
            max=max
            value=progress
        />
        <br/>
    }
}

#[component]
fn App() -> impl IntoView {
    let (count, set_count) = signal(0);
    let double_count = move || count.get() * 2;

    view! {
        <button on:click=move |_| *set_count.write() += 1>
            "Click me"
        </button>
        // `.into()` 将 `ReadSignal` 转换为 `Signal`
        <ProgressBar progress=count/>
        // 使用 `Signal::derive()` 包装派生信号
        <ProgressBar progress=Signal::derive(double_count)/>
    }
}
```

### Optional Generic Props

注意，您无法为组件指定可选的泛型属性。让我们看看如果尝试这样做会发生什么：

```rust,compile_fail
#[component]
fn ProgressBar<F: Fn() -> i32 + Send + Sync + 'static>(
    #[prop(optional)] progress: Option<F>,
) -> impl IntoView {
    progress.map(|progress| {
        view! {
            <progress
                max=100
                value=progress
            />
            <br/>
        }
    })
}

#[component]
pub fn App() -> impl IntoView {
    view! {
        <ProgressBar/>
    }
}
```

Rust 会给出下面有用的报错：

```
xx |         <ProgressBar/>
   |          ^^^^^^^^^^^ cannot infer type of the type parameter `F` declared on the function `ProgressBar`
   |
help: consider specifying the generic argument
   |
xx |         <ProgressBar::<F>/>
   |                     +++++
```

您可以通过 `<ProgressBar<F>/>` 语法为组件指定泛型（在 `view` 宏中不使用 turbofish）。然而，在这里指定正确的类型是不可能的，因为闭包和函数通常是无法命名的类型。编译器可能会用一种简写显示它们，但您无法直接指定它们。

不过，您可以通过使用 `Box<dyn _>` 或 `&dyn _` 提供具体类型来解决这个问题：

```rust
#[component]
fn ProgressBar(
    #[prop(optional)] progress: Option<Box<dyn Fn() -> i32 + Send + Sync>>,
) -> impl IntoView {
    progress.map(|progress| {
        view! {
            <progress
                max=100
                value=progress
            />
            <br/>
        }
    })
}

#[component]
pub fn App() -> impl IntoView {
    view! {
        <ProgressBar/>
    }
}
```

因为 Rust 编译器现在知道属性的具体类型，因此即使在 `None` 的情况下，它也知道内存中的大小，这样就可以正常编译了。

> 在本例中，`&dyn Fn() -> i32` 会引发生命周期问题，但在其他情况下，它可能是一个可行的选择。

## 为组件编写文档

这是本书中最非必要却又最重要的部分之一。  
记录组件及其属性并非严格必要，但根据团队规模和应用程序的复杂性，这可能变得非常重要。而且，这很简单，并且可以立即见效。

要为组件及其属性编写文档，您只需为组件函数和每个属性添加文档注释即可：

```rust
/// 显示目标的进度。
#[component]
fn ProgressBar(
    /// 进度条的最大值。
    #[prop(default = 100)]
    max: u16,
    /// 显示的进度值。
    #[prop(into)]
    progress: Signal<i32>,
) -> impl IntoView {
    /* ... */
}
```

这就是您需要做的全部。这些注释的行为与普通的 Rust 文档注释相同，只不过您可以为单个组件的属性编写文档，而这在普通的 Rust 函数参数中是无法做到的。

这将自动生成组件的文档，包括其 `Props` 类型及用于添加属性的每个字段的文档。  
直到您在组件名称或属性上悬停鼠标，看到 `#[component]` 宏结合 rust-analyzer 的强大功能，您才会真正理解这一点的强大之处。

## 将属性扩展到组件

有时候，您希望用户能够向组件添加额外的属性，例如，允许用户添加自己的 `class` 或 `id` 属性以便进行样式设计或其他目的。

一种方法是为组件创建 `class` 或 `id` 属性，并将它们应用到适当的元素。然而，Leptos 还支持将额外的属性“扩展”到组件上。添加到组件的属性将应用到组件的视图中返回的所有顶级 HTML 元素。

```rust
// 您可以使用 view 宏通过扩展 {..} 创建属性列表
let spread_onto_component = view! {
    <{..} aria-label="a component with attribute spreading"/>
};

view! {
    // 扩展到组件的属性将应用于组件视图中返回的 *所有* 元素。
    // 要将属性应用于组件的一部分，请通过组件属性传递它们
    <ComponentThatTakesSpread
        // 普通标识符用于组件属性
        some_prop="foo"
        another_prop=42

        // class:, style:, prop:, on: 语法与在 HTML 元素上使用时完全相同
        class:foo=true
        style:font-weight="bold"
        prop:cool=42
        on:click=move |_| alert("clicked ComponentThatTakesSpread")

        // 要传递普通的 HTML 属性，请加上 attr: 前缀
        attr:id="foo"

        // 或者，如果您想包含多个属性，而不是为每个属性添加 attr: 前缀，
        // 可以使用扩展 {..} 将它们与组件属性分开
        {..} // 此后的内容将被视为 HTML 属性
        title="ooh, a title!"

        // 我们可以添加上面定义的整个属性列表
        {..spread_onto_component}
    />
}
```

更多示例请参见 [`spread` 示例](https://github.com/leptos-rs/leptos/blob/main/examples/spread/src/lib.rs)。

```admonish sandbox title="Live example" collapsible=true

[Click to open CodeSandbox.](https://codesandbox.io/p/devbox/3-components-0-7-rkjn3j?file=%2Fsrc%2Fmain.rs%3A39%2C10)

<noscript>
  Please enable JavaScript to view examples.
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/3-components-0-7-rkjn3j?file=%2Fsrc%2Fmain.rs%3A39%2C10" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox Source</summary>

```rust
use leptos::prelude::*;

// Composing different components together is how we build
// user interfaces. Here, we'll define a reusable <ProgressBar/>.
// You'll see how doc comments can be used to document components
// and their properties.

/// Shows progress toward a goal.
#[component]
fn ProgressBar(
    // Marks this as an optional prop. It will default to the default
    // value of its type, i.e., 0.
    #[prop(default = 100)]
    /// The maximum value of the progress bar.
    max: u16,
    // Will run `.into()` on the value passed into the prop.
    #[prop(into)]
    // `Signal<T>` is a wrapper for several reactive types.
    // It can be helpful in component APIs like this, where we
    // might want to take any kind of reactive value
    /// How much progress should be displayed.
    progress: Signal<i32>,
) -> impl IntoView {
    view! {
        <progress
            max={max}
            value=progress
        />
        <br/>
    }
}

#[component]
fn App() -> impl IntoView {
    let (count, set_count) = signal(0);

    let double_count = move || count.get() * 2;

    view! {
        <button
            on:click=move |_| {
                *set_count.write() += 1;
            }
        >
            "Click me"
        </button>
        <br/>
        // If you have this open in CodeSandbox or an editor with
        // rust-analyzer support, try hovering over `ProgressBar`,
        // `max`, or `progress` to see the docs we defined above
        <ProgressBar max=50 progress=count/>
        // Let's use the default max value on this one
        // the default is 100, so it should move half as fast
        <ProgressBar progress=count/>
        // Signal::derive creates a Signal wrapper from our derived signal
        // using double_count means it should move twice as fast
        <ProgressBar max=50 progress=Signal::derive(double_count)/>
    }
}

fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>
