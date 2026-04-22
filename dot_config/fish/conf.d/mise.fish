# Activate mise for fish shell (interactive only — scripts use `mise exec`)
if status is-interactive; and command -v mise &>/dev/null
    mise activate fish | source
end
