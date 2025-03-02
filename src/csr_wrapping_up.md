# 第一部分总结：客户端渲染

到目前为止，我们编写的所有内容几乎完全是在浏览器中渲染的。当我们使用 Trunk 创建应用时，它是通过一个本地开发服务器提供服务的。如果将其构建为生产版本并部署，它会通过你的服务器或 CDN 提供服务。在这两种情况下，提供的内容是一个 HTML 页面，其中包含：

1. 你的 Leptos 应用程序的 URL，该应用程序已被编译为 WebAssembly (WASM)；
2. 用于初始化这个 WASM 模块的 JavaScript 的 URL；
3. 一个空的 `<body>` 元素。

当 JavaScript 和 WASM 加载完成后，Leptos 会将你的应用渲染到 `<body>` 中。这意味着在 JavaScript 和 WASM 加载并运行之前，屏幕上不会显示任何内容。这种方式存在一些缺点：

1. **增加加载时间**：用户的屏幕在额外资源下载完成之前是空白的；
2. **对 SEO 不友好**：加载时间更长，并且提供的 HTML 没有任何有意义的内容；
3. **对部分用户不可用**：如果某些原因导致 JavaScript/WASM 没有加载（例如用户在乘火车，刚好进入隧道，WASM 还未加载完成；用户使用不支持 WASM 的旧设备；或者用户因某些原因禁用了 JavaScript/WASM），应用将无法运行。

这些缺点存在于整个 Web 生态系统中，但对 WASM 应用尤其明显。

然而，具体项目是否受这些限制的影响取决于其需求。

如果你只想部署你的客户端渲染 (CSR) 网站，可以直接跳到 [“部署”](https://leptos-rs.github.io/leptos/deployment/index.html) 一章，在那里你会找到如何最好地部署 Leptos CSR 网站的指导。

但是，如果你希望在 `index.html` 页面中返回的不仅仅是一个空的 `<body>` 标签，该怎么办呢？可以使用“服务端渲染” (Server-Side Rendering, SSR)！

关于这个主题，可以写一本（可能已经有）完整的书，但其核心非常简单：通过 SSR，你可以返回一个初始的 HTML 页面，反映应用或站点的实际初始状态。这样在 JavaScript/WASM 加载期间，用户可以访问纯 HTML 版本，而不是只看到一个空白页面。

本书第二部分将详细介绍 Leptos 的服务端渲染 (SSR)！
