# 异步渲染和 SSR “模式”

如果一个页面使用的所有数据都是同步可用的，那么服务端渲染就相对简单：只需要沿着组件树往下遍历，将每个元素都渲染成 HTML 字符串即可。但这忽略了一个重要问题：如果页面包含异步数据——也就是在客户端会放在 `<Suspense/>` 里渲染的那种——该怎么处理呢？

当页面需要加载异步数据时，我们应该怎样做？等所有异步数据都加载完，再一次性渲染所有内容吗？（我们把这个叫做“异步（async）渲染”）或者说，完全走向另一个极端，只是立刻把现有的 HTML 发送给客户端，然后让客户端自行加载资源并填充数据？（我们把这个叫做“同步（synchronous）渲染”）又或者我们可以找到某个折中的方法？（提示：确实有！）

如果你曾听过在线音乐或看过在线视频，就知道 HTTP 支持流式传输 (streaming)。这意味着，一个连接可以分批发送数据，而不必等到所有内容都准备好再一次性发送。你可能不知道的是，浏览器在渲染部分 HTML 页面时也做得很不错。把这两点结合起来，你就能通过**流式传输 HTML**来提升用户体验。Leptos 甚至默认就支持了这一点，而且无需任何额外配置。而且，**流式传输 HTML**还有不止一种方式：你既可以按顺序把生成页面所需的 HTML 片段像视频帧一样按顺序发送，也可以不按顺序发送……确实可以有各种方式。

下面我们进一步看看具体是怎么回事。

Leptos 支持各种主要的、包含异步数据的服务端渲染方式：

