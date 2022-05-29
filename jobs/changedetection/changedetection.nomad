job "changedetection" {
  datacenters = ["{{ dc_name }}"]
  type        = "service"

  group "changedetection" {
    count = 1

    network {
      port "webUI" { to = "5000" }
    }
    
    volume "changedetection" {
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
      type            = "csi"
      read_only       = false
      source          = "changedetection"
    }
    
    service  {
      name = "${NOMAD_JOB_NAME}"
      port = "webUI"
      
      tags = [
        "traefik.enable=true",
        "coredns.enabled",
        "coredns.alias=changes",
        "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`changes.{{ net_subdomain }}`)",
        "traefik.http.routers.${NOMAD_JOB_NAME}.entryPoints=websecure",
      ]
      
      meta {
        coredns-consul = "allow private"
      }

      check {
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "4s"
      }
    }

    task "changedetection" {
      driver = "docker"
      
      env {
        PUID = 1000
        PGID = 1000
      }
      
      volume_mount {
        volume      = "changedetection"
        destination = "/datastore"
        read_only   = false
      }
      
      config {
        image = "dgtlmoon/changedetection.io:latest"
        hostname = "${NOMAD_JOB_NAME}"
        ports = ["webUI"]
      }

      resources {
        cpu    = 100
        memory = 150
      }
    }
  }
}