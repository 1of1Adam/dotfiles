# PATH and completion hygiene
typeset -gU path fpath

setopt auto_cd
setopt interactive_comments
setopt no_beep
setopt prompt_subst

# Homebrew
if [[ -d /opt/homebrew ]]; then
    export HOMEBREW_PREFIX=/opt/homebrew
    path=(/opt/homebrew/bin /opt/homebrew/sbin $path)
    export MANPATH="/opt/homebrew/share/man${MANPATH:+:$MANPATH}"
    export INFOPATH="/opt/homebrew/share/info${INFOPATH:+:$INFOPATH}"
fi

# User bins
for py_user_bin in "$HOME"/Library/Python/*/bin(N); do
    [[ -d "$py_user_bin" ]] && path=("$py_user_bin" $path)
done
for extra_dir in "$HOME/.local/bin" "$HOME/bin" "$HOME/.opencode/bin"; do
    [[ -d "$extra_dir" ]] && path=("$extra_dir" $path)
done
export PATH

# Completions
for completion_dir in \
    "$HOME/.zsh/completions" \
    /opt/homebrew/share/zsh-completions \
    /opt/homebrew/share/zsh/site-functions
do
    [[ -d "$completion_dir" ]] && fpath=("$completion_dir" $fpath)
done

autoload -Uz compinit
ZSH_COMPDUMP="${ZDOTDIR:-$HOME}/.zcompdump"
compinit -C -d "$ZSH_COMPDUMP"

if [[ -f "$HOME/.openclaw/completions/openclaw.zsh" ]]; then
    source "$HOME/.openclaw/completions/openclaw.zsh"
fi

# Prompt
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
else
    PROMPT='%n@%m %1~ %# '
fi

# Aliases
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --hyperlink'
    alias ll='eza -la --hyperlink'
fi
if command -v rg >/dev/null 2>&1; then
    alias rg='rg --hyperlink-format=file://{host}{path}#{line}'
fi
if command -v fd >/dev/null 2>&1; then
    alias fd='fd --hyperlink=always'
fi
if command -v claude >/dev/null 2>&1; then
    alias cc='claude --dangerously-skip-permissions --effort max --channels plugin:telegram@claude-plugins-official'
fi
if command -v codex >/dev/null 2>&1; then
    alias c='codex --yolo'
fi
alias q='cd ~'

# Chrome DevTools remote debugging
chrome() {
    local profile="${HOME}/.cache/chrome-devtools-mcp/devtools-mcp-manual-profile"
    local port="${1:-9333}"
    local pattern="Google Chrome.*--remote-debugging-port=${port}.*--user-data-dir=${profile}"

    if pgrep -f -- "$pattern" >/dev/null 2>&1; then
        osascript -e 'tell application "Google Chrome" to activate' >/dev/null 2>&1 || true
        echo "chrome debug profile already running on port ${port}"
        return 0
    fi

    mkdir -p "$profile"
    rm -f \
        "$profile/SingletonLock" \
        "$profile/SingletonCookie" \
        "$profile/SingletonSocket" \
        "$profile/DevToolsActivePort"
    open -na "Google Chrome" --args \
        --remote-debugging-port="$port" \
        --user-data-dir="$profile"
}

project_roots() {
    local dir
    for dir in \
        "$HOME/Developer" \
        "$HOME/Documents" \
        "$HOME/Projects" \
        "$HOME/UI" \
        "$HOME"
    do
        [[ -d "$dir" ]] && print -r -- "$dir"
    done
}

pick_package_project() {
    if ! command -v fd >/dev/null 2>&1 || ! command -v fzf >/dev/null 2>&1; then
        echo "quickserve requires fd and fzf"
        return 1
    fi

    local -a roots
    roots=("${(@f)$(project_roots)}")
    [[ "${#roots[@]}" -eq 0 ]] && return 1

    command fd --hyperlink=never -t f '^package\.json$' "${roots[@]}" -d 6 -E node_modules 2>/dev/null \
        | sed 's#/package.json$##' \
        | awk '!seen[$0]++' \
        | command fzf --prompt='project > ' --height=40% --reverse
}

detect_package_manager() {
    if [[ -f pnpm-lock.yaml ]]; then
        print -r -- pnpm
    elif [[ -f yarn.lock ]]; then
        print -r -- yarn
    else
        print -r -- npm
    fi
}

pick_script() {
    node -e '
        const scripts = Object.keys(require("./package.json").scripts || {});
        const preferred = ["dev", "start", "serve", "preview"];
        const first = preferred.find(name => scripts.includes(name));
        if (first) {
          console.log(first);
          process.exit(0);
        }
        console.log(scripts.join("\n"));
    ' 2>/dev/null
}

run_package_script() {
    local pm="$1"
    local script="$2"

    if [[ "$pm" == "yarn" ]]; then
        yarn "$script"
    else
        "$pm" run "$script"
    fi
}

dev() {
    if tmux has-session -t dev 2>/dev/null; then
        tmux attach -t dev
    else
        tmux new-session -d -s dev
        tmux send-keys -t dev 'cd ~/Developer/hangzhou && pnpm dev' Enter
        echo '服务器已启动，tmux attach -t dev 查看日志'
    fi
}

alias off="tmux kill-session -t dev 2>/dev/null && echo '已关闭'"

restart() {
    tmux kill-session -t dev 2>/dev/null
    tmux new-session -d -s dev
    tmux send-keys -t dev 'cd ~/Developer/hangzhou && pnpm dev' Enter
    echo '已重启'
}

quickserve() {
    local dir pm script scripts selected

    dir="$(pick_package_project)" || return
    [[ -z "$dir" ]] && return
    builtin cd "$dir" || return

    [[ ! -f package.json ]] && return 1

    scripts="$(pick_script)"
    [[ -z "$scripts" ]] && {
        echo "no runnable scripts found"
        return 1
    }

    script="$(printf '%s\n' "$scripts" | head -n1)"
    if [[ "$scripts" == *$'\n'* ]]; then
        selected="$(printf '%s\n' "$scripts" | command fzf --prompt='script > ' --height=40% --reverse)" || return
        [[ -n "$selected" ]] && script="$selected"
    fi

    pm="$(detect_package_manager)"
    echo "dir: $PWD"
    echo "run: $pm $script"
    run_package_script "$pm" "$script"
}
alias qs='quickserve'
alias rs='restart'

quickserve_tree() {
    if ! command -v fd >/dev/null 2>&1 || ! command -v fzf >/dev/null 2>&1; then
        echo "quickserve_tree requires fd and fzf"
        return 1
    fi

    local root selected rel dir pm script exit_code
    local -a dirs pms scripts pids
    local first_dir="" first_pm="" first_script=""

    root="${1:-$(pick_package_project)}" || return
    [[ -z "$root" ]] && return
    root="${root:A}"
    [[ ! -d "$root" ]] && {
        echo "root not found: $root"
        return 1
    }

    selected="$(
        builtin cd "$root" || exit 1
        command fd --hyperlink=never -t f '^package\.json$' . -d 6 -E node_modules 2>/dev/null \
            | sed -E 's#^\./##; s#/?package\.json$##' \
            | awk '{if($0=="")$0="."; if(!seen[$0]++) print}' \
            | command fzf -m --prompt='projects > ' --height=50% --reverse
    )" || return
    [[ -z "$selected" ]] && return

    for rel in "${(@f)selected}"; do
        dir="$root"
        [[ "$rel" != "." ]] && dir="$root/$rel"
        [[ ! -f "$dir/package.json" ]] && continue

        script="$(
            builtin cd "$dir" || exit 1
            pick_script
        )"
        script="$(printf '%s\n' "$script" | head -n1)"
        [[ -z "$script" ]] && continue

        builtin cd "$dir" || return
        pm="$(detect_package_manager)"

        if [[ -z "$first_dir" ]]; then
            first_dir="$dir"
            first_pm="$pm"
            first_script="$script"
        else
            dirs+=("$dir")
            pms+=("$pm")
            scripts+=("$script")
        fi
    done

    [[ -z "$first_dir" ]] && {
        echo "no runnable projects found"
        return 1
    }

    local i
    for ((i=1; i<=${#dirs[@]}; i++)); do
        (
            builtin cd "${dirs[i]}" || exit 1
            run_package_script "${pms[i]}" "${scripts[i]}"
        ) &
        pids+=("$!")
    done

    [[ "${#pids[@]}" -gt 0 ]] && trap 'for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null; done' INT TERM EXIT

    exit_code=0
    (
        builtin cd "$first_dir" || exit 1
        run_package_script "$first_pm" "$first_script"
    ) || exit_code=$?

    for pid in "${pids[@]}"; do
        kill "$pid" 2>/dev/null
    done
    trap - INT TERM EXIT
    return "$exit_code"
}
alias qst='quickserve_tree'

# Tool init
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

if [[ "${ENABLE_ATUIN:-0}" == "1" ]] && command -v atuin >/dev/null 2>&1; then
    eval "$(atuin init zsh)"
fi

if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh) 2>/dev/null || true
fi

if command -v delta >/dev/null 2>&1; then
    export GIT_PAGER=delta
fi

if [[ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
if [[ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

if [[ "${ENABLE_KAKU_ZSH:-0}" == "1" && -f "$HOME/.config/kaku/zsh/kaku.zsh" ]]; then
    source "$HOME/.config/kaku/zsh/kaku.zsh"
fi

# Generic env
export AGENT_BROWSER_USER_DATA_DIR="$HOME/.agent-browser-data"
export NODE_NO_WARNINGS=1

# Machine-specific aliases, tokens, and experiments belong here.
if [[ -f "$HOME/.zshrc.local" ]]; then
    source "$HOME/.zshrc.local"
fi

# bun completions
[ -s "/Users/adampeng/.bun/_bun" ] && source "/Users/adampeng/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export PATH="$HOME/bin:$PATH"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/adampeng/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/adampeng/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/adampeng/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/adampeng/Downloads/google-cloud-sdk/completion.zsh.inc'; fi
