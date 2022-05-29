job "gitea" {
  datacenters = ["{{ dc_name }}"]
  type        = "service"

  group "gitea" {
    count = 1

    network {
      port "http" { to = 3000 }
      port "ssh" { to = 22 }
    }
    
    volume "gitea" {
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
      type            = "csi"
      read_only       = false
      source          = "gitea"
    }

    service {
      name = "gitea"
      port = "http"
      
      tags = [
        "coredns.enabled",
        "coredns.alias=git",
        "traefik.enable=true",
        "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`git.{{ traefik.subdomain }}`)",
        "traefik.http.routers.${NOMAD_JOB_NAME}.entrypoints=websecure",
      ]
      
      meta {
        coredns-consul = "allow private"
      }

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "gitea" {
      driver = "docker"
      
      env {
        USER_UID = 1000
        USER_GID = 1000
        GITEA_CUSTOM = "${NOMAD_SECRETS_DIR}"
      }
      
      # Main data on csi volume
      volume_mount {
        volume      = "gitea"
        destination = "/data"
        read_only   = false
      }
            
      config {
        image        = "gitea/gitea:{{ gitea.vers }}"
        ports = ["http", "ssh"]
        
        mount {
          type = "bind"
          target = "/etc/timezone"
          source = "/etc/timezone"
          readonly = true
        }
        
        mount {
          type = "bind"
          target = "/etc/localtime"
          source = "/etc/localtime"
          readonly = true
        }
      }
      
      vault {
        policies = ["gitea"]
        change_mode   = "restart"
      }

      template {
        # Template config
        destination = "${NOMAD_SECRETS_DIR}/conf/app.ini"
        left_delimiter = "[%"
        right_delimiter = "%]"
        data = <<EOH
[% with secret "secrets/data/gitea/secrets" %]
APP_NAME = theta142
RUN_MODE = prod
RUN_USER = git

[repository]
ROOT = /data/git/repositories

[repository.local]
LOCAL_COPY_PATH = /data/gitea/tmp/local-repo

[repository.upload]
TEMP_PATH = /data/gitea/uploads

[server]
APP_DATA_PATH    = /data/gitea
DOMAIN           = git.{{ traefik.subdomain }}
SSH_DOMAIN       = git.{{ traefik.subdomain }}
HTTP_PORT        = 3000
ROOT_URL         = https://git.{{ traefik.subdomain }}/
DISABLE_SSH      = false
SSH_PORT         = 22
SSH_LISTEN_PORT  = 22
LFS_START_SERVER = true
LFS_CONTENT_PATH = /data/git/lfs
LFS_JWT_SECRET   = [% .Data.data.LFS_JWT_SECRET %]
OFFLINE_MODE     = false
                                                              
[database]
PATH     = /data/gitea/gitea.db
DB_TYPE  = sqlite3
HOST     = localhost:3306
NAME     = gitea
USER     = root
PASSWD   =                                                    
LOG_SQL  = false
SCHEMA   =
SSL_MODE = disable
CHARSET  = utf8

[indexer]
ISSUE_INDEXER_PATH = /data/gitea/indexers/issues.bleve

[session]                                                     
PROVIDER_CONFIG = /data/gitea/sessions
PROVIDER        = file

[picture]
AVATAR_UPLOAD_PATH            = /data/gitea/avatars
REPOSITORY_AVATAR_UPLOAD_PATH = /data/gitea/repo-avatars
DISABLE_GRAVATAR              = false
ENABLE_FEDERATED_AVATAR       = true

[attachment] 
PATH = /data/gitea/attachments

[log]
MODE      = console                                           
LEVEL     = info
ROUTER    = console
ROOT_PATH = /data/gitea/log

[security]
INSTALL_LOCK                  = true
SECRET_KEY                    =
REVERSE_PROXY_LIMIT           = 1      
REVERSE_PROXY_TRUSTED_PROXIES = *
INTERNAL_TOKEN                = [% .Data.data.INTERNAL_TOKEN %]
PASSWORD_HASH_ALGO            = pbkdf2

[service]
DISABLE_REGISTRATION              = false
REQUIRE_SIGNIN_VIEW               = false
REGISTER_EMAIL_CONFIRM            = false
ENABLE_NOTIFY_MAIL                = false
ALLOW_ONLY_EXTERNAL_REGISTRATION  = false
ENABLE_CAPTCHA                    = false
DEFAULT_KEEP_EMAIL_PRIVATE        = false
DEFAULT_ALLOW_CREATE_ORGANIZATION = true
DEFAULT_ENABLE_TIMETRACKING       = true
NO_REPLY_ADDRESS                  = noreply.localhost

[mailer]
ENABLED = false

[openid]
ENABLE_OPENID_SIGNIN = true
ENABLE_OPENID_SIGNUP = true
[% end %]
EOH
      }

      resources {
       cpu    = 100
       memory = 256
      }
    }
  }
}
