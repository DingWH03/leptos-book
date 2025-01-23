# 使用 `<For/>` 迭代更复杂的数据

本章将更深入地探讨如何迭代嵌套的数据结构。它与关于迭代的其他章节相关联，但如果你目前想专注于更简单的主题，可以跳过本章，稍后再回来学习。

## 问题

刚才提到，框架不会重新渲染某行中的任何项，除非该行的键发生了变化。这一逻辑乍一看似乎合理，但实际上可能会让你踩坑。

让我们考虑一个示例，其中每一行的项都是某种数据结构。想象一下，这些项来自某个 JSON 数组，每个项都有一个键和值：

```rust
#[derive(Debug, Clone)]
struct DatabaseEntry {
    key: String,
    value: i32,
}
```

我们定义一个简单的组件，迭代显示每一行：

```rust
#[component]
pub fn App() -> impl IntoView {
    // 初始设置三行数据
    let (data, set_data) = signal(vec![
        DatabaseEntry {
            key: "foo".to_string(),
            value: 10,
        },
        DatabaseEntry {
            key: "bar".to_string(),
            value: 20,
        },
        DatabaseEntry {
            key: "baz".to_string(),
            value: 15,
        },
    ]);
    view! {
        // 点击时更新每一行的值，值翻倍
        <button on:click=move |_| {
            set_data.update(|data| {
                for row in data {
                    row.value *= 2;
                }
            });
            // 记录信号的新值
            leptos::logging::log!("{:?}", data.get());
        }>
            "Update Values"
        </button>
        // 迭代显示每一行的值
        <For
            each=move || data.get()
            key=|state| state.key.clone()
            let:child
        >
            <p>{child.value}</p>
        </For>
    }
}
```

> 注意这里的 `let:child` 语法。在上一章中，我们通过 `children` 属性介绍了 `<For/>`。实际上，我们可以直接在 `<For/>` 组件的子节点中创建该值，而无需跳出 `view!` 宏。`let:child` 与 `<p>{child.value}</p>` 等价于：
>
> ```rust
> children=|child| view! { <p>{child.value}</p> }
> ```

当你点击 `Update Values` 按钮时……什么都没有发生。或者更确切地说：信号确实更新了，新值也被记录了，但每行的 `{child.value}` 并未更新。

我们来看一下：是不是忘记添加闭包来让它变为响应式了？让我们试试 `{move || child.value}`。

……还是不行。

**问题的根源**在于：如前所述，每行只有在键发生变化时才会重新渲染。我们更新了每行的值，但没有更新任何行的键，因此没有触发重新渲染。而如果查看 `child.value` 的类型，它是一个普通的 `i32`，而不是响应式的 `ReadSignal<i32>` 或类似的东西。这意味着，即使我们在其外部包裹一个闭包，该行的值也永远不会更新。

我们有三种可能的解决方案：

1. 修改 `key`，使其在数据结构发生变化时始终更新。
2. 修改 `value`，使其变为响应式。
3. 使用数据结构的响应式切片，而不是直接使用每行的数据。

## 方案 1：更改 Key

每一行只有在键（key）发生变化时才会重新渲染。上面的示例中行未重新渲染，是因为键没有变化。那么，为什么不强制键发生变化呢？

```rust
<For
    each=move || data.get()
    key=|state| (state.key.clone(), state.value)
    let:child
>
    <p>{child.value}</p>
</For>
```

现在，我们将键包含了行的键和值。这意味着每当行的值发生变化时，`<For/>` 会将其视为一行全新的数据，并替换掉之前的内容。

### 优点

这非常简单。通过为 `DatabaseEntry` 派生 `PartialEq`、`Eq` 和 `Hash`，我们甚至可以简化为 `key=|state| state.clone()`。

### 缺点

**这是三种选项中效率最低的。** 每当行的值发生变化时，都会丢弃之前的 `<p>` 元素，并用一个全新的元素替换它。换句话说，它没有进行细粒度的文本节点更新，而是每次都完全重新渲染整行内容。这种方式的开销与行的 UI 复杂性成正比。

此外，你会注意到我们需要克隆整个数据结构，以便 `<For/>` 可以保存键的副本。对于更复杂的数据结构，这种方式可能会很快变得不合适！

## 方案 2：嵌套信号

如果我们希望对值进行细粒度的响应式更新，可以将每行的 `value` 包装为一个信号。

```rust
#[derive(Debug, Clone)]
struct DatabaseEntry {
    key: String,
    value: RwSignal<i32>,
}
```

