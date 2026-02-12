# production-ready-server-with-ansible-
This repository provides a complete example of how to build and operate a production‑ready server on AWS using Infrastructure as Code (Terraform) and configuration management (Ansible). It provisions the network, compute, storage and monitoring infrastructure, configures an Ubuntu host with hardened SSH, firewall rules and fail2ban, installs Docker & Nginx, deploys a containerised application via Docker Compose, sets up scheduled database backups to S3 and implements health‑check/monitoring with alerts. Secrets are managed securely through Ansible Vault and Terraform modules encapsulate reusable infrastructure components.

## Overview
At a high level, the stack works as follows:
  * **Infrastructure provisioning (Terraform)** – The ```infra/``` folder contains a top‑level module (```infra.tf```) that orchestrates several sub‑modules. It creates an S3 bucket with a lifecycle policy for backups, builds a VPC with public subnets, launches an EC2 instance with a minimal IAM role and security group, and sets up monitoring resources such as CloudWatch log groups and SNS topics. For example, the ```backups_storage``` module provisions an S3 bucket and attaches an IAM role/policy allowing the EC2 instance to write objects. The ```servers``` module creates a security group allowing HTTP/HTTPS/SSH traffic and an EC2 instance that uses the instance profile from the backups module. The ```monitoring``` module defines SNS topics and a CloudWatch CPU utilization alarm that sends notifications via email and attaches the CloudWatchAgentServerPolicy to the EC2 role.
  * **Server bootstrap & configuration (Ansible)** – Playbooks in the project root coordinate several roles under ```roles/```. site.yml bootstraps the server by running the common, security, docker and nginx roles. ```deploy.yml``` deploys the application with the app role and reads secrets from an encrypted vault. ```backup.yml``` schedules database backups via the backup role. ```healtcheck.yml``` configures periodic health checks via the monitoring role.
  * **Application deployment** – The **app** role ensures the project directory exists and synchronises your local application source into the EC2 instance using ```ansible.builtin.synchronize```, excluding virtual‑env and Git artefacts. It renders a ```.env``` file from a template and triggers ```docker compose``` via a handler to build and run the container. After deployment, it waits for the ```/health``` endpoint on the HTTPS URL to return 200.
  * **System hardening & packages** – The common role updates and upgrades apt packages, sets the system timezone, creates a deploy user with sudo privileges and installs base packages such as ```curl```, ```ufw```, ```fail2ban``` and ```unzip```. The security role locks down SSH by installing an sshd drop‑in, disabling root/password logins, switching to a non‑default port and asserting that the daemon listens on that port. It also manages UFW to rate‑limit SSH and enable the firewall and configures fail2ban. Key‑based authentication is enforced and keys can be generated automatically.
  * **Docker & reverse proxy** – The **docker** role installs Docker Engine and the Compose plugin from the official repository and ensures the daemon is running with the deploy user added to the ```docker``` group. The nginx role installs Nginx, opens ports 80/443 in the firewall, serves a static site while the SSL certificate is obtained and later provides a reverse proxy that terminates TLS and forwards traffic to the Dockerised application. HTTPS is enabled with Let’s Encryptusing the ```geerlingguy.certbot``` role; once the certificate is present, a HTTPS‑specific configuration is deployed.
  * **Backups** – The **backup** role creates a scripts directory, installs a templated shell script (```backup.sh```) that uses ```pg_dump``` to dump a PostgreSQL database from the ```db``` container and uploads the compressed dump to the configured S3 bucket using the AWS CLI. It also installs a cron entry under ```/etc/cron.d/db-backup``` to schedule this script. The S3 bucket in Terraform enforces a lifecycle rule to expire backups after seven days.
  * **Monitoring & alerting** – The **monitoring** role installs the CloudWatch Agent, writes a JSON configuration that streams container logs to a CloudWatch log group and ensures the agent is running. It also deploys a health‑check script that inspects the database container’s health status and publishes alerts to an SNS topic via the AWS CLI when the database is unavailable or unhealthy. A cron job runs this script periodically. Terraform sets up SNS topics for CPU alarms and health‑check notifications and grants the EC2 role permission to publish to SNS. An alarm monitors EC2 CPU utilisation and triggers the CPU SNS topic when the average CPU usage exceeds 80 %.

## Project structure
```.
├── infra/            # Terraform configuration (top‑level and modules)
├── inventory/        # Ansible inventory and group variables
├── roles/            # Reusable Ansible roles (app, backup, common, docker, nginx, security, monitoring)
├── templates/        # Jinja2 templates for config files, cron jobs, CloudWatch agent, etc.
├── site.yml          # Playbook: bootstrap server with common, security, docker and nginx roles
├── deploy.yml        # Playbook: deploy application (uses encrypted secrets)
├── backup.yml        # Playbook: schedule database backups
├── healtcheck.yml    # Playbook: configure health check monitoring
├── vars/             # Non‑secret Ansible variables (e.g. user)
└── vault/            # Encrypted Ansible Vault file for secrets (DB credentials, etc.)
```

## ```infra/``` and Terraform modules
The top‑level ```infra/infra.tf``` file declares the AWS provider and instantiates four modules: ```backups_storage```, ```network```, ```servers``` and ```monitoring```. Each module lives under ```infra/modules``` and can be reused independently:
  * **backups_storage** – Creates an S3 bucket for database backups, attaches a lifecycle policy to expire backups after 7 days and defines an IAM role + instance profile that allows the EC2 instance to upload objects. Outputs the instance profile name and role name for consumption by other modules.
  * **network** – Uses the official ```terraform-aws-modules/vpc``` module to create a VPC, two public subnets and NAT gateway(s) from the provided CIDR. It exports the VPC ID and public subnet IDs.
  * **servers** – Creates a security group allowing ports 22/2222/80/443 and launches a single EC2 instance using the ```terraform-aws-modules/ec2-instance``` module with the provided AMI, key pair and instance type. The instance is associated with the IAM instance profile from the backups module.
  * **monitoring** – Defines SNS topics and subscriptions for CPU alarms and health‑check notifications, attaches policies to the EC2 role to allow publishing to SNS and reading CloudWatch, provisions a CloudWatch log group and a CPU utilisation alarm.

