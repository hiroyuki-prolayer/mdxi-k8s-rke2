# mdx I Kubernetes rke2-stack (Ansible)

RKE2 + Cilium + Ingress-NGINX + cert-manager(LE) + Rancher + Harbor + kube-prometheus-stack を
bastion から構築するためのリポジトリ。

## 前提
- SSH User: `mdxuser` / Key: `~/.ssh/mdx_ssh_key`（公開鍵: `~/.ssh/mdx_ssh_key.pub` を全ホストへ配布済み）
- Master: mnode 
- Workers: wnode001, wnode002, wnode003, wnode004, wnode005
- FQDN ベースドメイン: `ip-163-220-178-192.compute.mdx1.jp`
- Ingress 公開: wnode001, wnode002（hostPort 80/443）
- `machine-configs`の初回パスワード更新を指定ホストに対して一括で実施するPythonスクリプトセットを実行

## 使い方
```bash
cd rke2-stack
ansible-galaxy collection install -r collections/requirements.yml

# 0) 初期セットアップ（ホスト名・ベース設定・NTP）
ansible-playbook playbook/00_bootstrap.yml

# 1) master セットアップ
ansible-playbook-i inventory/hosts.ini playbook/10_rke2_server.yml

# 2) kubeconfig 書き替え
ansible-playbook -i inventory/hosts.ini playbook/11_fix_kubeconfig.yml

# 3) worker 参加
ansible-playbook-i inventory/hosts.ini playbook/12_rke2_workers.yml

# 4) Cilium 導入（bastion から）
ansible-playbook-i inventory/hosts.ini playbook/20_cilium.yml

# 5) Storage Class 導入
ansible-playbook-i inventory/hosts.ini playbook/21_storageclass.yml

# 6) Ingress-NGINX 導入（ラベル付与込み）
ansible-playbook-i inventory/hosts.ini playbook/30_ingress_nginx.yml

# 7) cert-manager + ClusterIssuer
ansible-playbook-i inventory/hosts.ini playbook/40_cert_manager.yml

# 8) Rancher
ansible-playbook-i inventory/hosts.ini playbook/50_rancher.yml

# 9) Harbor
ansible-playbook-i inventory/hosts.ini playbook/60_harbor.yml

# 10) Monitoring (Prometheus/Grafana/Alertmanager)
ansible-playbook-i inventory/hosts.ini playbook/70_monitoring.yml
```

### masterセットアップ後にbastionでkubectlを利用するための設定

`mnode` で生成された RKE2 の kubeconfig (`/etc/rancher/rke2/rke2.yaml`) を **bastion の `~/.kube/config`** にコピーして使う場合は、以下のようにする。

```bash
# bastion 側で実行
scp -i ~/.ssh/mdx_ssh_key mdxuser@mnode:/etc/rancher/rke2/rke2.yaml ~/.kube/config
```

その後、API サーバーのアドレスが `127.0.0.1` や `mnode` のローカル IP になっていることがあるので、bastion から疎通可能な **mnode の IP<mnode_ip>** に書き換える。

```bash
# kubeconfig 内の server: の部分を置換
sed -i 's/127.0.0.1/<mnode_ip>/' ~/.kube/config
```

### bastionからmnodeのtokenを取得する(`12_rke2_workers.yml`実行前)

```bash
ssh -i ~/.ssh/mdx_ssh_key mdxuser@mnode "sudo cat /var/lib/rancher/rke2/server/token"
```

この出力文字列を `group_vars/vault.yml` の `vault_rke2_token` に設定し、worker ノード追加時に使う。

### スケールアウト（wnode006..100 を inventory に追記後）:

`machin-configs/hosts.ini`から`inventory/hosts.ini`の`[new_workers]`に追加するノード情報を`convert.sh`を使って`wnodes.ini`に出力する。

```bash
./convert.sh ../machine-configs/hosts.ini ./wnodes.ini
```

`wnodes.ini`に出力された内容を`inventory/hosts.ini`の`[new_workers]`に転記する。

```bash
ansible-playbook-i inventory/hosts.ini playbook/scale-out-workers.yml
ansible-playbook-i inventory/hosts.ini playbook/20_cilium.yml
```

## 変更すべき値
- `group_vars/vault.yml` の `vault_rke2_token` と `vault_rancher_bootstrap` を **ansible-vault** で秘匿しつつ実値へ
- 必要に応じて `group_vars/all.yml` の `le_email`, `time_servers` を調整

## 注意
- Let’s Encrypt の HTTP-01 チャレンジは `ingress-nginx` 経由で 80/TCP が到達する必要あり
- ストレージはデフォルト `local-path`。本運用は Longhorn/Rook-Ceph 等の検討要
