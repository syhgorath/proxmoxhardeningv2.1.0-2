#!/bin/bash
group="hardening"
module_name="SvcTuner"
module_description="🔧 Service tuner for Proxmo x"
version=1.0.0
RegisterModules "$module_name" "$module_description" "$group"
SvcTuner() {

    tee /usr/local/bin/svc-tuner.sh >/dev/null <<'EOF'
#!/bin/bash
#set -Eeuo pipefail
IFS=$'\n\t'

# ===== Kritik Proxmox/service whitelist (yanlışlıkla kapanmasın) =====
KEEP=( ssh.service pvedaemon.service pveproxy.service pve-cluster.service pvestatd.service pvescheduler.service qmeventd.service pve-guests.service
       networking.service systemd-networkd.service systemd-networkd-wait-online.service
       rsyslog.service auditd.service apparmor.service
       chrony.service systemd-timesyncd.service
       proxmox-firewall.service pve-firewall.service pve-firewall-commit.service pvefw-logger.service
       zfs-import-cache.service zfs-mount.service zfs-zed.service )

ALLOW_CRITICAL="${ALLOW_CRITICAL:-0}"   # 1 → KEEP korumasını aş
FILTER="${FILTER:-}"                    # regex filtre (unit adına uygulanır)

# ===== Utils =====
msg(){ printf '%s\n' "$*"; }
warn(){ printf 'WARN: %s\n' "$*" >&2; }
die(){ printf 'ERR : %s\n' "$*" >&2; exit 1; }
trim(){ local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }
is_keep(){ local u="$1"; for k in "${KEEP[@]}"; do [[ "$u" == "$k" ]] && return 0; done; return 1; }

# ===== Data =====
declare -a UNIT DESC UFSTATE ACTSTATE

refresh_services(){
  UNIT=() DESC=() UFSTATE=() ACTSTATE=()
  # Raw satırı al, ilk tokenı UNIT, ikinci tokenı STATE yap (kalanı umursama)
  while IFS= read -r line; do
    [[ -z "${line// }" ]] && continue
    # 1. token = unit
    local unit="${line%%[[:space:]]*}"
    # kalan -> 2. token = state
    local rest="${line#"$unit"}"; rest="$(trim "$rest")"
    local state="${rest%%[[:space:]]*}"
    [[ -z "$unit" || -z "$state" ]] && continue
    # filtre uygula
    if [[ -n "$FILTER" && ! "$unit" =~ $FILTER ]]; then
      continue
    fi
    UNIT+=("$unit")
    UFSTATE+=("$state")
    # Description
    local d
    d="$(systemctl show -p Description --value "$unit" 2>/dev/null | head -n1)"
    [[ -z "$d" ]] && d="(no description)"
    DESC+=("$d")
    # Active state
    local a; a="$(systemctl is-active "$unit" 2>/dev/null || true)"
    [[ -z "$a" ]] && a="inactive"
    ACTSTATE+=("$a")
  done < <(systemctl list-unit-files --type=service --all --no-legend --no-pager)
}

print_table(){
  printf "\n#  | %-45s | %-45s | %-9s | %-8s\n" "Adı (Description)" "Servis Adı (Unit)" "UnitFile" "Active"
  printf -- "----+-%-45s-+-%-45s-+-%-9s-+-%-8s\n" "---------------------------------------------" "---------------------------------------------" "---------" "--------"
  local i
  for ((i=0; i<${#UNIT[@]}; i++)); do
    printf "%-3d| %-45.45s | %-45.45s | %-9s | %-8s" \
      "$((i+1))" "${DESC[$i]}" "${UNIT[$i]}" "${UFSTATE[$i]}" "${ACTSTATE[$i]}"
    if is_keep "${UNIT[$i]}"; then printf "  (KEEP)"; fi
    printf "\n"
  done
  printf "\nToplam: %d servis\n" "${#UNIT[@]}"
}

range_to_indices(){
  local spec="$1" out=() part
  IFS=',' read -r -a parts <<<"$spec"
  for part in "${parts[@]}"; do
    if [[ "$part" =~ ^[0-9]+-[0-9]+$ ]]; then
      local a="${part%-*}" b="${part#*-}"
      for ((n=a; n<=b; n++)); do out+=("$n"); done
    elif [[ "$part" =~ ^[0-9]+$ ]]; then
      out+=("$part")
    fi
  done
  printf '%s\n' "${out[@]}"
}

do_action(){
  local act="$1"; shift
  local idxs=("$@")
  [[ "${#idxs[@]}" -eq 0 ]] && { warn "seçim yok"; return; }
  for n in "${idxs[@]}"; do
    (( n>=1 && n<=${#UNIT[@]} )) || { warn "geçersiz numara: $n"; continue; }
    local u="${UNIT[$((n-1))]}"
    if is_keep "$u" && [[ "$ALLOW_CRITICAL" != "1" ]]; then
      warn "kritik (KEEP), atlanıyor: $u (geçmek için ALLOW_CRITICAL=1)"
      continue
    fi
    case "$act" in
      enable)      systemctl enable "$u";;
      disable)     systemctl disable "$u";;
      start)       systemctl start "$u";;
      stop)        systemctl stop "$u";;
      mask)        systemctl mask "$u";;
      unmask)      systemctl unmask "$u";;
      enable-now)  systemctl enable --now "$u";;
      disable-now) systemctl disable "$u"; systemctl stop "$u" || true;;
      *) die "bilinmeyen eylem: $act";;
    esac
    msg "OK: $act → $u"
  done
}

