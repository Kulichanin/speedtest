---
title: ExternalIP and Ingress
---

## Внешние IP адреса для сервиса ExternalIP LoadBalancer

*Проблема!*
k8s в варианте self-host не умеют получать внешние ip для сервисов

*Решение!*
Для решения подходит [MetalLB](https://metallb.io/) с возможностью [bgp](https://habr.com/ru/articles/450814/)

Неплохой [howto](https://github.com/fireflycons/howto-install-metallb), также разбор в kube_13

### Install mettallb

You can achieve this by editing kube-proxy config in current cluster:

```bash
kubectl edit configmap -n kube-system kube-proxy
```

and set:

```yml
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  strictARP: true
```

#### Installation with Helm

```bash
helm repo add metallb https://metallb.github.io/metallb
helm install --namespace metallb-system --create-namespace metallb metallb/metallb
```

#### Config address poll and LoadBalancer IPs provided by the selected pools via L2

Configuration address pool

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: ippool-ns-service
  namespace: metallb-system
spec:
  addresses:
    - 192.168.1.90-192.168.1.110
```

Configuration Layer2 Advertisement which allows MetalLB to advertise the LoadBalancer IPs provided by the selected pools via L2

```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-pool
  namespace: metallb-system
spec:
  ipAddressPools:
  - ippool-ns-service
```

## Внешений ingress IP

*Проблема!*
Соотвествие dns имени и ip адресса

*Решение!*
Пока не понятно зачем, если dns у нас в локальной сети и нет

## Работа приложения

*Проблема!*
Приложение собрано под docker-compose

*Решение!*
Собрать приложение в один большой container APP(PHP+NGINX)

*Пример*
Пример с оф сайта деплоя [php with reddis](https://kubernetes.io/docs/tutorials/stateless-application/guestbook/)

База должна быть весть отдельно?
