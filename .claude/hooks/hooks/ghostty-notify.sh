#!/bin/bash
# Ghostty 原生通知脚本
# 使用 OSC 777 发送通知，并显示 session 标题

# 读取 hook 输入
INPUT=$(cat)

# 获取 transcript 路径
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)

# 获取通知类型（用于区分不同事件）
HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)

# 固定标题
SESSION_TITLE="Claude Code"

# 根据事件类型设置通知内容和提示音
case "$HOOK_EVENT" in
    "PreToolUse")
        # AskUserQuestion（由 matcher 过滤）
        NOTIFICATION_BODY="需要你的输入"
        SOUND_FILE="/System/Library/Sounds/Pop.aiff"
        ;;
    "Stop")
        NOTIFICATION_BODY="任务已完成"
        SOUND_FILE="/System/Library/Sounds/Bottle.aiff"
        ;;
    *)
        NOTIFICATION_BODY="需要你的注意"
        SOUND_FILE="/System/Library/Sounds/Pop.aiff"
        ;;
esac

# 发送 macOS 系统通知（不带声音）
osascript -e "display notification \"$NOTIFICATION_BODY\" with title \"$SESSION_TITLE\"" 2>/dev/null &

# 播放提示音（60% 音量）
afplay -v 0.6 "$SOUND_FILE" &

exit 0
