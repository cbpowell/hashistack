job "teslamate" {
  datacenters = ["{{ dc_name }}"]
  type        = "service"

  group "teslamate" {
    count = 1

    network {
      port "http" { to = "4000" }
    }
    
    service  {
      name = "teslamate"
      port = "http"
      
      tags = [
        "traefik.enable=true",
        "coredns.enabled",
        "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`teslamate.{{ net_subdomain }}`)",
        "traefik.http.routers.${NOMAD_JOB_NAME}.entryPoints=websecure",
      ]
      
      meta {
        coredns-consul = "allow private"
      }

      check {
        type     = "http"
        path     = "/"
        interval = "120s"
        timeout  = "5s"
      }
    }

    task "teslamate" {
      driver = "docker"
      
      env {
        MQTT_HOST = "{{ teslamate.mqtt_server }}"
        #DATABASE_HOST = "{{ teslamate.db_server }}"
      }
      
      config {
        image = "teslamate/teslamate:{{ teslamate.vers }}"
        ports = ["http"]
        cap_drop = ["all"]
      }
      
      vault {
        policies = ["service-teslamate"]
      }
      
      template {
        destination = "local/env.txt"
        left_delimiter = "[%"
        right_delimiter = "%]"
        change_mode = "restart"
        env         = true
        data = <<EOH
[% range service "teslamate-db" %]
DATABASE_HOST = [% .Address %]
DATABASE_PORT = [% .Port %]
TEST_DBA_PORT = 77777
[% end %]
EOH
      }
      
      template {
        destination = "secrets/file.env"
        env = true
        left_delimiter = "[%"
        right_delimiter = "%]"
        change_mode = "restart"
        # read multiple secrets from Vault
        data = <<EOH
[% with secret "secrets/data/teslamate/encryption" %]
ENCRYPTION_KEY=[% .Data.data.ENCRYPTION_KEY %]
[% end %]

[% with secret "secrets/data/teslamate/config" %]
DATABASE_NAME=[% .Data.data.DATABASE_NAME %]
DATABASE_USER=[% .Data.data.DATABASE_USER %]
DATABASE_PASS=[% .Data.data.DATABASE_PASS %]
[% end %]
EOH
#[% range $key, $value := .Data.data %]
#[% $key %] = [% $value | toJSON %][% end %]
      }
      
      #resources {
        #cpu    = 300
        #memory = 300
        #}
    }
  } # group
  
  group "teslamate-db" {
    count = 1

    network {
      port "db" { to = "5432" }
    }
  
    volume "teslamate-postgres" {
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
      type            = "csi"
      read_only       = false
      source          = "teslamate-postgres"
    }
  
    service  {
      name = "teslamate-db"
      port = "db"

      check {
        type     = "tcp"
        port     = "db"
        interval = "60s"
        timeout  = "4s"
      }
    }

    task "teslamate-db" {
      driver = "docker"
    
      env {
        PUID = 1000
        PGID = 1000
      }
    
      volume_mount {
        volume      = "teslamate-postgres"
        destination = "/var/lib/postgresql/data"
        read_only   = false
      }
    
      config {
        image = "postgres:14"
        ports = ["db"]
      }
    
      vault {
        policies = ["service-teslamate"]
      }
    
      template {
        destination = "secrets/file.env"
        env = true
        left_delimiter = "[%"
        right_delimiter = "%]"
        change_mode = "restart"
        data = <<EOH
[% with secret "secrets/data/teslamate/config" %]
POSTGRES_DB=[% .Data.data.DATABASE_NAME %]
POSTGRES_USER=[% .Data.data.DATABASE_USER %]
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
} # job