---
title: Storage data
---

## Хранение данных

**Проблема!**

Приложению нужно отдать статику вебсерву caddy

*Решение!*

Развернуть [nfs сервер](https://www.howtoforge.com/how-to-install-nfs-server-and-client-on-almalinux-9/)

### Настройка nfs сервера

Для Ubuntu/Debian:

```bash
sudo apt update
sudo apt install nfs-kernel-server
```

Для CentOS/RHEL:

```bash
sudo dnf install nfs-utils
```

#### Создание каталога для экспорта

Выберите или создайте каталог, который будет экспортироваться клиентам.

```bash
sudo mkdir -p /data/shared
sudo chmod 777 /data/shared
```

#### Настройка экспорта

Отредактируйте файл /etc/exports, чтобы указать, какие каталоги экспортировать и какие права предоставлять.

Пример строки в /etc/exports:

```conf
/srv/nfs/shared 192.168.1.0/24(rw,sync,no_subtree_check)
```

/srv/nfs/shared — каталог для экспорта.
192.168.1.0/24 — подсеть, которой разрешен доступ.

Параметры:
rw — разрешение на чтение и запись.
sync — синхронизация записи на диск (безопаснее).
no_subtree_check — отключение проверки подпапок (повышает производительность).
После изменения файла примените настройки:

```bash
sudo exportfs -ra
```

#### Запуск и включение службы NFS

Запустите службу NFS и настройте её автозапуск:

Для Ubuntu/Debian:

```bash
sudo systemctl start nfs
sudo systemctl enable nfs
```

Для CentOS/RHEL:

```bash
sudo systemctl start nfs-server
sudo systemctl enable nfs-server
```

#### Настройка брандмауэра

Убедитесь, что порты NFS открыты:

NFS использует порты: 2049 (TCP/UDP), 111 (для RPC).
Для настройки брандмауэра:

Для UFW (Ubuntu/Debian):

```bash
sudo ufw allow from 192.168.1.0/24 to any port nfs
```

Для Firewalld (CentOS/RHEL):

```bash
sudo firewall-cmd --permanent --add-service=nfs
sudo firewall-cmd --reload
```

#### Проверка экспорта

Проверьте список экспортируемых каталогов:

```bash
sudo exportfs -v
```

Теперь ваш NFS-сервер готов к использованию! Если что-то не работает, проверьте журналы:

```bash
sudo journalctl -xe
```

### Настройка клиента (на другой машине)

Важно!

Обратить внимание, что для монтирования nfs на нодах k8s должен быть установлен пакет **nfs-common**.

Также необходим nfs provisioner

[On CentOS/RHEL]

```bash
dnf install nfs-utils nfs4-acl-tools 
```

[On Debian/Ubuntu]

```bash
apt install nfs-common nfs4-acl-tools 
```

Папку которую нужно смонтировать вы можете получить командой

```bash
showmount -e адрес_nfs_сервера
```

Смонтируйте удалённый каталог если требуется

```bash
sudo mount 192.168.1.10:/srv/nfs/shared /mnt
```

(где 192.168.1.10 — IP-адрес NFS-сервера, /mnt — точка монтирования на клиенте).
Для автоматического монтирования добавьте запись в /etc/fstab:
plaintext

```fstab
192.168.1.10:/srv/nfs/shared /mnt nfs defaults 0 0
```

### Настройка nfs kuber

To note [copy](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner?tab=readme-ov-file#how-to-deploy-nfs-subdir-external-provisioner-to-your-cluster), you must already have an NFS Server.

#### With Helm

```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install --namespace nfs-provisioner --create-namespace nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server=x.x.x.x \
    --set nfs.path=/exported/path 
```

### Connecting nfs storage to deployment

Let's create PVC for data storage using sc.

```yml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: pvc-app
spec:
  storageClassName: nfs-client
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
```

Use it to connect to the container

```yml
spec:      
  volumes:
  - name: static-app
    persistentVolumeClaim:
      claimName: pvc-app  
  containers:
  - name: speedtest
    image: harbor.nip.io/speedtest/app:0.1 
    volumeMounts:
      - name: static-app
        mountPath: /var/www/html
```

Warning! For database use [securityContext](https://github.com/docker-library/mysql/issues/647) other error create container: *cannot create directory '/var/lib/mysql/': File exists*

```yml
securityContext:
  runAsUser: 999
  fsGroup: 999
```

### Using configmaps for webserver settings

Let's create configmaps from the caddy config

```bash
kubectl create configmap caddyconfigmap --from-file=.infra/caddy/Caddyfile
kubectl create configmap servers-list --from-file=servers.json
```
