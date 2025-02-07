---
title: Registry for custom image
---

## Хранение кастомных image

*Проблема!*
Есть кастомные image, который нужно предоставить k8s для развертывания на нодах приложения

*Задание со звездочкой*
Все должно работать через авторизацию к registry

*Решение!*
Готовое self-host решение для всего этого [Harbor registry](https://github.com/goharbor/harbor)

### Install Docker

```bash
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
```

### Get harbor installer

```bash
wget https://github.com/goharbor/harbor/releases/download/v2.12.1/harbor-online-installer-v2.12.1.tgz && \
tar xvzf harbor-online-installer-v2.12.1.tgz && \
rm -rf harbor-online-installer-v2.12.1.tgz && \
cd harbor
```

### Update ca policy

**Важно!!!**

Если сертификаты самоподписаные необходимо их добавить на каждую ноду кубера или в докер

#### Докер

```bash
mkdir -p /etc/docker/certs.d/yourdomain.com/
cp yourdomain.com.cert /etc/docker/certs.d/yourdomain.com/
cp yourdomain.com.crt /etc/docker/certs.d/yourdomain.com/
cp ca.crt /etc/docker/certs.d/yourdomain.com/
```

```bash
systemctl restart docker
```

#### Для кубера (containerd)

```bash
mkdir -p /etc/containerd/certs.d/yourdomain.com/
cp yourdomain.com.cert /etc/containerd/certs.d/yourdomain.com/
cp yourdomain.com.crt /etc/containerd/certs.d/yourdomain.com/
cp ca.crt /etc/containerd/certs.d/yourdomain.com/
```

In this [way](https://github.com/containerd/containerd/blob/main/docs/hosts.md), Kubernetes already has the credentials for specifically this [registry](https://stackoverflow.com/questions/72298729/how-to-pull-image-from-a-private-repository-using-containerd).

##### Modify the containerd conf

vim /etc/containerd/config.toml

```toml
  [plugins."io.containerd.grpc.v1.cri".registry]
     config_path = "/etc/containerd/certs.d"
```

##### Bypass TLS Verification Example

Add registry add [skip verify](https://github.com/containerd/containerd/blob/main/docs/hosts.md#bypass-tls-verification-example)

for example, if you add this:
vim /etc/containerd/certs.d/docker.io/hosts.toml

```toml
server = "https://registry-1.docker.io"

[host."http://192.168.31.250:5000"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
```

Afer restart containerd

```bash
systemctl restart containerd 
```

### Add custom registry

```bash
kubectl create secret generic homelab-harbor \
    --from-file=.dockerconfigjson=<path/to/.docker/config.json> \
    --type=kubernetes.io/dockerconfigjson
```

### Для любого хоста

For Ubuntu/Debian

```bash
sudo cp ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

For Centos/Fedora

```bash
sudo cp ca.crt /etc/pki/ca-trust/source/anchors/
sudo dnf -y install ca-certificates
sudo update-ca-trust
```

Show system cert

```bash
awk -v cmd='openssl x509 -noout -subject' '
    /BEGIN/{close(cmd)};{print | cmd}' < /etc/pki/tls/cert.pem | grep "RU"
```
