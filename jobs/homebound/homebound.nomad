variables {
  democratic_csi_vers = "{{ democratic_csi.vers }}"
  csi_plugin_id = "org.democratic-csi.local.homebound"
}

job "homebound" {
  datacenters = ["{{ dc_name }}"]
  type        = "service"

  # Always deploy a unique version
  meta {
    run_uuid = "${uuidv4()}"
  }
  
  group "homebound" {
    restart {
      interval = "5m"
      attempts = 5
      delay    = "15s"
      mode     = "fail"
    }
    
    reschedule {
     delay          = "5m"
     delay_function = "constant"
     unlimited      = true
    }
    
    constraint {
      attribute = "${node.unique.name}"
      value     = "empiricist-nn2"
    }
    
    task "homebound-controller" {
      driver = "docker"
      
      csi_plugin {
        # must match --csi-name arg
        id        = "${var.csi_plugin_id}"
        type      = "controller"
        mount_dir = "/csi"
      }

      config {
        image = "docker.io/democraticcsi/democratic-csi:${var.democratic_csi_vers}"
        
        args = [
          "--csi-version=1.5.0",
          # must match the csi_plugin.id attribute below
          "--csi-name=${var.csi_plugin_id}",
          "--driver-config-file=${NOMAD_SECRETS_DIR}/driver-config-file.yaml",
          "--log-level=info",
          "--csi-mode=controller",
          "--server-socket=/csi/csi.sock",
        ]
        
        privileged = true
        
        mount {
          type = "bind"
          target = "/host"
          source = "/"
          readonly = false
        }
        
        mount {
          type = "bind"
          target = "/var/lib/csi-local-hostpath"
          source = "/var/lib/csi-local-hostpath"
          readonly = false
        }
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/driver-config-file.yaml"
        left_delimiter = "[%"
        right_delimiter = "%]"
        
        data = <<EOH
driver: local-hostpath
instance_id:
local-hostpath:
  # generally shareBasePath and controllerBasePath should be the same for this
  # driver, this path should be mounted into the csi-driver container
  shareBasePath:      "/var/lib/csi-local-hostpath"
  controllerBasePath: "/var/lib/csi-local-hostpath"
  dirPermissionsMode: "0777"
  dirPermissionsUser: root
  dirPermissionsGroup: root
EOH
      }

      /*resources {
        cpu    = 125
        memory = 128
      }*/
    }
    
    task "homebound-node" {
      driver = "docker"
      
      csi_plugin {
        # must match --csi-name arg
        id        = "${var.csi_plugin_id}"
        type      = "monolith"
        mount_dir = "/csi"
      }

      config {
        image = "docker.io/democraticcsi/democratic-csi:${var.democratic_csi_vers}"
        
        args = [
          "--csi-version=1.5.0",
          # must match the csi_plugin.id attribute below
          "--csi-name=${var.csi_plugin_id}",
          "--driver-config-file=${NOMAD_SECRETS_DIR}/driver-config-file.yaml",
          "--log-level=info",
          "--csi-mode=controller",
          "--csi-mode=node",
          "--server-socket=/csi/csi.sock",
        ]
        
        privileged = true
        
        mount {
          type = "bind"
          target = "/host"
          source = "/"
          readonly = false
        }
        
        mount {
          type = "bind"
          target = "/var/lib/csi-local-hostpath"
          source = "/var/lib/csi-local-hostpath"
          readonly = false
        }
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/driver-config-file.yaml"
        left_delimiter = "[%"
        right_delimiter = "%]"
        
        data = <<EOH
driver: local-hostpath
instance_id:
local-hostpath:
  # generally shareBasePath and controllerBasePath should be the same for this
  # driver, this path should be mounted into the csi-driver container
  shareBasePath:      "/var/lib/csi-local-hostpath"
  controllerBasePath: "/var/lib/csi-local-hostpath"
  dirPermissionsMode: "0777"
  dirPermissionsUser: root
  dirPermissionsGroup: root
EOH
      }

      /*resources {
        cpu    = 125
        memory = 128
      }*/
    }
  }
}