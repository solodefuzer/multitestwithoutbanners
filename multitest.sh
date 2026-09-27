#!/bin/bash

# ============================================================
#  Multitest — интерактивный скрипт диагностики сервера
# ============================================================

SCRIPT_VERSION="2.0"
REPO_URL="https://raw.githubusercontent.com/saveksme/multitest/master/multitest.sh"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Состояние сводки мультитеста
SUMMARY_DIR=""             
SUMMARY_TS=""
SCRIPT_CAPTURE="util"      
MT_UA="Mozilla/5.0 (X11; Linux x86_64) multitest/${SCRIPT_VERSION}"  

# ============================================================
#  Установка (--install)
# ============================================================

if [[ "$1" == "--install" ]]; then
    echo -e "${CYAN}Установка multitest...${NC}"
    INSTALL_PATH="/usr/local/bin/multitest"
    TMP_FILE=$(mktemp)

    if command -v curl &>/dev/null; then
        curl -sL "$REPO_URL" -o "$TMP_FILE"
    elif command -v wget &>/dev/null; then
        wget -qO "$TMP_FILE" "$REPO_URL"
    else
        echo -e "${RED}Нужен curl или wget для установки.${NC}"
        exit 1
    fi

    if head -1 "$TMP_FILE" 2>/dev/null | grep -q "^#!/bin/bash"; then
        mv "$TMP_FILE" "$INSTALL_PATH"
        chmod +x "$INSTALL_PATH"
        echo -e "${GREEN}Установлено в ${INSTALL_PATH}${NC}"
        echo -e "${GREEN}Теперь можно запускать командой: ${BOLD}multitest${NC}"
    else
        rm -f "$TMP_FILE"
        echo -e "${RED}Ошибка: загрузка не удалась (CDN кэш). Установите напрямую:${NC}"
        echo "  curl -sL $REPO_URL -o /usr/local/bin/multitest && chmod +x /usr/local/bin/multitest"
    fi
    exit 0
fi

# ============================================================
#  Интерфейс
# ============================================================

print_header() {
    clear
    echo -e "${CYAN}${BOLD}MULTITEST v${SCRIPT_VERSION} — Диагностика и тестирование сервера${NC}\n"
}

print_separator() {
    echo -e "\n${BOLD}>>> $1${NC}\n"
}

pause_prompt() {
    echo -e "\n${YELLOW}Нажмите Enter для возврата в меню...${NC}"
    read -r
}

# ============================================================
#  Установка зависимостей
# ============================================================

detect_pkg_manager() {
    if command -v apt-get &>/dev/null; then echo "apt"
    elif command -v dnf &>/dev/null; then echo "dnf"
    elif command -v yum &>/dev/null; then echo "yum"
    elif command -v apk &>/dev/null; then echo "apk"
    elif command -v pacman &>/dev/null; then echo "pacman"
    else echo "unknown"; fi
}

install_package() {
    local pkg="$1"
    local pm
    pm=$(detect_pkg_manager)

    echo -e "${YELLOW}Устанавливаю ${pkg}...${NC}"

    case "$pm" in
        apt)     DEBIAN_FRONTEND=noninteractive apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" ;;
        dnf)     dnf install -y -q "$pkg" ;;
        yum)     yum install -y -q "$pkg" ;;
        apk)     apk add --quiet "$pkg" ;;
        pacman)  pacman -S --noconfirm --quiet "$pkg" ;;
        *)       echo -e "${RED}Не удалось определить пакетный менеджер. Установите ${pkg} вручную.${NC}"; return 1 ;;
    esac
}

check_and_install() {
    local cmd="$1"
    local pkg="${2:-$1}"

    if ! command -v "$cmd" &>/dev/null; then
        install_package "$pkg"
        if ! command -v "$cmd" &>/dev/null; then
            echo -e "${RED}Не удалось установить ${cmd}.${NC}"
            return 1
        fi
    fi
    return 0
}

test_deps() {
    case "$1" in
        run_ip_region|run_censorcheck_geoblock|run_censorcheck_dpi|run_censorcheck_tlab|run_bench_sh) echo "wget" ;;
        run_iperf3_ru|run_iperf3_tlab) echo "wget iperf3 jq" ;;
        run_yabs|run_ip_check_place|run_ip_quality) echo "curl" ;;
        run_sysbench_cpu) echo "sysbench" ;;
    esac
}