`RwSignal<_>` 是一个“读写信号”，将 getter 和 setter 结合在一个对象中。这里我使用它是因为它比单独的 getter 和 setter 更容易存储在结构体中。

```rust
#[component]
pub fn App() -> impl IntoView {
    // 初始设置三行数据
    let (data, set_data) = signal(vec![
        DatabaseEntry {
            key: "foo".to_string(),
            value: RwSignal::new(10),
        },
        DatabaseEntry {
            key: "bar".to_string(),
            value: RwSignal::new(20),
        },
        DatabaseEntry {
            key: "baz".to_string(),
            value: RwSignal::new(15),
        },
    ]);
    view! {
        // 点击时更新每一行的值，值翻倍
        <button on:click=move |_| {
            for row in &*data.read() {
                row.value.update(|value| *value *= 2);
            }
            // 记录信号的新值
            leptos::logging::log!("{:?}", data.get());
        }>
            "Update Values"
        </button>
        // 迭代显示每一行的值
        <For
            each=move || data.get()
            key=|state| state.key.clone()
            let:child
        >
            <p>{child.value}</p>
        </For>
    }
}
```

这个版本可以正常工作！如果你在浏览器的 DOM 检查器中查看，会发现与之前的版本不同，这个版本中只有单个文本节点被更新。将信号直接传递给 `{child.value}` 能正常工作，因为信号在传递到视图中时仍然保留了它的响应式特性。

注意，我将 `set_data.update()` 更改为 `data.read()`。`.read()` 是一种非克隆方式访问信号值。在这里，我们只更新了内部的值，而没有更新值的列表。由于信号自己维护状态，我们实际上不需要更新 `data` 信号，所以使用不可变的 `.read()` 就可以了。

> 实际上，这个版本没有更新 `data`，因此 `<For/>` 本质上是一个静态列表，类似于上一章中的内容。理论上，这里可以直接使用普通迭代器。但如果我们希望将来添加或移除行，`<For/>` 会更有用。

### 优点

这是最有效的选项，与框架的其他思维模型完美契合：随时间变化的值包装在信号中，以便界面能响应这些变化。

### 缺点

如果从 API 或其他你无法控制的数据源接收数据，嵌套的响应式结构可能会显得繁琐。你可能不希望为每个字段创建一个信号包装的结构体。

## 方案 3：Memo 化切片

