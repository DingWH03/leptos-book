# 简介

本书旨在介绍 [Leptos](https://github.com/leptos-rs/leptos) 这一 Web 框架。
它将介绍构建应用程序所需要的基本概念，将从一个使用浏览器完成渲染的简单的应用程序开始，
逐步构建成为一个带有服务端渲染和状态复用（hydration）的全栈应用。

> 在后文中会提到 hydration ，该功能是通过 WebAssembly 将服务器生成的 HTML 转换为动态交互式应用的过程，因此这里译为状态复用，也可以译为状态激活。

本指南并不要求您事先对响应式框架（fine-grained reactivity 亦译作“细粒度响应性”）或现代 Web 框架的细节有所了解，
但是您需要熟悉 Rust 编程语言、HTML、CSS、DOM和基本 Web API。

Leptos 与 [Solid](https://www.solidjs.com)（JavaScript）和 [Sycamore](https://sycamore-rs.netlify.app/)（Rust）等框架最为相似。
它与像 React（JavaScript）、Svelte（JavaScript）、Yew（Rust）和 Dioxus（Rust）这些框架有一些相似之处，
因此如果您对这些框架有所了解会让您更容易理解 Leptos。

您可以在 [Docs.rs](https://docs.rs/leptos/latest/leptos/) 上找到各个 API 的更详细的文档。

> 这本书的英文源代码在[这里](https://github.com/leptos-rs/book)获取，[本书](https://github.com/DingWH03/leptos-book)是个人对该文档的中文翻译版本。
> 欢迎您提出见解与翻译指正。
