Tools
=====

## Backup Scripts
Directory contains few backup scripts that I'm using for backing up applications.

Scripts only support linux and you have to have installed following packages:
- openssl
- curl 
- aws-amitools-ec2
 
### archive-budle.sh
The script supports archiving most of the Atlassian applications. Before running the  
script you need to substitue all **TODO:**

| TODO               | Description                                                            |
|--------------------|------------------------------------------------------------------------|
| ACCESS_KEY_ID      | aws access key id                                                      |
| SECRET_ACCESS_KEY  | aws secret access key id                                               |
| BUCKET_NAME        | aws add bucket name                                                    |
| BACKUP_LIST        | a list of directories to back up                                       |
| APP_BASE_DIR       | applications base directory e.g. /application/atlassian                |
| DB_USER            | database username to archive                                           |
| DB_PASS            | database password                                                      |
| BUNDLE_BASE_DIR    | a temporary directory where bundle is created /media/ephemeral0/backup |

Cron example:
```
# crontab -e
0 2 * * * /root/bin/archive-bundle -a confluence
0 2 * * * /root/bin/archive-bundle -a stash
```

### archive-youtrack.sh
The script archives YouTrack application. Before running the  
script you need to substitue all **TODO:**

| TODO              | Description                   |
|-------------------|-------------------------------|
| ACCESS_KEY_ID     | aws access key id             |
| SECRET_ACCESS_KEY | aws secret access key id      |
| BUCKET_NAME       | aws add bucket name           |
| BUNDLE_DIR        | a YouTrack's backup directory |

Cron example:
```
# crontab -e
0 2 * * * /root/bin/archive-youtrack
```