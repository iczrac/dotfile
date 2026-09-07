#!/usr/bin/env bash
# 让 tmux-power 的状态栏按 client 宽度自适应:窄终端(手机 SSH)时腾出空间给
# window 列表 —— 只显示 session 图标(隐去 session name),并隐藏右侧的时间和日期。
#
# tmux 状态栏按 client 独立渲染,同一份模板在不同宽度的 client 上会各自求值
# #{client_width},因此只需要把条件表达式嵌进模板即可,不需要为每个 client
# 单独触发/轮询,也不依赖任何环境变量。
#
# 触发时机:~/.dotfiles/tmux.conf 末尾(tpm 初始化之后)跑一次 —— 必须在 tmux-power
# 之后,否则会被插件覆盖;session-created hook 给之后新建的 session 兜底。
# 这里只重建 status-left / status-right 两个 option,插件其余设置不受影响。

set -euo pipefail

# 用户没显式设置某个选项时,tmux show 返回空串,必须回退到插件自己的默认值,
# 否则箭头/图标会直接消失。默认值是 Powerline 私有区字符(U+E0B0 等),不适合
# 硬编码在这里(容易在编辑/同步过程中丢字节),所以直接从插件源码里提取。
plugin_src="$HOME/.tmux/plugins/tmux-power/tmux-power.tmux"
# 从形如 `xxx=$(tmux_get '@opt' '<默认值>')` 的行里取出第二个引号参数。
plugin_default() {
    [ -f "$plugin_src" ] || return 0
    sed -n "s/.*tmux_get '$1' '\\(.*\\)').*/\\1/p" "$plugin_src" | head -1
}

threshold="$(tmux show -gqv '@tmux_power_session_width_threshold' 2>/dev/null || true)"
threshold="${threshold:-80}"
# 窄屏判定,供下面各处复用。数值比较必须用 e| 前缀:
# 裸的 #{<:...} 是字符串比较,"74" < "80" 恰好碰巧为真,但 "102" < "80" 也会为真。
narrow="#{e|<:#{client_width},${threshold}}"

session_icon="$(tmux show -gqv '@tmux_power_session_icon' 2>/dev/null || true)"
session_icon="${session_icon:-$(plugin_default '@tmux_power_session_icon')}"

TC="$(tmux show -gqv '@tmux_power_theme' 2>/dev/null || true)"
TC="${TC:-gold}"
case "$TC" in
    gold) TC='#ffb86c' ;;
    redwine) TC='#b34a47' ;;
    moon) TC='#00abab' ;;
    forest) TC='#228b22' ;;
    violet) TC='#9370db' ;;
    snow) TC='#fffafa' ;;
    coral) TC='#ff7f50' ;;
    sky) TC='#87ceeb' ;;
    everforest) TC='#a7c080' ;;
    *) TC="$TC" ;;
esac
G0="$(tmux show -gqv '@tmux_power_g0' 2>/dev/null || true)"; G0="${G0:-#262626}"
G1="$(tmux show -gqv '@tmux_power_g1' 2>/dev/null || true)"; G1="${G1:-#303030}"
G2="$(tmux show -gqv '@tmux_power_g2' 2>/dev/null || true)"; G2="${G2:-#3a3a3a}"
rarrow="$(tmux show -gqv '@tmux_power_right_arrow_icon' 2>/dev/null || true)"
rarrow="${rarrow:-$(plugin_default '@tmux_power_right_arrow_icon')}"
show_user="$(tmux show -gqv '@tmux_power_show_user' 2>/dev/null || true)"; show_user="${show_user:-true}"
show_host="$(tmux show -gqv '@tmux_power_show_host' 2>/dev/null || true)"; show_host="${show_host:-true}"
show_session="$(tmux show -gqv '@tmux_power_show_session' 2>/dev/null || true)"; show_session="${show_session:-true}"
user_icon="$(tmux show -gqv '@tmux_power_user_icon' 2>/dev/null || true)"
user_icon="${user_icon:-$(plugin_default '@tmux_power_user_icon')}"
prefix_highlight_pos="$(tmux show -gqv '@tmux_power_prefix_highlight_pos' 2>/dev/null || true)"

# 窄屏时整个 session name(连同它前面的分隔空格)一起隐去,只留图标;
# 宽屏时正常显示完整 session name。
session_field="#{?${narrow},,#{session_name} }"

