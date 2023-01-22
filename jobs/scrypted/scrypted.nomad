job "scrypted" {
  datacenters = ["{{ dc_name }}"]
  type        = "service"

  group "scrypted" {
    count = 1
    
    constraint {
      attribute = "${node.unique.name}"
      value     = "empiricist-nn1"
    }
    
    network {
      port "https" {}
      port "http" {}
    }

    service {
      name = "scrypted"
      port = "http"
      
      tags = [
        "traefik.enable=true",
        "coredns.enabled",
        "traefik.http.routers.scrypted.rule=Host(`scrypted.{{ net_subdomain }}`)",
        "traefik.http.routers.scrypted.entryPoints=websecure",
      ]
      
      meta {
        coredns-consul = "allow private"
      }

      check {
        type     = "http"
        path     = "/"
        interval = "5s"
        timeout  = "2s"

        check_restart {
          limit           = 3
          grace           = "60s"
          ignore_warnings = false
        }
      }
    }

    task "scrypted" {
      driver = "docker"
      
      vault {
        policies = ["scrypted"]
      }
    
      template {
        destination = "secrets/file.env"
        env = true
        left_delimiter = "[%"
        right_delimiter = "%]"
        change_mode = "restart"
        data = <<EOH
[% with secret "secrets/data/scrypted/secrets" %]
SCRYPTED_WEBHOOK_UPDATE_AUTHORIZATION = "Bearer [% .Data.data.WEBHOOK_AUTH %]"
[% end %]
EOH
      }
      
      env {
        SCRYPTED_WEBHOOK_UPDATE = "https://scrypted.{{ net_subdomain }}:10444/v1/update"
        SCRYPTED_SECURE_PORT = "${NOMAD_PORT_https}"
        SCRYPTED_INSECURE_PORT = "${NOMAD_PORT_http}"
      }
            
      config {
        image = "koush/scrypted:{{ scrypted.vers }}"
        
        network_mode = "host"
        
        mount {
          type = "bind"
          target = "/server/volume"
          source = "/var/lib/csi-local-hostpath/scrypted"
          readonly = false
        }
        
        # Minimize logging to reduce log spam
        logging {
          type = "none"
        }
      }
      
      resources {
        cpu    = 600
        memory = 1200
      }
    }
  }
}
