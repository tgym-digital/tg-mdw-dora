# Deployment su AWS ECS con EFS

Questo documento descrive come deployare l'applicazione Middleware su AWS ECS utilizzando EFS per la persistenza dei dati.

## Architettura

L'applicazione viene deployata su ECS Fargate con le seguenti caratteristiche:

- **ECS Cluster**: `utilities-cluster`
- **EFS**: File system condiviso per persistenza dati
- **ALB**: Application Load Balancer per il traffico HTTP
- **CloudWatch**: Logging centralizzato
- **Secrets Manager**: Gestione sicura delle password

### Volumi EFS

L'applicazione utilizza tre volumi EFS per la persistenza:

1. **PostgreSQL Data** (`/efs/postgres_data`): Database PostgreSQL
2. **Config Data** (`/efs/config`): File di configurazione
3. **Logs Data** (`/efs/logs`): Log dell'applicazione

## Prerequisiti

1. **AWS CLI** configurato con credenziali appropriate
2. **Terraform** (versione >= 1.0)
3. **Docker** installato localmente
4. **Account AWS** con permessi per:
   - ECS
   - ECR
   - EFS
   - ALB
   - IAM
   - CloudWatch
   - Secrets Manager

## Setup Iniziale

### 1. Configurazione Terraform

Copia il file di esempio delle variabili:

```bash
cp aws/terraform/terraform.tfvars.example aws/terraform/terraform.tfvars
```

Modifica `aws/terraform/terraform.tfvars` con i tuoi valori:

```hcl
aws_region = "eu-west-1"
vpc_id = "vpc-your-vpc-id"
private_subnet_ids = [
  "subnet-private-1",
  "subnet-private-2"
]
public_subnet_ids = [
  "subnet-public-1",
  "subnet-public-2"
]
db_password = "your-secure-password"
```

### 2. Deploy delle Infrastrutture

```bash
cd aws/terraform
terraform init
terraform plan
terraform apply
```

### 3. Configurazione GitHub Secrets

Aggiungi i seguenti secrets al tuo repository GitHub:

- `AWS_ACCESS_KEY_ID`: Access key AWS
- `AWS_SECRET_ACCESS_KEY`: Secret key AWS

## Build e Deploy

### Opzione 1: GitHub Actions (Automatico)

Il workflow GitHub Actions si attiva automaticamente su push alla branch `main`:

1. Build dell'immagine Docker
2. Push su ECR
3. Deploy su ECS

### Opzione 2: Manuale

#### Build e Push su ECR

```bash
# Sostituisci con il tuo Account ID AWS
./aws/scripts/build-and-push.sh eu-west-1 YOUR_ACCOUNT_ID
```

#### Deploy su ECS

```bash
# Aggiorna la task definition
aws ecs register-task-definition --cli-input-json file://aws/ecs-task-definition.json

# Aggiorna il service
aws ecs update-service --cluster utilities-cluster --service middleware-service --force-new-deployment
```

## Configurazione EFS

### Access Points

L'infrastruttura Terraform crea automaticamente tre access points EFS:

1. **postgres-data**: Per i dati PostgreSQL (UID/GID: 999)
2. **config-data**: Per le configurazioni (UID/GID: 1000)
3. **logs-data**: Per i log (UID/GID: 1000)

### Permessi

I permessi sono configurati automaticamente tramite IAM roles e security groups.

## Monitoraggio

### CloudWatch Logs

I log dell'applicazione sono disponibili in CloudWatch:

- Log Group: `/ecs/middleware`
- Retention: 30 giorni

### Health Checks

L'ALB esegue health checks su:
- Porta: 3333
- Path: `/`
- Interval: 30 secondi
- Timeout: 5 secondi

## Troubleshooting

### Problemi Comuni

1. **Container non si avvia**:
   - Verifica i log in CloudWatch
   - Controlla i permessi IAM
   - Verifica la configurazione EFS

2. **EFS non montato**:
   - Verifica i security groups
   - Controlla gli access points
   - Verifica i permessi IAM

3. **Database non si connette**:
   - Verifica la password in Secrets Manager
   - Controlla i log PostgreSQL

### Comandi Utili

```bash
# Verifica lo stato del service
aws ecs describe-services --cluster utilities-cluster --services middleware-service

# Visualizza i log
aws logs tail /ecs/middleware --follow

# Verifica i task in esecuzione
aws ecs list-tasks --cluster utilities-cluster --service-name middleware-service
```

## Sicurezza

### Encryption

- **EFS**: Crittografia in transito e a riposo
- **Secrets Manager**: Crittografia automatica delle password
- **ALB**: HTTPS (configurare certificato SSL)

### Network Security

- ECS tasks in subnet private
- ALB in subnet pubbliche
- Security groups configurati per minimo accesso necessario

## Scaling

### Auto Scaling

Per abilitare l'auto scaling:

```bash
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount \
  --resource-id service/utilities-cluster/middleware-service \
  --min-capacity 1 \
  --max-capacity 10
```

### Manual Scaling

```bash
aws ecs update-service \
  --cluster utilities-cluster \
  --service middleware-service \
  --desired-count 3
```

## Backup e Disaster Recovery

### EFS Backup

EFS supporta backup automatici. Per abilitarli:

```bash
aws efs update-file-system \
  --file-system-id fs-your-efs-id \
  --enable-automatic-backups
```

### Cross-Region Replication

Per replicazione cross-region, considera l'uso di:
- AWS DataSync per EFS
- RDS per PostgreSQL (se migrato)

## Costi

### Componenti Principali

- **ECS Fargate**: ~$0.04048 per vCPU-ora, ~$0.004445 per GB-ora
- **EFS**: ~$0.30 per GB-mese
- **ALB**: ~$16.20 per mese
- **CloudWatch**: ~$0.50 per GB di log

### Ottimizzazioni

1. **Ridurre le risorse ECS** se non necessarie
2. **Configurare retention log** appropriata
3. **Utilizzare Spot instances** per workload non critici

## Supporto

Per problemi o domande:
1. Controlla i log CloudWatch
2. Verifica la documentazione AWS
3. Contatta il team DevOps 