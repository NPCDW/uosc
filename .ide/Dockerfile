FROM nickblah/lua:latest

# 安装依赖
RUN apt-get update && apt-get install -y curl wget unzip openssh-server git 

# 安装vscode支持 https://docs.cnb.cool/zh/vscode/quick-start.html
RUN curl -fsSL https://code-server.dev/install.sh | sh
RUN code-server --install-extension sumneko.lua
RUN code-server --install-extension njzy.stats-bar
RUN code-server --install-extension Tencent-Cloud.coding-copilot
RUN code-server --install-extension cnbcool.cnb-welcome
RUN code-server --install-extension donjayamanne.githistory

ENV LANG C.UTF-8
ENV LANGUAGE C.UTF-8