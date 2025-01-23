# 部署全栈 SSR 应用

可以将 Leptos 全栈 SSR 应用部署到多种服务器或容器托管服务中。将 Leptos SSR 应用投入生产的最简单方法可能是使用 VPS 服务，并在虚拟机中本地运行 Leptos（[更多详细信息请参见此处](https://github.com/leptos-rs/start-axum?tab=readme-ov-file#executing-a-server-on-a-remote-machine-without-the-toolchain)）。或者，你可以将 Leptos 应用容器化，并在 [Podman](https://podman.io/) 或 [Docker](https://www.docker.com/) 中运行，无论是本地托管还是云服务器都可以。

部署设置和托管服务种类繁多，总体来说，Leptos 本身对你使用的部署方式持中立态度。考虑到这些不同的部署目标，我们将探讨以下内容：

- [创建用于 Leptos SSR 应用的 `Containerfile`（或 `Dockerfile`）](#创建一个-containerfile)
- 使用 `Dockerfile` [部署到云服务](#云部署)（例如 [Fly.io](#部署到-flyio)）
- 将 Leptos 部署到[无服务器运行环境](#部署到无服务器运行环境)（例如 [AWS Lambda](#aws-lambda) 和 [支持 JS 的 WASM 运行时（如 Deno 和 Cloudflare）](#deno-和-cloudflare-workers)）
- [尚未支持 Leptos SSR 的平台](#支持-leptos-的平台)

_注意：Leptos 并不推荐使用任何特定的部署方式或托管服务。_

## 创建一个 Containerfile

目前，人们部署使用 `cargo-leptos` 构建的全栈应用最常见的方法是使用支持 Podman 或 Docker 构建的云托管服务。以下是一个示例 `Containerfile` / `Dockerfile`，基于我们用于部署 Leptos 网站的文件。

### Debian

```dockerfile
# Get started with a build env with Rust nightly
FROM rustlang/rust:nightly-bullseye as builder

# If you’re using stable, use this instead
# FROM rust:1.74-bullseye as builder

# Install cargo-binstall, which makes it easier to install other
# cargo extensions like cargo-leptos
RUN wget https://github.com/cargo-bins/cargo-binstall/releases/latest/download/cargo-binstall-x86_64-unknown-linux-musl.tgz
RUN tar -xvf cargo-binstall-x86_64-unknown-linux-musl.tgz
RUN cp cargo-binstall /usr/local/cargo/bin

# Install required tools
RUN apt-get update -y \
  && apt-get install -y --no-install-recommends clang

# Install cargo-leptos
RUN cargo binstall cargo-leptos -y

# Add the WASM target
RUN rustup target add wasm32-unknown-unknown

# Make an /app dir, which everything will eventually live in
RUN mkdir -p /app
WORKDIR /app
COPY . .

# Build the app
RUN cargo leptos build --release -vv

FROM debian:bookworm-slim as runtime
WORKDIR /app
RUN apt-get update -y \
  && apt-get install -y --no-install-recommends openssl ca-certificates \
  && apt-get autoremove -y \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

# -- NB: update binary name from "leptos_start" to match your app name in Cargo.toml --
# Copy the server binary to the /app directory
COPY --from=builder /app/target/release/leptos_start /app/

# /target/site contains our JS/WASM/CSS, etc.
COPY --from=builder /app/target/site /app/site

# Copy Cargo.toml if it’s needed at runtime
COPY --from=builder /app/Cargo.toml /app/

# Set any required env variables and
ENV RUST_LOG="info"
ENV LEPTOS_SITE_ADDR="0.0.0.0:8080"
ENV LEPTOS_SITE_ROOT="site"
EXPOSE 8080

# -- NB: update binary name from "leptos_start" to match your app name in Cargo.toml --
# Run the server
CMD ["/app/leptos_start"]
```

### Alpine

```dockerfile
# Get started with a build env with Rust nightly
FROM rustlang/rust:nightly-alpine as builder

RUN apk update && \
    apk add --no-cache bash curl npm libc-dev binaryen

RUN npm install -g sass

RUN curl --proto '=https' --tlsv1.2 -LsSf https://github.com/leptos-rs/cargo-leptos/releases/latest/download/cargo-leptos-installer.sh | sh

# Add the WASM target
RUN rustup target add wasm32-unknown-unknown

WORKDIR /work
COPY . .

RUN cargo leptos build --release -vv

FROM rustlang/rust:nightly-alpine as runner

WORKDIR /app

COPY --from=builder /work/target/release/leptos_start /app/
COPY --from=builder /work/target/site /app/site
COPY --from=builder /work/Cargo.toml /app/

ENV RUST_LOG="info"
ENV LEPTOS_SITE_ADDR="0.0.0.0:8080"
ENV LEPTOS_SITE_ROOT=./site
EXPOSE 8080

CMD ["/app/leptos_start"]
```

> 更多信息：[用于 Leptos 应用程序的 `gnu` 和 `musl` 构建文件。](https://github.com/leptos-rs/leptos/issues/1152#issuecomment-1634916088).

## 云部署

### 部署到 Fly.io

将 Leptos SSR 应用部署到 Fly.io 是一种选择。Fly.io 使用你的 Leptos 应用的 Dockerfile 定义，并将其运行在快速启动的微型虚拟机中。此外，Fly.io 提供了多种存储选项和托管数据库，可以与你的项目配合使用。以下示例展示了如何部署一个简单的 Leptos 入门应用，帮助你快速上手；如需使用 Fly.io 的存储选项，可以[参阅此处](https://fly.io/docs/database-storage-guides/)获取更多信息。

首先，在应用程序的根目录中创建一个 `Dockerfile`，并填入推荐的内容（如上文所示）；确保将 Dockerfile 示例中的二进制文件名称更新为你自己应用程序的名称，并根据需要进行其他调整。

确保已安装 `flyctl` CLI 工具，并在 [Fly.io](https://fly.io/) 上注册了一个账户。在 MacOS、Linux 或 Windows WSL 上安装 `flyctl` 的命令如下：

```sh
curl -L https://fly.io/install.sh | sh
```

如果遇到问题，或需要在其他平台上安装，请[参阅完整安装说明](https://fly.io/docs/hands-on/install-flyctl/)。

接下来登录 Fly.io：

```sh
fly auth login
```

然后手动启动你的应用程序：

```sh
fly launch
```

`flyctl` CLI 工具会引导你完成将应用部署到 Fly.io 的过程。

```admonish note
默认情况下，Fly.io 会在一段时间内没有流量时自动停止运行的机器。虽然 Fly.io 的轻量级虚拟机启动速度很快，但如果你希望最小化 Leptos 应用的延迟，并确保其始终快速响应，可以进入生成的 `fly.toml` 文件，将 `min_machines_running` 的值从默认的 0 修改为 1。

[更多详情请参阅 Fly.io 文档](https://fly.io/docs/apps/autostart-stop/)。
```

如果你更倾向于使用 Github Actions 管理部署，需要通过 [Fly.io](https://fly.io/) 的 Web UI 创建一个新的访问令牌。

前往“Account” > “Access Tokens”，创建一个名为 "github_actions" 的令牌，然后进入 Github 项目的“Settings” > “Secrets and Variables” > “Actions”，创建一个名为 "FLY_API_TOKEN" 的新仓库密钥，将令牌添加进去。

要生成用于部署到 Fly.io 的 `fly.toml` 配置文件，需要首先在项目源目录中运行以下命令：

```sh
fly launch --no-deploy
```

这将创建一个新的 Fly 应用并注册到服务中。然后将生成的 `fly.toml` 文件提交到 Git 仓库。

最后，将以下内容复制到 `.github/workflows/fly_deploy.yml` 文件中，以设置 Github Actions 的部署工作流：

```admonish example collapsible=true

	# For more details, see: https://fly.io/docs/app-guides/continuous-deployment-with-github-actions/

	name: Deploy to Fly.io
	on:
	push:
		branches:
		- main
	jobs:
	deploy:
		name: Deploy app
		runs-on: ubuntu-latest
		steps:
		- uses: actions/checkout@v4
		- uses: superfly/flyctl-actions/setup-flyctl@master
		- name: Deploy to fly
			id: deployment
			run: |
			  flyctl deploy --remote-only | tail -n 1 >> $GITHUB_STEP_SUMMARY
			env:
			  FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}

```

在你下一次成功提交到 Github `main` 分支时，项目将自动部署到 Fly.io。

请参见[此处的示例仓库](https://github.com/diversable/fly-io-leptos-ssr-test-deploy)。

### Railway

另一个云部署服务提供商是 [Railway](https://railway.app/)。  
Railway 与 GitHub 集成，可以自动部署你的代码。

有一个社区模板可以帮助你快速入门：

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template/pduaM5?referralCode=fZ-SY1)

该模板已经配置了 Renovate 来保持依赖项的最新，并支持在部署前使用 GitHub Actions 测试代码。

Railway 提供免费的套餐，无需信用卡注册，而 Leptos 的资源需求很小，这个免费套餐应该能支持很长时间。

请参阅[示例仓库](https://github.com/marvin-bitterlich/leptos-railway)。

## 部署到无服务器运行环境

Leptos 支持部署到 FaaS（Function as a Service）或“无服务器”运行环境，例如 AWS Lambda，以及与 [WinterCG](https://wintercg.org/) 兼容的 JavaScript 运行时（如 [Deno](https://deno.com/deploy) 和 Cloudflare）。需要注意的是，与 VM 或容器类型的部署相比，无服务器环境对 SSR 应用的功能会有一些限制（请参阅以下说明）。

### AWS Lambda

在 [Cargo Lambda](https://www.cargo-lambda.info/) 工具的帮助下，Leptos SSR 应用可以部署到 AWS Lambda。一个使用 Axum 作为服务器的入门模板仓库可在 [leptos-rs/start-aws](https://github.com/leptos-rs/start-aws) 找到；该说明也可以适配用于 Leptos + Actix-web 的服务器。该入门模板仓库包括用于 CI/CD 的 GitHub Actions 脚本，以及设置 Lambda 函数和获取云部署所需凭据的说明。

但请注意，一些本地服务器功能无法在像 Lambda 这样的 FaaS 服务中正常工作，因为环境在不同请求之间不一定一致。特别是 ['start-aws' 文档](https://github.com/leptos-rs/start-aws#state) 提到：“由于 AWS Lambda 是一个无服务器平台，您需要更加小心如何管理长时间运行的状态。写入磁盘或使用状态提取器在请求之间无法可靠地工作。相反，您需要使用数据库或其他微服务来从 Lambda 函数中查询数据。”

另一个需要注意的因素是 FaaS 服务的“冷启动”时间——根据您的用例和所使用的 FaaS 平台，这可能会或可能不会满足您的延迟要求；如果需要优化请求速度，可能需要保持一个函数始终运行。

### Deno 和 Cloudflare Workers

目前，Leptos-Axum 支持在 JavaScript 托管的 WebAssembly 运行时（例如 Deno、Cloudflare Workers 等）中运行。这种选择需要对源代码的设置进行一些更改（例如，在 `Cargo.toml` 中必须使用 `crate-type = ["cdylib"]` 定义应用，并为 `leptos_axum` 启用 "wasm" 功能）。[Leptos HackerNews JS-fetch 示例](https://github.com/leptos-rs/leptos/tree/leptos_0.6/examples/hackernews_js_fetch) 演示了所需的修改，并展示了如何在 Deno 运行时运行应用。此外，[`leptos_axum` crate 文档](https://docs.rs/leptos_axum/latest/leptos_axum/#js-fetch-integration) 也是设置适用于 JS 托管 WASM 运行时的 `Cargo.toml` 文件时的有用参考。

虽然为 JS 托管 WASM 运行时的初始设置并不复杂，但需要注意一个重要限制：由于您的应用将在服务器端和客户端都被编译为 WebAssembly（`wasm32-unknown-unknown`），因此必须确保应用中使用的所有 crates 都支持 WASM。这可能是一个限制条件，因为 Rust 生态系统中的所有 crates 并非都支持 WASM。

如果您能接受 WASM 服务器端的限制，那么目前最好的起点是查看 Leptos 官方 GitHub 仓库中 [使用 Deno 运行 Leptos 的示例](https://github.com/leptos-rs/leptos/tree/leptos_0.6/examples/hackernews_js_fetch)。

## 支持 Leptos 的平台

### 部署到 Spin 无服务器 WASI（支持 Leptos SSR）

服务器端的 WebAssembly 近年来发展迅速，开源的无服务器 WebAssembly 框架 Spin 的开发者正在努力实现对 Leptos 的原生支持。尽管 Leptos-Spin 的 SSR 集成还处于早期阶段，但已经有一个可用的示例可以尝试。

关于让 Leptos SSR 和 Spin 一起工作的完整说明，请参考 [Fermyon 博客的这篇文章](https://www.fermyon.com/blog/leptos-spin-get-started)。如果您想跳过文章直接尝试一个可用的入门仓库，[请点击这里](https://github.com/diversable/leptos-spin-ssr-test)。

### 部署到 Shuttle.rs

许多 Leptos 用户询问是否可以使用对 Rust 友好的 [Shuttle.rs](https://www.shuttle.rs/) 服务来部署 Leptos 应用。不幸的是，目前 Shuttle.rs 服务尚未正式支持 Leptos。

不过，Shuttle.rs 的开发团队承诺未来将实现对 Leptos 的支持。如果您想了解该工作的最新进展，请关注[此 Github 问题](https://github.com/shuttle-hq/shuttle/issues/1002#issuecomment-1853661643)。

此外，已经有一些尝试让 Shuttle 与 Leptos 协作，但目前为止，部署到 Shuttle 云仍然未达到预期效果。如果您感兴趣，可以自行研究或贡献修复：[Shuttle.rs 的 Leptos Axum 入门模板](https://github.com/Rust-WASI-WASM/shuttle-leptos-axum)。
