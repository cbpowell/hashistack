variables {
  democratic_csi_vers = "{{ democratic_csi.vers }}"
  fundament_host = "{{ fundament_host }}"
  csi_plugin_id = "org.democratic-csi.iscsi.fundament"
  data_dir = "/opt/nomad/data"
  csi_path = "/client/csi/controller"
}

job "fundament-controller" {
  datacenters = ["{{ dc_name }}"]
  type        = "service"
  
  # Always deploy a unique version
  meta {
    run_uuid = "${uuidv4()}"
  }

  group "controller" {
    restart {
      interval = "15m"
      attempts = 5
      delay    = "15s"
      mode     = "delay"
    }
    
    reschedule {
     delay          = "3m"
     delay_function = "constant"
     unlimited      = true
    }
    
    task "controller" {
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
          "--log-level=debug",
          "--csi-mode=controller",
          "--server-socket=/csi/csi.sock",
        ]
      }
      
      vault {
        policies = ["storage-fundament"]
        change_mode   = "restart"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/driver-config-file.yaml"
        left_delimiter = "[%"
        right_delimiter = "%]"
        
        data = <<-EOF
driver: zfs-generic-iscsi
sshConnection:
  host: ${var.fundament_host}
  port: 22
[% with secret "secrets/data/storage/fundament/auth" %]
  username: [% .Data.data.ssh_username %]
  privateKey: |
[% .Data.data.ssh_privatekey %]
[% end %]
service:
  identity: {}
  controller: {}
  node: {}
zfs:
  # can be used to override defaults if necessary
  # the example below is useful for TrueNAS 12
  #cli:
  #  sudoEnabled: true
  #  paths:
  #    zfs: /usr/local/sbin/zfs
  #    zpool: /usr/local/sbin/zpool
  #    sudo: /usr/local/bin/sudo
  #    chroot: /usr/sbin/chroot

  # can be used to set arbitrary values on the dataset/zvol
  # can use handlebars templates with the parameters from the storage class/CO

  datasetParentName: fundament-vms/csi/v
  # do NOT make datasetParentName and detachedSnapshotsDatasetParentName overlap
  # they may be siblings, but neither should be nested in the other
  detachedSnapshotsDatasetParentName: fundament-vms/csi/s

  # "" (inherit), lz4, gzip-9, etc
  zvolCompression:
  # "" (inherit), on, off, verify
  zvolDedup:
  zvolEnableReservation: false
  # 512, 1K, 2K, 4K, 8K, 16K, 64K, 128K default is 16K
  zvolBlocksize:

iscsi:
  shareStrategy: "targetCli"

  # https://kifarunix.com/how-to-install-and-configure-iscsi-storage-server-on-ubuntu-18-04/
  # https://kifarunix.com/how-install-and-configure-iscsi-storage-server-on-centos-7/
  # https://linuxlasse.net/linux/howtos/ISCSI_and_ZFS_ZVOL
  # http://www.linux-iscsi.org/wiki/ISCSI
  # https://bugzilla.redhat.com/show_bug.cgi?id=1659195
  # http://atodorov.org/blog/2015/04/07/how-to-configure-iscsi-target-on-red-hat-enterprise-linux-7/
  shareStrategyTargetCli:
    #sudoEnabled: true
    basename: "iqn.2022-02.com.theta142.home.ablation.csi"
    tpg:
      attributes:
        # set to 1 to enable CHAP
        authentication: 0
        # this is required currently as we do not register all node iqns
        # the effective outcome of this is, allow all iqns to connect
        generate_node_acls: 1
        cache_dynamic_acls: 1
        # if generate_node_acls is 1 then must turn this off as well (assuming you want write ability)
        demo_mode_write_protect: 0
      auth:
        # CHAP
        [% with secret "secrets/data/storage/fundament/auth" %]
        userid: "[% .Data.data.chap_userid %]"
        password: "[% .Data.data.chap_password %]"
        [% end %]
        # mutual CHAP
        #mutual_userid: "baz"
        #mutual_password: "bar"
  targetPortal: "${var.fundament_host}"
  # for multipath
  #targetPortals: [] # [ "server[:port]", "server[:port]", ... ]
  # leave empty to omit usage of -I with iscsiadm
  interface: ""
  
  namePrefix: ""
  nameSuffix: ""
EOF
      }

      resources {
        cpu    = 125
        memory = 128
      }
    }
  }
}