missing_deps_for() {
    local fn d; local -a want=( curl ) out=()
    for fn in "$@"; do
        for d in $(test_deps "$fn"); do
            [[ " ${want[*]} " == *" $d "* ]] || want+=( "$d" )
        done
    done
    for d in "${want[@]}"; do
        command -v "$d" &>/dev/null || out+=( "$d" )
    done
    printf '%s' "${out[*]}"
}

install_deps_for() {
    local miss d
    miss=$(missing_deps_for "$@")
    if [[ -n "$miss" ]]; then
        echo -e "${CYAN}Установка зависимостей: ${BOLD}${miss}${NC}"
        for d in $miss; do check_and_install "$d"; done
        echo ""
    fi
}

# ============================================================
#  Функции тестов
# ============================================================

run_ip_region() {
    print_separator "IP Region"
    check_and_install wget
    bash <(wget -qO- https://github.com/Davoyan/ipregion/raw/main/ipregion.sh)
}

run_censorcheck_geoblock() {
    print_separator "Censorcheck — проверка геоблока"
    check_and_install wget
    bash <(wget -qO- https://github.com/vernette/censorcheck/raw/master/censorcheck.sh) --mode geoblock
}

run_censorcheck_dpi() {
    print_separator "Censorcheck — DPI (серверы РФ)"
    check_and_install wget
    bash <(wget -qO- https://github.com/vernette/censorcheck/raw/master/censorcheck.sh) --mode dpi
}

run_censorcheck_tlab() {
    print_separator "Censorcheck — censorcheck.tlab.pw"
    check_and_install wget
    wget -qO- censorcheck.tlab.pw | bash
}

run_iperf3_ru() {
    print_separator "iPerf3 — тест до российских серверов"
    check_and_install wget
    check_and_install iperf3
    check_and_install jq
    bash <(wget -qO- https://github.com/itdoginfo/russian-iperf3-servers/raw/main/speedtest.sh)
}

run_iperf3_tlab() {
    print_separator "iPerf3 — bench.tlab.pw (РФ)"
    check_and_install wget
    check_and_install iperf3
    check_and_install jq
    wget -qO- bench.tlab.pw | bash
}

run_yabs() {
    print_separator "YABS — бенчмарк сервера"
    check_and_install curl
    curl -sL yabs.sh | bash -s -- -4
}

run_ip_check_place() {
    print_separator "IP Check Place"
    check_and_install curl
    bash <(curl -Ls https://IP.Check.Place) -E -n </dev/null
}

run_bench_sh() {
    print_separator "bench.sh"
    check_and_install wget
    wget -qO- bench.sh | bash
}

run_ip_quality() {
    print_separator "IPQuality"
    check_and_install curl
    bash <(curl -Ls https://IP.Check.Place) -E -n </dev/null
}

run_sysbench_cpu() {
    print_separator "sysbench CPU"
    check_and_install sysbench
    sysbench cpu run --threads=1
}

MULTITEST_SKIPPED=0

multitest_skip_handler() {
    MULTITEST_SKIPPED=1
}

fmt_eta() {
    local v=$1
    if (( v < 90 )); then printf '≈%d c' "$v"; else printf '≈%d мин' $(( (v + 30) / 60 )); fi
}

pad_to() {
    local s="$1" w="$2" l; l=$(vlen "$s")
    printf '%s' "$s"
    while (( l < w )); do printf ' '; l=$((l+1)); done
}

mt_select_tests() {
    local n=${#all_funcs[@]} cur=0 i key rest need eta total selected
    MT_SEL=(); for ((i=0;i<n;i++)); do MT_SEL[$i]=1; done

    trap 'printf "\033[?25h\n"; exit 130' INT
    printf '\033[?25l'
    while true; do
        printf '\033[H\033[J'
        echo -e "${CYAN}${BOLD}  МУЛЬТИТЕСТ — выбор тестов${NC}\n"
        echo -e "  ${BOLD}↑↓${NC} навигация  ${BOLD}ПРОБЕЛ${NC} отметить  ${BOLD}A${NC} все  ${BOLD}N${NC} снять все  ${BOLD}F${NC} быстрые  ${BOLD}ENTER${NC} запуск  ${BOLD}Q${NC} выход\n"
        
        for ((i=0;i<n;i++)); do
            need=$(missing_deps_for "${all_funcs[$i]}")
            if (( i == cur )); then printf "  ${CYAN}▸${NC} "; else printf "    "; fi
            if [[ "${MT_SEL[$i]}" == "1" ]]; then printf "${GREEN}[×]${NC}"; else printf "[ ]"; fi
            printf " %2d  " "$((i+1))"
            if (( i == cur )); then printf "${BOLD}"; fi
            pad_to "$(vcut "${all_names[$i]}" 46)" 47
            if (( i == cur )); then printf "${NC}"; fi
            printf "%s" "$(pad_to "$(fmt_eta "${all_secs[$i]}")" 9)"
            [[ -n "$need" ]] && printf "${YELLOW}зависимости: %s${NC}" "${need// /, }"
            printf "\n"
        done

        total=0; selected=0
        for ((i=0;i<n;i++)); do
            [[ "${MT_SEL[$i]}" == "1" ]] || continue
            selected=$((selected+1)); total=$((total + all_secs[i]))
        done
        echo -e "\n  Выбрано ${BOLD}${selected}${NC} из ${n} · примерное время: $(fmt_eta $total)"

        IFS= read -rsn1 key
        [[ "$key" == [$'\xd0'-$'\xd1'] ]] && { IFS= read -rsn1 rest 2>/dev/null; key="$key$rest"; }
        case "$key" in
            ф|Ф) key=a ;; т|Т) key=n ;; а|А) key=f ;; й|Й) key=q ;; л|Л) key=k ;; о|О) key=j ;;
        esac
        case "$key" in
            $'\e')
                IFS= read -rsn2 -t 0.05 rest
                case "$rest" in
                    '[A') (( cur = (cur - 1 + n) % n )) ;;
                    '[B') (( cur = (cur + 1) % n )) ;;
                    '')   trap - INT; printf '\033[?25h'; return 1 ;;
                esac ;;
            ' ')  MT_SEL[$cur]=$(( 1 - MT_SEL[$cur] )) ;;
            k|K)  (( cur = (cur - 1 + n) % n )) ;;
            j|J)  (( cur = (cur + 1) % n )) ;;
            a|A)  for ((i=0;i<n;i++)); do MT_SEL[$i]=1; done ;;
            n|N)  for ((i=0;i<n;i++)); do MT_SEL[$i]=0; done ;;
            f|F)  for ((i=0;i<n;i++)); do if (( all_secs[i] <= 60 )); then MT_SEL[$i]=1; else MT_SEL[$i]=0; fi; done ;;
            q|Q)  trap - INT; printf '\033[?25h'; return 1 ;;
            '')   (( selected > 0 )) && { trap - INT; printf '\033[?25h'; return 0; } ;;
        esac
    done
}

