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
        DATABASE_HOST = "{{ teslamate.db_server }}"
        MQTT_HOST = "{{ teslamate.mqtt_server }}"
      }
      
      config {
        image = "teslamate/teslamate:latest"
        ports = ["http"]
        cap_drop = ["all"]
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
      
      resources {
        cpu    = 300
        memory = 300
      }
    }
  }
}