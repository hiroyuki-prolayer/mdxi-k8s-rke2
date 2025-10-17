# mdx I Kubernetes rke2-stack (Ansible)

RKE2 + Cilium + Ingress-NGINX + cert-manager(LE) + Rancher + Harbor + kube-prometheus-stack + Kueueを
bastion（K8sクラスターメンテナンス用VM） からAnsibleによって構築するためのリポジトリである。

## 前提
- SSH User: `mdxuser` / Key: `~/.ssh/mdx_ssh_key`（公開鍵: `~/.ssh/mdx_ssh_key.pub` を全ホストへ配布済み）
- Master Node: mnode 
- Workers Nodes: wnode001~wnode100
- FQDN ベースドメイン: Rancher `ip-163-220-178-192.compute.mdx1.jp` Harbor`ip-163-220-178-7.compute.mdx1.jp`
- Ingress 公開: wnode001, wnode002, wnode003（hostPort 80/443）
- `machine-configs`の初回パスワード更新を指定ホストに対して一括で実施するPythonスクリプトセットを実行
- Python仮想環境での作業を推奨

## 使い方
```bash
# Ansible Collectionファイルの準備
cd mdxi-k8s-rke2
ansible-galaxy collection install -r collections/requirements.yml

# 0) 初期セットアップ（ホスト名・ベース設定・NTP）
ansible-playbook -i inventory/hosts.ini playbook/00_bootstrap.yml

# 1) master セットアップ
ansible-playbook -i inventory/hosts.ini playbook/10_rke2_server.yml

# 2) kubeconfig 書き替え
ansible-playbook -i inventory/hosts.ini playbook/11_fix_kubeconfig.yml

# 3) worker 参加
ansible-playbook -i inventory/hosts.ini playbook/20_rke2_workers.yml

# 4) Cilium 導入（bastion から）
ansible-playbook -i inventory/hosts.ini playbook/30_cilium.yml

# 5) Storage Class 導入
ansible-playbook -i inventory/hosts.ini playbook/40_storageclass.yml

# 6) Ingress-NGINX 導入（ラベル付与込み）
ansible-playbook -i inventory/hosts.ini playbook/50_ingress_nginx.yml

# 7) cert-manager + ClusterIssuer
ansible-playbook -i inventory/hosts.ini playbook/51_cert_manager.yml

# 8) Rancher
ansible-playbook -i inventory/hosts.ini playbook/60_rancher.yml

# 9) Harbor
ansible-playbook -i inventory/hosts.ini playbook/61_harbor.yml

# 10) Monitoring (Prometheus/Grafana/Alertmanager) ※ Rancher上でもインストール可
ansible-playbook -i inventory/hosts.ini playbook/62_monitoring.yml

# 11) Kueue
ansible-playbook -i inventory/hosts.ini playbook/63_kueue.yml
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

### bastionからmnodeのtokenを取得する(`20_rke2_workers.yml`実行前)

```bash
ssh -i ~/.ssh/mdx_ssh_key mdxuser@mnode "sudo cat /var/lib/rancher/rke2/server/token"
```

この出力文字列を `group_vars/vault.yml` の `vault_rke2_token` に設定し、worker ノード追加時に使う。

## 変更すべき値
- `group_vars/vault.yml` の `vault_rke2_token` と `vault_rancher_bootstrap` を **ansible-vault** で秘匿しつつ実値へ
- 必要に応じて `group_vars/all.yml` の `le_email`, `time_servers` を調整

## 注意
- Let’s Encrypt の HTTP-01 チャレンジは `ingress-nginx` 経由で 80/TCP が到達する必要あり
- ストレージはデフォルト `local-path`。本運用は Longhorn/Rook-Ceph 等の検討要