run_all() {
    local all_funcs=( "run_ip_region" "run_censorcheck_geoblock" "run_censorcheck_dpi" \
                      "run_censorcheck_tlab" "run_iperf3_ru" "run_iperf3_tlab" "run_yabs" \
                      "run_ip_check_place" "run_bench_sh" "run_ip_quality" "run_sysbench_cpu" )
    local all_names=( "IP Region" "Censorcheck — проверка геоблока" "Censorcheck — DPI (серверы РФ)" \
                      "Censorcheck — censorcheck.tlab.pw" "iPerf3 — тест до российских серверов" \
                      "iPerf3 — bench.tlab.pw (РФ)" "YABS — бенчмарк сервера" \
                      "IP Check Place — блокировки" "bench.sh — параметры сервера и скорость" \
                      "IPQuality" "sysbench CPU — тест процессора" )
    local all_secs=( 40 120 180 120 180 120 720 180 300 180 15 )
    local catalog_total=${#all_funcs[@]}

    local -a MT_SEL=()
    if [[ -t 0 && -t 1 && "${TERM:-dumb}" != "dumb" ]]; then
        if ! mt_select_tests; then echo -e "\n  ${YELLOW}Мультитест отменён.${NC}"; return 0; fi
    else
        for k in $(seq 0 $((catalog_total - 1))); do MT_SEL[$k]=1; done
    fi

    test_funcs=()
    test_names=()
    for k in $(seq 0 $((catalog_total - 1))); do
        [[ "${MT_SEL[$k]}" == "1" ]] || continue
        test_funcs+=( "${all_funcs[$k]}" )
        test_names+=( "${all_names[$k]}" )
    done

    print_separator "МУЛЬТИТЕСТ — запуск (${#test_funcs[@]} тестов)"
    install_deps_for "${test_funcs[@]}"

    MT_CAT_FUNCS=( "${all_funcs[@]}" )
    MT_CAT_NAMES=( "${all_names[@]}" )
    declare -gA MT_STATUS=()
    for _f in "${test_funcs[@]}"; do MT_STATUS["$_f"]="пропущен"; done

    test_status=(); test_metric=(); test_log=()
    SUMMARY_TS=$(date +%Y%m%d-%H%M%S)
    SUMMARY_DIR="/tmp/multitest-summary-${SUMMARY_TS}"
    mkdir -p "$SUMMARY_DIR" 2>/dev/null
    detect_script_flavor

    local total=${#test_funcs[@]}
    for i in $(seq 0 $((total - 1))); do
        local num=$((i + 1))
        test_status[$i]="пропущен"
        test_log[$i]="$SUMMARY_DIR/test-${num}.log"

        echo -e "\n  ${CYAN}[${num}/${total}]${NC} Текущий тест: ${BOLD}${test_names[$i]}${NC}\n"

        MULTITEST_SKIPPED=0
        trap multitest_skip_handler INT
        ( capture_test "${test_funcs[$i]}" "${test_log[$i]}" )
        trap - INT

        if [[ $MULTITEST_SKIPPED -eq 1 ]]; then
            echo -e "  ${YELLOW}Тест пропущен (Ctrl+C).${NC}"
            test_status[$i]="пропущен"
        else
            test_status[$i]="выполнен"
            [[ -s "${test_log[$i]}" ]] || test_status[$i]="ошибка"
            parse_test_output "${test_funcs[$i]}" "${test_log[$i]}" "$SUMMARY_DIR/${test_funcs[$i]}.metrics" "$SUMMARY_DIR/${test_funcs[$i]}.services"
        fi
        MT_STATUS["${test_funcs[$i]}"]="${test_status[$i]}"
    done

    echo -e "\n${GREEN}${BOLD}Все тесты завершены! (${total}/${total})${NC}"
    render_and_upload_summary
}

# ============================================================
#  Утилиты
# ============================================================

BBR_CONF="/etc/sysctl.d/99-bbr-cake.conf"
IPV6_CONF="/etc/sysctl.d/99-disable-ipv6.conf"

sysctl_other_sources() {
    local key="${1//./\\.}" mine="$2"
    grep -rlsE "^[[:space:]]*${key}[[:space:]]*=" /etc/sysctl.conf /etc/sysctl.d /run/sysctl.d /usr/lib/sysctl.d 2>/dev/null | grep -vFx "$mine" | sort -u
}

enable_bbr_cake() {
    print_separator "Включение BBR + Cake"
    modprobe tcp_bbr 2>/dev/null
    modprobe sch_cake 2>/dev/null

    cat > "$BBR_CONF" <<EOF
net.core.default_qdisc=cake
net.ipv4.tcp_congestion_control=bbr
EOF
    sysctl -p "$BBR_CONF"
    echo -e "${GREEN}Настройки применены.${NC}"
}

disable_bbr_cake() {
    print_separator "Выключение BBR + Cake"
    rm -f "$BBR_CONF"
    sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null 2>&1
    sysctl -w net.core.default_qdisc=fq_codel >/dev/null 2>&1
    echo -e "${GREEN}Настройки сброшены.${NC}"
}

disable_ipv6() {
    print_separator "Выключение IPv6"
    cat > "$IPV6_CONF" <<EOF
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
EOF
    sysctl -p "$IPV6_CONF"
    echo -e "${GREEN}IPv6 выключен.${NC}"
}

enable_ipv6() {
    print_separator "Включение IPv6"
    rm -f "$IPV6_CONF"
    sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.lo.disable_ipv6=0 >/dev/null 2>&1
    echo -e "${GREEN}IPv6 включен.${NC}"
}

show_utilities_menu() {
    while true; do
        print_header
        echo -e "  ${CYAN}${BOLD}── Утилиты ──${NC}\n"
        echo -e "  ${GREEN}1)${NC}  BBR + Cake (переключить)"
        echo -e "  ${GREEN}2)${NC}  IPv6 (переключить)"
        echo -e "\n  ${RED}0)${NC}  Назад\n"
        echo -ne "  ${BOLD}Выберите пункт: ${NC}"
        read -r util_choice

        case "$util_choice" in
            1) enable_bbr_cake; pause_prompt ;;
            2) disable_ipv6; pause_prompt ;;
            0) return ;;
        esac
    done
}

