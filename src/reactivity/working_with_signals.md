# 信号的使用

到目前为止，我们已经通过一些简单的例子了解了如何使用 [`signal`](https://docs.rs/leptos/latest/leptos/reactive/signal/fn.signal.html)，它返回一个 [`ReadSignal`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.ReadSignal.html) 读取器和一个 [`WriteSignal`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.WriteSignal.html) 写入器。

## 获取与设置

以下是一些基本的信号操作：

### 获取值

1. [`.read()`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.ReadSignal.html#impl-Read-for-T) 返回一个只读保护对象（read guard），可以通过解引用来获取信号的值，并且会对信号值的未来变化进行响应式跟踪。注意，在此保护对象被释放之前，不能更新信号的值，否则会导致运行时错误。
2. [`.with()`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.ReadSignal.html#impl-With-for-T) 接收一个函数，该函数会获得信号当前值的引用（`&T`），并对信号进行跟踪。
3. [`.get()`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.ReadSignal.html#impl-Get-for-T) 克隆信号的当前值，并对信号值的后续更改进行跟踪。

`.get()` 是访问信号最常用的方法。`.read()` 适用于需要通过不可变引用（而不是克隆值）调用的方法（如 `my_vec_signal.read().len()`）。`.with()` 则在需要对该引用执行更多操作时非常有用，并确保不会长时间持有锁。

### 设置值

1. [`.write()`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.WriteSignal.html#impl-Write-for-WriteSignal%3CT,+S%3E) 返回一个写保护对象（write guard），它是信号值的一个可变引用，并会通知所有订阅者需要更新。注意，在该保护对象被释放之前，无法读取信号的值，否则会导致运行时错误。
2. [`.update()`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.WriteSignal.html#impl-Update-for-T) 接收一个函数，该函数会获得信号当前值的可变引用（`&mut T`），并通知订阅者更新。（`.update()` 不会返回闭包的返回值，但如果需要返回值，可以使用 [`.try_update()`](https://docs.rs/leptos/latest/leptos/trait.SignalUpdate.html#tymethod.try_update)，例如当从 `Vec<_>` 中移除一个元素并希望获取被移除的元素时。）
3. [`.set()`](https://docs.rs/leptos/latest/leptos/reactive/signal/struct.WriteSignal.html#impl-Set-for-T) 替换信号的当前值，并通知订阅者更新。

`.set()` 是设置新值最常用的方法；`.write()` 在原地更新值时非常有用。与 `.read()` 和 `.with()` 类似，`.update()` 在需要避免长时间持有写锁时也非常实用。

```admonish note
这些特性（traits）基于特性组合，并通过通用实现（blanket implementations）提供。例如，`Read` 为任何实现了 `Track` 和 `ReadUntracked` 的类型提供实现；`With` 为任何实现了 `Read` 的类型提供实现；`Get` 为实现了 `With` 和 `Clone` 的类型提供实现，等等。

类似的关系也适用于 `Write`、`Update` 和 `Set`。

在阅读文档时值得注意：如果只看到 `ReadUntracked` 和 `Track` 作为已实现的特性，仍然可以使用 `.with()`、`.get()`（如果 `T: Clone`），等等。
```

## 信号的使用

你可能会注意到，`.get()` 和 `.set()` 可以通过 `.read()` 和 `.write()`，或者 `.with()` 和 `.update()` 实现。换句话说，`count.get()` 等同于 `count.with(|n| n.clone())` 或 `count.read().clone()`，而 `count.set(1)` 的实现可以通过 `count.update(|n| *n = 1)` 或 `*count.write() = 1` 实现。

当然，`.get()` 和 `.set()` 的语法更加简洁。

不过，其他方法也有一些非常好的使用场景。

例如，考虑一个保存了 `Vec<String>` 的信号。

```rust
let (names, set_names) = signal(Vec::new());
if names.get().is_empty() {
	set_names(vec!["Alice".to_string()]);
}
```

从逻辑上看，这段代码很简单，但它隐藏了一些显著的效率问题。请记住，`names.get().is_empty()` 会克隆整个值。这意味着我们克隆了整个 `Vec<String>`，运行了 `is_empty()` 方法，然后立即丢弃了克隆的副本。

同样，`set_names` 用一个全新的 `Vec<_>` 替换了原有值。这种做法是可以的，但其实我们完全可以直接就地修改原有的 `Vec<_>`。

```rust
let (names, set_names) = signal(Vec::new());
if names.read().is_empty() {
	set_names.write().push("Alice".to_string());
}
```

现在，我们的函数通过引用访问 `names` 来运行 `is_empty()`，避免了克隆操作，并且直接对原有的 `Vec<_>` 进行修改。

## Nightly 语法

在使用 `nightly` 特性和 `nightly` 语法时，将 `ReadSignal` 作为函数调用是 `.get()` 的语法糖。将 `WriteSignal` 作为函数调用是 `.set()` 的语法糖。因此：

```rust
let (count, set_count) = signal(0);
set_count(1);
logging::log!(count());
```

等同于：

```rust
let (count, set_count) = signal(0);
set_count.set(1);
logging::log!(count.get());
```

这不仅仅是语法糖，而是通过将信号语义上与函数统一，使 API 更加一致：详情请参阅 [插曲：函数](./interlude_functions.md)。

## 让信号相互依赖

经常有人会问，如果一个信号需要根据另一个信号的值进行变化，该如何实现？对此，有三种不错的方法，以及一种虽然不太理想但在特定情况下也可以接受的方法。

### 推荐的选项

**1) B 是 A 的函数。** 为 A 创建一个信号，为 B 创建一个派生信号或 Memo。

```rust
// A
let (count, set_count) = signal(1);
// B 是 A 的函数
let derived_signal_double_count = move || count.get() * 2;
// B 是 A 的函数
let memoized_double_count = Memo::new(move |_| count.get() * 2);
```

> 关于是选择派生信号还是 Memo 的建议，请参阅 [`Memo`](https://docs.rs/leptos/latest/leptos/reactive/computed/struct.Memo.html) 的文档。

**2) C 是 A 和其他事物 B 的函数。** 为 A 和 B 创建信号，为 C 创建一个派生信号或 Memo。

```rust
// A
let (first_name, set_first_name) = signal("Bridget".to_string());
// B
let (last_name, set_last_name) = signal("Jones".to_string());
// C 是 A 和 B 的函数
let full_name = move || format!("{} {}", &*first_name.read(), &*last_name.read());
```

**3) A 和 B 是独立的信号，但有时会同时更新。** 在调用更新 A 时，单独调用更新 B。

```rust
// A
let (age, set_age) = signal(32);
// B
let (favorite_number, set_favorite_number) = signal(42);
// 用于处理“清空”按钮的点击事件
let clear_handler = move |_| {
  // 同时更新 A 和 B
  set_age.set(0);
  set_favorite_number.set(0);
};
```

### 如果你真的必须这样做……

**4) 创建一个 Effect，当 A 更改时写入 B。** 这种方法不被推荐，原因如下：
a) 它的效率总是较低，因为每次 A 更新时都会进行两次完整的响应式流程（更新 A 会触发 effect 的运行，以及任何依赖 A 的其他 effect 的运行；然后更新 B，会触发任何依赖 B 的 effect 的运行）。  
b) 它增加了意外创建无限循环或过度重新运行 effect 的风险。这种“乒乓式”响应式意大利面条代码在 2010 年代初很常见，但我们通过读取-写入分离等机制试图避免这些问题，并不推荐从 effect 中写入信号。

在大多数情况下，最好通过派生信号或 Memo 的方式，按照清晰的自上而下的数据流重新设计。但即使不这样，也不是不可接受的。

> 我这里特意没有提供示例。阅读 [`Effect`](https://docs.rs/leptos/latest/leptos/reactive/effect/struct.Effect.html) 文档，了解具体如何实现这种方式。
