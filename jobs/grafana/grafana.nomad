job "grafana" {
  datacenters = ["{{ dc_name }}"]
  type        = "service"

  group "grafana" {
    count = 1

    network {
      port "http" { to = "3000" }
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

    task "grafana" {
      driver = "docker"
      
      env {
        DATABASE_HOST = "{{ teslamate.db_server }}"
        # GRAFANA_PASSWD=${GRAFANA_PW}
        # GF_AUTH_BASIC_ENABLED = "true"
        # GF_AUTH_ANONYMOUS_ENABLED = "false"
        GF_SERVER_ROOT_URL = "https://grafana.{{ net_subdomain }}"
        GF_SERVER_SERVE_FROM_SUB_PATH = "true"
      }
      
      config {
        image = "{{ grafana.image }}:{{ grafana.vers }}"
        ports = ["http"]
      }
      
      vault {
        policies = ["monitoring-grafana", "service-teslamate"]
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
#[% range $key, $value := .Data.data %]
#[% $key %] = [% $value | toJSON %][% end %]
      }
      
      # Todo
      # Template in Grafana provisioning files
      # https://grafana.com/docs/grafana/latest/administration/provisioning/
      # https://github.com/adriankumpf/teslamate/blob/master/grafana/dashboards.yml
      # https://github.com/adriankumpf/teslamate/blob/master/grafana/datasource.yml
      
      resources {
        cpu    = 200
        memory = 100
      }
    }
  }
}