# ============================================================
#  Сводка мультитеста (изображение)
# ============================================================

detect_script_flavor() {
    if script --version 2>&1 | grep -qi 'util-linux'; then SCRIPT_CAPTURE='util'
    else SCRIPT_CAPTURE='busybox'; fi
}

strip_ansi() {
    sed -r 's/\x1B\[[0-9;]*[a-zA-Z]//g; s/\x1B\][^\x07]*\x07//g; s/\r$//; s/.*\r//'
}

capture_test() {
    local fn="$1" logfile="$2"
    export RED GREEN YELLOW CYAN BOLD NC SCRIPT_VERSION
    export -f print_separator check_and_install install_package detect_pkg_manager
    export -f run_ip_region run_censorcheck_geoblock run_censorcheck_dpi \
              run_censorcheck_tlab run_iperf3_ru run_iperf3_tlab run_yabs \
              run_ip_check_place run_bench_sh run_ip_quality run_sysbench_cpu

    if [[ "$SCRIPT_CAPTURE" == "util" ]]; then
        COLUMNS=200 script -q -c "stty cols 200 2>/dev/null; bash -c '$fn'" "$logfile"
    else
        COLUMNS=200 bash -c "$fn" 2>&1 | tee "$logfile"
    fi
}

MT_IMGDB_TTL="${MT_IMGDB_TTL:-259200}"

