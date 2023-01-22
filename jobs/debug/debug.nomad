variables {
  volume_name = "debug"
}

job "debug" {
  datacenters = ["{{ dc_name }}"]
  type        = "service"
  
  group "debug" {
    count = 1

    /*network {
      port "debug" { to = "3001" }
    }*/
      
    constraint {
      attribute = "${attr.unique.hostname}"
      value     = "empiricist-nn2"
    }
    
    volume "debug" {
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
      type            = "csi"
      read_only       = false
      source          = "${var.volume_name}"
    }
    
    service  {
      name = "debug"
      /*
      port = "debug"
      
      /*
      tags = [
        "traefik.enable=true",
        "coredns.enabled",
        "coredns.alias=uptime",
        "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`uptime.{{ net_subdomain }}`)",
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
      */
    }

    task "debug" {
      driver = "docker"
      
      /*env {
        PUID = 1000
        PGID = 1000
      }*/
      
      volume_mount {
        volume      = "debug"
        destination = "/etc/debug_volume"
        read_only   = false
      }
      
      config {
        image    = "debian:latest"
        hostname = "debug"
        args     = [
          "/bin/bash"
        ]
          /*"/bin/sh",
          "-c",
          "chmod 755 /local/bootstrap.sh && /local/bootstrap.sh && /bin/bash"
        ]*/
        interactive = true
      }

      /*template {
        destination = "local/bootstrap.sh"
        data        = <<EOH
#!/bin/sh
apk update
apk add --no-cache bash
apk add --no-cache curl
apk add --no-cache git
apk add --no-cache jq
apk add --no-cache openssl
apk add --no-cache iperf3
apk add --no-cache nano
apk add --no-cache wget
EOH
      }*/
    }
  }
}