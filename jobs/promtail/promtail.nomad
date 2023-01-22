job "promtail" {
  datacenters = ["{{ dc_name }}"]
  type        = "system"

  group "promtail" {
    
    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }
    
    network {
      port "http" {}
    }
    
    task "promtail" {
      driver = "docker"
      
      env {
        HOSTNAME = "${attr.unique.hostname}"
      }
      
      config {
        image = "grafana/promtail:{{ promtail.vers }}"
        ports = ["http"]
        args = [
          "-config.file=${NOMAD_TASK_DIR}/promtail-config.yml",
          "-print-config-stderr",
          "-server.http-listen-port=${NOMAD_PORT_http}",
        ]
        volumes = [
          "/data/promtail:/data",
          "/opt/nomad/data/:/nomad/",
          "/var/log:/var/log"
        ]
      }
      
      vault {
        policies = ["promtail"]
      }
      
      template {
        destination = "local/promtail-config.yml"
        left_delimiter = "[%"
        right_delimiter = "%]"
        change_mode = "restart"
        data = <<EOH
server:
  http_listen_port: 9080
  grpc_listen_port: 0
  
positions:
  filename: /data/positions.yaml
  
clients:
  - url: http://loki.lab.theta142.com:3100/loki/api/v1/push
  
scrape_configs:
  - job_name: 'nomad-logs'
    consul_sd_configs:
      - server: 'consul.service.consul:8500'
[% with secret "secrets/data/monitoring" %]
        token: '[% .Data.data.CONSUL_TOKEN %]'
[% end %]
    relabel_configs:
      - source_labels: [__meta_consul_node]
        target_label: __host__
        
      - source_labels: [__meta_consul_service_metadata_external_source]
        target_label: source
        regex: (.*)
        replacement: '$1'
        
        
      - source_labels: [__meta_consul_service_id]
        regex: '_nomad-task-([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})-.*'
        target_label:  'task_id'
        replacement: '$1'
        
      - source_labels: [__meta_consul_tags]
        regex: ',(app|monitoring),'
        target_label:  'group'
        replacement:   '$1'
      
      - source_labels: [__meta_consul_service]
        regex: '(nomad-client|nomad)'
        action: drop
        
      - source_labels: [__meta_consul_service]
        target_label: job
        
      - source_labels: ['__meta_consul_node']
        regex:         '(.*)'
        target_label:  'instance'
        replacement:   '$1'
        
      - source_labels: [__meta_consul_service_id]
        regex: '_nomad-task-([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})-.*'
        target_label:  '__path__'
        replacement: '/nomad/alloc/$1/alloc/logs/*std*.{?,??}'
EOH
      }
      
      /*
        - job_name: system
          static_configs:
          - targets:
              - localhost
            labels:
              job: syslog
              host: [% env "node.unique.name" %]
              __path__: /var/log/syslog
          - targets:
              - localhost
            labels:
              job: authlog
              host: [% env "node.unique.name" %]
              __path__: /var/log/auth.log
      */
      
      service {
        name = "promtail"
        port = "http"
        tags = ["monitoring","prometheus"]

        check {
          name     = "Promtail HTTP"
          type     = "http"
          path     = "/ready"
          interval = "30s"
          timeout  = "2s"

          check_restart {
            limit           = 2
            grace           = "60s"
            ignore_warnings = false
          }
        }
      }

      resources {
        cpu    = 120
        memory = 256
      }
    }
  }
}