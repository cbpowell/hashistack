job "traefik" {
  datacenters = ["{{ dc_name }}"]
  type        = "service"

  group "traefik" {
    count = 1

    network {
      port "http" { static = 80 }
      port "https" { static = 443 }
      port "api" { static = 8081 }
      port "mqtt" { static = 1883 }
      port "mqttsecure" { static = 8883 }
      port "mqttws" { static = 9001 }
    }
    
    volume "traefik" {
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
      type            = "csi"
      read_only       = false
      source          = "traefik"
    }

    service {
      name = "traefik"
      
      tags = [
        {% for tag in combined_tags %}
        "{{ tag }}",
        {% endfor %}
        "traefik.enable=true",
        "traefik.http.routers.traefik.rule=Host(`traefik.{{ traefik.subdomain }}`)",
        "traefik.http.routers.traefik.entrypoints=websecure",
        "traefik.http.services.traefik.loadbalancer.server.port=${NOMAD_HOST_PORT_api}"
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"
      
      volume_mount {
        volume      = "traefik"
        destination = "/etc/traefik"
        read_only   = false
      }
            
      config {
        image        = "traefik:{{ traefik.vers }}"
        network_mode = "host"
        
        args = [
          "--configFile=${NOMAD_TASK_DIR}/traefik.yml",
        ]
      }
      
      vault {
        policies = ["networking-traefik"]
        change_mode   = "restart"
      }
      
      template {
        # Template ENV vars
        destination = "${NOMAD_SECRETS_DIR}/file.env"
        env = true
        left_delimiter = "[%"
        right_delimiter = "%]"

        data = <<EOH
[% with secret "secrets/data/traefik/certresolver/cloudflare" %]
CF_API_KEY=[% .Data.data.api_key %]
CF_API_EMAIL=[% .Data.data.api_email %]
[% end %]
EOH
      }

      template {
        # Template config
        destination = "${NOMAD_TASK_DIR}/traefik.yml"
        left_delimiter = "[%"
        right_delimiter = "%]"
        
        data = <<EOF
log:
  level: {{ traefik.log_level | default("ERROR") }}

entryPoints:
  web:
    address: ":[% env "NOMAD_HOST_PORT_http" %]"
    http:
      redirections:
        entrypoint:
          to: websecure
          scheme: https
    
  websecure:
    address: ":[% env "NOMAD_HOST_PORT_https" %]"
    http:
      tls:
        certResolver: le
        domains:
          - main: lab.theta142.com
            sans:
              - "*.lab.theta142.com"
              
  mqtt:
    address: ":[% env "NOMAD_HOST_PORT_mqtt" %]"
  
  mqttsecure:
    address: ":[% env "NOMAD_HOST_PORT_mqttsecure" %]"
    http:
      tls:
        certResolver: le
        domains:
          - main: lab.theta142.com
            sans:
              - "*.lab.theta142.com"
  
  traefik:
    address: ":[% env "NOMAD_HOST_PORT_api" %]"

api:
  dashboard: true
  insecure: true

[% with secret "secrets/data/traefik/certresolver/cloudflare" %]
certificatesResolvers:
  le:
    acme:
      email: [% .Data.data.api_email %]
      storage: "/etc/traefik/acme.json"
      dnsChallenge:
        provider: cloudflare
[% end %]

# Enable Consul Catalog configuration backend.
providers:
  consulCatalog:
    prefix: traefik
    exposedByDefault: false
    endpoint:
      address: 127.0.0.1:8500
      scheme: http
EOF
      }

      resources {
       cpu    = 75
       memory = 64
      }
    }
  }
}
