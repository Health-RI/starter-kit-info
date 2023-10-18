# REMS at Health-RI

The following manual scripts let you to operational REMS deployment. I used an Azure VM with Ubuntu 22.06 and SKU Standard B2ms. Ensure that HTTPS endpoinnt is added to the firewall 

Consist of the following steps

<!-- toc -->

- [Set global variables](#set-global-variables)
- [Install prerequisites](#install-prerequisites)
  * [Install docker](#install-docker)
  * [Install jq for parsing jsons](#install-jq-for-parsing-jsons)
  * [Install certbot certificates and create java keystore](#install-certbot-certificates-and-create-java-keystore)
  * [Install postgress](#install-postgress)
    + [Pull and run postgres container](#pull-and-run-postgres-container)
    + [Install psql client](#install-psql-client)
    + [Test connection interactive. Non interactive must be investigated](#test-connection-interactive-non-interactive-must-be-investigated)
  * [Install Java](#install-java)
    + [Set JAVA path](#set-java-path)
  * [Install nginx](#install-nginx)
- [Install REMS](#install-rems)
  * [Get Config](#get-config)
  * [Keys for visa's](#keys-for-visas)
  * [App registration LSAAI](#app-registration-lsaai)
  * [SSL keystore](#ssl-keystore)
  * [Addjust further the config file](#addjust-further-the-config-file)

<!-- tocstop -->

## Set global variables

  ```
    VM_USER=azureuser
    LTS_REMS=2.33
    POSTGRES_USER=postgres
    POSTGRES_PASSWORD=postgresPW
    POSTGRES_DB=postgresDB
  ```


## Install prerequisites 

### Install docker 

```
    sudo apt-get update
    sudo apt install docker.io -y
    sudo service docker start
    sudo service docker status 
    sudo usermod -a -G docker ${VM_USER}
```

### Install jq for parsing jsons 

```
    sudo apt install -y jq
```

### Install certbot certificates and create java keystore 

```
certbot certonly --standalone --noninteractive --agree-tos --preferred-challenges http --email hanschristian.vanderwerf@health-ri.nl -d htsget.gdi-dev.health-ri.nl -d login.gdi-dev.health-ri.nl -d download.gdi-dev.health-ri.nl -d beacon.gdi-dev.health-ri.nl -d inbox.gdi-dev.health-ri.nl -d rems.gdi-dev.health-ri.nl --expand
```

For creating a java keystore I used https://keychest.net/stories/lets-encrypt-certificate-into-java-jks

I used in this example a simple pwd 1234
```
openssl pkcs12 -export -in /etc/letsencrypt/live/htsget.gdi-dev.health-ri.nl/fullchain.pem -inkey /etc/letsencrypt/live/htsget.gdi-dev.health-ri.nl/privkey.pem -out ./certs/rems.gdi-dev.health-ri.nl.p12 -name rems.gdi-dev.health-ri.nl
```
```
keytool -importkeystore -deststorepass health-ri.nl -destkeypass health-ri.nl -destkeystore rems.gdi-dev.health-ri.nl.keystore.jks -srckeystore server.p12 -srcstoretype PKCS12 -srcstorepass 1234 -alias rems.gdi-dev.health-ri.nl
```

### Install postgress 

#### Pull and run postgres container
```
docker pull postgres
docker run -d --restart unless-stopped --name postgresdb -p 5455:5432 -e POSTGRES_USER=${POSTGRES_USER} -e POSTGRES_PASSWORD=${POSTGRES_PASSWORD} -e POSTGRES_DB=${POSTGRES_DB} -d postgres
```
#### Install psql client 
```
sudo apt install postgresql-client
```
#### Test connection interactive. Non interactive must be investigated 
```
psql -h 127.0.0.1 -p 5455 -U ${POSTGRES_USER} -c 'select 1;' -d ${POSTGRES_DB} 
```


### Install Java 

```
sudo apt-get update
sudo apt install default-jre
```
#### Set JAVA path 

```
sudo nano /etc/environment
```

Paste the JAVA_HOME assignment at the bottom of the file, for example:
```
JAVA_HOME="/lib/jvm/java-11-openjdk-amd64/bin/java"
```

Save the and activate. To ensure that java can be found. 
```
source /etc/environment
```

### Install nginx
Nginx is needed as proxy to map the REMS to a specific endpoint port 443. 

```
sudo apt-get install python3-certbot-nginx
sudo apt install nginx
```

Create conf file 
```
sudo vi /etc/nginx/conf.d/gdi.conf
```
Add the following code snippet to this file
```
server {
      #server_name .westeurope.cloudapp.azure.com;
      server_name rems.gdi-dev.health-ri.nl;

      location / {
            proxy_pass http://127.0.0.1:3001;
      }
}
```


The config consist a mapping of port 80 to non ssl port of REMS. (I cannot get it work with the SSL of REMS itself, which makes use of the generated Java keystore file). 

Add SSL with following command.(Don't forget to restart the nginx server)
```
 sudo certbot --nginx -d rems.gdi-dev.health-ri.nl
```



## Install REMS 

Get the latest REMS LTS from REMS github REPO 
```
mkdir REMS
cd REMS/
curl -L https://github.com/CSCfi/rems/releases/download/v${LTS_REMS}/rems.jar -o rems_${LTS_REMS}.jar
```

### Get Config 

See an example config file of health-ri ([config.edn](./config.edn)) and place it next to the JAR file 
 

### Keys for visa's 

In the same folder of REMS run the next script

```
sudo apt install python3-pip
pip install "Authlib>=1.2.0"
mkdir keys
curl -o keys/generate_jwks.py https://raw.githubusercontent.com/GenomicDataInfrastructure/starter-kit-rems/main/generate_jwks.py
chmod +x keys/generate_jwks.py
cd keys
python3 generate_jwks.py
cd ..
```

### App registration LSAAI 

Authentication and Authorization Infrastructure (AAI). Initially, obtaining an account is the first step https://elixir-europe.org/platforms/compute/aai/service-providers. Subsequently, I proceeded to register our service. Please note that approval for this step may entail a waiting period. After approval you can e-mail to **support@aai.lifescience-ri.eu** for adding your REMS service as GA4GH Passports and Visas issuer/broker. Here is that https://rems.gdi-dev.health-ri.nl

Management of the app registration is done within: [LS AAI Services navigator](https://services.aai.lifescience-ri.eu/spreg/)

The LSAAI configuration looks for example 

```
Service name: REMS_GDI_NL_DEV
Description**: REMS DEV
Service homepage: https://www.health-ri.nl
Login url: https://rems.gdi-dev.health-ri.nl
Client ID: Received after registration
Client Secret: Received after registration
Flows service will use: authorization code
Token endpoint authentication type: client_secret_basic
PKCE type: SHA256 code challenge
Scopes the service will use: openid profile email
Allowed post logout redirect URLs: https://rems.gdi-dev.health-ri.nl
Issue refresh token logout: checked
```

After approvel by the LSAAI copy the required field to the OIDC fiels in the configuration

### SSL keystore

Set path in the confg file to the location of the JAVA keystore. Which is generated in the [Java key store generation step](#Install-certbot-certificates-and-create-java-keystore) AT THE MOMENT SSL BINDING DOES NOT WORK, THEREFORE WE FOLLOW STEPS AT [Install nginx](#Install-certbot-certificates-and-create-java-keystore) 

### Addjust further the config file ###

**public url**: url of your choice 
**database-url**: correct username and password from global variables



