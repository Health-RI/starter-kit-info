# I. REMS

To deploy REMS

- install java, configure postgresql (or use docker, explained below)
- download latest REMS
- configure .edn file
- populate with java postgres database (migrate)
- create resources (either manually or with script first_populating.sh)
- (optional) synchonize local node portal with rems - script parsing_user_portal.sh


## Basic info about REMS

- [REMS entire API](https://rems-demo.rahtiapp.fi/swagger-ui/index.html#/)
- [REMS web interface manual](https://github.com/CSCfi/rems/blob/master/manual/owner.md)
- [Starter kit REMS](https://github.com/GenomicDataInfrastructure/starter-kit-rems) - bottom of the site - REMS api curl calls
- 3 min of basics about [REMS web usage](https://www.youtube.com/watch?v=mDBrrg75alo&list=PLD5XtevzF3yEz1KpPVfDdQk3i44JgRr9t)
- [Script creating Rems starter kit test data](https://github.com/GenomicDataInfrastructure/starter-kit-rems/blob/main/test_data.sh)

## I. Deploying fresh REMS from java

- using Rocky linux 9 (Red Hat-based operating system)
- installing docker

   ```
      $ sudo dnf check-update
      $ sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      $ sudo dnf install docker-ce docker-ce-cli containerd.io
      $ sudo systemctl start docker
      $ sudo systemctl status docker
      $ sudo systemctl enable docker
      $ sudo usermod -aG docker $USER
      $ # logout (and clean ssh multiplextion connection) and login back to the node, so that user gets new ID
   ```
- install jq (needed later for parsin when creating forms)

  ```
      $ sudo dnf install -y jq lsof
  ```

- [Following main REMS instructions](https://github.com/CSCfi/rems)
- [REMS installation instructions](https://github.com/CSCfi/rems/blob/master/docs/installing-upgrading.md)
- get .jar from GitHub releases page > [https://github.com/CSCfi/rems/releases](https://github.com/CSCfi/rems/releases)
- download jar

  `$ curl -L -k https://github.com/CSCfi/rems/releases/download/v2.32/rems.jar -o rems_2.32.jar`

- download config.edn

  `$ curl -L -k -o config.edn https://raw.githubusercontent.com/CSCfi/rems/master/resources/config-defaults.edn`

- install java

  ```
      $ sudo dnf install java       # for rocky9
      $ sudo yum install java       # for centos7
  ```

- run postgres docker

  ```
      docker run -d --restart unless-stopped --name postgresdb -p 5455:5432 -e POSTGRES_USER=postgresUser \
      -e POSTGRES_PASSWORD=postgresPW -e POSTGRES_DB=postgresDB -d postgres
  ```

- install psql client

  ```
      sudo dnf install postgresql         # for rocky9
      sudo yum install postgresql         # for centos7
  ```

- REMS make OWNER - to get admin access

  ```
      export REMS_OWNER="7adc31a3f976d4f389f0610d46d5ba1ba0851157@elixir-europe.org"
      java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar grant-role owner $REMS_OWNER
  ```

- create `keys`

  ```
      pip install "Authlib>=1.2.0"
      mkdir keys
      curl -o keys/generate_jwks.py https://raw.githubusercontent.com/GenomicDataInfrastructure/starter-kit-rems/main/generate_jwks.py
      chmod +x keys/generate_jwks.py
      cd keys
      python generate_jwks.py
      cd ..
  ```

- configure settings
      - common settings

        ```
            ; :public-url "http://localhost:3000/"
            :public-url "https://rems-gdi-nl.molgenis.net/"
            :database-url "postgresql://localhost:5455/postgresDB?user=postgresUser&password=postgresPW"
            :authentication :oidc
            :languages [:en]
            ;; :search-index-path "/tmp/rems-search-index"
            ;;   ^ it will be autormatically generated in the folder where rems is run
            :catalogue-is-public true
            :enable-permissions-api true
            :ga4gh-visa-private-key "/admin/sandi/rems_2.32/keys/private-key.jwk"
            :ga4gh-visa-public-key "/admin/sandi/rems_2.32/keys/public-key.jwk"
            :enable-pdf-api true
            :enable-catalogue-tree true
            :catalogue-tree-show-matching-parents true
            :enable-autosave true
            :extra-pages-path "/admin/sandi/rems_2.32/extra-pages"}
            :mail-from "some@gmail.com"
            :smtp {:host "smtp.gmail.com" :user "some@gmail.com" :pass "somepassword" :port 587 :tls true}
            :theme {:color1 "#ccc"
            :color2 "#e6e6ff"
            :color3 "#1A3D75"
        ```
            - then either for `LS AAI` `Test group`

              ```
                  [sandi@local-lega-m rems_2.32]$ diff -y --suppress-common-lines config.default.edn config.edn
                  :oidc-metadata-url "https://login.elixir-czech.org/oidc/.well-known/openid-configuration"
                  :oidc-client-id "some-client-id-here"
                  :oidc-client-secret "some-secret-here"
              ```

            - or for Molgenis keycloak server
              ```
                  :oidc-metadata-url "https://auth1.molgenis.net/realms/Molgenis/.well-known/openid-configuration"
                  :oidc-client-id "molgenis-rems"
                  :oidc-client-secret "some-client-secret-here"
            ```
            - or for Molgenis fusionauth server
            ```
                  :oidc-metadata-url "https://auth.molgenis.org/.well-known/openid-configuration/e88a4e77-eb14-fd69-5fef-5c4b6cb2ea76"
                  :oidc-client-id "some-client-id-here"
                  :oidc-client-secret "some-client-secret-here"
            ```

- populate PosgreSQL database for REMS - use [migrate](https://github.com/CSCfi/rems/blob/master/docs/installing-upgrading.md)

  ```
      cd ~/rems_2.32/; java -Drems.config=config.edn -jar rems_2.32.jar migrate
  ```

- run REMS

  ```
      cd ~/rems_2.32/;
      java -Drems.config=config.edn -jar rems_2.32.jar run
      [ctrl]+[z]              # sleep the process
      bg                      # put in backgroud
      disown -h %1            # make it uninterruptable from current user's disconnect
  ```

- assign user as rems owner

      cd ~/rems_2.32/
      REMS_OWNER=7adc31a3f976d4f389f0610d46d5ba1ba0851157@elixir-europe.org
      # or if using keycloak
      REMS_OWNER=ba5ec9ea-b983-4365-9e32-2ab6626622fa
      API_KEY="some-api-key-here"
      cd ~/rems_2.32/; java -Drems.config=config.edn -jar rems_2.32.jar grant-role owner ${REMS_OWNER}
      cd ~/rems_2.32/; java -Drems.config=config.edn -jar rems_2.32.jar api-key add ${API_KEY}

- tested WORKING REMS API (examples taken from starter-kit)
      - create approver bot
      deprecated ... works, but better done in populating script
            ```
            curl -X POST http://localhost:3000/api/users/create \
            -H "content-type: application/json" \
            -H "x-rems-api-key: $API_KEY" \
            -H "x-rems-user-id: $REMS_OWNER" \
            -d '{
                  "userid": "approver-bot", "name": "Approver Bot", "email": null
            }'
            ```
      - create organization
            ```
            curl -s -X POST http://localhost:3000/api/organizations/create     -H "content-type: application/json"     -H "x-rems-api-key: $API_KEY"     -H "x-rems-user-id: $REMS_OWNER"     -d "{
                  \"organization/id\": \"${_organisation_id}\",
                  \"organization/short-name\": {
                  \"en\": \"${_organisation_short_name}\"
                  },
                  \"organization/name\": {
                  \"en\": \"${_organisation_name}\"
                  }
            }" | tr ',' '\n' | grep '"success":' | grep true
            ```
### REMS java options

- possible java options
      `migrate`
      `run`
      `api-key add <api-key>`
      `test-data`
      `grant-role <role> <userid>`

- Users don't usually need to be added manually as they are automatically created when logging in.


#### Populating REMS values (based on starter-kit)

1. create a bot to auto-approve applications
2. create an organisation which will hold all data
3. create a license for a resource
4. create a form for the dataset application process
5. create a workflow (DAC) to handle the application, here the auto-approve bot will handle it
6. create a resource for the dataset identifier
7. finally create a catalogue item, so that the dataset shows up on the main page

## Passports and Visas

Rems [VISAS](https://github.com/CSCfi/rems/blob/master/docs/ga4gh-visas.md)

- Getting permissions out of REMS
  - Getting the permissions in GA4GH passport format.
    > In a real deployment you would create a robot account, and an api key, and then register REMS as a visa provider in Life Science AAI. LS AAI would then provide REMS permissions in the ga4gh_passport_v1 claim in your third party service.
      Create a robot user and an api key

- Creating the "robot" (for reading visas) user and "portalbot" (for reading and creating resources and catalogues)

    ```
      curl -X POST http://localhost:3000/api/users/create \
      -H "content-type: application/json" \
      -H "x-rems-api-key: $API_KEY" \
      -H "x-rems-user-id: $REMS_OWNER" \
      -d '{
            "userid": "robot", "name": "Permission Robot", "email": null
      }'
      curl -X POST http://localhost:3000/api/users/create \
      -H "content-type: application/json" \
      -H "x-rems-api-key: $API_KEY" \
      -H "x-rems-user-id: $REMS_OWNER" \
      -d '{
            "userid": "portalbot", "name": "Portal Robot for reading and creating resources and catalogues", "email": null
      }'
    ```

- Grant the ROBOT the reporter role, so that it has privileges to get anyone's permissions, and then add an api key to the database and whitelist it so that only the robot can use it on the permission API

  ```
      cd ~/rems_2.32/;

      # Visas robot
      java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar grant-role reporter robot
      java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar api-key add ${PERMISSION_ROBOT_KEY} robot-key
      java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar api-key allow ${PERMISSION_ROBOT_KEY} get '/api/permissions/.*'
      java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar api-key set-users ${PERMISSION_ROBOT_KEY} robot

      # Resource and Catalogue robot
      java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar grant-role owner portalbot
      java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar api-key add ${PORTALBOT_KEY} portalbot-key
      java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar api-key allow ${PORTALBOT_KEY} any '/api/(catalogue|catalogue-items|resources)/.*'
      java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar api-key set-users ${PORTALBOT_KEY} portalbot

      # To list all the keys
      java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar api-key get

      # to list all the users (and bots)
      java -Drems.config=~/rems_2.32/config.edn -jar rems_2.32.jar list-users
  ```

- Using the ROBOT and API KEY to get Visas from the API

    ```
      export ELIXIR_ID=<your username here>
      curl http://localhost:3000/api/permissions/$ELIXIR_ID?expired=false \
      -H "content-type: application/json" \
      -H "x-rems-api-key: ${PERMISSION_ROBOT_KEY}" \
      -H "x-rems-user-id: robot"
    ```

ga4gh passport structure:

      base64.base64.base64
      header.payload.signature

to get the values out of raw format, you have to decrypt the ga4gh_passport_v1 - for that you can use the `base64 -d` command, but make sure you are taking care of padding

### Webinars

- [Part 1 - the overview](https://www.youtube.com/watch?v=l5Cu76NQyUY)
- [Part 2 - the technical deep dive](https://www.youtube.com/watch?v=K7HID5KAhz0)

by GA4GH see 23:50 for REMS implementation

Flow of Assertions

      https://ga4gh.github.io/data-security/aai-openid-connect-profile#flow-of-assertions

ELIXIR Webinar: Access to Sensitive Human Data with ELIXIR AAI (4 years ago)

      by ELIXIR Europe
      https://www.youtube.com/watch?v=4dGPU-S6xls

From https://ga4gh.github.io/data-security/aai-openid-connect-profile#term-passport

      Passport    A signed and verifiable JWT that contains Visas.
      Visa        A Visa encodes a Visa Assertion in compact and digitally signed format that can be passed as a URL-safe string value.
                  A Visa MUST be signed by a Visa Issuer. A Visa MAY be passed through various Brokers as needed while retaining the signature of the original Visa Issuer.
      JWT         JSON Web Token as defined in [RFC7519]. A JWT contains a set of Claims.
      visa1 (from EGA)        \
      visa1 (from dbGap)      --> Passport (with all 3 visas)
      visa1 (from LS RI)      /

What is a Broker

      https://github.com/ga4gh/data-security/blob/master/AAI/AAIConnectProfile.md#term-broker
      An OIDC Provider service that authenticates a user (potentially by relying on an Identity Provider), collects user's Visas from internal and/or external Visa Issuers, and provides them to Passport Clearinghouses.

Broker can be also the Visa Issuer

      https://github.com/ga4gh-duri/ga4gh-duri.github.io/blob/master/researcher_ids/ga4gh_passport_v1.md#overview


## Getting tokens from Keycloak

One way to extract tokens from the keycloak, but it depends on keycloak's implementation

Example with CURL providing Client ID + Client Secret + Username + Password

```
      curl -s -k -X POST https://auth1.molgenis.net/realms/Molgenis/protocol/openid-connect/token -d scope=openid -d response_type=id_token -d username="s.cimerman@umcg.nl" -d "password=mypassword" -d grant_type=client_credentials -d "client_id=molgenis-rems" -d "client_secret=some-client-secret-here"
```

### Configuring SSL certificate to REMS

**note: this was a dead end for me** - as I went for the alternative: having REMS behind a nginx proxy with certbot downloading and configuring a certificate.

- from [github issues](https://github.com/CSCfi/rems/issues/2844)

  ```
      Here are the relevant configs.

      NB: The keystore file path is relative to the working directory so an absolute path is perhaps the safe way to go.

      ;; HTTP server port.
      :port 3000 ; can be set to nil if only SSL is used

      ;; SSL configuration, if SSL is not terminated before
      :ssl-port nil ; no SSL by default
      :ssl-keystore nil ; Java keystore file
      :ssl-keystore-password nil ; (optional) password of key file

  ```

Additional info

- [Most Common Java Keytool Keystore](https://www.sslshopper.com/article-most-common-java-keytool-keystore-commands.html
- [Creating a self signed certificate with java keytool](https://www.sslshopper.com/article-how-to-create-a-self-signed-certificate-using-java-keytool.html)

  ```
      keytool -genkey -keyalg RSA -alias selfsigned -keystore keystore.jks -storepass password -validity 360 -keysize 2048
  ```

## II. Portal / Molgenis

### Structure Rems and Portal / Molgenis

      Molgenis      catalogue >   datasets >   distributions  > files
                                     ↑↓
      REMS          catalogue <   resource <   workflow       < form     < licenses < organization

## Molgenis / Portal Beacon commands

- [beacon](https://portal-gdi-nl.molgeniscloud.org/api/beacon)
- [beacon/info](https://portal-gdi-nl.molgeniscloud.org/api/beacon/info)
- [beacon/map](https://portal-gdi-nl.molgeniscloud.org/api/beacon/map)
- [beacon/entry_types](https://portal-gdi-nl.molgeniscloud.org/api/beacon/entry_types)
- [Molgenis beacon guide](https://molgenis.gitbook.io/molgenis/interoperability/guide-beacon)
- [Beacon v2 and Molgenis](https://portal-gdi-nl.molgeniscloud.org/PortalGDI/docs/#/molgenis/dev_beaconv2)
- [ga4gh beacon v2](https://github.com/ga4gh-beacon/beacon-v2/)
   - [specification](https://github.com/ga4gh-beacon/specification-v2)

## OS and services

### PostgreSQL in docker

```
      $ docker run --name postgresdb -p 5455:5432 -e POSTGRES_USER=postgresUser -e POSTGRES_PASSWORD=postgresPW -e POSTGRES_DB=postgresDB -d postgres
```

### Adding let's encrypt certificate

```
      $ sudo vi /etc/nginx/conf.d/gdi.conf
            server {
            listen       80;
            #server_name gdi.westeurope.cloudapp.azure.com;
            server_name rems-gdi-nl.molgenis.net

            location / {
                  proxy_pass http://127.0.0.1:3000;
            }
            }
      $ sudo certbot --nginx -d rems-gdi-nl.molgenis.net
```

### compress logging

All the services create a LARGE log files, so lets keep the things tidy

```
      vi /etc/logrotate.d/rsyslog
      after `sharedscripts` add `compress`
      vi /etc/logrotate.conf
      change `rotate 45` into `rotate 45`
      change `weekly` into `daily`
```

## Rems other

### Applying directly to resource access based on uniq ID number

Either linking to the item ID

      http://localhost:3000/application?items=30,32

or to the resource identifier

      http://localhost:3000//apply-for?resource=dataset0123&resource=anotherDataset&resource=...

### About REMS Bots

from the [REMS documentation about bots](https://github.com/CSCfi/rems/blob/master/docs/bots.md)

- Approver Bot

  > The approver bot approves applications automatically, unless a member of the application is blacklisted for an applied resource.

  Example of creating the bot user with the API:

  ```
      curl -X POST -H "content-type: application/json" -H "x-rems-api-key: 42" -H "x-rems-user-id: owner" http://localhost:3000/api/users/create --data '{"userid": "approver-bot", "name": "Approver Bot", "email": null}'
  ```

- Rejecter bot

  > The rejecter bot complements the approver bot. It rejects applications where a member is blacklisted for an applied resource. This can happen in three ways:
  >  - An applicant who is already blacklisted for a resource submits a new application for that resource. Rejecter bot rejects the application.
  >  - An approved application is revoked. This adds the applicant and the members to the blacklist for the applied resources. Rejecter bot then rejects any open applications these users have for the resources in question.
  >  - A user is added to a resource blacklist manually (via the administration UI or the API). Rejecter bot then rejects any open applications this user has for the resource in question.

  Example of creating the bot user with the API

  ```
      curl -X POST -H "content-type: application/json" -H "x-rems-api-key: 42" -H "x-rems-user-id: owner" http://localhost:3000/api/users/create --data '{"userid": "rejecter-bot", "name": "Rejecter Bot", "email": null}'
  ```
- Expirer bot

  > The Expirer bot is used to remove applications and send notification email to application members about impending expiration. Expirations can be configured by application state for both application removal and sending reminder email.
  > Unlike other bots, the Expirer bot is designed to be triggered by an external event, such as a periodically ran process.

  Example of creating the bot user with the API

  ```
      curl -X POST -H "content-type: application/json" -H "x-rems-api-key: 42" -H "x-rems-user-id: owner" http://localhost:3000/api/users/create --data '{"userid": "expirer-bot", "name": "Expirer Bot", "email": null}'
  ```
- Bona fide bot

  > When an application gets submitted for the catalogue item, the bot sends a decision request to the email address it extracts from the application.
  > Then the bot waits until the recipient of the request logs in to rems and performs the decide action. At this point:
  >
  > - If the decider has a ResearcherStatus visa (with "by": "so" or "by": "system", see from their IDP, ga4gh-visas.md):
  >
  >   -  and if the decider posted an approve decision: the bot approves the application
  >   -  and if the decider posted a reject decision: the bot rejects the application
  >
  > - If the decider doesn't have a ResearcherStatus visa, the bot rejects the application


## storage starter kit

load a very small sample dataset in the storage-and-interface repository

      https://github.com/GenomicDataInfrastructure/starter-kit-storage-and-interfaces/blob/main/scripts/load_data.sh

