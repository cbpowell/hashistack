job "scratch-map" {
  datacenters = ["{{ dc_name }}"]
  type        = "service"

  group "scratch-map" {
    
    count = 1
    
    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }
    
    network {
      port "http" { to = "3000" }
    }
    
    volume "scratch-map" {
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
      type            = "csi"
      read_only       = false
      source          = "scratch-map"
    }
    
    # Prep disk required due to this problem: https://github.com/hashicorp/nomad/issues/8892
    task "prep-disk" {
      driver = "docker"
      
      volume_mount {
        volume      = "scratch-map"
        destination = "/data"
        read_only   = false
      }
      
      config {
        image        = "busybox:latest"
        command      = "sh"
        args         = ["-c", "chown -R 1000:1000 /data"] #userid is hardcoded here
      }
      
      resources {
        cpu    = 50
        memory = 32
      }

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
    }
    
    task "scratch-map" {
      driver = "docker"
      
      env {
        PUID = 1000
        PGID = 1000
        DBLOCATION = "/data"
      }
      
      volume_mount {
        volume      = "scratch-map"
        destination = "/data"
        read_only   = false
      }
      
      config {
        image = "ad3m3r5/scratch-map:{{ scratch_map.vers }}"
        ports = ["http"]
      }
      
      service {
        name = "scratch-map"
        port = "http"
      
        tags = [
          "traefik.enable=true",
          "coredns.enabled",
          "coredns.alias=scratch",
          "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`scratch.{{ net_subdomain }}`)",
          "traefik.http.routers.${NOMAD_JOB_NAME}.entryPoints=websecure",
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
            limit           = 2
            grace           = "60s"
            ignore_warnings = false
          }
        }
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}