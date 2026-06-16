#!/bin/bash
# Synopsys Copilot GUI ask wrapper
# Usage: ask.sh "question" [--tool vcs]
#        ask.sh --start
#        ask.sh --status

SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sp.shentao.lu@10.9.200.12"
SCRIPT="/home/sp.shentao.lu/copilot_cli.py"

case "${1:-}" in
    --start)
        $SSH "python3 $SCRIPT --start"
        ;;
    --status)
        $SSH "python3 $SCRIPT --status"
        ;;
    "")
        echo "Usage: ask.sh <question> [--tool <tool>]"
        echo "       ask.sh --start"
        echo "       ask.sh --status"
        exit 1
        ;;
    *)
        question="$1"
        tool_arg=""
        if [ "$2" = "--tool" ] && [ -n "$3" ]; then
            tool_arg="--tool $3"
        fi
        $SSH "python3 $SCRIPT $tool_arg \"$question\""
        ;;
esac
