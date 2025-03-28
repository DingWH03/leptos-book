# 附录：反应式系统如何工作？

要成功使用 Leptos，你无需深入了解反应式系统的具体工作原理。但当你开始以更高级的方式使用框架时，了解其幕后运行机制会非常有帮助。

反应式系统的原语分为三类：

- **信号（Signals）**（`ReadSignal`/`WriteSignal`、`RwSignal`、`Resource`、`Trigger`）：可以主动更改以触发反应式更新的值。
- **计算（Computations）**（`Memo`）：依赖于信号（或其他计算），通过某些纯计算派生出新的反应式值。
- **效果（Effects）**：观察者，监听某些信号或计算的变化并运行一个函数，从而产生某种副作用。

派生信号（Derived Signals）是一种非原语计算：它们是简单的闭包，只是允许你将一些重复的基于信号的计算重构为可重用的函数，可以在多个地方调用，但它们并未在反应式系统中作为节点表示。

其他所有原语实际上都存在于反应式系统中，作为反应式图中的节点。

反应式系统的大部分工作是将信号的更改传播到效果中，可能会经过一些中间的 `Memo`。

反应式系统假定，效果（例如渲染到 DOM 或发出网络请求）的成本远远高于在应用中更新一个 Rust 数据结构。

因此，反应式系统的**主要目标**是**尽可能少地运行效果**。

Leptos 通过构建反应式图来实现这一点。

