# mdx I Kubernetes rke2-stack (Ansible)

RKE2 + Cilium + Ingress-NGINX + cert-manager(LE) + Rancher + Harbor + kube-prometheus-stack を
bastion から構築するためのリポジトリ。

## 前提
- SSH User: `mdxuser` / Key: `~/.ssh/mdx_ssh_key`（公開鍵: `~/.ssh/mdx_ssh_key.pub` を全ホストへ配布済み）
- Master: mnode (10.14.23.161)
- Workers: wnode001(10.14.21.101), wnode002(10.14.16.228), wnode003(10.14.17.111), wnode004(10.14.20.10), wnode005(10.14.23.9)
- FQDN ベースドメイン: `ip-163-220-178-192.compute.mdx1.jp`
- Ingress 公開: wnode001, wnode002（hostPort 80/443）

## 使い方
```bash
cd rke2-stack
ansible-galaxy collection install -r collections/requirements.yml

# 0) 初期セットアップ（ホスト名・ベース設定・NTP）
ansible-playbook playbook/00_bootstrap.yml

# 1) kubeconfig 書き替え
ansible-playbook -i inventory/hosts.ini playbook/09_fix_kubeconfig.yml

# 2) master セットアップ
ansible-playbook-i inventory/hosts.ini playbook/10_rke2_server.yml

# 3) worker 参加
ansible-playbook-i inventory/hosts.ini playbook/11_rke2_workers.yml

# 4) Cilium 導入（bastion から）
ansible-playbook-i inventory/hosts.ini playbook/20_cilium.yml

# 5) Ingress-NGINX 導入（ラベル付与込み）
ansible-playbook-i inventory/hosts.ini playbook/30_ingress_nginx.yml

# 6) cert-manager + ClusterIssuer
ansible-playbook-i inventory/hosts.ini playbook/40_cert_manager.yml

# 7) Rancher
ansible-playbook-i inventory/hosts.ini playbook/50_rancher.yml

# 8) Harbor
ansible-playbook-i inventory/hosts.ini playbook/60_harbor.yml

# 9) Monitoring (Prometheus/Grafana/Alertmanager)
ansible-playbook-i inventory/hosts.ini playbook/70_monitoring.yml
```

スケールアウト（wnode006..100 を inventory に追記後）:
```bash
ansible-playbook-i inventory/hosts.ini playbook/scale-out-workers.yml
```

## 変更すべき値
- `group_vars/vault.yml` の `vault_rke2_token` と `vault_rancher_bootstrap` を **ansible-vault** で秘匿しつつ実値へ
- 必要に応じて `group_vars/all.yml` の `le_email`, `time_servers` を調整

## 注意
- Let’s Encrypt の HTTP-01 チャレンジは `ingress-nginx` 経由で 80/TCP が到達する必要あり
- ストレージはデフォルト `local-path`。本運用は Longhorn/Rook-Ceph 等をご検討ください
