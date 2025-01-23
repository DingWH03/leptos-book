# 插曲：样式

几乎所有在做网站或应用开发的人都会碰到一个问题：怎么给界面加样式？对于一个小应用来说，用一份 CSS 文件来管理全部样式就足够了。但随着应用规模的增长，许多开发者会发现纯 CSS 越来越难以维护。

一些前端框架（如 Angular、Vue、Svelte）内置了将 CSS 作用域限定到特定组件的方法，能更轻松地管理大型应用的样式，避免只想改一个小组件的样式却影响到全局。另一些框架（如 React、Solid）并没有内置的 CSS 作用域功能，而是依赖社区生态中的库来实现。Leptos 也属于后者：它本身对 CSS 并没有任何看法，但是提供了一些工具和基础功能，方便其他人建立自己的样式库。

下面介绍在 Leptos 应用中，除了直接使用纯 CSS 以外的几种常见做法。

## TailwindCSS：基于工具类的 CSS

[TailwindCSS](https://tailwindcss.com/) 是一个流行的“工具类优先（utility-first）”CSS 库。它通过在模板中使用各类工具类（utility class）进行样式控制，并配合一个自定义 CLI 工具扫描代码中所有 Tailwind 类名，然后打包所需 CSS。

这样，你可以写出类似如下的组件：

```rust
#[component]
fn Home() -> impl IntoView {
    let (count, set_count) = signal(0);

    view! {
        <main class="my-0 mx-auto max-w-3xl text-center">
            <h2 class="p-6 text-4xl">"Welcome to Leptos with Tailwind"</h2>
            <p class="px-10 pb-10 text-left">"Tailwind will scan your Rust files for Tailwind class names and compile them into a CSS file."</p>
            <button
                class="bg-sky-600 hover:bg-sky-700 px-5 py-3 text-white rounded-lg"
                on:click=move |_| *set_count.write() += 1
            >
                {move || if count.get() == 0 {
                    "Click me!".to_string()
                } else {
                    count.get().to_string()
                }}
            </button>
        </main>
    }
}
```

初次配置 Tailwind 需要一些步骤。你可以查看以下示例，了解如何在 [client-side-rendered 的 `trunk` 应用](https://github.com/leptos-rs/leptos/tree/main/examples/tailwind_csr)或 [server-rendered 的 `cargo-leptos` 应用](https://github.com/leptos-rs/leptos/tree/main/examples/tailwind_actix) 中使用 Tailwind。`cargo-leptos` 还提供了[内置的 Tailwind 支持](https://github.com/leptos-rs/cargo-leptos#site-parameters)，可用于替代 Tailwind CLI。

## Stylers：编译期提取 CSS

[Stylers](https://github.com/abishekatp/stylers) 是一个编译期作用域 CSS 库，允许你在组件里内联定义局部（作用域）CSS。Stylers 会在编译期提取这些 CSS 到独立的文件中，然后在你的应用中引入。因此它不会额外增加应用的 WASM 二进制体积。

下面是一个使用 Stylers 编写组件的示例：

```rust
use stylers::style;

#[component]
pub fn App() -> impl IntoView {
    let styler_class = style! { "App",
        ##two{
            color: blue;
        }
        div.one{
            color: red;
            content: raw_str(r#"\hello"#);
            font: "1.3em/1.2" Arial, Helvetica, sans-serif;
        }
        div {
            border: 1px solid black;
            margin: 25px 50px 75px 100px;
            background-color: lightblue;
        }
        h2 {
            color: purple;
        }
        @media only screen and (max-width: 1000px) {
            h3 {
                background-color: lightblue;
                color: blue
            }
        }
    };

    view! { class = styler_class,
        <div class="one">
            <h1 id="two">"Hello"</h1>
            <h2>"World"</h2>
            <h2>"and"</h2>
            <h3>"friends!"</h3>
        </div>
    }
}
```

## Stylance：将作用域 CSS 写在独立文件中

Stylers 让你可以在 Rust 代码中内联写 CSS，并在编译期提取和作用域化。[Stylance](https://github.com/basro/stylance-rs) 则允许你在单独的 CSS 文件中编写样式，然后在组件中引入，并把 CSS 类作用域限定到对应的组件。

这种方式与 `trunk` 和 `cargo-leptos` 的热重载（live reloading）特性配合得很好，因为你可以直接编辑 CSS 文件并在浏览器中立刻看到更新。

```rust
import_style!(style, "app.module.scss");

#[component]
fn HomePage() -> impl IntoView {
    view! {
        <div class=style::jumbotron/>
    }
}
```

你可以直接编辑 CSS 文件，而无需引发 Rust 重新编译：

```css
.jumbotron {
  background: blue;
}
```

## 欢迎贡献

Leptos 本身对样式没有特定主张，但我们很乐意为任何旨在简化样式管理的工具提供支持。如果你正在开发某种 CSS 或样式方案，并且想要把它加入这份清单，请告诉我们！
