job "grafana" {
  datacenters = ["{{ dc_name }}"]
  type        = "service"

  group "grafana" {
    count = 1

    network {
      port "http" { to = "3000" }
    }
    
    volume "grafana" {
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
      type            = "csi"
      read_only       = false
      source          = "grafana"
    }
    
    service  {
      name = "grafana"
      port = "http"
      
      tags = [
        "traefik.enable=true",
        "coredns.enabled",
        "traefik.http.routers.${NOMAD_JOB_NAME}.rule=Host(`grafana.{{ net_subdomain }}`)",
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
    
    # Prep disk required due to this problem: https://github.com/hashicorp/nomad/issues/8892
    task "prep-disk" {
      driver = "docker"
      
      volume_mount {
        volume      = "grafana"
        destination = "/data"
        read_only   = false
      }
      
      config {
        image        = "busybox:latest"
        command      = "sh"
        args         = ["-c", "chown -R 472:0 /data"] #userid is hardcoded here
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

    task "grafana" {
      driver = "docker"
      
      env {
        GF_SERVER_ROOT_URL = "https://grafana.{{ net_subdomain }}"
        GF_SERVER_SERVE_FROM_SUB_PATH = "true"
      }
      
      volume_mount {
        volume      = "grafana"
        destination = "/var/lib/grafana"
        read_only   = false
      }
      
      config {
        image = "{{ grafana.image }}:{{ grafana.vers }}"
        ports = ["http"]
        volumes = [
          "theta142-datasource.yml:/etc/grafana/provisioning/datasources/loki-datasource.yml:ro"
        ]
      }
      
      vault {
        policies = ["monitoring-grafana", "service-teslamate"]
      }
      
      template {
        destination = "local/env.txt"
        left_delimiter = "[%"
        right_delimiter = "%]"
        change_mode = "restart"
        env         = true
        data = <<EOH
[% range service "teslamate-db" %]
DATABASE_HOST = [% .Address %]
DATABASE_PORT = [% .Port %]
TEST_DBA_PORT = 77777
[% end %]
EOH
      }
      
      template {
        destination = "secrets/file.env"
        env = true
        left_delimiter = "[%"
        right_delimiter = "%]"
        change_mode = "restart"
        # read multiple secrets from Vault
        data = <<EOH
[% with secret "secrets/data/teslamate/config" %]
DATABASE_NAME=[% .Data.data.DATABASE_NAME %]
DATABASE_USER=[% .Data.data.DATABASE_USER %]
DATABASE_PASS=[% .Data.data.DATABASE_PASS %]
[% end %]
[% with secret "secrets/data/grafana/config" %]
GF_SECURITY_ADMIN_USER=[% .Data.data.GF_SECURITY_ADMIN_USER %]
GF_SECURITY_ADMIN_PASSWORD=[% .Data.data.GF_SECURITY_ADMIN_PASSWORD %]
[% end %]
EOH
      }
      
      # Template in datasources
      template {
        destination = "theta142-datasource.yml"
        left_delimiter = "[%"
        right_delimiter = "%]"
        change_mode = "restart"
        data = <<EOH
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    [% range service "loki" %]
    url: http://[%- .Address -%]:[%- .Port -%]
    [% end %]
    # url: http://loki.lab.theta142.com:3100
    jsonData:
      maxLines: 1000
      
  - name: Prometheus
    type: prometheus
    name: Prometheus
    access: proxy
    [% range service "prometheus" %]
    url: http://[%- .Address -%]:[%- .Port -%]
    [% end %]
    # url: http://localhost:9090
EOH
      }
      # Todo
      # Template in Grafana provisioning files
      # https://grafana.com/docs/grafana/latest/administration/provisioning/
      # https://github.com/adriankumpf/teslamate/blob/master/grafana/dashboards.yml
      # https://github.com/adriankumpf/teslamate/blob/master/grafana/datasource.yml
      
      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}