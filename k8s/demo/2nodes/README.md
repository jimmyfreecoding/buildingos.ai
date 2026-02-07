# 双节点 K8s 高可用部署方案 (BuildingOS Demo)

本方案旨在通过两台服务器（主节点 + 工作节点）构建一个具备高可用特性的 K8s 集群。

## 1. 架构亮点

*   **前端高可用 (Frontend HA)**: 部署双副本，通过 `podAntiAffinity` 强制分散在两个不同节点，任一节点宕机不影响访问。
*   **数据库高可用 (PostgreSQL HA)**: 采用 **CloudNativePG** 构建主从流复制集群，支持自动故障切换 (Failover)。
*   **消息队列高可用 (EMQX HA)**: 双节点集群模式，通过 K8s Headless Service 自动发现组网。
*   **有状态服务容灾 (Node-RED)**: 使用 **NFS 共享存储**，当主节点故障时，Pod 可在副节点重新挂载数据启动。

## 2. 部署文件说明

所有配置文件均位于 `/home/ubuntu/k8s/demo/2nodes` 目录下：

| 文件名 | 用途 |
| :--- | :--- |
| `infra.yaml` | 基础设施层：Frontend Init Job, PVC, Redis, EMQX (集群模式) |
| `apps.yaml` | 应用层：Frontend (双副本), Backend (连接 HA 数据库) |
| `addons.yaml` | 插件层：Node-RED (NFS存储), TDengine |
| `postgres-cluster.yaml` | 数据库层：CloudNativePG 集群定义 |
| `ingress.yaml` | 路由层：域名转发规则 |

## 3. 部署步骤

### 第一步：环境准备 (NFS 存储)

为了实现数据共享，我们需要在 **主机 (Master)** 上搭建 NFS 服务。

**在主机 (Node-A) 执行：**

```bash
# 1. 安装 NFS 服务
sudo apt-get update && sudo apt-get install -y nfs-kernel-server

# 2. 创建共享目录
sudo mkdir -p /srv/nfs/kubedata
sudo chown nobody:nogroup /srv/nfs/kubedata
sudo chmod 777 /srv/nfs/kubedata

# 3. 配置导出 (允许所有 IP 读写，生产环境请限制网段)
echo "/srv/nfs/kubedata *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee /etc/exports

# 4. 生效配置
sudo exportfs -rav
sudo systemctl restart nfs-kernel-server
```

### 第二步：部署 K8s 集群 (K3s)

**1. 初始化主机 (Master)**

```bash
# 安装 K3s Master
curl -sfL https://get.k3s.io | sh -

# 获取加入令牌 (Token)
sudo cat /var/lib/rancher/k3s/server/node-token
# 记下输出的 Token，后续称为 <TOKEN>
# 记下主机的内网 IP，后续称为 <MASTER_IP> (例如 10.4.4.140)
```

**2. 加入副机 (Worker)**

在 **副机 (Node-B)** 执行：

```bash
# 务必设置唯一的主机名，防止冲突
sudo hostnamectl set-hostname node-b

# 加入集群 (注意替换 IP 和 Token)
curl -sfL https://get.k3s.io | K3S_URL=https://<MASTER_IP>:6443 \
K3S_TOKEN=<TOKEN> \
sh -s - agent --node-name node-b
```

*验证：在主机执行 `sudo kubectl get nodes`，应看到两个节点均为 Ready 状态。*

### 第三步：部署系统组件

**在主机 (Node-A) 执行：**

1.  **安装 NFS Provisioner (自动创建存储卷)**
    ```bash
    # 添加 Helm 仓库并安装 (如果尚未安装 Helm，请先安装)
    helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
    helm install nfs-client nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
      --set nfs.server=<MASTER_IP> \
      --set nfs.path=/srv/nfs/kubedata \
      --set storageClass.name=nfs-client
    ```

2.  **安装 CloudNativePG Operator (数据库控制器)**
    ```bash
    sudo kubectl apply -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.22/releases/cnpg-1.22.1.yaml
    ```

### 第四步：部署应用

**在主机 (Node-A) 执行：**

```bash
cd /home/ubuntu/k8s/demo/2nodes

# 1. 创建命名空间和密钥
sudo kubectl create namespace buildingos-demo
sudo kubectl create secret generic postgres-ha-auth \
  --from-literal=username=buildingos \
  --from-literal=password=buildingos_prod_2024 \
  -n buildingos-demo

# 2. 依次应用配置
sudo kubectl apply -f infra.yaml
sudo kubectl apply -f postgres-cluster.yaml
sudo kubectl apply -f addons.yaml
sudo kubectl apply -f apps.yaml
sudo kubectl apply -f ingress.yaml
```

## 4. 验证高可用

1.  **查看 Pod 分布**：
    ```bash
    sudo kubectl get pods -n buildingos-demo -o wide
    ```
    *   应看到 `frontend` 和 `emqx` 的 Pod 分别运行在两个不同的节点上。
    *   `postgres-ha` 应有两个实例。

2.  **模拟故障**：
    *   尝试重启副机 (Node-B)，观察 Pod 是否会自动漂移或重新调度。
    *   由于配置了 NFS，Node-RED 的数据在漂移后依然保留。
