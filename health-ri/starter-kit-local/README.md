# GDI Starter Kit Local Deployment

This document walks you through local deployment of dockerized starter kit components.

The setup consists of the following components:
- Mock LS-AAI - identity provider
- REMS - visas issuer
- Storage and Interfaces - data storage tool

**Table of content:**
 - [Installing SSL certificate](#Installing-SSL-certificate)
 - [Components configuration and deployment](#components-configuration-and-deployment)
      + [Mock LS-AAI configuration](#mock-ls-aai-configuration)
      + [REMS configuration](#rems-configuration)
      + [REMS deployment](#rems-deployment)
      + [Storage and interfaces configuration](#storage-and-interfaces-configuration)

## Deployment notes

### Installing SSL certificate

`download` component of `storage and interfaces` requires issuer endpoint to support HTTPS, that is why installation of 
an SSL certificate is a first and mandatory step. It can be done as described [here](../rems-deployment/deploying.md#install-nginx).

### Components configuration and deployment

Both `REMS` and `storage and interfaces` require mock `ls-aai` preconfigured and running and being connected
to `starter-kit-lsaai-mock_lsaaimock` network.

#### Mock LS-AAI configuration

1. Clone [Mock LS-AAI GDI git repository](https://github.com/GenomicDataInfrastructure/starter-kit-lsaai-mock).

LS AAI mock consists of two web applications:
- localhost:8080/oidc/ - the mock of the AAI which provides login and OpenID Connect provider functionality
- localhost:8080/ga4gh-broker/ - the mock of the LS AAI GA4GH Passport broker

OIDC configuration is an `application.properties` located under `<LS-AAI repo>/configuration/aai-mock/`.
Broker configuration is an `application.yaml` located under `<LS-AAI repo>/configuration/aai-mock/ga4gh-broker/`

2. Replace oidc issue link and web URL in `<LS-AAI repo>/configuration/aai-mock/application.properties` with relevant domain name e.g.:

```yaml
main.oidc.issuer.url=http://healthri-dev.westeurope.cloudapp.azure.com:8080/oidc/
web.baseURL=https://healthri-dev.westeurope.cloudapp.azure.com:8080/oidc
```
3. Configure `<LS-AAI repo>/configuration/aai-mock/ga4gh-broker/application.yaml`:

   3.1 Uncomment and configure passport repositories:
   
   ```yaml
   passport-repositories:
     # name does not act as an id, can be anything
     - name: REMS-LOCAL-API
       # rems endpoint for user permission info and jwk
       url: https://healthri-dev.westeurope.cloudapp.azure.com:3001/api/permissions/{user_id}?expired=false
       jwks: https://healthri-dev.westeurope.cloudapp.azure.com:3001/api/jwk
       headers:
         # rems api key and user id (preconfigured as per https://github.com/GenomicDataInfrastructure/starter-kit-rems#load-test-data)
         - header: x-rems-api-key
           value: qwedsa
         - header: x-rems-user-id
           value: robot
   ```
   3.2 Note, visas storage is not implemented so that part should stay commented or disabled.
   3.3 Enable passports

Broker configuration config is presented in [application.yaml file](application.yaml)

4. Change username in default user config to machine username (in our example `azureuser`)

User's configurations are stored under `<LS-AAI repo>/configuration/aai-mock/userinfos/`.
`s3` and `s3inbox` components of `storage and interfaces` requires username to match username of a user registered in ls-aai
but within `s3inbox` username is currently overwritten by machine username.

5. Provide configurations for clients.

In this example we need to register `storage and interfaces` as a regular client and `REMS` as broker client. 
Clients configuration should be placed under `<LS-AAI repo>/configuration/aai-mock/clients` and contain the following:

- Storage and interfaces client congig:
```yaml
client-name: "auth"
client-id: "XC56EL11xx"
client-secret: "wHPVQaYXmdDHg"
redirect-uris: ["http://aai-mock:8080/oidc-callback"]
token-endpoint-auth-method: "client_secret_basic"
scope: ["openid", "profile", "email", "ga4gh_passport_v1"]
grant-types: ["authorization_code"]
post-logout-redirect-uris: ["https://auth:8085/elixir/login"]
```

- REMS (broker) config:

```yaml
client-name: "GA4GH Broker"
client-id: "broker"
client-secret: "broker-secret"
redirect-uris: [https://healthri-dev.westeurope.cloudapp.azure.com:3001/oidc-callback]
token-endpoint-auth-method: "client_secret_basic"
scope: ["openid", "profile", "email", "ga4gh_passport_v1"]
grant-types: ["authorization_code"]
```

6. Make sure mysql volumes of `aai-db` and `broker-db` are not the same in `docker-compose.yml`, rename if they are.

7. Run mock ls-aai via
```shell
docker compose up -d
```
Please review [GDI mock LS-AAI documentation](https://github.com/GenomicDataInfrastructure/starter-kit-lsaai-mock/blob/main/README.md)
for additional information.

#### REMS configuration

To enable communication between docker containers add network configuration to all components and general section of `docker-compose.yml`:
```yaml
networks:
  lsaaimock:
  my-app-network:
    external: true
```
Change local ports for `rems_app` and `rems_db` so they are `3000:3000` and `5452:5432` respectively.

In `config.edn` provide/update the following parameters:
```yaml
# public REMS url
 :public-url "https://healthri-dev.westeurope.cloudapp.azure.com:3001/"
# configuration endpoint of mock ls-aai:
 :oidc-metadata-url "http://healthri-dev.westeurope.cloudapp.azure.com:8080/oidc/.well-known/openid-configuration"
# REMS client id and password as per registration in mock ls-aai
 :oidc-client-id "broker"
 :oidc-client-secret "broker-secret"
```
Overall REMS configuration is as the following:

- REMS [docker-compose.yaml file](docker-compose-rems.yml)
- REMS [config.edn file](config.edn) 

#### REMS deployment

Make sure REMS broker client is configured in mock `ls-aai` (see above).
Follow [instructions](https://github.com/GenomicDataInfrastructure/starter-kit-rems#create-a-jwk-pair-for-ga4gh-visas) to run and populate REMS.

#### Storage and interfaces configuration

1. Clone [GDI storage and interfaces repo](https://github.com/GenomicDataInfrastructure/starter-kit-storage-and-interfaces)

2. Edit .env file so `auth_ELIXIR_ID`, `auth_ELIXIR_PROVIDER` and `auth_ELIXIR_SECRET` are the same as registered in LS-AAI mock client config.
```yaml
auth_ELIXIR_ID=XC56EL11xx
auth_ELIXIR_PROVIDER=http://healthri-dev.westeurope.cloudapp.azure.com:8080/oidc/
auth_ELIXIR_SECRET=wHPVQaYXmdDHg
```
3. Remove `cacert` parameter from `<storage and interfaces repo>/config/config.yaml` and set url to LS-AAI configuration endpoint url:
```yaml
oidc:
  # oidc configuration API must have values for "userinfo_endpoint" and "jwks_uri"
  #cacert: "/shared/cert/ca.crt"
  configuration:
    url: "http://healthri-dev.westeurope.cloudapp.azure.com:8080/oidc/.well-known/openid-configuration"
  trusted:
    iss: "/iss.json"
```
4. Add the following pairs of issuer and jku to `<storage and interfaces repo>/config/iss.json`:

```json
{
        "iss": "https://healthri-dev.westeurope.cloudapp.azure.com:3001/",
        "jku": "https://healthri-dev.westeurope.cloudapp.azure.com:3001/api/jwk"
    },
    {
        "iss": "https://healthri-dev.westeurope.cloudapp.azure.com:3001/",
        "jku": "http://healthri-dev.westeurope.cloudapp.azure.com:8080/oidc/jwk"
    },
```
In the example the issuer should match REMS url.

5. Run storage and interfaces via
```shell
docker compose up -d
```

### Loading data

Loading data into storage and interfaces and creating a corresponding REMS catalog item is described in [Loading_data.md](Loading_data.md)
