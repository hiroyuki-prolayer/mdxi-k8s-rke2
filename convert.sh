#!/bin/bash
set -euo pipefail

in="${1:-hosts.ini}"
out="${2:-wnodes.ini}"

awk '
  BEGIN { in_default = 0 }
  # セクション開始行
  /^\s*\[/ {
    in_default = ($0 ~ /^\s*\[default\]\s*$/) ? 1 : 0
    next
  }
  # defaultセクション内の有効行のみ処理（空行/コメント除外）
  in_default && $0 !~ /^\s*($|#|;)/ {
    line = $0
    first_ip = $1

    # hostnameから番号を取得
    num = ""
    if (match(line, /hostname=prolayer-worker-([0-9]{3})/, m)) {
      num = m[1]
    }

    # ethipv4 を取得（無ければ先頭カラム）
    ethip = ""
    if (match(line, /ethipv4=([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/, m2)) {
      ethip = m2[1]
    } else {
      ethip = first_ip
    }

    if (num != "") {
      printf("wnode%s ansible_host=%s node_ip=%s\n", num, ethip, ethip)
    }
  }
' "$in" > "$out"

