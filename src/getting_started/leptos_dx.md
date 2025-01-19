# 优化 Leptos 开发体验

有几件事可以帮助您提升使用 Leptos 开发网站和应用的体验。您可能需要花几分钟时间来配置您的开发环境，以优化开发流程，特别是如果您计划跟随本书中的示例一起编写代码的话。

## 1) 设置`console_error_panic_hook`

默认情况下，当您的 WASM 代码在浏览器中运行时发生 panic，浏览器会抛出一条没有实际帮助的信息，例如`Unreachable executed`，并提供一个指向 WASM 二进制文件的堆栈跟踪。

使用`console_error_panic_hook`后，您将获得一个实际的 Rust 堆栈跟踪，其中包含 Rust 源代码中的具体行号。

设置非常简单：

1. 在项目中运行`cargo add console_error_panic_hook` 命令。
2. 在`main`函数中添加`console_error_panic_hook::set_once();`

> 如果您不太明白如何修改`main`函数，点击[这里](https://github.com/leptos-rs/leptos/blob/main/examples/counter/src/main.rs#L6)查看示例。

现在，您应该能在浏览器控制台中看到更清晰的 panic 错误信息！

## 2) `#[component]`和`#[server]`代码块内部的自动补全

由于宏的特性（它们可以从任何东西扩展到任何东西，但前提是输入在那个时刻必须完全正确），这可能会让 rust-analyzer 很难提供适当的自动补全和其他支持。

如果在编辑器中使用这些宏时遇到问题，您可以显式告诉 rust-analyzer 忽略某些过程宏。对于`#[server]`宏尤其如此，它用于注解函数体，但实际上并不会修改函数体内部的内容，这时这种做法会非常有帮助。

```admonish note
从 Leptos 版本 0.5.3 开始，`#[component]`宏得到了 rust-analyzer 的支持，但如果遇到问题，您可能需要将`#[component]`添加到宏忽略列表中（如下所示）。

请注意，这意味着 rust-analyzer 无法识别您的组件属性，这可能会在 IDE 中生成一组错误或警告。
```

VSCode `settings.json`:

```json
"rust-analyzer.procMacro.ignored": {
	"leptos_macro": [
        // optional:
		// "component",
		"server"
	],
}
```

VSCode with cargo-leptos `settings.json`:
```json
"rust-analyzer.procMacro.ignored": {
	"leptos_macro": [
        // optional:
		// "component",
		"server"
	],
},
// if code that is cfg-gated for the `ssr` feature is shown as inactive,
// you may want to tell rust-analyzer to enable the `ssr` feature by default
//
// you can also use `rust-analyzer.cargo.allFeatures` to enable all features
"rust-analyzer.cargo.features": ["ssr"]
```

neovim with lspconfig:

```lua
require('lspconfig').rust_analyzer.setup {
  -- Other Configs ...
  settings = {
    ["rust-analyzer"] = {
      -- Other Settings ...
      procMacro = {
        ignored = {
            leptos_macro = {
                -- optional: --
                -- "component",
                "server",
            },
        },
      },
    },
  }
}
```

Helix, in `.helix/languages.toml`:

```toml
[[language]]
name = "rust"

[language-server.rust-analyzer]
config = { procMacro = { ignored = { leptos_macro = [
	# Optional:
	# "component",
	"server"
] } } }
```

Zed, in `settings.json`:

```json
{
  -- Other Settings ...
  "lsp": {
    "rust-analyzer": {
      "procMacro": {
        "ignored": [
          // optional:
          // "component",
          "server"
        ]
      }
    }
  }
}
```

SublimeText 3, under `LSP-rust-analyzer.sublime-settings` in `Goto Anything...` menu:

```json
// Settings in here override those in "LSP-rust-analyzer/LSP-rust-analyzer.sublime-settings"
{
  "rust-analyzer.procMacro.ignored": {
    "leptos_macro": [
      // optional:
      // "component",
      "server"
    ],
  },
}
```

## 3) 设置`leptosfmt`配合 Rust Analyzer工作（可选）

`leptosfmt`是用于格式化 Leptos `view!`宏的工具（在该宏内部，您通常会编写 UI 代码）。由于`view!`宏采用类似 JSX 的 RSX 风格编写 UI，cargo-fmt 很难自动格式化该宏内部的代码。而`leptosfmt`是一个解决格式化问题的 crate，它能确保您的 RSX 风格 UI 代码保持整洁和美观！

`leptosfmt` 可以通过命令行或代码编辑器内进行安装和使用：

首先，使用命令`cargo install leptosfmt`来安装该工具。

如果您只想使用默认选项进行命令行格式化，只需要在项目根目录下运行`leptosfmt ./**/*.rs`，它将使用`leptosfmt`格式化所有的 Rust 文件。

如果您希望在编辑器中使用 `leptosfmt`，或者想自定义`leptosfmt`的使用体验，请参阅[`leptosfmt` GitHub 仓库的 README.md 页面中的说明](https://github.com/bram209/leptosfmt)。

需要注意的是，建议在每个工作区内单独设置编辑器与`leptosfmt`的集成为最佳效果。
