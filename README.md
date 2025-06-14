# Web Server Backend Repo

## Backups

### Source code backup

* This repo is used as the backup of all config and data of dockers
* wordpress sites are backuped by sub repo which is trated as submodules
  * `blog.libmuy.com` : `git@github.com:libmuy/websrv-backup-blog.git`
  * `english.libmuy.com` : `git@github.com:libmuy/websrv-backup-english.git`

### Database(MySQL) backup

* database's files are too big to backup directly.
* so that database is dumped by `other/scripts/backup/backup-mysql.sh`, stored at `other/backup`
* and can be restored with `other/scripts/backup/restore-mysql.sh.sh`

### SD card backup

RaspberryPi OS sd card should be backuped with below steps:
As umounting the backup target SD card is necessary
We needd to create a RaspberryPi OS sd card for backuping the real RaspberryPi OS sd card

1. Defragment File System
   1. connect the sd card with raspberry pi with USB card reader
   2. `sudo mount /dev/sdf2 /mnt`
   3. `sudo e4defrag /mnt`
   4. `sudo umount /mnt`
2. Zero Out Free Space
   1. `sudo apt-get install zerofree`
   2. `sudo zerofree -v /dev/sdf2`
3. Backup with macOS
   1. Connect SD card with macOS
   2. startup `Disk Utility`
   3. eject all partition of SD card
   4. right click the SD card drive
   5. select `Image from xxxxxx`
   6. select `Format` as `compressed`
   7. select a location and file name.


## Structure

all docker is managed by `docker compose`

```
├── conf                         # all config files
│   ├── mysql
│   ├── nginx
│   └── php.ini
├── data                         # all data files
│   ├── certbot                  # certbot data, a certificate update script in it.
│   ├── db                       # database(MySQL) files this is not managed by git, db is backuped by mysql dump
│   ├── html                     # htmls of sites, this is managed by this repo and git sub modules
│   └── letsencrypt              # https certificates 
├── docker-compose.yml           # docker-compose's config file
├── xxx.Dockerfile               # Dockerfiles referenced by docker-compose.yml
├── other
│   ├── backup                   # backups 
│   ├── old                      # not needed files
│   └── scripts                  # scripts
```

## git Repos


- [websrv](https://github.com/libmuy/websrv)
```
[websrv](https://github.com/libmuy/websrv)
│
│  submodule
├─────────────── [websrv-english(data/html/english.libmuy.com)](https://github.com/libmuy/websrv-english)
│                   │
│                   │  submodule
│                   ├──────────── [english-app-resource(app-resource)](https://github.com/libmuy/english-app-resource)
│                   │
│                   │  submodule
│                   └──────────── [english-app-backend(app-backend)](https://github.com/libmuy/english-app-backend)
│
│  submodule
└─────────────── [websrv-blog(data/html/blog.libmuy.com)](https://github.com/libmuy/websrv-blog)
```

- [english app github pages](https://github.com/libmuy/english-app-gh-pages)
- [english app flutter frontend](https://github.com/libmuy/english-app-frontend)
- [manage site contents](https://github.com/libmuy/site-manage)

## How to rebuild the server

### Restore RaspberryPi OS SD card

use balenaEtcher to restore the SD card(16GB)

### build the server environment

1. change `PATH_TO_APPDATA` in `.env` file to the root directory of this repo
2. update submodules: `git submodule update --init --recursive`
3. startup all containers: `docker-compose up -d`
4. restore database: `other/scripts/restore-mysql.sh.sh other/backup/all_databases_xxxx-xx-xx.sql.gz`
5. restart mysql container: `docker-compose restart mysql`
6. install php package
   1. go into container: `docker exec -it php bash`
   2. install php package in container: `composer install`

## Renew certificates

1. enable below comment in order to respond the `certbot`'s test content. and **disable 301 redirect line.**

   ```
   server {
      listen 80;
      listen [::]:80;
      server_name www.libmuy.com libmuy.com;

      location ^~ /.well-known/acme-challenge/ {
        root /var/www/html/www.libmuy.com;
      }
      location = /.well-known/acme-challenge/ {
        return 404;
      }

      # return 301 https://www.libmuy.com$request_uri;
   ...
   ```

   execute:
   ```bash
   docker exec -it nginx nginx -s reload
   ```

2. execute below command in certbot docker:
   1. start container
      ```bash
      docker compose up certbot -d
      ```
   2. enter docker with root user
      ```bash
      docker exec -it --user root certbot sh
      ```
   3. check if renew is ok with `--dry-run`
      ```bash
      certbot renew --dry-run
      ```
   4. do renew if no error occurs
      ```bash
      certbot renew
      ```

3. restore comment in step 1

   ```
   server {
      listen 80;
      listen [::]:80;
      server_name www.libmuy.com libmuy.com;


      # location ^~ /.well-known/acme-challenge/ {
      #   root /var/www/html/www.libmuy.com;
      # }
      # location = /.well-known/acme-challenge/ {
      #   return 404;
      # }

      return 301 https://www.libmuy.com$request_uri;
   ...
   ```

## Update resource to database

### prepare python execute environment

use ubuntu docker to execute python scripts which will update database.
create a venv after ubuntu container startup.
1. startup container and enter it

   ```bash
   docker-compose up ubuntu -d
   docker exec  -it ubuntu bash
   ```

2. create venv and install necessary libraries

   ```bash
   python3 -m venv venv
   . venv/bin/activate
   pip install python-dotenv
   pip install mysql-connector-python
   ```

### scripts

- `resource_master_update.py` 
  - recursively scan resource directory insert all category, course, episod into database
- `sentence_master_update_all.py` 
  - fetch all episods in db, and add all their sentences in files into db
  - this will remove all sentences before add sentences
- `sentence_master_update_one.py`
  - specify a episod path in argument 1, this script will add all its sentences in files into db
  - this will remove all sentences before add sentences
- `resource_master_clear.py` 
  - delete all data in `category_master`, `course_master`, `episod_master`

### database

- `category_master` : all category are here
- `course_master` : all course are here
- `episod_master` : all episod are here




## Memo

- SQL
   SQL to create database is stored in `other/scripts/resource_db/recreate_db.sql`
