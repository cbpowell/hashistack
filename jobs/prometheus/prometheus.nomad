job "prometheus" {
  datacenters = ["{{ dc_name }}"]
  type        = "service"

  group "prometheus" {
    count = 1

    network {
      port "http" {
        to = 9090
      }
    }

    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }

    task "prometheus" {
      driver = "docker"
      
      service {
        name = "prometheus"
        port = "http"
        tags = [
          "monitoring","prometheus",
          "traefik.enable=true",
          "coredns.enabled",
          "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`prometheus.{{ net_subdomain }}`)",
          "traefik.http.routers.${NOMAD_JOB_NAME}.entryPoints=websecure",
        ]

        check {
          name     = "Prometheus HTTP"
          type     = "http"
          path     = "/targets"
          interval = "5s"
          timeout  = "2s"

          check_restart {
            limit           = 2
            grace           = "60s"
            ignore_warnings = false
          }
        }
      }
      
      config {
        image = "prom/prometheus:{{ prometheus.vers }}"
        ports = ["http"]
        args = [
          "--config.file=/local/prometheus.yml",
        ]
      }
      
      vault {
        policies = ["prometheus"]
      }

      template {
        destination = "/local/prometheus.yml"
        left_delimiter = "[%"
        right_delimiter = "%]"
        change_mode  = "signal"
        data        = <<EOH
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'nomad_metrics'
    scrape_interval: 15s
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']
    consul_sd_configs:
      - server: 'consul.service.consul:8500'
[% with secret "secrets/data/monitoring" %]
        token: '[% .Data.data.CONSUL_TOKEN %]'
[% end %]
        services: ['nomad-client', 'nomad']
    relabel_configs:
      - source_labels: ['__meta_consul_tags']
        regex: '(.*)http(.*)'
        action: keep
EOH
      }

      resources {
        cpu    = 200
        memory = 200
      }
    }
  }
}