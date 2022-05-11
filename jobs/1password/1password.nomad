job "1password" {
  datacenters = ["{{ dc_name }}"]
  type        = "service"

  group "1password" {
    count = 1

    network {
      port "rest-api" { to = 8080 }
      port "rest-sync" { to = 8080 }
    }
    
    /*volume "1password" {
      attachment_mode = "file-system"
      access_mode     = "single-node-writer"
      type            = "csi"
      read_only       = false
      source          = "1password"
    }*/

    service {
      name = "1password-api"

      check {
        name     = "alive"
        type     = "tcp"
        port     = "rest-api"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "1password-connect-api" {
      driver = "docker"
            
      config {
        image = "1password/connect-api:latest"
        ports = ["rest-api"]
        
        mount {
          type = "volume"
          target = "/home/opuser/.op/data"
          source = "1password"
          readonly = false
        }
        
        volumes = [
          "secrets/1password-credentials.json:/home/opuser/.op/1password-credentials.json",
        ]
      }
      
      vault {
        policies = ["1password"]
        change_mode   = "restart"
      }

      template {
        # Template config
        destination = "${NOMAD_SECRETS_DIR}/1password-credentials.json"
        left_delimiter = "[%"
        right_delimiter = "%]"
        data = <<EOH
[% with secret "secrets/data/1password/credentials" %]
[% .Data.data.json %]
[% end %]
EOH
      }

      resources {
       cpu    = 100
       memory = 64
      }
    }
    
    service {
      name = "1password-sync"

      check {
        name     = "alive"
        type     = "tcp"
        port     = "rest-sync"
        interval = "10s"
        timeout  = "2s"
      }
    }
    
    task "1password-connect-sync" {
      driver = "docker"
            
      config {
        image = "1password/connect-sync:latest"
        ports = ["rest-sync"]
        
        mount {
          type = "volume"
          target = "/home/opuser/.op/data"
          source = "1password"
          readonly = false
        }
        
        volumes = [
          "secrets/1password-credentials.json:/home/opuser/.op/1password-credentials.json",
        ]
      }
      
      vault {
        policies = ["1password"]
        change_mode   = "restart"
      }

      template {
        # Template config
        destination = "${NOMAD_SECRETS_DIR}/1password-credentials.json"
        left_delimiter = "[%"
        right_delimiter = "%]"
        data = <<EOH
[% with secret "secrets/data/1password/credentials" %]
[% .Data.data.json %]
[% end %]
EOH
      }

      resources {
       cpu    = 100
       memory = 64
      }
    }
  }
}
