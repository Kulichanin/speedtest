---
title: Vault
---

## Хранение секретов для переди в env контейнеров

*Проблема!*
Есть много данных, которые необходимо передать в вертуальное окружение для работы сервиса должным образом. Секреты хроняться сейчас в Secret k8s.

Все секреты должны быть переданы зарнее и если их большой список их надо автоматизировать в helm. Также не нравится что они храняться в base64 в деплое

Лучше изменить ширование и передавать их из единой точки хранения. [Подробнее](https://habr.com/ru/companies/slurm/articles/658123/)

*Решение!*
Для решения подходит [vault](https://www.vaultproject.io/) или [Helm Secrets](https://github.com/jkroepke/helm-secrets)

## Install

install of [programs74](https://blog.programs74.ru/how-to-install-vault-on-ubuntu-22-04/)

install of [dmosk](https://www.dmosk.ru/instruktions.php?object=vault-hashicorp)

### Before you start

You must have a valid Vault binary.

CentOS/RHEL

But this content is not currently
available in your region!

```bash
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo yum -y install vault
```

### Download binary file

```bash
wget https://releases.hashicorp.com/vault/1.18.3/vault_1.18.3_linux_amd64.zip
```

install of Manually [install a Vault binary](https://developer.hashicorp.com/vault/docs/install)

### Configure the environment

```bash
export VAULT_DATA=/opt/vault/data
export VAULT_CONFIG=/etc/vault.d
```

### Preparing binary file

```bash
sudo mv PATH/TO/VAULT/BINARY /usr/bin/
sudo setcap cap_ipc_lock=+ep $(readlink -f $(which vault))
```

### Create directory for vault

```bash
sudo mkdir -p ${VAULT_DATA}
sudo mkdir -p ${VAULT_CONFIG}
```

### Create user for vault

```bash
sudo useradd --system --home ${VAULT_DATA} --shell /sbin/nologin vault
sudo chown vault:vault ${VAULT_DATA}
sudo chmod -R 750 ${VAULT_DATA}
```

### Create a basic configuration file

```bash
sudo tee ${VAULT_CONFIG}/vault.hcl <<EOF
 ui            = true
 cluster_addr  = "http://127.0.0.1:8201"
 api_addr      = "https://127.0.0.1:8200"
 disable_mlock = true

 storage "raft" {
   path    = "${VAULT_DATA}"
   node_id = "127.0.0.1"
 }

 listener "tcp" {
   address       = "0.0.0.0:8200"
   cluster_address = "0.0.0.0:8201"
   tls_disable = 1
 }
EOF
```

Change ownership and permissions on the Vault configuration file.

```bash
sudo chown vault:vault "${VAULT_CONFIG}/vault.hcl" && \
sudo chmod 640 "${VAULT_CONFIG}/vault.hcl"
```

### For homelabe

Adding an option to skip certificate verification is a more acceptable option because The connection remains encrypted, but the certificate is not verified.

```bash
echo "VAULT_API_ADDR=https://127.0.0.1:8200" > /etc/vault.d/vault.env
echo "VAULT_API_SKIP_VERIFY=true" >> /etc/vault.d/vault.env
```

```bash
sudo chown vault:vault "${VAULT_CONFIG}/vault.env" && \
sudo chmod 640 "${VAULT_CONFIG}/vault.env"
```

### Run Vault as a service

Confirm the path to your Vault binary: `VAULT_BINARY=$(which vault)`

```bash
sudo tee /lib/systemd/system/vault.service <<EOF
[Unit]
Description="HashiCorp Vault"
Documentation="https://developer.hashicorp.com/vault/docs"
ConditionFileNotEmpty="${VAULT_CONFIG}/vault.hcl"

[Service]
User=vault
Group=vault
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=${VAULT_BINARY} server -config=${VAULT_CONFIG}/vault.hcl
ExecReload=/bin/kill --signal HUP
KillMode=process
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
EOF
```

Change permision

```bash
sudo chmod 644 /lib/systemd/system/vault.service
```

CentOS/RHEL install selinux policies

```bash
sudo sed -i "s/SELINUX=enforcing/SELINUX=permissive/" /etc/selinux/config
sudo setenforce 0
```

```bash
sudo systemctl daemon-reload
sudo systemctl start vault.service
sudo systemctl status vault.service
```

### Change permission firewall

Ubuntu/Debian

```bash
sudo iptables -I INPUT -p tcp --dport 8200 -j ACCEPT
```

CentOS/RHEL

```bash
sudo firewall-cmd --permanent --add-port=8200/tcp
sudo firewall-cmd --reload 
```

## Configuratioon server

### Sealed problem

После установки, сервер Vault находится в запечатанном (sealed) состоянии. То есть, он не знает, как ему расшифровывать секреты, которые будут храниться в базе.

При попытке выполнить любую операцию с хранилищем секретов мы получим ошибку: **Vault is sealed**

Теперь нам нужно инициировать Vault и создать мастер-ключ и секретное хранилище, для этого используется команда

```bash
vault operator init
```

**ВАЖНО!** Не вводите ключ в качестве аргумента команды vault operator unseal, т.к. он сохраниться в истории bash и это может очень негативно сказаться на безопасности!

**НЕ ДЕЛАЙТЕ ТАК!**

```bash
vault operator unseal 4v8A0s4aHJ9cyywmeKTJnTeS2liP3OYY/MQGPz0KGSv1
```

## Use secret

### Secret storage

Show list

```bash
vault secret list
```

Enable aws

```bash
vault secret enable -path=aws asw
```

Enable custom

```bash
vault secrets enable -path=my/path/ kv
```

### key/value

Write secret

```bash
vault kv put my/path key1=value1
```

Get secret

```bash
vault kv get my/path
```

Get secret json format

```bash
vault kv get -format=json /dev-secrets/creds
```

Delete secret

```bash
vault kv delete my/path
```

## Integration with Kubernetes

### Manage your Kubernetes secrets with Hashicorp Vault

Существует [3 способа](https://www.hashicorp.com/blog/kubernetes-vault-integration-via-sidecar-agent-injector-vs-csi-provider) интегрировать Vault в Kubernetes

#### Vault integration via Sidecar Agent Injector

Подробная информация настройки [тут](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-external-vault#deploy-application-with-hard-coded-vault-address)

Как пользоваться [тут](https://developer.hashicorp.com/vault/docs/platform/k8s/injector?_gl=1*13kpjcb*_gcl_au*MTkzMTk0NzM2NC4xNzM3Mzg2OTE2*_ga*OTA1MDgwODgzLjE3MzcxMjMwMjQ.*_ga_P7S46ZYEKW*MTczNzM4NjkxNi4xLjEuMTczNzM4NzU3OS41OS4wLjA.&product_intent=vault)

##### Install the Vault Helm chart configured to address an external Vault

Clone repo with vault helm

```bash
git clone https://github.com/hashicorp/vault-helm.git && cd vault-helm
```

Install the Vault Helm chart

```bash
helm install vault ./vault-helm  --set "global.externalVaultAddr=http://external-vault:8200"
```

Describe the **vault** service account.

```bash
kubectl describe serviceaccount vault
```

Create vault token

```bash
cat > vault-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: vault-token-change_name
  annotations:
    kubernetes.io/service-account.name: vault
type: kubernetes.io/service-account-token
EOF
```

```bash
kubectl apply -f vault-secret.yaml
```

Create a variable named VAULT_HELM_SECRET_NAME that stores the secret name.

```bash
VAULT_HELM_SECRET_NAME=$(kubectl get secrets --output=json | jq -r '.items[].metadata | select(.name|startswith("vault-token-")).name')
```

Describe the vault-token secret.

```bash
kubectl describe secret $VAULT_HELM_SECRET_NAME
```

##### Configure Kubernetes authentication

Enable the Kubernetes authentication method.

```bash
vault auth enable kubernetes
```

Get the JSON web token (JWT) from the secret.

```bash
TOKEN_REVIEW_JWT=$(kubectl get secret $VAULT_HELM_SECRET_NAME --output='go-template={{ .data.token }}' | base64 --decode)
```

Retrieve the Kubernetes CA certificate.

```bash
KUBE_CA_CERT=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode)
```

Retrieve the Kubernetes host URL.

```bash
KUBE_HOST=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.server}')
```

Configure the Kubernetes authentication method to use the service account token, the location of the Kubernetes host, its certificate, and its service account issuer name.

```bash
vault write auth/kubernetes/config \
     token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
     kubernetes_host="$KUBE_HOST" \
     kubernetes_ca_cert="$KUBE_CA_CERT" \
     issuer="https://kubernetes.default.svc.cluster.local"
```

###### Create policy for your app

Create a secret at path secret/speedtest/config with a DB_NAME, DB_PASSWORD and DB_USERNAME.

```bash
vault secrets enable -path=secret/speedtest kv
vault kv put secret/speedtest/config DB_NAME='speedtest_db' DB_USERNAME='speedtest' DB_PASSWORD='speedtest!'
```

Write out the policy named **speedtest** that enables the read capability for secrets at path **secret/speedtest/**

```bash
vault policy write speedtest - <<EOF
path "secret/speedtest/config" {
  capabilities = ["read"]
}
EOF
```

Create a Kubernetes authentication role named **speedtest**

```bash
vault write auth/kubernetes/role/speedtest \
     bound_service_account_names=vault \
     bound_service_account_namespaces=default \
     policies=speedtest \
     ttl=24h
```

The role connects the Kubernetes service account, **vault**, and namespace, **default**, with the Vault policy, **speedtest**. The tokens returned after authentication are valid for 24 hours.

###### Use secret with app in Kubernetes

Add metadata annotations

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx
      annotations:
        vault.hashicorp.com/agent-inject: 'true'
        vault.hashicorp.com/role: 'speedtest'
        vault.hashicorp.com/agent-inject-secret-config.env: 'secret/speedtest/config'
        vault.hashicorp.com/agent-inject-template-config.env: |
          {{- with secret "/secret/speedtest/config" }}
              {{- range $k, $v := .Data -}}
                  {{ $k | nindent 0}}={{ $v }}
              {{- end }}
          {{- end }}
    spec:
      serviceAccountName: vault
      containers:
      - name: nginx
        image: nginx
        resources:
          limits:
            memory: "128Mi"
            cpu: "500m"
        ports:
        - containerPort: 80
```

#### Vault integration via Vault CSI provider

Подробная доку [тут](https://developer.hashicorp.com/vault/docs/platform/k8s/csi?_gl=1*y0tmx3*_gcl_au*MTkzMTk0NzM2NC4xNzM3Mzg2OTE2*_ga*OTA1MDgwODgzLjE3MzcxMjMwMjQ.*_ga_P7S46ZYEKW*MTczNzM4NjkxNi4xLjEuMTczNzM4NzczOS42MC4wLjA.)

Как настраивать:

1. [Использование HashiCorp Vault для хранения секретов](https://yandex.cloud/ru/docs/managed-kubernetes/tutorials/marketplace/hashicorp-vault#kubernetes-authentication)
2. [Секреты в kubernetes используя Hashicorp Vault + External Secrets Operator](https://habr.com/ru/companies/rshb/articles/759816/)
3. [Manage your Kubernetes secrets with Hashicorp Vault](https://craftech.io/blog/manage-your-kubernetes-secrets-with-hashicorp-vault/)
4. [Configure Hashicorp's Vault for Kubernetes Auth](https://docs.armory.io/continuous-deployment/armory-admin/secrets/vault-k8s-configuration/)

#### Vault integration via Vault Secrets Operator

##### Configuration Vault

1. Enable the Kubernetes auth method.

```bash
vault auth enable -path vso kubernetes
```

2. Get env for kuber

Retrieve the Kubernetes CA certificate.

```bash
KUBE_CA_CERT=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode)
```

Retrieve the Kubernetes host URL.

```bash
KUBE_HOST=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.server}')
```

3. Configure the auth method.

```bash
vault write auth/vso/config \
    kubernetes_host="$KUBE_HOST" \
    kubernetes_ca_cert="$KUBE_CA_CERT"
```

The output should resemble the following:

```bash
Success! Data written to: auth/vso/config
```

4. Enable the kv v2 Secrets Engine

```bash
vault secrets enable -path=kvv2 kv-v2
```

5. Create a JSON file with a Vault policy.

```bash
tee vso.json <<EOF
path "kvv2/data/vso/config" {
  capabilities = ["read", "list"]
}
EOF
```

```bash
vault policy write vso vso.json
```

6. Create a role in Vault to enable access to secrets within the kv v2 secrets engine.

Change namespaces default for you namespace

```bash
vault write auth/vso/role/role1 \
  bound_service_account_names=vso \
  bound_service_account_namespaces=default \
  policies=vso \
  audience=vault \
  ttl=24h
```

The output should resemble the following:

```bash
Success! Data written to: auth/vso/role/role1
```

##### Install Vault Secrets Operator with helm

Clone [repository with VSO](https://github.com/hashicorp/vault-secrets-operator.git)

```bash
git clone https://github.com/hashicorp/vault-secrets-operator.git
```

Configuration `vault-secrets-operator/chart/values.yaml`

```yaml
/:567

defaultVaultConnection:
  enabled: true
  address: "http://ADDR:8200"
  skipTLSVerify: false
```

Install with helm

```bash
helm install vault-secrets-operator vault-secrets-operator/chart -n vault-secrets-operator-system --create-namespace -f vault-secrets-operator/chart/values.yaml
```

##### Set up Kubernetes authentication for the secret

Let's create resources for authorization and interaction with vault vault-auth-static.yaml

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  # SA bound to the VSO namespace for transit engine auth
  namespace: vault-secrets-operator-system
  name: vso-operator
---
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: default
  name: vso
---
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: vso-va
  namespace: default
spec:
  method: kubernetes
  mount: vso
  kubernetes:
    role: role1
    serviceAccount: vso
    audiences:
      - vault
```

Create the secret names secretkv in the default namespace.

static-secret.yaml

```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: vault-kv-vso
  namespace: default
spec:
  type: kv-v2

  # mount path
  mount: kvv2

  # path of the secret
  path: vso/config

  # dest k8s secret
  destination:
    name: secretkv
    create: true

  # static secret refresh interval
  refreshAfter: 30s

  # Name of the CRD to authenticate to Vault
  vaultAuthRef: vso-va
```

Подробная [дока](https://developer.hashicorp.com/vault/tutorials/kubernetes/vault-secrets-operator)

```bash
export VAULT_ADDR=http://ADDR:8200/
```