up_imgdb() {
    local r url
    r=$(curl -fsS -4 -A "$MT_UA" --max-time 60 -F "file=@$1" "https://imgdb.io/api/v1/upload?ttl=${MT_IMGDB_TTL}" 2>/dev/null) || return 1
    url=$(printf '%s' "$r" | grep -oE '"url"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    [[ -n "$url" ]] && printf '%s' "$url"
}

up_imgdb_album() {
    local -a args=(); local f r url
    for f in "$@"; do args+=( -F "file=@$f" ); done
    r=$(curl -fsS -4 -A "$MT_UA" --max-time 180 "${args[@]}" "https://imgdb.io/api/v1/album?ttl=${MT_IMGDB_TTL}" 2>/dev/null) || return 1
    url=$(printf '%s' "$r" | grep -oE '"url"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    [[ "$url" == https://* ]] && printf '%s' "$url"
}

up_x0() { curl -fsS -4 -A "$MT_UA" -F "file=@$1" https://x0.at 2>/dev/null; }

upload_report() {
    local file="$1" url name
    for name in imgdb x0; do
        url=$("up_${name}" "$file" 2>/dev/null); url=$(printf '%s' "$url" | tr -d '\r\n[:space:]')
        if [[ "$url" == https://* ]]; then printf '%s\n' "$url"; return 0; fi
    done
    return 1
}

ensure_rsvg() {
    command -v rsvg-convert &>/dev/null && return 0
    local pm; pm=$(detect_pkg_manager)
    case "$pm" in
        apt) check_and_install rsvg-convert librsvg2-bin ;;
        dnf|yum) check_and_install rsvg-convert librsvg2-tools ;;
        apk) check_and_install rsvg-convert rsvg-convert ;;
        pacman) check_and_install rsvg-convert librsvg ;;
    esac
}

mt_fetch_ttf() {
    if command -v curl &>/dev/null; then curl -fsSL "$1" -o "$2" 2>/dev/null
    else wget -qO "$2" "$1" 2>/dev/null; fi
}

ensure_fonts() {
    command -v fc-list &>/dev/null || install_package fontconfig >/dev/null 2>&1
    if ! fc-list 2>/dev/null | grep -qi 'IBM *Plex *Sans'; then
        local fdir="$HOME/.local/share/fonts/ibm-plex-sans"; mkdir -p "$fdir"
        for w in 400Regular 600SemiBold 700Bold; do mt_fetch_ttf "https://cdn.jsdelivr.net/npm/@expo-google-fonts/ibm-plex-sans/IBMPlexSans_${w}.ttf" "$fdir/IBMPlexSans_${w}.ttf"; done
    fi
    command -v fc-cache &>/dev/null && fc-cache -f >/dev/null 2>&1
}

gather_system_facts() {
    SYS_OS=$(grep -E '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"')
    SYS_KERNEL=$(uname -r 2>/dev/null || echo "unknown")
    SYS_CPU=$(lscpu 2>/dev/null | grep -m1 'Model name' | cut -d: -f2- | sed 's/^ *//')
    SYS_CORES=$(nproc 2>/dev/null)
    SYS_RAM=$(free -h 2>/dev/null | awk '/Mem:/ {print $2}')
    SYS_DISK=$(df -h / 2>/dev/null | awk 'NR==2 {print $2}')
    SYS_IP4=$(curl -s4 --max-time 6 https://ifconfig.me 2>/dev/null)
    SYS_IP6=$(curl -s6 --max-time 6 https://ifconfig.me 2>/dev/null)
    local geo=$(curl -s4 --max-time 6 https://ipinfo.io/json 2>/dev/null)
    SYS_COUNTRY=$(printf '%s' "$geo" | grep -oE '"country"[ ]*:[ ]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
    SYS_CITY=$(printf '%s' "$geo" | grep -oE '"city"[ ]*:[ ]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
}

mask_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then printf '%s' "$ip" | awk -F. '{print $1"."$2".*.*"}'
    elif [[ "$ip" == *:* ]]; then printf '%s' "$ip" | awk -F: '{print $1":"$2"::*"}'
    else printf '%s' "$ip"; fi
}

xml_escape() {
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e "s/'/\&apos;/g" -e 's/"/\&quot;/g'
}

declare -A LOGO_PATH
load_logos() {
    while IFS=$'\t' read -r s c d; do [[ -n "$s" ]] && LOGO_PATH["$s"]="$d"; done <<'LOGOEOF'
netflix	#E50914	m5.398 0 8.348 23.602c2.346.059 4.856.398 4.856.398L10.113 0H5.398zm8.489 0v9.172l4.715 13.33V0h-4.715zM5.398 1.5V24c1.873-.225 2.81-.312 4.715-.398V14.83L5.398 1.5z
youtube	#FF0000	M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z
telegram	#26A5E4	M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z
LOGOEOF
}

brand_slug_for() {
    local n; n=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//')
    case "$n" in
        youtube|telegram|netflix) echo "$n" ;;
        *) echo "" ;;
    esac
}

mt_metric() { printf '%s\x1f%s\x1f%s\n' "$1" "$2" "${3:-}" >> "$MT_MFILE"; }
mt_service() { printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\n' "$1" "$2" "${3:-}" "${4:-na}" "${5:-}" "${6:--1}" >> "$MT_SFILE"; }

parse_ipregion() {
    local txt="$1" rows
    rows=$(printf '%s\n' "$txt" | awk -F'\t' 'NF>=2 && $2!="" && $1!="Service" {print $0}')
    mt_metric "Сервисов" "$(echo "$rows" | wc -l)" "ok"
}

parse_test_output() {
    local fn="$1" log="$2"
    MT_MFILE="$3"; MT_SFILE="$4"
    : > "$MT_MFILE"; : > "$MT_SFILE"
    [[ -f "$log" ]] || return 0
    local txt; txt=$(strip_ansi < "$log" | tr -d '\r')
    case "$fn" in run_ip_region) parse_ipregion "$txt" ;; esac
}

sv() { SVG_BODY="${SVG_BODY}$1"$'\n'; }
sv_esc() { printf '%s' "$1" | xml_escape; }
vlen() { local c="${1//[$'\x80'-$'\xbf']/}"; echo "${#c}"; }
vcut() {
    local s="$1" n="$2" out="" cnt=0
    for (( i=0; i<${#s}; i++ )); do
        c="${s:$i:1}"; [[ "$c" == [$'\x80'-$'\xbf'] ]] || cnt=$((cnt+1))
        (( cnt > n )) && break; out+="$c"
    done
    printf '%s' "${out}"
}

mt_style_init() {
    C_BG="#0A0A0A"; C_SC="#131313"; C_SCH="#202020"; C_TRACK="#2E2E2E"
    C_LINE="#262626"; C_LINE2="#3D3D3D"
    C_TXT="#F2F2F2"; C_TXT2="#9C9C9C"; C_TXT3="#757575"; C_FOOT="#545454"
    C_INV="#E6E6E6"; C_INK="#0A0A0A"; C_MARK="#C6C6C6"
    W=1100; PAD=32; IPAD=28; CARDW=$((W-2*PAD))
    load_logos
}

sv_footer_and_close() {
    local Y="$1" note="$2"
    local footY=$((Y+34)) SVGH
    (( footY + 14 < MT_PAGE_MINH )) && footY=$(( MT_PAGE_MINH - 14 ))
    sv "<text x=\"$PAD\" y=\"$footY\" fill=\"$C_FOOT\" font-size=\"12\">$(sv_esc "$note")</text>"
    SVGH=$((footY+24))
    MT_PAGE_H=$SVGH
    cat <<HEAD
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 $W $SVGH" text-rendering="geometricPrecision" font-family="'IBM Plex Sans', Roboto, 'Noto Sans', 'DejaVu Sans', sans-serif">
<rect width="$W" height="$SVGH" fill="$C_BG"/>
HEAD
    printf '%s' "$SVG_BODY"
    echo "</svg>"
}

build_summary_svg() {
    mt_style_init
    SVG_BODY=""
    local date_e; date_e=$(date '+%Y-%m-%d %H:%M')
    sv "<text x=\"$PAD\" y=\"60\" fill=\"$C_TXT\" font-size=\"26\">MULTITEST Сводка</text>"
    sv_footer_and_close 100 "multitest v${SCRIPT_VERSION} · ${date_e}"
}

render_and_upload_summary() {
    print_separator "Формирую сводку"
    if [[ -z "$SUMMARY_DIR" || ! -d "$SUMMARY_DIR" ]]; then SUMMARY_DIR=$(mktemp -d); fi
    
    ensure_rsvg
    build_summary_svg > "$SUMMARY_DIR/summary.svg"
    local png="$SUMMARY_DIR/summary.png"
    if command -v rsvg-convert &>/dev/null; then rsvg-convert -w 2200 -o "$png" "$SUMMARY_DIR/summary.svg"; fi
    
    local url; url=$(upload_report "$png")
    echo -e "\n${GREEN}Ссылка на сводку: ${url}${NC}"
}

show_menu() {
    print_header
    echo -e "  ${GREEN} 1)${NC}  IP Region"
    echo -e "  ${GREEN} 2)${NC}  Censorcheck"
    echo -e "  ${YELLOW}12)${NC}  ${BOLD}Мультитест — запуск тестов${NC}"
    echo -e "  ${GREEN}13)${NC}  Утилиты (BBR, IPv6...)"
    echo -e "  ${RED} 0)${NC}  Выход\n"
    echo -ne "  ${BOLD}Выберите пункт: ${NC}"
}

while true; do
    show_menu
    read -r choice
    case "$choice" in
        1)  run_ip_region; pause_prompt ;;
        2)  run_censorcheck_geoblock; pause_prompt ;;
        12) run_all; pause_prompt ;;
        13) show_utilities_menu ;;
        0)  echo -e "${GREEN}До свидания!${NC}"; exit 0 ;;
        *)  echo -e "${RED}Неверный выбор.${NC}"; pause_prompt ;;
    esac
done