1. [同步渲染（Synchronous Rendering）](#同步渲染synchronous-rendering)
2. [异步渲染（Async Rendering）](#异步渲染async-rendering)
3. [按顺序流式传输（In-Order Streaming）](#按顺序流式传输in-order-streaming)
4. [不按顺序流式传输（Out-of-Order Streaming）](#不按顺序流式传输out-of-order-streaming)（以及部分阻塞变体）

## 同步渲染（Synchronous Rendering）

1. **Synchronous**：返回一个带有 `<Suspense/>` `fallback` 的 HTML shell（外壳）。在客户端通过 `create_local_resource` 加载数据，数据加载完成后再替换掉 `fallback`。

- **优点 (Pros)**  
  - 应用外壳（App shell）能非常快地出现，即极佳的 TTFB（到首字节的时间）。
- **缺点 (Cons)**  
  - 资源加载相对较慢；你需要等到 JS 和 WASM 都加载完才能开始请求任何数据。  
  - 无法在 `<title>` 或其他 `<meta>` 标签等位置使用异步资源的数据，从而影响 SEO，以及社交媒体的链接预览等。

如果你正在使用服务端渲染，那么从性能角度看，“同步模式”几乎不是你真正想要的方式。原因在于它错过了一个重要的优化点：如果你在服务端渲染期间加载异步资源，你可以在服务器就开始加载数据，而不是等到客户端收到 HTML、再加载 JS + WASM，**然后**才知道需要哪些资源并开始加载。服务端渲染可以在客户端第一次发出请求时就开始加载资源。从这个角度看，对于服务端渲染来说，异步资源就像一个在服务端启动加载、在客户端完成的 `Future`。只要这些资源可以序列化，整体加载时间就会更快。

> 这就是为什么 `Resource` 需要它的数据可序列化（serializable），以及为什么对于不能序列化、只能在浏览器端加载的异步数据，你应该使用 `LocalResource`。当你**可以**创建可序列化（serializable）的资源却选择用 `LocalResource` 时，就意味着你放弃了一个可能的优化机会。

## 异步渲染（Async Rendering）

<video controls>
  <source src="https://github.com/leptos-rs/leptos/blob/main/docs/video/async.mov?raw=true" type="video/mp4">
</video>

2. **`async`**：在服务器端加载所有资源。等所有数据都加载完成，再一次性输出整页 HTML。

- **优点 (Pros)**  
  - 能够在真正渲染 `<head>` 之前就已经知道所有异步数据，从而更好地处理 `<meta>` 等标签。  
  - 相比 “同步（synchronous）” 渲染，整体加载速度更快，因为异步资源会在服务器上提前开始加载。
- **缺点 (Cons)**  
  - 更长的加载时间 / TTFB：你必须等到所有异步资源都加载完成后，才能向客户端展示任何东西。在这之前，页面都是空白的。

## 按顺序流式传输（In-Order Streaming）

<video controls>
  <source src="https://github.com/leptos-rs/leptos/blob/main/docs/video/in-order.mov?raw=true" type="video/mp4">
</video>

3. **In-order streaming**：遍历组件树，渲染 HTML，直到遇到 `<Suspense/>`。将到目前为止生成的所有 HTML 作为一个数据块发送给客户端，然后等待这个 `<Suspense/>` 下需要的所有资源加载完成，接着再将它们渲染成 HTML，继续往下遍历并发送，直到遇到下一个 `<Suspense/>` 或者页面结束。

- **优点 (Pros)**  
  - 页面不会一直空白；在数据尚未准备好之前，至少可以显示一些内容。
- **缺点 (Cons)**  
  - 由于在每个 `<Suspense/>` 处都要暂停，外壳会比同步渲染（或者不按顺序流式传输）更慢出现。  
  - 无法展示 `<Suspense/>` 的 fallback 状态。  
  - 需要等整个页面全部加载完成后才能开始“重水化”（hydrate），因此在等待那些被“挂起”的片段加载完之前，已经发送给客户端的页面部分也无法互动。

## 不按顺序流式传输（Out-of-Order Streaming）

<video controls>
  <source src="https://github.com/leptos-rs/leptos/blob/main/docs/video/out-of-order.mov?raw=true" type="video/mp4">
</video>

4. **Out-of-order streaming**：类似同步渲染，会立即返回一个带有 `<Suspense/>` `fallback` 的 HTML 壳。但实际上还是在**服务器端**加载数据，并在数据加载完后通过流式传输把真正的内容发给客户端，用来替换原本的 fallback。

- **优点 (Pros)**  
  - **同步**和 **`async`** 的优点结合：  
    - 由于立即发送了整个同步壳，初始响应 / TTFB 非常快；  
    - 同时，资源在服务器端提前加载，使整体时间也很快；  
    - 可以显示 fallback 加载状态，并在数据就绪后动态替换，而不是给未加载的数据留空白。  
- **缺点 (Cons)**  
  - 要让被挂起的片段以正确顺序出现，需要启用 JavaScript。对于不支持或禁用 JavaScript 的用户，需要一小段在 `<template>` 标签旁的 `<script>` 来完成片段替换，但不用额外加载其他 JS 文件。

5. **部分阻塞流式传输（Partially-blocked streaming）**  
   当页面上有多个 `<Suspense/>` 时，“部分阻塞”流式传输会很有用。可通过在路由上设置 `ssr=SsrMode::PartiallyBlocked` 并在视图中使用“阻塞资源”（blocking resources）触发。若某个 `<Suspense/>` 会读取一个或多个“阻塞资源” (参见下方说明)，则不会发送 fallback；服务器会等它准备好后，在服务器端直接替换 fallback，并将完整片段包含在初始 HTML 响应里，所以即使 JavaScript 被禁用也能看到内容。其他 `<Suspense/>` 将会以不按顺序的方式流式传输，即和 `SsrMode::OutOfOrder` 的默认行为类似。

   这在你有多个 `<Suspense/>` 且其中一个比其他更重要的场景非常有用：例如博客文章（比较重要）和评论（不太重要），或者产品信息（重要）和评论（次要）。如果页面只有一个 `<Suspense/>`，或者所有 `<Suspense/>` 都包含阻塞资源，那么此时它就等同于慢一些的 `async` 渲染，没有太大意义。

   - **优点 (Pros)**  
     - 即使用户禁用了 JavaScript，也能看到已加载的内容。
   - **缺点 (Cons)**  
     - 初始响应时间比不按顺序流式传输更慢。  
     - 服务器需做更多工作，可能会稍微拖慢整体响应时间。  
     - 没有 fallback 状态展示。

## 如何使用这些 SSR 模式

因为它在性能方面有一个很好的平衡，Leptos 默认采用“不按顺序流式传输”(out-of-order streaming)。不过，想要使用其他模式也很简单：你只需在某个（或多个）`<Route/>` 组件上加一个 `ssr` 属性即可，具体可参考 [“ssr_modes” 示例](https://github.com/leptos-rs/leptos/blob/main/examples/ssr_modes/src/app.rs)。

```rust
<Routes fallback=|| "Not found.">
    // 用不按顺序流式传输和 <Suspense/> 加载首页
    <Route path=path!("") view=HomePage/>

    // 加载帖子时使用异步渲染，以便在加载完数据后才能设定
    // 标题和元数据
    <Route
        path=path!("/post/:id")
        view=Post
        ssr=SsrMode::Async
    />
</Routes>
```

如果一个路径包含多个嵌套路由，则会使用其中限制性最强的 SSR 模式：也就是说，如果有一个嵌套路由要求 `async` 渲染，那么整个初始请求就会采用 `async` 来渲染。从严格程度上看，`async` 是最严格的，其次是 in-order，然后才是 out-of-order。（思考一下就能明白为什么是这样。）

## 阻塞资源（Blocking Resources）

可以通过 `Resource::new_blocking` 创建一个阻塞资源（blocking resource）。阻塞资源依然是异步加载，就像任何 Rust 中的异步操作或 `.await` 一样，并不会真的阻塞服务器线程等。但如果某个 `<Suspense/>` 内部读取了一个阻塞资源，那么在该 `<Suspense/>` 完成之前，整个 HTML **流**（包括初始同步外壳）都不会发回客户端。

从性能角度看，这通常不是理想的，因为页面的同步外壳在资源准备好之前无法显示。然而，这样做可以让你在真正渲染 `<head>` 时使用这些资源的数据，比如设置 `<title>` 或 `<meta>` 等标签。这听起来跟 `async` 渲染很相似，但有一个重大区别：如果你有多个 `<Suspense/>` 区域，你可以只对其中一个 `<Suspense/>` 阻塞，但对其他 `<Suspense/>` 仍然可以使用 fallback 并采用流式传输。

举个例子：想象一个博客页面。为了 SEO 和社交分享，我非常想在初始 HTML 的 `<head>` 中呈现博客文章的标题和摘要；但评论加载早或晚并不重要，我可以希望尽可能延迟加载它们。

用阻塞资源，你可以这么写：

```rust
#[component]
pub fn BlogPost() -> impl IntoView {
    let post_data = Resource::new_blocking(/* 加载博文内容 */);
    let comments_data = Resource::new(/* 加载评论 */);
    view! {
        <Suspense fallback=|| ()>
            {move || Suspend::new(async move {
                let data = post_data.await;
                view! {
                    <Title text=data.title/>
                    <Meta name="description" content=data.excerpt/>
                    <article>
                        /* 渲染文章内容 */
                    </article>
                }
            })}
        </Suspense>
        <Suspense fallback=|| "Loading comments...">
            {move || Suspend::new(async move {
                let comments = comments_data.await;
                todo!()
            })}
        </Suspense>
    }
}
```

第一个 `<Suspense/>`（也就是博客文章的正文）使用的是阻塞资源，因此会阻塞 HTML 流的返回，直到数据准备好。这样依赖该资源的 `<meta>` 或 `<title>` 等也会在服务器端就生成好。

如果再结合下面的路由定义（其中使用了 `SsrMode::PartiallyBlocked`），被阻塞的资源会在服务器端完整渲染，这让禁用 JavaScript 或不支持 JavaScript 的用户也能查看到文章内容：

```rust
<Routes fallback=|| "Not found.">
    // 首页使用不按顺序流式传输和 <Suspense/>
    <Route path=path!("") view=HomePage/>

    // 加载帖子时使用异步渲染，以便在加载完数据后才能设定
    // 标题和元数据
    <Route
        path=path!("/post/:id")
        view=Post
        ssr=SsrMode::PartiallyBlocked
    />
</Routes>
```

而第二个 `<Suspense/>`（评论部分）并不会阻塞流式传输。这样一来，“阻塞资源”能让你在 SEO 和用户体验之间做一个很好的平衡和细粒度控制：在满足搜索引擎和社交分享需要的同时，其他不太重要的数据依然可以采用更快的流式加载方式。
