---
title: Efk stack
---

## Развертывание efk стака для логтрования кластера kubernetes

Согласно оф. документации команда elastic предлагает [Elastic Cloud on Kubernetes(ECK)](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-deploy-eck.html). Данный вариант предлагает максимальное эффективное управление изменениями кластера, как горизонтально так и вертикально

### Установка elastic

#### Подготовка кластера

Для установки необходимо скачать репозиторий [cloud-on-k8s](https://github.com/elastic/cloud-on-k8s.git)

```bash
git clone https://github.com/elastic/cloud-on-k8s.git
```

В виду локальных ограничений необходимо изменить репозиторий eck оператора `cloud-on-k8s/deploy/eck-operator/values.yaml`

```yaml
/:20
image:
  # repository is the container image prefixed by the registry name.
  repository: elastic/eck-operator
  # pullPolicy is the container image pull policy.
  pullPolicy: IfNotPresent
  # tag is the container image tag. If not defined, defaults to chart appVersion.
  tag: "2.16.1"
  # fips specifies whether the operator will use a FIPS compliant container image for its own StatefulSet image.
  # This setting does not apply to Elastic Stack applications images.
  # Can be combined with config.ubiOnly.
  fips: false

/:204
containerRegistry: docker.io
```

#### Установка eck оператора

Установка происходить с помощью helm в namespace elastic-system

```bash
helm install elastic-operator cloud-on-k8s/deploy/eck-operator -n elastic-system --create-namespace
```

Определить namespace elastic-system по умолчанию для удобства

```bash
kubectl config set-context --current --namespace=elastic-system
```

### Установка elastic+kibana

Установка происходит через kubectl и обращение к новым Role-based access contro(rbac)

Данный пример создает daemonset, который меняет [max_map_count](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-virtual-memory.html), после чего происходит установка кластера elasticsearch(3 ноды в режиме master и 3 ноды в режиме data). Также определен volumeClaimTemplates размером 1 гб и 5 гб в зависимости от роли.

В конце файла создается kibana c типом service LoadBalancer

elastic.yml

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: max-map-count-setter
  labels:
    k8s-app: max-map-count-setter
spec:
  selector:
    matchLabels:
      name: max-map-count-setter
  template:
    metadata:
      labels:
        name: max-map-count-setter
    spec:
      initContainers:
        - name: max-map-count-setter
          image: docker.io/bash:5.2.21
          resources:
            limits:
              cpu: 100m
              memory: 32Mi
          securityContext:
            privileged: true
            runAsUser: 0
          command: ['/usr/local/bin/bash', '-e', '-c', 'echo 262144 > /proc/sys/vm/max_map_count']
      containers:
        - name: sleep
          image: docker.io/bash:5.2.21
          command: ['sleep', 'infinity']
---
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: elastic-cluster
  namespace: elastic-system
spec:
  version: 8.17.1
  image: elastic/elasticsearch:8.17.1
  nodeSets:
  - name: master-nodes
    count: 3
    config:
      node.roles: ["master"]
    volumeClaimTemplates:
      - metadata:
          name: elasticsearch-data # Do not change this name unless you set up a volume mount for the data path.
        spec:
          accessModes:
          - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
          storageClassName: nfs-sc  
    podTemplate:
      spec:
        # This init container ensures that the max_map_count setting has been applied before starting Elasticsearch.
        # This is not required, but is encouraged when using the previous Daemonset to set max_map_count.
        # Do not use this if setting config.node.store.allow_mmap: false
        initContainers:
        - name: max-map-count-check
          command: ['sh', '-c', "while true; do mmc=$(cat /proc/sys/vm/max_map_count); if [ ${mmc} -eq 262144 ]; then exit 0; fi; sleep 1; done"]
  - name: data
    count: 3
    config:
      node.roles: ["data"]
    volumeClaimTemplates:
      - metadata:
          name: elasticsearch-data # Do not change this name unless you set up a volume mount for the data path.
        spec:
          accessModes:
          - ReadWriteOnce
          resources:
            requests:
              storage: 5Gi
          storageClassName: nfs-sc
---
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: elastic-cluster
  namespace: elastic-system
spec:
  version: 8.17.1
  image: kibana:8.17.1
  count: 1
  elasticsearchRef:
    name: elastic-cluster
    namespace: elastic-system
  http:
    service:
      spec:
        type: LoadBalancer
```

Применим файл

```bash
kubectl apply -f elastic.yml
```

#### Проверка работы elastic

Получим пароль из соответствующего секрета

```bash
kubectl get secrets elastic-cluster-es-elastic-user -o json | jq -r .data.elastic | base64 -d
```

Прокинем порт для работы обращение через localhost

```bash
kubectl port-forward service/elastic-cluster-es-http 9200
```

В отдельном окне обратимся к сервису

```bash
curl https://localhost:9200 -u elastic:PASSWORD -k
```

### Установка fluent-bit

#### Подготовка к установке

Для установки необходимо скачать репозиторий c помощью helm

```bash
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update
helm pull fluent/fluent-bit --untar
```

Изменить данные в файле `./fluent-bit/values.yaml` для подлючения к кластеру elasticsearch

```yaml
:/315

env:
- name: ELASTICSEARCH_PASSWORD
    valueFrom:
      secretKeyRef:
        name: elastic-cluster-es-elastic-user
        key: elastic

:/419

  outputs: |
    [OUTPUT]
        Name es
        Match kube.*
        Host elastic-cluster-es-http  
        Logstash_Format On
        Logstash_Prefix kube
        Retry_Limit False
        Suppress_Type_Name On
        Buffer_Size 1Mb
        http_user elastic
        http_passwd ${ELASTICSEARCH_PASSWORD}
        tls on
        tls.debug 4
        tls.verify on
        tls.ca_file /opt/certs/es.ca
        tls.crt_file /opt/certs/es.crt
        tls.key_file /opt/certs/es.key

    [OUTPUT]
        Name es
        Match host.*
        Host elastic-cluster-es-http
        Logstash_Format On
        Logstash_Prefix node
        Retry_Limit False
        Suppress_Type_Name On
        Buffer_Size 1Mb
        http_user elastic
        http_passwd ${ELASTICSEARCH_PASSWORD}
        tls on
        tls.debug 4
        tls.verify on
        tls.ca_file /opt/certs/es.ca
        tls.crt_file /opt/certs/es.crt 
        tls.key_file /opt/certs/es.key 
```

#### Установка

Установка с корректной конфигурацией

```bash
helm install fluent-bit -n elastic-system ./fluent-bit/ -f fluent-bit/values.yaml
```

После успешного развертывания можем зайти в kibana и убедиться в получение данных