Leptos 提供了一种原语 [`Memo`](https://docs.rs/leptos/latest/leptos/reactive/computed/struct.Memo.html)，可以创建一个派生计算，仅在其值发生变化时触发响应式更新。

这允许你为较大数据结构的子字段创建响应式值，而无需将该结构的字段包装成信号。

大部分应用逻辑可以与初始（问题）版本保持一致，但 `<For/>` 部分需要更新为以下代码：

```rust
<For
    each=move || data.get().into_iter().enumerate()
    key=|(_, state)| state.key.clone()
    children=move |(index, _)| {
        let value = Memo::new(move |_| {
            data.with(|data| data.get(index).map(|d| d.value).unwrap_or(0))
        });
        view! {
            <p>{value}</p>
        }
    }
/>
```

以下是一些关键的不同点：

- 将 `data` 信号转换为一个带索引的迭代器。
- 显式使用 `children` 属性，以便在运行 `view!` 代码之前可以运行其他代码。
- 定义了一个 `value` memo，并在视图中使用它。这个 `value` 字段实际上并没有使用传递到每行的 `child`，而是通过索引回到原始 `data` 中获取值。

现在，每次 `data` 发生变化时，每个 memo 都会重新计算。如果其值发生变化，它会更新相应的文本节点，而不会重新渲染整行。

### 优点

我们可以获得与信号包装版本相同的细粒度响应式更新，而无需将数据包装成信号。

### 缺点

在 `<For/>` 循环中为每行设置 memo 的操作比使用嵌套信号要复杂一些。例如，你会注意到我们需要通过 `data.get(index)` 防止 `data[index]` 引发 panic，这是因为在移除行后，memo 可能会被触发重新运行一次。（这是因为每行的 memo 和整个 `<For/>` 都依赖于相同的 `data` 信号，而多个依赖于同一信号的响应式值的执行顺序并不保证一致。）

另外需要注意的是，虽然 memo 会缓存其响应式变化，但每次都需要重新运行相同的计算来检查值，因此嵌套信号在进行精准更新时仍然更高效。

## 方案 4：Stores（存储）

> 本部分内容与 [全局状态管理章节](../15_global_state.md#option-3-create-a-global-state-store) 中关于 Stores 的内容有些重复。由于这两部分都是中级/可选内容，适当的重复并无大碍。

Leptos 0.7 引入了一种新的响应式原语，称为“Stores”。Stores 专为解决本章中描述的问题而设计。它们还属于实验性功能，因此需要在 `Cargo.toml` 中添加额外的依赖 `reactive_stores`。

Stores 允许对结构体的单个字段和集合（如 `Vec<_>`）中的单个项目进行细粒度的响应式访问，而无需像上述选项那样手动创建嵌套信号或 Memo。

Stores 基于 `Store` 派生宏构建，该宏为结构体的每个字段创建一个 getter。调用该 getter 可以获得对特定字段的响应式访问。读取该字段时，只会跟踪该字段及其父级/子级；更新它时，也只会通知该字段及其父级/子级，而不会通知同级字段。换句话说，修改 `value` 字段不会通知 `key` 字段，反之亦然。

我们可以调整上面示例中的数据类型。

Store 的顶层必须是一个结构体，因此我们创建一个 `Data` 包装器，它有一个 `rows` 字段：

```rust
#[derive(Store, Debug, Clone)]
pub struct Data {
    #[store(key: String = |row| row.key.clone())]
    rows: Vec<DatabaseEntry>,
}

#[derive(Store, Debug, Clone)]
struct DatabaseEntry {
    key: String,
    value: i32,
}
```

为 `rows` 字段添加 `#[store(key)]` 注解，可以为 Store 字段提供键控访问功能，这在下面的 `<For/>` 组件中会非常有用。我们可以简单地使用 `key`，即在 `<For/>` 中将用到的键。

`<For/>` 组件的实现非常直观：

```rust
<For
    each=move || data.rows()
    key=|row| row.read().key.clone()
    children=|child| {
        let value = child.value();
        view! { <p>{move || value.get()}</p> }
    }
/>
```

由于 `rows` 是一个键控字段，它实现了 `IntoIterator`，因此我们可以直接将 `move || data.rows()` 用作 `each` 属性。这会像嵌套信号版本中的 `move || data.get()` 一样，响应 `rows` 列表的任何变化。

`key` 字段调用 `.read()` 以获取行的当前值，然后克隆并返回 `key` 字段。

在 `children` 属性中，调用 `child.value()` 可以获得该行 `value` 字段的响应式访问权限。如果行被重新排序、添加或移除，键控 Store 字段会保持同步，确保此 `value` 始终与正确的键关联。

在更新按钮的处理程序中，我们迭代 `rows` 中的条目并更新每一项：

```rust
for row in data.rows().iter_unkeyed() {
    *row.value().write() *= 2;
}
```

### 优点

我们可以获得与嵌套信号和 Memo 版本相同的细粒度响应式更新，而无需手动创建嵌套信号或 Memo 化切片。我们只需使用普通数据（结构体和 `Vec<_>`），并用派生宏注解即可，而不需要特殊的嵌套响应式类型。

个人认为，Stores 版本是这里最好的解决方案。这并不意外，因为它是最新的 API。经过几年的经验积累，Stores 综合了我们学到的一些经验教训。

### 缺点

另一方面，这个 API 是最新的。截至本文撰写时（2024 年 12 月），Stores 刚发布几周。我相信仍然有一些需要解决的 bug 或边界情况。

### 完整示例

以下是完整的 Store 示例。你可以在[这里](https://github.com/leptos-rs/leptos/blob/main/examples/stores/src/lib.rs)找到另一个更完整的示例，以及书中的更多讨论[请见此处](../15_global_state.md)。

```rust
#[component]
pub fn App() -> impl IntoView {
    // 创建一个 Store，用于存储 Data，而不是单独存储 rows
    let data = Store::new(Data {
        rows: vec![
            DatabaseEntry {
                key: "foo".to_string(),
                value: 10,
            },
            DatabaseEntry {
                key: "bar".to_string(),
                value: 20,
            },
            DatabaseEntry {
                key: "baz".to_string(),
                value: 15,
            },
        ],
    });

    view! {
        // 点击按钮时更新每一行的值，将其翻倍
        <button on:click=move |_| {
            // 调用 rows() 访问行列表
            for row in data.rows().iter_unkeyed() {
                *row.value().write() *= 2;
            }
            // 记录信号的新值
            leptos::logging::log!("{:?}", data.get());
        }>
            "Update Values"
        </button>
        // 迭代 rows 并显示每一行的值
        <For
            each=move || data.rows()
            key=|row| row.read().key.clone()
            children=|child| {
                let value = child.value();
                view! { <p>{move || value.get()}</p> }
            }
        />
    }
}
```
