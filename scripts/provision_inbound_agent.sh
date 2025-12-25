#!/usr/bin/env bash
# provision_inbound_agent.sh
set -Eeuo pipefail

### ======== KONFIG (UZUPEŁNIJ) ========
# Jenkins controller:
JENKINS_URL="http://10.101.50.15:8080"   # URL kontrolera
JENKINS_USER="administrator"                     # login w Jenkinsie
JENKINS_API_TOKEN="1190d664b3ca8a5886bd6a126da6490f87"  # <-- wklej swój token

# Node/agent:
NODE_NAME="V035BD001"                    # nazwa noda w Jenkins
NODE_LABELS="V035BD001"               # etykiety (opcjonalnie)
NODE_EXECUTORS="1"
NODE_DESC="Inbound agent for V035BD001"
REMOTE_FS="/home/jenkins/agent"          # katalog pracy noda (na tym hoście)

# Lokalne konto pod agenta + dostęp z Jenkinsa:
LOCAL_USER="jenkins"
LOCAL_PASS="buty2022!@RUDE(*"              # hasło lokalnego usera (opcjonalne)
LOCAL_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC/NWy9a2iWHfWYK0FrIkwG25Zlx92Yjme8/c64Elx3Y jenkins_ssh_user"  # publiczny klucz (opcjonalnie)

# Dodatki:
INSTALL_DOCKER="yes"
OPEN_UFW_PORTS="22,8080,9100"            # jeśli masz UFW
JAVA_PKG_DEBIAN="openjdk-17-jre"
JAVA_PKG_RHEL="java-17-openjdk"
### ====================================

log(){ printf "\n\033[1;32m==> %s\033[0m\n" "$*"; }
warn(){ printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
die(){ printf "\033[1;31m[ERR]\033[0m %s\n" "$*"; exit 1; }
require_root(){ [ "${EUID:-$(id -u)}" -eq 0 ] || die "Uruchom jako root."; }

detect_os(){
  if command -v apt-get >/dev/null 2>&1; then OS_FAM="debian"
  elif command -v dnf >/dev/null 2>&1; then OS_FAM="rhel"
  elif command -v yum >/dev/null 2>&1; then OS_FAM="rhel"
  else die "Nie wykryto apt/dnf/yum"; fi
  log "OS: $OS_FAM"
}

pkg(){
  case "$OS_FAM" in
    debian) apt-get update -y; apt-get install -y "$@";;
    rhel)   (command -v dnf >/dev/null && dnf install -y "$@") || yum install -y "$@";;
  esac
}

ensure_basics(){
  pkg curl tar bash ca-certificates openssh-server sudo
  systemctl enable --now ssh >/dev/null 2>&1 || systemctl enable --now sshd >/dev/null 2>&1 || true
}

ensure_local_user(){
  id "$LOCAL_USER" &>/dev/null || useradd -m -s /bin/bash "$LOCAL_USER"
  echo "${LOCAL_USER}:${LOCAL_PASS}" | chpasswd || true
  install -d -m 700 -o "$LOCAL_USER" -g "$LOCAL_USER" "/home/${LOCAL_USER}/.ssh"
  if [ -n "${LOCAL_PUBKEY:-}" ]; then
    AUTH="/home/${LOCAL_USER}/.ssh/authorized_keys"
    touch "$AUTH"; chown "$LOCAL_USER:$LOCAL_USER" "$AUTH"; chmod 600 "$AUTH"
    grep -Fq "$LOCAL_PUBKEY" "$AUTH" || echo "$LOCAL_PUBKEY" >> "$AUTH"
  fi
  # SSHD: klucze + hasło ok
  for F in /etc/ssh/sshd_config /etc/ssh/sshd_config.d/00-jenkins.conf; do
    [ -f "$F" ] || touch "$F"
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' "$F"
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' "$F"
  done
  systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
}

ensure_docker(){
  [ "$INSTALL_DOCKER" = "yes" ] || { warn "Pomijam Docker"; return; }
  if ! command -v docker >/dev/null 2>&1; then
    log "Instaluję Docker"
    case "$OS_FAM" in
      debian) pkg docker.io ;;
      rhel)   pkg docker ;;
    esac
    systemctl enable --now docker
  fi
  usermod -aG docker "$LOCAL_USER" || true
}

ensure_sudoers(){
  SFILE="/etc/sudoers.d/${LOCAL_USER}-jenkins"
  cat >"$SFILE" <<EOF
${LOCAL_USER} ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/bin/systemctl, /usr/bin/apt-get, /usr/bin/dnf, /usr/bin/yum, /usr/bin/curl, /usr/bin/tar
EOF
  chmod 440 "$SFILE"
  visudo -cf "$SFILE" >/dev/null || die "Błąd w sudoers"
}

open_ufw(){
  if command -v ufw >/dev/null 2>&1; then
    IFS=',' read -r -a PORTS <<< "$OPEN_UFW_PORTS"
    for p in "${PORTS[@]}"; do ufw allow "$p"/tcp || true; done
    ufw status || true
  fi
}

