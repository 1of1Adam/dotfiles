#!/bin/bash
#
# macOS 新电脑一键配置脚本
# 使用方法: curl -fsSL https://raw.githubusercontent.com/1of1Adam/dotfiles/main/setup.sh | bash
#

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

CURRENT_USER=$(whoami)
if [[ -n "${BASH_SOURCE[0]}" && "${BASH_SOURCE[0]}" != "bash" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # curl | bash 模式：无本地文件，所有配置从远程拉取
    SCRIPT_DIR=""
fi
DOTFILES_RAW_BASE="https://raw.githubusercontent.com/1of1Adam/dotfiles/main"

install_managed_file() {
    local target_path="$1"
    local local_source="$2"
    local remote_source="$3"
    local label="$4"

    mkdir -p "$(dirname "$target_path")"

    if [[ -f "$target_path" ]]; then
        if diff -q "$target_path" "${local_source:-/dev/null}" &>/dev/null; then
            log_info "$label 内容一致，跳过"
            return
        fi
        cp "$target_path" "$target_path.backup.$(date +%Y%m%d%H%M%S)"
        log_info "已备份现有 $label"
    fi

    if [[ -f "$local_source" ]]; then
        cp "$local_source" "$target_path"
    else
        curl -fsSL "$DOTFILES_RAW_BASE/$remote_source" -o "$target_path"
    fi
}

install_template_if_missing() {
    local target_path="$1"
    local local_source="$2"
    local remote_source="$3"
    local label="$4"

    if [[ -f "$target_path" ]]; then
        log_info "$label 已存在，跳过"
        return
    fi

    mkdir -p "$(dirname "$target_path")"

    if [[ -f "$local_source" ]]; then
        cp "$local_source" "$target_path"
    else
        curl -fsSL "$DOTFILES_RAW_BASE/$remote_source" -o "$target_path"
    fi

    log_info "$label 已创建 ✓"
}

install_managed_directory() {
    local target_dir="$1"
    local local_source="$2"
    local remote_source="$3"
    local label="$4"
    local tmp_dir

    mkdir -p "$(dirname "$target_dir")"

    if [[ -d "$target_dir" ]]; then
        mv "$target_dir" "$target_dir.backup.$(date +%Y%m%d%H%M%S)"
        log_info "已备份现有 $label"
    fi

    mkdir -p "$target_dir"

    if [[ -d "$local_source" ]]; then
        cp -R "$local_source/." "$target_dir/"
        return
    fi

    tmp_dir="$(mktemp -d)"
    git clone --depth 1 --filter=blob:none --sparse https://github.com/1of1Adam/dotfiles.git "$tmp_dir/dotfiles" >/dev/null 2>&1
    (
        cd "$tmp_dir/dotfiles" || exit 1
        git sparse-checkout set "$remote_source" >/dev/null 2>&1
    )
    cp -R "$tmp_dir/dotfiles/$remote_source/." "$target_dir/"
    rm -rf "$tmp_dir"
}

echo ""
echo "=========================================="
echo "   macOS 新电脑一键配置脚本"
echo "   用户: $CURRENT_USER"
echo "=========================================="
echo ""

# ============================================
# 1. 配置 sudo 免密码
# ============================================
setup_sudo_nopasswd() {
    log_info "配置 sudo 免密码..."

    SUDOERS_FILE="/etc/sudoers.d/$CURRENT_USER"
    SUDOERS_CONTENT="$CURRENT_USER ALL=(ALL) NOPASSWD: ALL"

    if [[ -f "$SUDOERS_FILE" ]]; then
        log_warn "sudoers 文件已存在，跳过"
    else
        echo "$SUDOERS_CONTENT" | sudo tee "$SUDOERS_FILE" > /dev/null
        sudo chmod 440 "$SUDOERS_FILE"
        log_info "sudo 免密码配置完成 ✓"
    fi
}

# ============================================
# 2. 禁用 Gatekeeper（允许任何来源的 App）
# ============================================
disable_gatekeeper() {
    log_info "禁用 Gatekeeper..."

    # 检查当前状态
    if spctl --status 2>/dev/null | grep -q "disabled"; then
        log_info "Gatekeeper 已禁用，跳过"
    else
        # 禁用 Gatekeeper
        sudo spctl --master-disable 2>/dev/null || true

        # 设置允许任何来源（通过 defaults 写入偏好设置）
        sudo defaults write /Library/Preferences/com.apple.security GKAutoRearm -bool false 2>/dev/null || true
        sudo defaults write /Library/Preferences/com.apple.security LSQuarantine -bool false 2>/dev/null || true

        log_info "Gatekeeper 已禁用 ✓"
        log_warn "注意：首次运行仍需在系统设置 → 隐私与安全性中手动确认 '任何来源'"
    fi
}

# ============================================
# 3. 安装 Xcode Command Line Tools
# ============================================
install_xcode_cli_tools() {
    if xcode-select -p &>/dev/null; then
        log_info "Xcode CLI Tools 已安装，跳过"
    else
        log_info "安装 Xcode Command Line Tools..."
        xcode-select --install
        log_info "等待 Xcode CLI Tools 安装完成（请在弹窗中点击安装）..."
        until xcode-select -p &>/dev/null; do
            sleep 5
        done
        log_info "Xcode CLI Tools 安装完成 ✓"
    fi
}

# ============================================
# 4. 安装 Homebrew
# ============================================
install_homebrew() {
    if command -v brew &> /dev/null; then
        log_info "Homebrew 已安装，跳过"
    else
        log_info "安装 Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # 添加到 PATH (Apple Silicon)
        if [[ -f /opt/homebrew/bin/brew ]]; then
            if ! grep -qF 'brew shellenv' ~/.zprofile 2>/dev/null; then
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            fi
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        log_info "Homebrew 安装完成 ✓"
    fi
}

# ============================================
# 4. 安装常用工具
# ============================================
install_tools() {
    log_info "安装常用开发工具..."

    TOOLS=(
        git
        node
        pnpm
        python
        gh          # GitHub CLI
        jq
        ripgrep     # 替代 grep
        fzf         # 模糊搜索
        fswatch     # 监听 Downloads（AutoInstaller 依赖）
        eza         # 替代 ls
        bat         # 替代 cat
        fd          # 替代 find
        zoxide      # 替代 cd，智能目录跳转
        atuin       # shell 历史管理
        starship    # 终端 prompt 美化
        delta       # git diff 美化
        lazygit     # git TUI
        tmux        # 终端多路复用
        htop        # 替代 top
        mole        # macOS 清理工具
        dust        # 替代 du
        duf         # 替代 df
        procs       # 替代 ps
        httpie      # 替代 curl (更友好)
        tldr        # 替代 man (简化版)
        zsh-autosuggestions      # zsh 自动补全建议
        zsh-syntax-highlighting  # zsh 语法高亮
    )

    for tool in "${TOOLS[@]}"; do
        if brew list "$tool" &>/dev/null; then
            log_info "$tool 已安装"
        else
            log_info "安装 $tool..."
            brew install "$tool"
        fi
    done

    log_info "常用工具安装完成 ✓"
}

# ============================================
# 5. 修复 Zsh completion 权限
# ============================================
fix_zsh_completion_permissions() {
    log_info "修复 Zsh completion 权限..."

    local completion_dir
    for completion_dir in \
        /opt/homebrew/share/zsh \
        /opt/homebrew/share/zsh/site-functions \
        /opt/homebrew/share/zsh-completions
    do
        if [[ -d "$completion_dir" ]]; then
            find "$completion_dir" -type d -exec chmod go-w {} + 2>/dev/null || true
        fi
    done

    if command -v zsh &> /dev/null; then
        local insecure_dirs
        insecure_dirs="$(zsh -fc 'autoload -Uz compaudit; compaudit' 2>/dev/null || true)"
        if [[ -n "$insecure_dirs" ]]; then
            log_warn "仍检测到不安全目录，请手动检查:"
            printf '%s\n' "$insecure_dirs"
        else
            log_info "Zsh completion 权限正常 ✓"
        fi
    fi
}

# ============================================
# 6. 登录 GitHub CLI
# ============================================
ensure_github_login() {
    if ! command -v gh &> /dev/null; then
        log_warn "gh 未安装，跳过 GitHub 登录"
        return
    fi

    if gh auth status &>/dev/null; then
        log_info "GitHub CLI 已登录，跳过"
        return
    fi

    read -p "是否现在登录 GitHub CLI？(Y/n): " confirm < /dev/tty
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        log_warn "跳过 GitHub CLI 登录，可稍后手动运行: gh auth login"
        return
    fi

    log_info "启动 GitHub CLI 登录..."
    gh auth login
    log_info "GitHub CLI 登录完成 ✓"
}

# ============================================
# 7. 生成 SSH Key
# ============================================
setup_ssh_key() {
    local ssh_key="$HOME/.ssh/id_ed25519"

    if [[ -f "$ssh_key" ]]; then
        log_info "SSH key 已存在，跳过"
        return
    fi

    log_info "生成 SSH key (ed25519)..."
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    local email
    email="$(git config --global user.email 2>/dev/null || true)"
    if [[ -z "$email" ]]; then
        read -p "SSH key email: " email < /dev/tty
    fi

    ssh-keygen -t ed25519 -C "$email" -f "$ssh_key" -N "" < /dev/tty
    eval "$(ssh-agent -s)" &>/dev/null
    ssh-add "$ssh_key" 2>/dev/null

    log_info "SSH 公钥:"
    cat "$ssh_key.pub"

    if command -v gh &>/dev/null && gh auth status &>/dev/null; then
        read -p "是否将 SSH key 添加到 GitHub？(Y/n): " confirm < /dev/tty
        if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
            gh ssh-key add "$ssh_key.pub" -t "$(hostname)"
            log_info "SSH key 已添加到 GitHub ✓"
        fi
    else
        log_warn "请手动将上方公钥添加到 GitHub → Settings → SSH Keys"
    fi
}

# ============================================
# 8. 配置 Git
# ============================================
setup_git() {
    log_info "配置 Git 默认项..."

    git config --global init.defaultBranch main
    git config --global pull.rebase false

    if command -v code &> /dev/null; then
        git config --global core.editor "code --wait"
        log_info "Git 编辑器已设置为 VS Code"
    else
        git config --global --unset core.editor 2>/dev/null || true
        log_info "未检测到 VS Code，跳过 Git 编辑器配置"
    fi

    log_info "Git 默认配置完成 ✓"
}

# ============================================
# 8. 安装 Ghostty 字体
# ============================================
install_ghostty_fonts() {
    log_info "安装 Ghostty 字体..."

    if brew list --cask font-geist-mono &>/dev/null; then
        log_info "Geist Mono 已安装"
    else
        log_info "安装 Geist Mono..."
        brew install --cask font-geist-mono
    fi

    if ! brew tap | grep -qx 'laishulu/homebrew'; then
        log_info "添加 Sarasa Nerd 字体源..."
        brew tap laishulu/homebrew
    fi

    if brew list --cask font-sarasa-nerd &>/dev/null; then
        log_info "Sarasa Term SC Nerd 已安装"
    else
        log_info "安装 Sarasa Term SC Nerd..."
        brew install --cask font-sarasa-nerd
    fi

    if brew list --cask font-jetbrains-mono-nerd-font &>/dev/null; then
        log_info "JetBrains Mono Nerd Font 已安装"
    else
        log_info "安装 JetBrains Mono Nerd Font..."
        brew install --cask font-jetbrains-mono-nerd-font
    fi

    log_info "Ghostty 字体安装完成 ✓"
}

# ============================================
# 9. 安装 GUI 应用
# ============================================
install_cask_apps() {
    local app_spec token app_path app_name
    local -a app_specs=(
        "google-chrome|/Applications/Google Chrome.app|Google Chrome"
        "raycast|/Applications/Raycast.app|Raycast"
        "ghostty|/Applications/Ghostty.app|Ghostty"
        "codex-app|/Applications/Codex.app|Codex App"
        "zed|/Applications/Zed.app|Zed"
        "wechat|/Applications/WeChat.app|WeChat"
        "1password|/Applications/1Password.app|1Password"
        "typeless|/Applications/Typeless.app|Typeless"
    )

    for app_spec in "${app_specs[@]}"; do
        IFS='|' read -r token app_path app_name <<< "$app_spec"

        if [[ -d "$app_path" ]]; then
            log_info "$app_name 已安装，跳过"
        else
            log_info "安装 $app_name..."
            brew install --cask "$token"
            log_info "$app_name 安装完成 ✓"
        fi
    done
}

# ============================================
# 10. 安装 Claude Code CLI
# ============================================
install_claude_code() {
    if command -v claude &> /dev/null; then
        log_info "Claude Code 已安装，跳过"
    else
        log_info "安装 Claude Code CLI..."
        curl -fsSL https://claude.ai/install.sh | bash
        log_info "Claude Code 安装完成 ✓"
    fi
}

# ============================================
# 11. 安装 OpenAI Codex CLI
# ============================================
install_codex() {
    if command -v codex &> /dev/null; then
        log_info "OpenAI Codex 已安装，跳过"
    else
        log_info "安装 OpenAI Codex CLI..."
        npm i -g @openai/codex
        log_info "OpenAI Codex 安装完成 ✓"
    fi
}

# ============================================
# 12. 配置 Ghostty
# ============================================
setup_ghostty() {
    log_info "配置 Ghostty..."
    install_managed_directory "$HOME/.config/ghostty" "$SCRIPT_DIR/ghostty" "ghostty" "Ghostty 配置"
    log_info "Ghostty 配置完成 ✓"
}

# ============================================
# 13. macOS 系统优化
# ============================================
setup_macos_defaults() {
    log_info "配置 macOS 系统优化..."

    # 开发机电源策略：常亮、不自动睡眠、关闭 Power Nap
    sudo pmset -c sleep 0 displaysleep 0 disksleep 0 powernap 0 tcpkeepalive 1 ttyskeepawake 1 womp 1 lowpowermode 0
    sudo pmset -b sleep 0 displaysleep 0 disksleep 0 powernap 0 tcpkeepalive 1 ttyskeepawake 1 womp 0 lowpowermode 0 lessbright 0 || true

    # 加快键盘重复速度
    defaults write NSGlobalDomain KeyRepeat -int 1
    defaults write NSGlobalDomain InitialKeyRepeat -int 10

    # 显示隐藏文件
    defaults write com.apple.finder AppleShowAllFiles YES

    # 禁止在网络卷上生成 .DS_Store
    defaults write com.apple.desktopservices DSDontWriteNetworkStores true

    # 不自动启动屏保
    defaults -currentHost write com.apple.screensaver idleTime -int 0

    log_info "macOS 系统优化完成 ✓ (电源策略/部分设置可能需要重新登录生效)"
}

# ============================================
# 14. 配置 .zshrc
# ============================================
setup_zshrc() {
    log_info "配置 .zshrc..."
    install_managed_file "$HOME/.zshrc" "$SCRIPT_DIR/zshrc" "zshrc" ".zshrc"
    install_template_if_missing "$HOME/.zshrc.local" "$SCRIPT_DIR/zshrc.local.example" "zshrc.local.example" ".zshrc.local 模板"
    log_info ".zshrc 配置完成 ✓"
}

# ============================================
# 15. 配置 Starship
# ============================================
setup_starship() {
    log_info "配置 Starship..."
    install_managed_file "$HOME/.config/starship.toml" "$SCRIPT_DIR/.config/starship.toml" ".config/starship.toml" "Starship 配置"
    log_info "Starship 配置完成 ✓"
}

# ============================================
# 16. 配置 Claude
# ============================================
setup_claude() {
    log_info "配置 Claude..."
    install_managed_file "$HOME/.claude/CLAUDE.md" "$SCRIPT_DIR/.claude/CLAUDE.md" ".claude/CLAUDE.md" "Claude CLAUDE.md"
    install_managed_file "$HOME/.claude/settings.json" "$SCRIPT_DIR/.claude/settings.json" ".claude/settings.json" "Claude settings.json"
    install_managed_directory "$HOME/.claude/hooks" "$SCRIPT_DIR/.claude/hooks" ".claude/hooks" "Claude hooks"
    install_managed_directory "$HOME/.claude/sounds" "$SCRIPT_DIR/.claude/sounds" ".claude/sounds" "Claude sounds"
    log_info "Claude 配置完成 ✓"
}

# ============================================
# 17. 配置 Codex
# ============================================
setup_codex_agent() {
    log_info "配置 Codex..."
    install_managed_file "$HOME/.codex/AGENTS.md" "$SCRIPT_DIR/.codex/AGENTS.md" ".codex/AGENTS.md" "Codex AGENTS.md"
    install_managed_file "$HOME/.codex/config.toml" "$SCRIPT_DIR/.codex/config.toml" ".codex/config.toml" "Codex config.toml"
    log_info "Codex 配置完成 ✓"
}

# ============================================
# 主流程
# ============================================
main() {
    local failed=()

    run_step() {
        local name="$1"
        if ! "$name"; then
            log_error "$name 失败"
            failed+=("$name")
        fi
    }

    # sudo 免密码必须首先配置
    run_step setup_sudo_nopasswd

    # 禁用 Gatekeeper（允许运行任何来源的 App）
    run_step disable_gatekeeper

    # 开发环境
    run_step install_xcode_cli_tools
    run_step install_homebrew
    run_step install_tools
    run_step fix_zsh_completion_permissions
    run_step ensure_github_login
    run_step setup_ssh_key
    run_step install_ghostty_fonts
    run_step install_cask_apps
    run_step setup_ghostty
    run_step setup_git
    run_step install_claude_code
    run_step install_codex

    # 系统配置
    run_step setup_macos_defaults
    run_step setup_zshrc
    run_step setup_starship
    run_step setup_claude
    run_step setup_codex_agent

    echo ""
    echo "=========================================="
    echo "   配置完成！"
    echo "=========================================="
    echo ""
    echo "已配置:"
    echo "  - sudo 免密码"
    echo "  - Gatekeeper 禁用（允许任何来源 App）"
    echo "  - Homebrew + 常用工具"
    echo "  - Zsh completion 权限修复"
    echo "  - 终端字体 (Geist Mono + Sarasa Term SC Nerd + JetBrains Mono Nerd Font)"
    echo "  - Google Chrome"
    echo "  - Raycast"
    echo "  - Ghostty"
    echo "  - Ghostty 配置与主题"
    echo "  - Codex App"
    echo "  - Zed"
    echo "  - WeChat"
    echo "  - 1Password"
    echo "  - Typeless"
    echo "  - Git 默认配置"
    echo "  - Claude Code CLI"
    echo "  - OpenAI Codex CLI"
    echo "  - macOS 系统优化 (电源策略、键盘速度等)"
    echo "  - .zshrc 配置"
    echo "  - .zshrc.local 模板"
    echo "  - Starship 主题"
    echo "  - Claude 配置 (CLAUDE.md, settings.json, hooks, sounds)"
    echo "  - Codex 配置 (AGENTS.md, config.toml)"
    echo ""
    echo "提示:"
    echo "  - 部分设置需要重启或重新登录生效"
    echo ""

    if [[ ${#failed[@]} -gt 0 ]]; then
        log_error "以下步骤失败，可单独重试:"
        for step in "${failed[@]}"; do
            echo "  - $step"
        done
        return 1
    fi
}

# 运行
main "$@"
