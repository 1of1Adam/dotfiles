# macOS 新电脑一键配置

新电脑开箱后的一键配置脚本。

## 快速使用

```bash
# 下载并运行（脚本会在需要时提示登录 GitHub CLI）
curl -fsSL https://raw.githubusercontent.com/1of1Adam/dotfiles/main/setup.sh | bash
```

## 配置内容

| 功能 | 说明 |
|------|------|
| sudo 免密码 | 在 `/etc/sudoers.d/` 创建免密码规则 |
| Homebrew | macOS 包管理器 |
| 常用工具 | git, node, pnpm, python, gh, jq, ripgrep, fzf, eza, bat, fd, tmux, mole, starship |
| Zsh completion 权限修复 | 修正常见的 Homebrew 补全目录权限问题 |
| GitHub CLI 登录 | 安装 `gh` 后按提示执行 `gh auth login` |
| 终端字体 | 安装 `Geist Mono`、`Sarasa Term SC Nerd`、`JetBrains Mono Nerd Font` |
| Google Chrome | `brew install --cask google-chrome` |
| Raycast | `brew install --cask raycast` |
| Ghostty | `brew install --cask ghostty` |
| Ghostty 配置与主题 | 同步 `~/.config/ghostty/`，包含 config、icon、themes |
| Codex App | `brew install --cask codex-app` |
| Zed | `brew install --cask zed` |
| WeChat | `brew install --cask wechat` |
| 1Password | `brew install --cask 1password` |
| Typeless | `brew install --cask typeless` |
| Git 默认配置 | 默认分支 main、pull.rebase=false，检测到 VS Code 时才设置 `editor=code --wait` |
| Claude Code | `curl -fsSL https://claude.ai/install.sh \| bash` |
| OpenAI Codex | `npm i -g @openai/codex` |
| macOS 优化 | 开发机电源策略、禁用自动屏保、键盘重复速度、显示隐藏文件 |
| .zshrc | 常用别名、OSC 8 超链接等 |
| .zshrc.local 模板 | 为私有 alias、token、机器专属 PATH 预留 |
| Starship 主题 | 同步 `~/.config/starship.toml`，启用 gruvbox-rainbow 风格 |
| Claude 配置 | 同步 `~/.claude/CLAUDE.md` |
| Codex 配置 | 同步 `~/.codex/AGENTS.md` |

## 单独配置 sudo 免密码

```bash
# 手动配置（替换 USERNAME 为你的用户名）
echo "USERNAME ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/USERNAME
sudo chmod 440 /etc/sudoers.d/USERNAME
```

## 注意事项

- sudo 免密码配置需要管理员权限
- 建议在安全的环境下使用这些配置
- 私有 token / 机器专属 alias 建议写到 `~/.zshrc.local`

## 自动安装器（Downloads: .dmg / .iso*）

用于监听 `~/Downloads`，自动挂载并安装新下载的 `.dmg` / `.iso*` 镜像中的应用：

```bash
bash ~/Documents/dotfiles/auto-installer/install.sh
```

卸载：

```bash
bash ~/Documents/dotfiles/auto-installer/uninstall.sh
```
