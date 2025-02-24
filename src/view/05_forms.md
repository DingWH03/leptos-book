# 表单(Forms)和输入

表单和表单输入是交互式应用程序的重要组成部分。在 Leptos 中，有两种与输入交互的基本模式，如果你熟悉 React、SolidJS 或类似框架，这些模式可能会让你感到熟悉：**受控 (controlled)** 和 **非受控 (uncontrolled)** 输入。

## 受控输入

在“受控输入”中，框架会控制输入元素的状态。每次触发 `input` 事件时，都会更新一个保存当前状态的本地信号，而这个信号反过来又会更新输入的 `value` 属性。

有两个重要的点需要记住：

1. `input` 事件会在元素的每次（几乎是每次）更改时触发，而 `change` 事件会在输入失去焦点时（大致是这样）触发。你可能更需要使用 `on:input`，但框架也给你选择的自由。
2. `value` **属性** 仅设置输入的初始值，即它只会在你开始输入之前更新输入值。而 `value` **属性 (property)** 则会在你开始输入后持续更新输入值。出于这个原因，你通常需要设置 `prop:value`。（对于 `<input type="checkbox">` 中的 `checked` 和 `prop:checked` 也是如此。）

```rust
let (name, set_name) = signal("Controlled".to_string());

view! {
    <input type="text"
        // 添加 :target 可以让我们以类型安全的方式访问
        // 触发事件的目标元素
        on:input:target=move |ev| {
            // .value() 返回 HTML 输入元素的当前值
            set_name.set(ev.target().value());
        }

        // 使用 `prop:` 语法更新 DOM 属性而不是 HTML 属性
        prop:value=name
    />
    <p>"Name is: " {name}</p>
}
```

> #### 为什么需要使用 `prop:value`？
>
> Web 浏览器是现存最普遍、最稳定的图形用户界面渲染平台之一。它们在存在的三十多年中还保持了令人难以置信的向后兼容性。这不可避免地导致了一些奇怪的行为。
>
> 一个奇怪的地方是，HTML 属性 (attribute) 和 DOM 元素属性 (property) 之间存在区别，即所谓的“属性(attribute)”是从 HTML 中解析出来的，可以通过 `.setAttribute()` 在 DOM 元素上设置，而“属性 (property)”是解析后的 HTML 元素在 JavaScript 类表示中的一个字段。
>
> 以 `<input value=...>` 为例，设置 `value` **属性 (attribute)** 被定义为设置输入的初始值，而设置 `value` **属性 (property)** 则是设置其当前值。你可以通过打开 `about:blank` 并在浏览器控制台中逐行运行以下 JavaScript 代码来更容易理解这一点：
>
> ```js
> // 创建一个输入框并将其添加到 DOM
> const el = document.createElement("input");
> document.body.appendChild(el);
>
> el.setAttribute("value", "test"); // 更新输入值
> el.setAttribute("value", "another test"); // 再次更新输入值
>
> // 现在尝试在输入框中输入内容，比如删除一些字符等
>
> el.setAttribute("value", "one more time?");
> // 此时应该什么都没改变，设置“初始值”现在不起作用
>
> // 然而……
> el.value = "But this works";
> ```
>
> 许多其他前端框架混淆了属性 (attribute) 和属性 (property) 的概念，或者为输入框创建了一个特殊的处理方式，使其值可以正确设置。也许 Leptos 也应该这样做；但目前，我更倾向于给用户最大程度的控制，允许他们选择是设置属性 (attribute) 还是属性 (property)，同时尽力向用户解释底层浏览器的实际行为，而不是隐藏它。

### 使用 `bind:` 简化受控输入

遵循 Web 标准，并清晰地区分“从信号读取”和“写入信号”是很好的做法，但以这种方式创建受控输入有时可能看起来比实际需要的更多样板代码。

Leptos 还包括了一种特殊的 `bind:` 语法，用于输入控件，可以让你自动将信号绑定到输入控件。它们与上面提到的“受控输入”模式完全相同：创建一个事件监听器来更新信号，并通过动态属性从信号读取数据。你可以使用 `bind:value` 绑定文本输入，使用 `bind:checked` 绑定复选框。

