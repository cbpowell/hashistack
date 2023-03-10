job "mqtt" {
  datacenters = ["{{ dc_name }}"]
  type        = "service"

  group "mqtt" {
    count = 1
    
    network {
      port "mqtt" { to = "1883" }
      port "mqttsecure" { to = "8883" }
      port "websock" { to = "9001" }
    }

    service {
      name = "mqtt"
      port = "mqtt"
      
      tags = [
        "traefik.enable=true",
        "coredns.enabled",
        "traefik.tcp.routers.mqtt.rule=HostSNI(`*`)",
        "traefik.tcp.routers.mqtt.entryPoints=mqtt",
        "traefik.tcp.routers.mqtt.service=mqtt",
        "traefik.tcp.services.mqtt.loadbalancer.server.port=${NOMAD_HOST_PORT_mqtt}",
        "traefik.tcp.routers.mqttsecure.rule=HostSNI(`mqtt.{{ net_subdomain }}`)",
        "traefik.tcp.routers.mqttsecure.entryPoints=mqttsecure",
        "traefik.tcp.routers.mqttsecure.service=mqtt",
        "traefik.tcp.routers.mqttsecure.tls=true",
        "traefik.tcp.routers.mqttsecure.tls.certresolver=le",
        "traefik.tcp.services.mqttsecure.loadbalancer.server.port=${NOMAD_HOST_PORT_mqttsecure}",
      ]
      
      meta {
        coredns-consul = "allow private"
      }

      check {
        type     = "tcp"
        port     = "mqtt"
        interval = "60s"
        timeout  = "4s"
      }
    }

    task "mqtt" {
      driver = "docker"
      
      env {
        PUID = 1000
        PGID = 1000
        TZ   = "{{ home_tz }}"
      }
            
      config {
        image = "eclipse-mosquitto:latest"
        
        ports = ["mqtt", "mqttsecure", "websock"]
        
        mount {
          type = "bind"
          target = "/mosquitto/config"
          source = "local"
          readonly = false
        }
      }
      
      template {
        # Template config
        destination = "${NOMAD_TASK_DIR}/mosquitto.conf"
        
        data = <<EOF
listener 1883
allow_anonymous true
persistence true
persistence_location /mosquitto/data/

log_dest stdout
log_type error
log_type warning
log_type notice
log_type information
log_type debug
connection_messages true
log_timestamp true
log_timestamp_format [%H:%M:%S]
EOF
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}