usage(){
cat <<USAGE
svc-tuner.sh — Systemd servislerini listele ve yönet (Proxmox dostu)

Kullanım:
  svc-tuner.sh                    # etkileşimli mod
  svc-tuner.sh --list             # sadece listele (numaralı)
  svc-tuner.sh --csv              # CSV çıktısı (index,description,unit,state,active)
  svc-tuner.sh --filter REGEX     # liste filtresi (ör '^ssh')
  svc-tuner.sh --enable  "1,2,5-10"
  svc-tuner.sh --disable "3,4"
  svc-tuner.sh --start   "7"
  svc-tuner.sh --stop    "8-12"
  svc-tuner.sh --mask    "13"
  svc-tuner.sh --unmask  "13"
  svc-tuner.sh --enable-now  "2,3"
  svc-tuner.sh --disable-now "4"

Notlar:
- KEEP listesi kritik PVE servislerini korur. Geçmek için: ALLOW_CRITICAL=1 svc-tuner.sh --disable "N"
- Sütun: (1) numara, (2) Description, (3) Unit, (4) Unit file state (enabled/disabled/static/indirect/masked), (5) Active.
USAGE
}

# ===== CLI (non-interactive) =====
if [[ "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ "${1:-}" == "--filter" ]]; then FILTER="${2:-}"; shift 2 || true; fi

case "${1:-}" in
  --list|--csv|--enable|--disable|--start|--stop|--mask|--unmask|--enable-now|--disable-now)
    refresh_services
    case "$1" in
      --list) print_table; exit 0;;
      --csv)
        echo "index,description,unit,unit_file_state,active"
        for ((i=0;i<${#UNIT[@]};i++)); do
          # description içinde çift tırnakları kaçır
          d="${DESC[$i]//\"/\"\"}"
          printf '%d,"%s",%s,%s,%s\n' $((i+1)) "$d" "${UNIT[$i]}" "${UFSTATE[$i]}" "${ACTSTATE[$i]}"
        done
        exit 0;;
      *)
        action="${1#--}"; sel="${2:-}"; [[ -z "$sel" ]] && die "seçim belirtin (örn 1,2,5-10)"
        mapfile -t idxs < <(range_to_indices "$sel")
        do_action "$action" "${idxs[@]}"; exit 0;;
    esac
  ;;
esac

# ===== Interactive loop =====
refresh_services
while true; do
  print_table
  printf "Komutlar: [e]nable [d]isable [E]nable+start [D]isable+stop [s]tart [x]stop [m]ask [u]nmask [f]ilter [r]efresh [q]uit\n"
  read -rp "Örnek: 1,2,5-8:e  veya  f:^ssh  → " line || exit 0
  line="${line// /}"
  [[ -z "$line" ]] && continue
  if [[ "$line" =~ ^f: ]]; then
    FILTER="${line#f:}"; refresh_services; continue
  fi
  cmd="${line##*:}"; sel="${line%%:*}"
  case "$cmd" in
    e|d|E|D|s|x|m|u)
      mapfile -t idxs < <(range_to_indices "$sel")
      case "$cmd" in
        e) do_action enable "${idxs[@]}";;
        d) do_action disable "${idxs[@]}";;
        E) do_action enable-now "${idxs[@]}";;
        D) do_action disable-now "${idxs[@]}";;
        s) do_action start "${idxs[@]}";;
        x) do_action stop  "${idxs[@]}";;
        m) do_action mask  "${idxs[@]}";;
        u) do_action unmask "${idxs[@]}";;
      esac
      ;;
    r|refresh) refresh_services;;
    q|quit) exit 0;;
    *) warn "bilinmeyen komut";;
  esac
done
EOF
    sudo chmod +x /usr/local/bin/svc-tuner.sh
   
}