ensure_java(){
  case "$OS_FAM" in
    debian) pkg "$JAVA_PKG_DEBIAN" ;;
    rhel)   pkg "$JAVA_PKG_RHEL" ;;
  esac
  su - "$LOCAL_USER" -c 'java -version' || true
}

# --- Jenkins API helpers ---
crumb(){
  curl -s -u "$JENKINS_USER:$JENKINS_API_TOKEN" "$JENKINS_URL/crumbIssuer/api/json" \
    | sed -n 's/.*"crumb"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
}

node_exists(){
  curl -s -o /dev/null -w '%{http_code}' -u "$JENKINS_USER:$JENKINS_API_TOKEN" \
    "$JENKINS_URL/computer/${NODE_NAME}/api/json" | grep -q '^200$'
}

create_node(){
  log "Tworzę noda ${NODE_NAME} (JNLP/inbound)…"
  local JSON payload http
  JSON=$(cat <<EOF
{
 "name": "${NODE_NAME}",
 "nodeDescription": "${NODE_DESC}",
 "numExecutors": "${NODE_EXECUTORS}",
 "remoteFS": "${REMOTE_FS}",
 "labelString": "${NODE_LABELS}",
 "mode": "NORMAL",
 "type": "hudson.slaves.DumbSlave$DescriptorImpl",
 "retentionStrategy": {"stapler-class": "hudson.slaves.RetentionStrategy$Always"},
 "nodeProperties": {"stapler-class-bag": "true"},
 "launcher": {"stapler-class":"hudson.slaves.JNLPLauncher","$class":"hudson.slaves.JNLPLauncher","webSocket":true}
}
EOF
)
  payload="json=$(python3 -c 'import json,sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read()))' <<<"$JSON" 2>/dev/null || ruby -rjson -e 'puts ERB::Util.url_encode(STDIN.read)' <<<"$JSON" 2>/dev/null || echo "$JSON")"
  local CR; CR=$(crumb || true)
  http=$(curl -s -o /dev/null -w '%{http_code}' -u "$JENKINS_USER:$JENKINS_API_TOKEN" \
    -H "Jenkins-Crumb: ${CR}" \
    -X POST "$JENKINS_URL/computer/doCreateItem?name=${NODE_NAME}&type=hudson.slaves.DumbSlave" \
    --data "$payload")
  [ "$http" = "200" -o "$http" = "302" ] || die "Create node HTTP $http (sprawdź uprawnienia/token/CSRF)"
}

get_secret(){
  # w nowszych: jenkins-agent.jnlp, w starszych: slave-agent.jnlp
  local JNLP http
  for path in "jenkins-agent.jnlp" "slave-agent.jnlp"; do
    http=$(curl -s -o /tmp/agent.jnlp -w '%{http_code}' -u "$JENKINS_USER:$JENKINS_API_TOKEN" \
      "$JENKINS_URL/computer/${NODE_NAME}/${path}")
    [ "$http" = "200" ] && break
  done
  [ "$http" = "200" ] || die "Nie pobrałem JNLP (HTTP $http)"
  # Secret jest drugim <argument> w JNLP
  sed -n 's:.*<argument>\([0-9a-f]\{32,\}\)</argument>.*:\1:p' /tmp/agent.jnlp | head -n1
}

install_service(){
  log "Instaluję agent.jar i service systemd…"
  install -d -m 755 -o "$LOCAL_USER" -g "$LOCAL_USER" "$REMOTE_FS"
  su - "$LOCAL_USER" -c "curl -fsSL '$JENKINS_URL/jnlpJars/agent.jar' -o '$REMOTE_FS/agent.jar'"

  local SECRET="$1"
  cat >/etc/systemd/system/jenkins-agent.service <<EOF
[Unit]
Description=Jenkins Inbound Agent (${NODE_NAME})
After=network.target

[Service]
User=${LOCAL_USER}
WorkingDirectory=${REMOTE_FS}
Environment=JENKINS_URL=${JENKINS_URL}
ExecStart=/usr/bin/java -jar ${REMOTE_FS}/agent.jar -url \${JENKINS_URL} -name ${NODE_NAME} -secret ${SECRET} -workDir ${REMOTE_FS} -webSocket
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now jenkins-agent
  systemctl status jenkins-agent --no-pager || true
}

main(){
  require_root
  detect_os
  ensure_basics
  ensure_local_user
  ensure_docker
  ensure_sudoers
  open_ufw
  ensure_java

  # Jenkins API: utwórz noda jeśli brak
  if node_exists; then
    log "Node ${NODE_NAME} już istnieje."
  else
    create_node
  fi

  # Pobierz SECRET z JNLP i zainstaluj usługę
  SECRET="$(get_secret)"
  [ -n "$SECRET" ] || die "Nie udało się wyciągnąć secretu z JNLP"
  log "Pobrany secret: (ukryty)"
  install_service "$SECRET"

  log "Gotowe ✅ — wejdź w Jenkins → Nodes → ${NODE_NAME} i sprawdź status (online)."
}

main "$@"
