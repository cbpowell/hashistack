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
      port "postgres" { static = 5432 }
      port "loki" { static = 3100 }
    }

    service {
      name = "traefik"
      
      tags = [
        {% for tag in combined_tags | default([]) %}
        "{{ tag }}",
        {% endfor %}
        "traefik.enable=true",
        "coredns.enabled",
        "traefik.http.routers.traefik.rule=Host(`traefik.{{ traefik.subdomain }}`)",
        "traefik.http.routers.traefik.entrypoints=websecure",
        "traefik.http.services.traefik.loadbalancer.server.port=${NOMAD_HOST_PORT_api}"
      ]
      
      meta {
        coredns-consul = "allow private"
      }

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }
    
    # ACME Updater sidecar script
    task "acme-update" {
      lifecycle {
        hook = "poststart"
        sidecar = true
      }
      
      vault {
        policies = ["networking-traefik-acme"]
        change_mode   = "noop"
      }

      driver = "docker"

      # Bootstrap script
      template {
        destination = "${NOMAD_TASK_DIR}/bootstrap.sh"
        data        = <<EOF
#!/bin/sh
apk update
apk add --no-cache jq
apk add --no-cache curl

# Uncomment and change volume below for testing
# echo "Starting startup.sh.."
# echo "*       *       *       *       *       run-parts /etc/periodic/1min" >> /etc/crontabs/root

# Start crond
crond -f -l 8
EOF
      }
      
      # Action script
      template {
        destination = "acme-push"
        perms       = "755"
        left_delimiter = "[%"
        right_delimiter = "%]"
        data        = <<EOF
#!/bin/sh
echo "Pushing current acme.json to Vault"
# Push latest acme.json to Vault
curl --header "X-Vault-Token: $VAULT_TOKEN" \
     --request POST \
     --data "$(jq -n --arg data "$(jq . [% env "NOMAD_ALLOC_DIR" %]/acme.json)" '{"data": {"json": $data }}')" \
     --max-time 5 \
     -sS http://vault.service.consul:8200/v1/secrets/data/traefik/acme
EOF
      }
      
      config {
        image = "alpine:latest"
        args  = [
          "/bin/sh",
          "-c",
          "chmod 755 ${NOMAD_TASK_DIR}/bootstrap.sh && ${NOMAD_TASK_DIR}/bootstrap.sh"
        ]
        volumes = [
          "acme-push:/etc/periodic/daily/acme-push:ro"
        ]
      }
    }

    # Traefik
    task "traefik" {
      driver = "docker"
            
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
        change_mode = "restart"

        data = <<EOH
[% with secret "secrets/data/traefik/certresolver/cloudflare" %]
CF_API_KEY=[% .Data.data.api_key %]
CF_API_EMAIL=[% .Data.data.api_email %]
[% end %]
EOH
      }
      
      template {
        # Template initial acme.json from Vault
        destination = "${NOMAD_ALLOC_DIR}/acme.json"
        left_delimiter = "[%"
        right_delimiter = "%]"
        change_mode = "noop"
        # Traefik requires 600 on acme.json
        perms = "600"

        data = <<EOH
[% with secret "secrets/data/traefik/acme" %]
[% .Data.data.json %]
[% end %]
EOH
      }

      template {
        # Template config
        destination = "${NOMAD_TASK_DIR}/traefik.yml"
        left_delimiter = "[%"
        right_delimiter = "%]"
        change_mode = "restart"
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
  
  mqttws:
    address: ":[% env "NOMAD_HOST_PORT_mqttws" %]"
  
  mqttsecure:
    address: ":[% env "NOMAD_HOST_PORT_mqttsecure" %]"
    #http:
    #  tls:
    #    certResolver: le
    #    domains:
    #      - main: lab.theta142.com
    #        sans:
    #          - "*.lab.theta142.com"
  
  postgres:
    address: ":[% env "NOMAD_HOST_PORT_postgres" %]"
    
  loki:
    address: ":[% env "NOMAD_HOST_PORT_loki" %]"
  
  #traefik:
  #  address: ":[% env "NOMAD_HOST_PORT_api" %]"

api:
  dashboard: true
  insecure: true

[% with secret "secrets/data/traefik/certresolver/cloudflare" %]
certificatesResolvers:
  le:
    acme:
      email: [% .Data.data.api_email %]
      # storage: "/etc/traefik/acme.json"
      storage: "[% env "NOMAD_ALLOC_DIR" %]/acme.json"
      dnsChallenge:
        provider: cloudflare
        # Use an external resolvers to avoid conflict with CoreDNS and dnsChallenge!
        resolvers:
          - "1.1.1.1:53"
          - "8.8.8.8:53"
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
       memory = 128
      }
    }
  }
}