You can adjust variables such as ```bucket_name```, ```ami_id```, ```instance_type``` and ```key_name``` in ```infra/variables.tf``` before applying. Initialise and deploy the infrastructure with:
```.
cd infra
terraform init
terraform plan -out plan
terraform apply plan
```
Remember to set your AWS CLI profile or environment variables accordingly. The ```terraform.tfstate``` file should be stored securely (e.g. in an S3 backend) when used in production.

## ```inventory/``` and Ansible configuration
```inventory/inventory``` lists the hosts to manage (by default a ```dev``` group pointing to the EC2 instance). ```inventory/group_vars/dev.yml``` defines environment‑specific variables such as ```hostname```, ```timezone```, the HTTP domain, S3 bucket, SNS topic ARN and paths for scripts and logs. Secrets such as database credentials and API keys are stored in ```vault/secrets.yml```, which is encrypted with Ansible Vault. To view or edit these secrets use ```ansible-vault``` (e.g. ```ansible-vault edit vault/secrets.yml```).

## Running the Ansible playbooks
After provisioning the infrastructure, update ```inventory/inventory``` with the public IP of the EC2 instance (the ```ec2_public_ip ``` output of Terraform). Then run the playbooks in sequence:
```.
# Bootstrap the server (users, packages, security, docker, nginx)
ansible-playbook -i inventory/inventory site.yml

# Deploy the application (requires secrets and app source on your machine)
ansible-playbook -i inventory/inventory deploy.yml

# Configure backups (sets up backup.sh and cron job)
ansible-playbook -i inventory/inventory backup.yml

# Configure health monitoring (CloudWatch agent and DB health checks)
ansible-playbook -i inventory/inventory healtcheck.yml
```
The ```app``` role uses ```ansible.builtin.synchronize``` to copy your application source from your local machine (```src```) to the remote server. Update ```roles/app/tasks/build-up.yml``` to point to your actual project path. The ```.env``` file is generated from the app.env.j2 template and should contain environment variables required by your Docker Compose file. Once the app is running, the role polls ```https://<your-domain>.com/health``` until it returns 200.

## Backups and monitoring
Database backups are performed by a cron job installed by the **backup** role. The job executes ```backup.sh``` which dumps the PostgreSQL database from the ```db``` container and uploads the compressed dump to S3 via the AWS CLI. Backup frequency and log file locations can be customised via variables in ```inventory/group_vars/dev.yml```. S3 lifecycle rules expire backups older than seven days.

The **monitoring** role sets up two complementary monitoring mechanisms:
 1. **CloudWatch Agent** – Installs and configures the AWS CloudWatch Agent to ship container logs to a log group named ```/ec2/docker```. Logs can be viewed in the CloudWatch console. You can customise additional metrics or log files in ```templates/amazon-cloudwatch-agent.json.j2.```
 2. **Health‑check script** – Deploys ```healthcheck.sh``` and a cron job that monitors the health of the database container using Docker and publishes SNS alerts if the container is missing, starting or unhealthy. Email recipients for these alerts are configured via the ```email``` variable in ```infra/variables.tf``` and the ```TOPIC_ARN``` variable in group vars.

Terraform additionally defines a CPU utilization alarm that triggers an email notification when the EC2 instance’s average CPU usage exceeds 80 % for two consecutive periods.

## Security considerations
This project implements several best practices for securing a production server:
 * **Least‑privilege IAM roles** – The EC2 instance receives an IAM instance profile that allows it only to upload to the backup bucket and publish to SNS. The CloudWatch Agent policy is attached separately.
 * **SSH hardening** – Password authentication and root login are disabled; only public‑key authentication is allowed and the SSH daemon listens on a custom port. A firewall (UFW) rate‑limits SSH connections and is enabled by default.
 * **Fail2ban** – A custom jail is installed to block repeated authentication failures on the SSH service.
 * **Automatic updates** – The common role updates apt cache and upgrades packages. Additional tasks install and verify the AWS CLI to avoid packaging outdated versions.
 * **TLS termination** – Nginx is configured to terminate TLS using certificates from Let’s Encrypt (via the certbot role) and proxy traffic to the Dockerized application
 * **Secret management** – Sensitive variables (e.g. database credentials, API keys) are stored in an Ansible Vault (```vault/secrets.yml```). Never commit decrypted secrets to version control.

## Getting started quickly
 1. Clone this repository and download your application source code.
 2. Provision AWS infrastructure with Terraform (AWS CLI configured).
 3. Populate ```inventory/group_vars/dev.yml``` and ```vars/main.yml``` with your domain, bucket name, region, instance type, key pair name and email address. Encrypt sensitive data into ```vault/secrets.yml```.
 4. Run ```ansible-playbook``` commands in the order shown above.
 5. Verify that:
    * Your domain points to the EC2 instance and HTTPS works.
    * The application responds on ```/health```.
    * Cron jobs create backup files in the S3 bucket and logs appear in CloudWatch.
    * You receive email alerts for CPU spikes or database health issues.

Feel free to adapt and extend this blueprint to suit your specific application and team processes.