```rust
let (name, set_name) = signal("Controlled".to_string());
let email = RwSignal::new("".to_string());
let spam_me = RwSignal::new(true);

view! {
    <input type="text"
        bind:value=(name, set_name)
    />
    <input type="email"
        bind:value=email
    />
    <label>
        "Please send me lots of spam email."
        <input type="checkbox"
            bind:checked=spam_me
        />
    </label>
    <p>"Name is: " {name}</p>
    <p>"Email is: " {email}</p>
    <Show when=move || spam_me.get()>
        <p>"You’ll receive cool bonus content!"</p>
    </Show>
}
```

## 非受控输入（Uncontrolled Inputs）

在“非受控输入”中，浏览器控制输入元素的状态。而不是不断更新一个信号来存储其值，我们使用 [`NodeRef`](https://docs.rs/leptos/latest/leptos/tachys/reactive_graph/node_ref/struct.NodeRef.html) 来在需要获取值时访问输入元素。

在下面的示例中，我们只在 `<form>` 触发 `submit` 事件时通知框架。请注意 [`leptos::html`](https://docs.rs/leptos/latest/leptos/html/index.html) 模块的使用，它提供了每个 HTML 元素的多种类型。

```rust
let (name, set_name) = signal("Uncontrolled".to_string());

let input_element: NodeRef<html::Input> = NodeRef::new();

view! {
    <form on:submit=on_submit> // on_submit 在下方定义
        <input type="text"
            value=name
            node_ref=input_element
        />
        <input type="submit" value="Submit"/>
    </form>
    <p>"Name is: " {name}</p>
}
```

到现在为止，这个视图应该是相当直观的。请注意以下两点：

1. 与受控输入示例不同，我们使用 `value`（而不是 `prop:value`）。这是因为我们只是设置输入框的初始值，并让浏览器控制其状态。（当然，我们也可以使用 `prop:value`。）
2. 我们使用 `node_ref=...` 来填充 `NodeRef`。（早期的示例有时使用 `_ref`，它们的作用是相同的，但 `node_ref` 对 `rust-analyzer` 的支持更好。）

`NodeRef` 是一种 **响应式智能指针**，它允许我们访问底层的 DOM 节点。当元素被渲染时，其值将被设置。

```rust
let on_submit = move |ev: SubmitEvent| {
    // 阻止页面刷新
    ev.prevent_default();

    // 这里，我们从输入框中提取值
    let value = input_element
        .get()
        // 事件处理程序只能在视图挂载到 DOM 后触发，
        // 因此 `NodeRef` 一定是 `Some`
        .expect("<input> 应该已经挂载")
        // `leptos::HtmlElement<html::Input>` 实现了 `Deref`
        // 到 `web_sys::HtmlInputElement`，
        // 这意味着我们可以调用 `HtmlInputElement::value()`
        // 来获取输入框的当前值
        .value();
    set_name.set(value);
};
```

我们的 `on_submit` 处理程序会访问输入框的值，并用它来调用 `set_name`。要访问 `NodeRef` 存储的 DOM 节点，我们可以直接调用它（或使用 `.get()`）。它会返回 `Option<leptos::HtmlElement<html::Input>>`，但我们知道该元素已经被挂载（否则事件无法触发！），因此在这里安全地 `unwrap` 是可以接受的。

然后，我们可以调用 `.value()` 来获取输入框的值，因为 `NodeRef` 为我们提供了一个正确类型的 HTML 元素。

要了解更多关于 `leptos::HtmlElement` 的用法，可以查看 [`web_sys` 和 `HtmlElement`](../web_sys.md)。此外，请查看页面底部的完整 CodeSandbox 示例。

## 特殊情况：`<textarea>` 和 `<select>`

有两种表单元素在使用时容易引发一些混淆，分别是 `<textarea>` 和 `<select>`。

### `<textarea>`

与 `<input>` 不同，`<textarea>` 元素不支持 `value` 属性。相反，它通过其 HTML 子节点中的纯文本节点来接收其值。

在当前版本的 Leptos（0.1 到 0.6）中，创建动态子节点会插入一个注释标记节点。如果你尝试使用动态内容，这可能会导致 `<textarea>` 渲染错误（以及在 **hydration** 期间的问题）。

相反，你可以将一个非响应式的初始值作为子节点传递，并使用 `prop:value` 来设置其当前值。（`<textarea>` 不支持 `value` **属性(attribute)**，但 _确实_ 支持 `value` **属性值(property)**。）

```rust
view! {
    <textarea
        prop:value=move || some_value.get()
        on:input:target=move |ev| some_value.set(ev.target().value())
    >
        /* 纯文本初始值，即使信号发生变化也不会改变 */
        {some_value.get_untracked()}
    </textarea>
}
```

### `<select>`

`<select>` 元素同样可以通过其自身的 `value` 属性来控制，`value` 属性会选择与该值匹配的 `<option>` 元素。

```rust
let (value, set_value) = signal(0i32);
view! {
  <select
    on:change:target=move |ev| {
      set_value.set(ev.target().value().parse().unwrap());
    }
    prop:value=move || value.get().to_string()
  >
    <option value="0">"0"</option>
    <option value="1">"1"</option>
    <option value="2">"2"</option>
  </select>
  // 一个可以循环切换选项的按钮
  <button on:click=move |_| set_value.update(|n| {
    if *n == 2 {
      *n = 0;
    } else {
      *n += 1;
    }
  })>
    "Next Option"
  </button>
}
```

```admonish sandbox title="Controlled vs uncontrolled forms CodeSandbox" collapsible=true

[Click to open CodeSandbox.](https://codesandbox.io/p/devbox/5-forms-0-7-l5hktg?file=%2Fsrc%2Fmain.rs&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb)

<noscript>
  Please enable JavaScript to view examples.
</noscript>

<template>
  <iframe src="https://codesandbox.io/p/devbox/5-forms-0-7-l5hktg?file=%2Fsrc%2Fmain.rs&workspaceId=478437f3-1f86-4b1e-b665-5c27a31451fb" width="100%" height="1000px" style="max-height: 100vh"></iframe>
</template>

```

<details>
<summary>CodeSandbox Source</summary>

```rust
use leptos::{ev::SubmitEvent};
use leptos::prelude::*;

#[component]
fn App() -> impl IntoView {
    view! {
        <h2>"Controlled Component"</h2>
        <ControlledComponent/>
        <h2>"Uncontrolled Component"</h2>
        <UncontrolledComponent/>
    }
}

#[component]
fn ControlledComponent() -> impl IntoView {
    // create a signal to hold the value
    let (name, set_name) = signal("Controlled".to_string());

    view! {
        <input type="text"
            // fire an event whenever the input changes
            // adding :target after the event gives us access to
            // a correctly-typed element at ev.target()
            on:input:target=move |ev| {
                set_name.set(ev.target().value());
            }

            // the `prop:` syntax lets you update a DOM property,
            // rather than an attribute.
            //
            // IMPORTANT: the `value` *attribute* only sets the
            // initial value, until you have made a change.
            // The `value` *property* sets the current value.
            // This is a quirk of the DOM; I didn't invent it.
            // Other frameworks gloss this over; I think it's
            // more important to give you access to the browser
            // as it really works.
            //
            // tl;dr: use prop:value for form inputs
            prop:value=name
        />
        <p>"Name is: " {name}</p>
    }
}

#[component]
fn UncontrolledComponent() -> impl IntoView {
    // import the type for <input>
    use leptos::html::Input;

    let (name, set_name) = signal("Uncontrolled".to_string());

    // we'll use a NodeRef to store a reference to the input element
    // this will be filled when the element is created
    let input_element: NodeRef<Input> = NodeRef::new();

    // fires when the form `submit` event happens
    // this will store the value of the <input> in our signal
    let on_submit = move |ev: SubmitEvent| {
        // stop the page from reloading!
        ev.prevent_default();

        // here, we'll extract the value from the input
        let value = input_element.get()
            // event handlers can only fire after the view
            // is mounted to the DOM, so the `NodeRef` will be `Some`
            .expect("<input> to exist")
            // `NodeRef` implements `Deref` for the DOM element type
            // this means we can call`HtmlInputElement::value()`
            // to get the current value of the input
            .value();
        set_name.set(value);
    };

    view! {
        <form on:submit=on_submit>
            <input type="text"
                // here, we use the `value` *attribute* to set only
                // the initial value, letting the browser maintain
                // the state after that
                value=name

                // store a reference to this input in `input_element`
                node_ref=input_element
            />
            <input type="submit" value="Submit"/>
        </form>
        <p>"Name is: " {name}</p>
    }
}

// This `main` function is the entry point into the app
// It just mounts our component to the <body>
// Because we defined it as `fn App`, we can now use it in a
// template as <App/>
fn main() {
    leptos::mount::mount_to_body(App)
}
```

</details>
</preview>
