job "loki" {
  datacenters = ["{{ dc_name }}"]
  type        = "service"

  group "loki" {
    count = 1

    network {
      port "http" { to = "3100" }
      port "grpc" { to = "9096" }
    }
    
    volume "loki" {
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
      type            = "csi"
      read_only       = false
      source          = "loki"
    }
    
    service  {
      name = "loki"
      port = "http"
      
      tags = [
        "traefik.enable=true",
        "coredns.enabled",
        "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`loki.{{ net_subdomain }}`)",
        "traefik.http.routers.${NOMAD_JOB_NAME}.entryPoints=loki",
      ]
      
      meta {
        coredns-consul = "allow private"
      }

      check {
        type     = "http"
        path     = "/metrics"
        interval = "120s"
        timeout  = "5s"
      }
    }
    
    # Prep disk required due to this problem: https://github.com/hashicorp/nomad/issues/8892
    task "prep-disk" {
      driver = "docker"
      
      volume_mount {
        volume      = "loki"
        destination = "/loki"
        read_only   = false
      }
      config {
        image        = "busybox:latest"
        command      = "sh"
        args         = ["-c", "chown -R 10001:10001 /loki"] #userid is hardcoded here, based on Loki dockerfile: https://github.com/grafana/loki/blob/main/cmd/loki/Dockerfile
      }
      resources {
        cpu    = 200
        memory = 128
      }

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
    }

    task "loki" {
      driver = "docker"
      
      volume_mount {
        volume      = "loki"
        destination = "/loki"
        read_only   = false
      }
      
      config {
        image = "grafana/loki:{{ loki.vers }}"
        ports = ["http","grpc"]
        args = [
          "-config.file=${NOMAD_TASK_DIR}/loki-config.yml"
        ]
      }
      
      template {
        destination = "local/loki-config.yml"
        left_delimiter = "[%"
        right_delimiter = "%]"
        change_mode = "restart"
        data = <<EOH
auth_enabled: false

analytics:
  reporting_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

#ruler:
#  alertmanager_url: http://localhost:9093
EOH
      }

      /*resources {
        cpu    = 200
        memory = 150
      }*/
    }
  }
}