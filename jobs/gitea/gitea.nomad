variables {
  data_dir = "/data"
  data_uid = 1000
  data_gid = 1000
}

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
        USER_UID = "${var.data_uid}"
        USER_GID = "${var.data_gid}"
        GITEA_CUSTOM = "/etc/gitea" #"${NOMAD_TASK_DIR}"
      }
      
      # Main data on csi volume
      volume_mount {
        volume      = "gitea"
        destination = "${var.data_dir}"
        read_only   = false
      }
            
      config {
        image        = "gitea/gitea:{{ gitea.vers }}"
        ports = ["http", "ssh"]
        volumes = [
          "local/app.ini:/etc/gitea/conf/app.ini",
        ]
        
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
      }

      template {
        # Template config
        destination = "local/app.ini"
        uid = "${var.data_uid}"
        gid = "${var.data_gid}"
        perms = "0600" # Gitea will change this anyway
        left_delimiter = "[%"
        right_delimiter = "%]"
        change_mode = "restart"
        data = <<EOH
APP_NAME = theta142
RUN_MODE = prod
RUN_USER = git

[security]
INSTALL_LOCK = true

[repository]
ROOT = /data/git/repositories

[repository.local]
LOCAL_COPY_PATH = /data/gitea/tmp/local-repo

[repository.upload]
TEMP_PATH = /data/gitea/uploads

[% with secret "secrets/data/gitea/secrets" %]
[server]
APP_DATA_PATH    = /data/gitea
DOMAIN           = git.{{ traefik.subdomain }}
SSH_DOMAIN       = git.{{ traefik.subdomain }}
HTTP_PORT        = 3000
ROOT_URL         = https://git.{{ traefik.subdomain }}/
DISABLE_SSH      = false
SSH_PORT         = 22
SSH_LISTEN_PORT  = 22
OFFLINE_MODE     = false

[security]
INSTALL_LOCK                  = true
SECRET_KEY                    =
REVERSE_PROXY_LIMIT           = 1      
REVERSE_PROXY_TRUSTED_PROXIES = *
INTERNAL_TOKEN                = [%- .Data.data.INTERNAL_TOKEN -%]
PASSWORD_HASH_ALGO            = pbkdf2
[% end %]
                                                              
[database]
DB_TYPE  = postgres
[% range service "db-gitea" %]
HOST     = [%- .Address -%]:[%- .Port -%]
[% end %]
NAME     = gitea
USER     = gitea
[% with secret "secrets/data/gitea/config" %]
PASSWD   = [%- .Data.data.DATABASE_PASS -%]
[% end %]
LOG_SQL  = false
SSL_MODE = disable

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
EOH
      }

      resources {
       cpu    = 100
       memory = 350
      }
    }
  }
  
  group "db-gitea" {
    count = 1

    network {
      port "db" { to = "5432" }
    }
  
    volume "db-gitea" {
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
      type            = "csi"
      read_only       = false
      source          = "db-gitea"
    }
  
    service  {
      name = "db-gitea"
      port = "db"
      
      check {
        type     = "tcp"
        port     = "db"
        interval = "60s"
        timeout  = "4s"
      }
    }

    task "db-gitea" {
      driver = "docker"
    
      env {
        PUID = 1000
        PGID = 1000
      }
    
      volume_mount {
        volume      = "db-gitea"
        destination = "/var/lib/postgresql/data"
        read_only   = false
      }
    
      config {
        image = "postgres:14"
        ports = ["db"]
      }
      
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
      
      vault {
        policies = ["gitea"]
        change_mode   = "restart"
      }
    
      template {
        destination = "secrets/file.env"
        env = true
        left_delimiter = "[%"
        right_delimiter = "%]"
        change_mode = "restart"
        data = <<EOH
[% with secret "secrets/data/gitea/config" %]
POSTGRES_DB=gitea
POSTGRES_USER=gitea
POSTGRES_PASSWORD=[% .Data.data.DATABASE_PASS %]
[% end %]
EOH
      }

      /*resources {
        cpu    = 200
        memory = 150
      }*/
    }
  }
}
