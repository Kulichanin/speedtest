---
title: Build app
---

## Сборка приложения с SBOM

SBOM (Software Bill of Materials) – это документ, который содержит полный перечень компонентов, библиотек и модулей, используемых в программном обеспечении. В контексте Docker, SBOM помогает отслеживать все зависимости и версии, используемые в контейнерных образах, что упрощает управление уязвимостями и соответствие нормативным требованиям.

Основные преимущества SBOM:

* Прозрачность: Предоставляет детальную информацию о том, что входит в состав ПО, что важно для безопасности и соответствия требованиям.
Управление уязвимостями: Помогает быстрее выявлять и устранять уязвимости, так как точно известно, какие компоненты подвержены рискам.
* Соответствие требованиям: SBOM помогает соблюдать стандарты и законы, связанные с безопасностью ПО, такие как стандарты NIST и директивы по безопасности цепочки поставок.
* Docker Scout может автоматически генерировать SBOM для образов, что значительно упрощает процесс управления безопасностью и отслеживания зависимостей в контейнерных средах.

Docker (docker driver) не поддерживает создание SBOM (Software Bill of Materials) через аттестации. Вам нужно использовать другой драйвер или включить использование хранилища изображений containerd.

### Сборка с генерацией sbom

Стандартный sbom

To use the latest release of BuildKit, create a [docker-container builder using buildx](https://docs.docker.com/build/builders/drivers/docker-container/):

```bash
docker buildx create --use --name=buildkit-container --driver=docker-container
```

```bash
docker buildx build --sbom=true --tag harbor-192-168-1-20.nip.io/speedtest/app:0.1  --attest type=sbom .
```

Использую кастомный [генератор](https://docs.docker.com/scout/how-tos/view-create-sboms/#attest) необходимо переклюситься на containerd

#### Переключение на containerd

Убедитесь, что Docker использует containerd как хранилище образов.

Добавьте следующую строку в файл конфигурации Docker (/etc/docker/daemon.json):

```json
{
  "features": {
    "containerd-snapshotter": true
  }
}
```

Перезапустите Docker:

```bash
sudo systemctl restart docker
```

Кастомный SBOM

```bash
docker build --tag harbor-192-168-1-20.nip.io/speedtest/app:sbom  --attest type=sbom,generator=docker/scout-sbom-indexer:latest .
```

### Test db connect

mysql connect

```bash
kubectl exec -it mysql-x-x -- mysql -u speedtest -ppass -h 127.0.0.1 speedtest_db  --execute="SHOW DATABASES;"
```

Show envirement

```bash
kubectl exec -it mysql-x-x -- printenv | grep "MYSQL"
```

### Сборка с генерацией sbom в registry

Иногда проще доверить Vulnerabilities и SBOM в private registry

```bash
docker build --tag harbor-192-168-1-20.nip.io/speedtest/app:vault --no-cache --push .
```

## Create deploy with helm

### Debug deploy

Get full deploy

```bash
helm template --debug speedtest ./
```

Get yaml template one element

```bash
helm template -s templates/deployment.yaml .
```

### Push deploy

```bash
helm install speedtest speedtest/
```
