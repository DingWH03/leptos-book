# 测试你的组件

测试用户界面可能相对棘手，但非常重要。这篇文章将讨论一些测试 Leptos 应用程序的原则和方法。

## 1. 使用普通的 Rust 测试业务逻辑

在很多情况下，将逻辑从组件中抽离出来并单独测试是明智的。对于一些简单的组件，没有什么特殊的逻辑需要测试，但对于很多组件，值得使用一个可测试的封装类型，并在普通的 Rust `impl` 块中实现逻辑。

例如，不要直接在组件中嵌入逻辑，如下所示：

```rust
#[component]
pub fn TodoApp() -> impl IntoView {
    let (todos, set_todos) = signal(vec![Todo { /* ... */ }]);
    // ⚠️ 这是难以测试的，因为它嵌入在组件中
    let num_remaining = move || todos.read().iter().filter(|todo| !todo.completed).sum();
}
```

可以将逻辑抽离到一个单独的数据结构中并测试它：

```rust
pub struct Todos(Vec<Todo>);

impl Todos {
    pub fn num_remaining(&self) -> usize {
        self.0.iter().filter(|todo| !todo.completed).sum()
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_remaining() {
        // ...
    }
}

#[component]
pub fn TodoApp() -> impl IntoView {
    let (todos, set_todos) = signal(Todos(vec![Todo { /* ... */ }]));
    // ✅ 这段逻辑可以单独测试
    let num_remaining = move || todos.read().num_remaining();
}
```

一般来说，逻辑越少嵌入组件本身，你的代码就越符合惯用的 Rust 风格，也越容易测试。

## 2. 使用端到端测试（`e2e`）测试组件

我们的 [`examples`](https://github.com/leptos-rs/leptos/tree/main/examples) 目录包含了多个带有端到端测试的示例，使用了不同的测试工具。

最简单的了解方式是直接查看这些测试示例本身：

### 使用 `wasm-bindgen-test` 测试 [`counter`](https://github.com/leptos-rs/leptos/blob/main/examples/counter/tests/web.rs)

这是一个相对简单的手动测试设置，使用 [`wasm-pack test`](https://rustwasm.github.io/wasm-pack/book/commands/test.html) 命令。

#### 示例测试

```rust
#[wasm_bindgen_test]
async fn clear() {
    let document = document();
    let test_wrapper = document.create_element("section").unwrap();
    let _ = document.body().unwrap().append_child(&test_wrapper);

    // 渲染计数器并将其挂载到 DOM 上
    let _dispose = mount_to(
        test_wrapper.clone().unchecked_into(),
        || view! { <SimpleCounter initial_value=10 step=1/> },
    );

    // 从 DOM 中提取按钮
    let div = test_wrapper.query_selector("div").unwrap().unwrap();
    let clear = test_wrapper
        .query_selector("button")
        .unwrap()
        .unwrap()
        .unchecked_into::<web_sys::HtmlElement>();

    // 点击 `clear` 按钮
    clear.click();

    // 由于反应式系统基于异步系统，因此更改不会立即反映在 DOM 中
    tick().await;

    // 测试 <div> 的内容是否符合预期
    assert_eq!(div.outer_html(), {
        let (value, _set_value) = signal(0);
        view! {
            <div>
                <button>"Clear"</button>
                <button>"-1"</button>
                <span>"Value: " {value} "!"</span>
                <button>"+1"</button>
            </div>
        }
        .into_view()
        .build()
        .outer_html()
    });

    // 更简单的方法是直接测试初始值为 0 的 <SimpleCounter/>
    assert_eq!(test_wrapper.inner_html(), {
        let comparison_wrapper = document.create_element("section").unwrap();
        let _dispose = mount_to(
            comparison_wrapper.clone().unchecked_into(),
            || view! { <SimpleCounter initial_value=0 step=1/>},
        );
        comparison_wrapper.inner_html()
    });
}
```

### 使用 Playwright 测试 [`counters`](https://github.com/leptos-rs/leptos/tree/main/examples/counters/e2e)

这些测试使用了常见的 JavaScript 测试工具 Playwright，对相同示例进行端到端测试，采用了许多前端开发者熟悉的库和测试方法。

#### 示例测试

```js
test.describe("Increment Count", () => {
  test("should increase the total count", async ({ page }) => {
    const ui = new CountersPage(page);
    await ui.goto();
    await ui.addCounter();

    await ui.incrementCount();
    await ui.incrementCount();
    await ui.incrementCount();

    await expect(ui.total).toHaveText("3");
  });
});
```

### 使用 Gherkin/Cucumber 测试 [`todo_app_sqlite`](https://github.com/leptos-rs/leptos/blob/main/examples/todo_app_sqlite/e2e/README.md)

你可以将任何测试工具集成到这个流程中。本示例使用 Cucumber，一种基于自然语言的测试框架。

```
@add_todo
Feature: Add Todo

    Background:
        Given I see the app

    @add_todo-see
    Scenario: Should see the todo
        Given I set the todo as Buy Bread
        When I click the Add button
        Then I see the todo named Buy Bread

    # @allow.skipped
    @add_todo-style
    Scenario: Should see the pending todo
        When I add a todo as Buy Oranges
        Then I see the pending todo
```

这些操作的定义在 Rust 代码中实现：

```rust
use crate::fixtures::{action, world::AppWorld};
use anyhow::{Ok, Result};
use cucumber::{given, when};

#[given("I see the app")]
#[when("I open the app")]
async fn i_open_the_app(world: &mut AppWorld) -> Result<()> {
    let client = &world.client;
    action::goto_path(client, "").await?;

    Ok(())
}

#[given(regex = "^I add a todo as (.*)$")]
#[when(regex = "^I add a todo as (.*)$")]
async fn i_add_a_todo_titled(world: &mut AppWorld, text: String) -> Result<()> {
    let client = &world.client;
    action::add_todo(client, text.as_str()).await?;

    Ok(())
}

// 等等
```

### 了解更多

可以查看 Leptos 仓库中的 CI 设置，了解如何在自己的应用中使用这些工具。这些测试方法会定期针对 Leptos 示例应用运行。
