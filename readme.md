# Setup

This guide provides instructions for setting up the project for local development and includes key information for CI/CD pipelines.

## Prerequisites

Before you begin, ensure you have the following tools installed and configured:

-   [Git](https://git-scm.com/)
-   [Docker](https://www.docker.com/products/docker-desktop/) & Docker Compose V2
---

## Development

### Clone repositories

First, clone each required service into this root directory.

```bash
git clone git@github.com:sespesoft/<repository-name>.git
```

### Configure environment

The project uses a `.env` file for environment-specific variables. To create yours, copy the provided example file.

For Linux or macOS:

```bash
cp example.env .env
```

For Windows, you can copy the file manually. After copying, you may need to adjust the variables inside the .env file to match your local setup.

### Execute

To run all services, use the all profile:

```bash
docker compose --profile all up -d
```

To run a custom group of services instead of all of them, you must first assign a profile name to the desired services in their `profiles` section. This same profile name must also be added to the `_services/infrastructure/traefik.yml` file.

After making these changes, you can launch your custom profile with the following command:

```bash
docker compose --profile <your-profile-name> up -d
```
---

## Production

### Frontend assets

To modify the frontend assets used when deploying the project, you must include the build context within the pipeline configuration.

Use the `with` block to specify the `build-contexts` argument, pointing `assets` to the desired Git repository and subdirectory.

```yaml
with:
    push: true
    build-contexts: assets=https://github.com/sespesoft/lego.git#:_assets/caresoft
```


### Create keys

```bash
openssl genrsa -out priv_key.pem 2048
openssl rsa -in priv_key.pem -pubout -out pub_key.pem
```

_:warning: Never use sample keys in the `_configs` folder in production._

### Upload secrets and configs

```bash
docker secret create priv_key ./priv_key.pem
docker config create pub_key ./pub_key.pem
```
