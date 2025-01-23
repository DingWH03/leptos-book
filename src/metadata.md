# 元数据

到目前为止，我们渲染的所有内容都在 HTML 文档的 `<body>` 内。这是有道理的，毕竟网页上所有可见的内容都位于 `<body>` 中。

然而，在某些情况下，你可能需要使用与 UI 相同的响应式原语和组件模式来更新文档 `<head>` 中的内容。

这就是 [`leptos_meta`](https://docs.rs/leptos_meta/latest/leptos_meta/) 包的作用。

## 元数据组件

`leptos_meta` 提供了一些特殊组件，可以让你从应用程序的任何组件中向 `<head>` 注入数据：

[`<Title/>`](https://docs.rs/leptos_meta/latest/leptos_meta/fn.Title.html) 允许你从任意组件设置文档的标题。它还支持一个 `formatter` 函数，用于对其他页面设置的标题应用相同的格式。例如，如果你在 `<App/>` 组件中放置 `<Title formatter=|text| format!("{text} — My Awesome Site")/>`，然后在路由中分别放置 `<Title text="Page 1"/>` 和 `<Title text="Page 2"/>`，你会得到 `Page 1 — My Awesome Site` 和 `Page 2 — My Awesome Site`。

[`<Link/>`](https://docs.rs/leptos_meta/latest/leptos_meta/fn.Link.html) 向 `<head>` 注入一个 `<link>` 元素。

[`<Stylesheet/>`](https://docs.rs/leptos_meta/latest/leptos_meta/fn.Stylesheet.html) 创建一个带有指定 `href` 的 `<link rel="stylesheet">`。

[`<Style/>`](https://docs.rs/leptos_meta/latest/leptos_meta/fn.Style.html) 创建一个 `<style>` 元素，并将你传递的子内容（通常是字符串）放入其中。可以在编译时引入其他文件的自定义 CSS，例如 `<Style>{include_str!("my_route.css")}</Style>`。

[`<Meta/>`](https://docs.rs/leptos_meta/latest/leptos_meta/fn.Meta.html) 允许你设置 `<meta>` 标签，如描述或其他元数据。

## `<Script/>` 和 `<script>`

`leptos_meta` 还提供了一个 [`<Script/>`](https://docs.rs/leptos_meta/latest/leptos_meta/fn.Script.html) 组件。这里值得稍作停顿说明。上面提到的所有组件都将 `<head>` 元素注入 `<head>` 中，而 `<script>` 既可以放在 `<head>` 中，也可以放在 `<body>` 中。

有一个简单的规则可以帮助你决定是使用 `<Script/>` 组件还是 `<script>` 元素：`<Script/>` 会被渲染到 `<head>` 中，而 `<script>` 会根据你在用户界面中放置的位置，直接渲染到 `<body>` 中。两者加载和运行 JavaScript 的时间不同，因此根据需要选择适合你的方式。

## `<Body/>` 和 `<Html/>`

还有两个元素专为语义化 HTML 和样式设计提供便利：`<Body/>` 和 `<Html/>`。它们允许你向页面上的 `<html>` 和 `<body>` 标签添加任意属性。可以通过常规 Leptos 语法结合扩展操作符（`{..}`）添加任意数量的属性，这些属性会直接添加到相应的元素中。

```rust
<Html
    {..}
    lang="he"
    dir="rtl"
    data-theme="dark"
/>
```

## 元数据与服务器端渲染

某些场景下，上述功能是非常有用的，而在搜索引擎优化（SEO）中则尤为重要。确保拥有适当的 `<title>` 和 `<meta>` 标签是关键。现代搜索引擎爬虫确实能够处理客户端渲染的应用（即通过空的 `index.html` 加载，然后用 JS/WASM 渲染整个页面）。但搜索引擎更喜欢直接接收到已经渲染成实际 HTML 的页面，并带有 `<head>` 中的元数据。

这正是 `leptos_meta` 的作用。事实上，在服务器端渲染时，它会收集整个应用程序中使用这些组件声明的所有 `<head>` 内容，然后将它们注入实际的 `<head>` 中。

不过我们稍微超前了一点。我们尚未正式讨论服务器端渲染。下一章将介绍如何与 JavaScript 库集成，然后完成客户端部分的讨论，接着进入服务器端渲染的主题。