> Leptos 当前的反应式系统在很大程度上基于 JavaScript 的 [Reactively](https://github.com/modderme123/reactively) 库。你可以阅读 Milo 的文章《[Super-Charging Fine-Grained Reactivity](https://dev.to/modderme123/super-charging-fine-grained-reactive-performance-47ph)》，这是一篇关于其算法以及细粒度反应式系统的优秀说明，其中包括一些非常漂亮的图表！

## 反应式图

信号（signals）、计算（memos）和效果（effects）都具有以下三个特性：

- **值（Value）**：它们有一个当前值：要么是信号的值，要么是（对于 memos 和 effects）上一次运行返回的值（如果有）。
- **来源（Sources）**：它们依赖的其他反应式原语。（对于信号，这始终是一个空集。）
- **订阅者（Subscribers）**：依赖它们的其他反应式原语。（对于效果，这始终是一个空集。）

实际上，信号、memos 和效果只是“反应式图”中“节点”这一通用概念的常规名称。信号始终是“根节点”，没有来源/父节点。效果始终是“叶节点”，没有订阅者。memos 通常既有来源又有订阅者。

> 在以下示例中，我将使用 `nightly` 语法，这样可以减少文档的冗长，便于阅读，而非复制粘贴。

### 简单依赖关系

想象以下代码：

```rust
// A
let (name, set_name) = signal("Alice");

// B
let name_upper = Memo::new(move |_| name.with(|n| n.to_uppercase()));

// C
Effect::new(move |_| {
	log!("{}", name_upper());
});

set_name("Bob");
```

这里的反应式图非常清晰：`name` 是唯一的信号/源节点，`Effect::new` 是唯一的效果/终端节点，中间有一个 memo。

```
A   (name)
|
B   (name_upper)
|
C   (the effect)
```

### 分裂分支

让我们增加一些复杂性：

```rust
// A
let (name, set_name) = signal("Alice");

// B
let name_upper = Memo::new(move |_| name.with(|n| n.to_uppercase()));

// C
let name_len = Memo::new(move |_| name.len());

// D
Effect::new(move |_| {
	log!("len = {}", name_len());
});

// E
Effect::new(move |_| {
	log!("name = {}", name_upper());
});
```

这也很直观：一个信号源 `name`（A）分裂为两条平行的分支：`name_upper`（B）和 `name_len`（C），每条分支都有一个依赖它的效果。

```
 __A__
|     |
B     C
|     |
E     D
```

现在更新信号：

```rust
set_name("Bob");
```

日志会立即输出：

```
len = 3
name = BOB
```

再试一次：

```rust
set_name("Tim");
```

日志显示：

```
name = TIM
```

`len = 3` 不会再次记录。

记住：**反应式系统的目标是尽可能减少运行效果的次数**。将 `name` 从 `"Bob"` 改为 `"Tim"` 会导致每个 memo 重新运行。但只有当它们的值实际上发生变化时，它们才会通知其订阅者。`"BOB"` 和 `"TIM"` 不同，因此相关效果会再次运行。但两个名字的长度都是 `3`，因此相关效果不会再次运行。

### 合并分支

我们来看一个被称为**菱形问题**（diamond problem）的例子：

```rust
// A
let (name, set_name) = signal("Alice");

// B
let name_upper = Memo::new(move |_| name.with(|n| n.to_uppercase()));

// C
let name_len = Memo::new(move |_| name.len());

// D
Effect::new(move |_| {
	log!("{} is {} characters long", name_upper(), name_len());
});
```

这个例子的反应式图看起来像这样：

```
 __A__
|     |
B     C
|     |
|__D__|
```

你可以看到为什么它被称为“菱形问题”。如果用直线而不是 ASCII 艺术来连接这些节点，它会形成一个菱形：两个 memos 分别依赖于一个信号，并最终合并到一个效果中。

一个简单的基于推送的反应式实现会导致这个效果运行两次，这会很糟糕。（记住，我们的目标是尽可能少地运行效果。）例如，可以实现一种反应式系统，让信号和 memos 将它们的更改立即推送到整个图的下游，基本上是以深度优先的方式遍历图。换句话说，更新 `A` 会通知 `B`，然后通知 `D`；接着 `A` 再通知 `C`，然后再次通知 `D`。这既低效（`D` 运行了两次），又容易出错（`D` 在第一次运行时实际上使用了第二个 memo 的不正确值）。

## 解决菱形问题

任何值得信赖的反应式实现都会致力于解决这个问题。解决方法有多种（再次推荐阅读 [Milo 的文章](https://dev.to/modderme123/super-charging-fine-grained-reactive-performance-47ph) 获取全面的概览）。

以下是 Leptos 的实现方式的简要说明。

一个反应式节点始终处于以下三种状态之一：

- **`Clean`**：已知没有更改。
- **`Check`**：可能已更改。
- **`Dirty`**：确定已更改。

更新信号会将信号标记为 `Dirty`，并递归地将其所有后代标记为 `Check`。任何后代中是效果的节点会被加入到队列中以便重新运行。

```
    ____A (DIRTY)___
   |               |
B (CHECK)    C (CHECK)
   |               |
   |____D (CHECK)__|
```

接下来，效果会被运行。（此时，所有效果都会被标记为 `Check`。）在重新运行其计算之前，效果会检查其父节点是否为 `Dirty`。因此：

1. `D` 检查 `B` 是否为 `Dirty`。
2. `B` 被标记为 `Check`，因此 `B` 会检查它的父节点 `A`：
   - `B` 发现 `A` 是 `Dirty`。
   - 这意味着 `B` 需要重新运行，因为它的来源之一发生了更改。
   - `B` 重新运行，生成一个新值，并标记自己为 `Clean`。
   - 由于 `B` 是一个 memo，它会将之前的值与新值进行比较。
   - 如果它们相同，`B` 返回“没有更改”；否则，返回“有更改”。
3. 如果 `B` 返回“有更改”，`D` 知道需要运行并立即重新运行，而无需检查其他来源。
4. 如果 `B` 返回“没有更改”，`D` 会继续检查 `C`（`C` 的处理方式与 `B` 相同）。
5. 如果 `B` 和 `C` 都没有更改，效果不需要重新运行。
6. 如果 `B` 或 `C` 中的任意一个更改，效果将会重新运行。

因为效果只会被标记为 `Check` 一次并且只会被加入队列一次，所以它只会运行一次。

如果简单版本是一个“基于推送”的反应式系统，通过图的下游推送反应式更改并导致效果运行两次，那么这种实现可以称为“推-拉”系统。它将 `Check` 状态推送到图的下游，然后“拉”回来。在大规模图中，系统可能需要在图中上下左右来回移动，以准确确定哪些节点需要重新运行。

**重要的权衡**：基于推送的反应式系统传播信号更改的速度更快，但代价是过度运行 memos 和效果。记住：反应式系统的设计目标是**最小化效果的运行次数**，基于一个正确的假设：副作用的成本远远高于这种完全在库的 Rust 代码中进行的、缓存友好的图遍历。衡量一个反应式系统的好坏，不是看它传播更改的速度有多快，而是看它传播更改时能否**避免过度通知**。

## Memos 与 Signals 的区别

需要注意的是，**信号（signals）始终会通知它们的子节点**。也就是说，当信号更新时，它总是会被标记为 `Dirty`，即使它的新值与旧值相同。否则，我们就必须要求信号实现 `PartialEq`，但对某些类型来说，这可能是非常昂贵的检查。（例如，像 `some_vec_signal.update(|n| n.pop())` 这样的操作很明显会发生变化，因此增加不必要的相等性检查没有意义。）

**Memos** 则会在通知它们的子节点之前检查它们是否发生了变化。Memos 的计算只会运行一次，无论你调用 `.get()` 多少次，但它会在其来源信号发生变化时运行。这意味着，如果 memo 的计算非常昂贵，你可能需要对其输入进行缓存（memoize），以确保只有当输入发生变化时才重新计算。

## Memos 与派生信号（Derived Signals）的区别

以上机制说明了 Memos 的强大之处，但大多数实际应用的反应式图往往**较浅且较宽**：你可能有 100 个来源信号和 500 个效果，但没有 Memo，或者在极少数情况下，信号与效果之间可能有三四个 Memo。Memos 非常擅长限制通知其订阅者的频率，但如前文所述，它们也带来了一些开销：

1. **`PartialEq` 检查**：这可能会非常昂贵，具体取决于类型。
2. **增加内存开销**：在反应式系统中存储另一个节点需要额外的内存。
3. **增加计算开销**：图遍历会消耗更多计算资源。

在计算本身比上述反应式处理更便宜的情况下，应该避免过度使用 Memo，而是直接使用派生信号。以下是一个永远不应该使用 Memo 的示例：

```rust
let (a, set_a) = signal(1);
// 以下这些计算不需要使用 Memo
let b = move || a() + 2;
let c = move || b() % 2 == 0;
let d = move || if c() { "even" } else { "odd" };

set_a(2);
set_a(3);
set_a(5);
```

尽管从技术上讲，Memo 可以在将 `a` 从 `3` 设置为 `5` 之间节省一次额外的 `d` 计算，但这些计算本身比反应式算法更便宜。

在某些情况下，你可能只考虑在运行某些昂贵的副作用之前缓存最后一个节点：

```rust
let text = Memo::new(move |_| {
    d()
});
Effect::new(move |_| {
    engrave_text_into_bar_of_gold(&text());
});
```

这使得 Memo 的使用仅在真正需要时才会进行，避免了不必要的开销。
