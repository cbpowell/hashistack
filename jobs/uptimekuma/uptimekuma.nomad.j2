job "uptimekuma" {
  datacenters = ["{{ dc_name }}"]
  type        = "service"

  group "uptimekuma" {
    count = 1

    network {
      port "ui" { to = "3001" }
    }
    
    volume "uptimekuma" {
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
      type            = "csi"
      read_only       = false
      source          = "uptimekuma"
    }
    
    service  {
      name = "uptimekuma"
      port = "ui"
      
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`uptime.{{ net_subdomain }}`)",
        "traefik.http.routers.${NOMAD_JOB_NAME}.entryPoints=websecure",
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "4s"
      }
    }

    task "uptimekuma" {
      driver = "docker"
      
      env {
        PUID = 1000
        PGID = 1000
      }
      
      volume_mount {
        volume      = "uptimekuma"
        destination = "/app/data"
        read_only   = false
      }
      
      config {
        image = "louislam/uptime-kuma:latest"
        ports = ["ui"]
      }

      resources {
        cpu    = 200
        memory = 150
      }
    }
  }
}