LS=""
if [ "$show_user" = true ] && [ "$show_host" = true ]; then
    LS="#[fg=$G0,bg=$TC,bold] $user_icon $(whoami)@#h #[fg=$TC,bg=$G2,nobold]$rarrow"
elif [ "$show_user" = true ]; then
    LS="#[fg=$G0,bg=$TC,bold] $user_icon $(whoami) #[fg=$TC,bg=$G2,nobold]$rarrow"
elif [ "$show_host" = true ]; then
    LS="#[fg=$G0,bg=$TC,bold] #h #[fg=$TC,bg=$G2,nobold]$rarrow"
fi

if [ "$show_session" = true ]; then
    LS="$LS#[fg=$TC,bg=$G2] $session_icon $session_field"
fi
LS="$LS#[fg=$G2,bg=$G0]$rarrow"

if [ "$prefix_highlight_pos" = "L" ] || [ "$prefix_highlight_pos" = "LR" ]; then
    LS="$LS#{prefix_highlight}"
fi

tmux set-option -gq status-left "$LS"

# -- status-right:窄屏时隐藏时间和日期 ----------------------------------------
# 复刻 tmux-power.tmux:127-137 的拼装,只把时间/日期两块包进窄屏条件里。
larrow="$(tmux show -gqv '@tmux_power_left_arrow_icon' 2>/dev/null || true)"
larrow="${larrow:-$(plugin_default '@tmux_power_left_arrow_icon')}"
time_icon="$(tmux show -gqv '@tmux_power_time_icon' 2>/dev/null || true)"
time_icon="${time_icon:-$(plugin_default '@tmux_power_time_icon')}"
date_icon="$(tmux show -gqv '@tmux_power_date_icon' 2>/dev/null || true)"
date_icon="${date_icon:-$(plugin_default '@tmux_power_date_icon')}"
time_format="$(tmux show -gqv '@tmux_power_time_format' 2>/dev/null || true)"
time_format="${time_format:-%T}"
date_format="$(tmux show -gqv '@tmux_power_date_format' 2>/dev/null || true)"
date_format="${date_format:-%F}"
show_download_speed="$(tmux show -gqv '@tmux_power_show_download_speed' 2>/dev/null || true)"
show_download_speed="${show_download_speed:-false}"
show_web_reachable="$(tmux show -gqv '@tmux_power_show_web_reachable' 2>/dev/null || true)"
show_web_reachable="${show_web_reachable:-false}"
download_speed_icon="$(tmux show -gqv '@tmux_power_download_speed_icon' 2>/dev/null || true)"
download_speed_icon="${download_speed_icon:-$(plugin_default '@tmux_power_download_speed_icon')}"

# 时间 + 日期整块:窄屏时求值为空,宽屏时是插件原本的样子。
datetime_block="#[fg=$G2]$larrow#[fg=$TC,bg=$G2] $time_icon $time_format #[fg=$TC,bg=$G2]$larrow#[fg=$G0,bg=$TC] $date_icon $date_format "
RS="#{?${narrow},,${datetime_block}}"

if [ "$show_download_speed" = true ]; then
    RS="#[fg=$G1,bg=$G0]$larrow#[fg=$TC,bg=$G1] $download_speed_icon #{download_speed} $RS"
fi
if [ "$show_web_reachable" = true ]; then
    RS=" #{web_reachable_status} $RS"
fi
if [ "$prefix_highlight_pos" = "R" ] || [ "$prefix_highlight_pos" = "LR" ]; then
    RS="#{prefix_highlight}$RS"
fi

tmux set-option -gq status-right "$RS"

# -- window 列表:窄屏时只显示序号,不显示 window 名 -----------------------------
# 复刻 tmux-power.tmux:140-141,把 `#I:#W#F` 换成条件表达式。
# #F 是状态标志(* 当前 / - 上一个 / # 有活动),只占一个字符,窄屏也保留。
window_field="#{?${narrow},#I#F,#I:#W#F}"
tmux set-option -gq window-status-format \
    "#[fg=$G0,bg=$G2]$rarrow#[fg=$TC,bg=$G2] $window_field #[fg=$G2,bg=$G0]$rarrow"
tmux set-option -gq window-status-current-format \
    "#[fg=$G0,bg=$TC]$rarrow#[fg=$G0,bg=$TC,bold] $window_field #[fg=$TC,bg=$G0,nobold]$rarrow"
