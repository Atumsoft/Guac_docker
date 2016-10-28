# docker-compose-guacamole

The 10/13/16 update introduced the ability to have persistant databases so user and machine settings are saved between restarts. This means that we need to do a proper removal process when testing new builds.

NEW INSTALLATION

run

```bash
docker-compose up -d
```

Then go to `http://DOCKER_HOST:8080/atumate/` or whatever the .war files are named.

Log in as user: `guacadmin` and password: `guacadmin`, or any other user in the SQL file.



REBOOTING EXISTING INSTALLATION

Open docker-compose.yml

comment out the following line and save

```bash
- ./init:/docker-entrypoint-initdb.d
```

run

```bash
docker-compose up -d
```

Then go to `http://DOCKER_HOST:8080/atumate/` or whatever the .war files are named.



REMOVING EXISTING INSTALLATION

If currently running run
```bash
^C
docker-compose down
rm -rf ./data
```

Open docker-compose.yml

uncomment out the following line and save

```bash
- ./init:/docker-entrypoint-initdb.d
```




