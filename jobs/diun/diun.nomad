job "diun" {
  datacenters = ["{{ dc_name }}"]
  type        = "system"
  
  constraint {
    operator = "distinct_hosts"
    value = true
  }

  group "diun" {
    count = 1

    service {
      name = "diun"

      /*check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }*/
    }

    task "diun" {
      driver = "docker"
      
      env {
        # DIUN_PROVIDERS_DOCKER_ENDPOINT       = "unix:///var/run/docker.sock"
        DIUN_NOTIF_DISCORD_WEBHOOKURL        = "{{ secrets.diun.webhook_url }}"
        DIUN_NOTIF_DISCORD_TEMPLATEBODY      = "{{ diun.notification }}"
        DIUN_NOTIF_DISCORD_MENTIONS          = "@everyone"
        DIUN_PROVIDERS_DOCKER_WATCHBYDEFAULT = "true"
        DIUN_WATCH_SCHEDULE                  = "0 13 * * THU"
        TZ                                   = "{{ home_tz }}"
      }
            
      config {
        image        = "crazymax/diun:{{ diun.vers }}"
        
        mount {
          type = "bind"
          target = "/var/run/docker.sock"
          source = "/var/run/docker.sock"
          readonly = true
        }
      }
      
      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}
