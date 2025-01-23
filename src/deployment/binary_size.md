# 优化 WASM 二进制文件大小

部署 Rust/WebAssembly 前端应用的主要缺点之一是将一个 WASM 文件拆分成可动态加载的小块比拆分 JavaScript 包更困难。虽然 Emscripten 生态中有类似 [`wasm-split`](https://emscripten.org/docs/optimizing/Module-Splitting.html) 的实验，但目前还没有办法拆分和动态加载 Rust/`wasm-bindgen` 二进制文件。这意味着整个 WASM 二进制文件需要在应用变为交互式之前加载完毕。由于 WASM 格式设计为流式编译，WASM 文件的每千字节编译速度比 JavaScript 文件快得多。（更多详细内容，请[参考 Mozilla 团队的一篇文章](https://hacks.mozilla.org/2018/01/making-webassembly-even-faster-firefoxs-new-streaming-and-tiering-compiler/)，讲述了 WASM 流式编译的原理。）

尽管如此，尽可能向用户提供最小的 WASM 二进制文件仍然很重要，这可以减少网络使用并让应用尽快变为可交互状态。

那么，有哪些实用的优化步骤呢？

## 优化措施

1. **确保使用 release 构建。**（Debug 构建会大得多。）
2. **为 WASM 添加一个优化大小而非速度的 release 配置。**

对于一个 `cargo-leptos` 项目，可以在 `Cargo.toml` 中添加以下内容：

```toml
[profile.wasm-release]
inherits = "release"
opt-level = 'z'
lto = true
codegen-units = 1

# ....

[package.metadata.leptos]
# ....
lib-profile-release = "wasm-release"
```

这会让 WASM 的 release 构建针对大小进行高度优化，同时保持服务器端构建针对速度优化。（对于纯客户端渲染的应用，可以直接将 `[profile.wasm-release]` 配置用作 `[profile.release]`。）

3. **在生产环境中始终使用压缩的 WASM 文件。**  
WASM 通常压缩效果很好，未压缩大小的 50% 以下，使用 Actix 或 Axum 提供静态文件时可以轻松启用压缩。

4. **如果使用 nightly Rust，可以用相同的配置重建标准库**，而不是使用 `wasm32-unknown-unknown` 目标提供的预构建标准库。

在项目中创建 `.cargo/config.toml` 文件：

```toml
[unstable]
build-std = ["std", "panic_abort", "core", "alloc"]
build-std-features = ["panic_immediate_abort"]
```

注意：如果同时用于 SSR，这相同的 Cargo 配置也会被应用到服务器。需要明确指定目标：

```toml
[build]
target = "x86_64-unknown-linux-gnu" # 或其他目标
```

如果出现由于未设置 `has_std` 导致的构建错误，可以通过以下方式修复：

```toml
[build]
rustflags = ["--cfg=has_std"]
```

此外，需要在 `Cargo.toml` 的 `[profile.release]` 中添加 `panic = "abort"`。

5. **序列化/反序列化代码会增加二进制大小。**  
Leptos 默认使用 `serde` 处理资源的序列化和反序列化。可以尝试使用 `miniserde` 或 `serde-lite`，这些库实现了 `serde` 的子集功能，通常更注重优化大小而非速度。

## 避免的情况

某些 crates 会显著增加二进制文件大小。例如，`regex` crate 默认功能会增加大约 500kb（主要因为需要引入 Unicode 表数据）。在对大小敏感的场景下，可以考虑避免使用正则表达式，或者直接调用浏览器 API 使用内置正则引擎。（例如，`leptos_router` 在需要正则时就是这样做的。）

Rust 对运行时性能的承诺有时会与优化二进制大小相冲突。例如，Rust 会对泛型函数进行单态化，为每种调用类型创建单独的函数版本。这比动态调度更快，但会增加二进制文件大小。Leptos 在运行时性能与二进制大小之间进行了平衡；但如果你在代码中大量使用泛型，可能会增加二进制大小。例如，一个泛型组件体内包含大量代码，且被四种不同类型调用，编译器可能会包含这段代码的四个副本。可以通过重构为具体的内部函数或辅助函数，既保持性能又减少二进制大小。

## 最后一点思考

请记住，在服务器渲染的应用中，JS 包大小或 WASM 二进制文件大小只会影响**一个方面**：首次加载的交互时间。这对用户体验非常重要：没有人希望点击按钮三次却没反应，因为交互代码仍在加载——但这不是唯一重要的指标。

值得注意的是，流式加载一个完整的 WASM 二进制文件意味着后续导航几乎是即时的，仅取决于额外数据的加载。正因为 WASM 二进制文件**不是**按包拆分的，导航到新路由时不需要像 JavaScript 框架那样加载额外的 JS/WASM。这是权衡两种方法的真实体现。

始终优化应用中的“低垂果实”，同时在真实用户的网络速度和设备条件下测试应用效果，在采取复杂优化之前确保实际效果良好。
