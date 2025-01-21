#!/bin/bash

# 下载并解压 mdBook
curl -Lo mdbook.tar.gz https://github.com/rust-lang/mdBook/releases/download/v0.4.43/mdbook-v0.4.43-x86_64-unknown-linux-musl.tar.gz
tar -xvzf mdbook.tar.gz

# 下载并解压 mdbook-admonish
curl -Lo mdbook-admonish.tar.gz https://github.com/tommilligan/mdbook-admonish/releases/download/v1.18.0/mdbook-admonish-v1.18.0-x86_64-unknown-linux-musl.tar.gz
tar -xvzf mdbook-admonish.tar.gz

# 将当前目录添加到 PATH，确保 mdbook 和 mdbook-admonish 可用
export PATH=$PWD:$PATH

# 运行 mdBook 构建
./mdbook build
