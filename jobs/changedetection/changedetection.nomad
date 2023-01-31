variables {
  uid = 1000
  gid = 1000
}

job "changedetection" {
  datacenters = ["{{ dc_name }}"]
  type        = "service"

  group "changedetection" {
    count = 1

    network {
      mode = "bridge"
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
    
    # Prep disk required due to this problem: https://github.com/hashicorp/nomad/issues/8892
    task "prep-disk" {
      driver = "docker"
      
      volume_mount {
        volume      = "changedetection"
        destination = "/data"
        read_only   = false
      }
      
      config {
        image        = "busybox:latest"
        command      = "sh"
        args         = ["-c", "chown -R ${var.uid}:${var.gid} /data"] #userid is hardcoded here
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
    
    task "playwrite-chrome" {
      driver = "docker"
      
      env {
        SCREEN_WIDTH            = 1920
        SCREEN_HEIGHT           = 1024
        SCREEN_DEPTH            = 16
        ENABLE_DEBUGGER         = false
        PREBOOT_CHROME          = true
        CONNECTION_TIMEOUT      = 300000
        MAX_CONCURRENT_SESSIONS = 8
        CHROME_REFRESH_TIME     = 600000
        DEFAULT_BLOCK_ADS       = true
        DEFAULT_STEALTH         = true
      }
      
      config {
        ports = ["chrome"]
        network_aliases = ["${NOMAD_TASK_NAME}"]
        image     = "browserless/chrome:latest"
      }
      
      resources {
        memory = 1024
      }

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }
    }

    task "changedetection" {
      driver = "docker"
      
      env {
        PUID = "${var.uid}"
        PGID = "${var.gid}"
        PLAYWRIGHT_DRIVER_URL = "ws://localhost:3000/?stealth=1&--disable-web-security=true"
      }
      
      volume_mount {
        volume      = "changedetection"
        destination = "/datastore"
        read_only   = false
      }
      
      config {
        image = "dgtlmoon/changedetection.io:{{ changedetection.vers }}"
        ports = ["webUI"]
      }

      resources {
        cpu    = 150
        memory = 384
      }
    }
    
    /*task "multitool" {
      driver = "docker"

      env {
        PUID = "${var.uid}"
        PGID = "${var.gid}"
      }

      config {
        image = "wbitt/network-multitool:alpine-extra"
      }

      resources {
        cpu    = 100
        memory = 150
      }
    }*/
  }
}