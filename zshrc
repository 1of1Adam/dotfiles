# ══════════════════════════════════════════════════════════════════════
# 1. PATH 配置
# ══════════════════════════════════════════════════════════════════════

# Homebrew (Apple Silicon)
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Python user bin
for py_user_bin in "$HOME/Library/Python"/*/bin; do
    [ -d "$py_user_bin" ] || continue
    case ":$PATH:" in
        *":$py_user_bin:"*) ;;
        *) PATH="$py_user_bin:$PATH" ;;
    esac
done

# 常用工具路径
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"

# ══════════════════════════════════════════════════════════════════════
# 2. 命令补全
# ══════════════════════════════════════════════════════════════════════

# Zsh 补全系统增强
if type brew &>/dev/null; then
    FPATH="$(brew --prefix)/share/zsh-completions:$FPATH"
    FPATH="$(brew --prefix)/share/zsh/site-functions:$FPATH"
fi

# 初始化补全系统
autoload -Uz compinit
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

# ══════════════════════════════════════════════════════════════════════
# 3. 常用别名
# ══════════════════════════════════════════════════════════════════════

# Claude Code
alias cc='claude --dangerously-skip-permissions'

# Chrome DevTools (远程调试模式)
alias chrome='/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222 --user-data-dir=$HOME/.chrome-dev --no-first-run --no-default-browser-check'

# ══════════════════════════════════════════════════════════════════════
# 4. OSC 8 超链接：终端内文件路径可 Cmd+Click 打开
# ══════════════════════════════════════════════════════════════════════

alias rg='rg --hyperlink-format=file://{host}{path}#{line}'
alias fd='fd --hyperlink=always'
alias ls='eza --hyperlink'
alias ll='eza -la --hyperlink'

# 辅助函数：将路径转为 OSC 8 可点击链接
osc8_link() {
    local path="${1:a}"
    printf '\e]8;;file://%s%s\e\\%s\e]8;;\e\\' "$(hostname)" "$path" "${2:-$1}"
}

# open-dir: 用 OSC 8 打印当前目录的可点击链接
olink() {
    local target="${1:-.}"
    local abs="${target:a}"
    printf '\e]8;;file://%s%s\e\\📂 %s\e]8;;\e\\\n' "$(hostname)" "$abs" "$abs"
}

# pwd 也输出可点击链接
pwdl() {
    printf '\e]8;;file://%s%s\e\\%s\e]8;;\e\\\n' "$(hostname)" "$PWD" "$PWD"
}

# ══════════════════════════════════════════════════════════════════════
# 5. 其他配置
# ══════════════════════════════════════════════════════════════════════

# 禁用 Node.js 废弃警告
export NODE_OPTIONS="--no-deprecation"

# agent-browser 数据目录
export AGENT_BROWSER_USER_DATA_DIR=~/.agent-browser-data
