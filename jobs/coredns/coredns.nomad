variables {
  uid = 1000
  gid = 1000
}

job "coredns" {
  datacenters = ["{{ dc_name }}"]
  type        = "system"
  
  update {
    max_parallel = 1
    stagger = "10s"
  }

  group "coredns" {

    network {
      port "dns" {
        static = "5371"
        to = "53"
      }
    }
    
    service  {
      name = "${NOMAD_JOB_NAME}"
      port = "dns"
      
      # tags = []

      check {
        type     = "tcp"
        interval = "30s"
        timeout  = "1s"
      }
    }
    
    task "build" {
      driver = "docker"
      
      lifecycle {
        hook = "prestart"
      }
      
      artifact {
        # Auto unarchives!
        source      = "https://github.com/cbpowell/coredns-consul/releases/latest/download/coredns.tar.gz"
        destination = "${NOMAD_TASK_DIR}/coredns-dir"
      }
      
      template {
        destination = "${NOMAD_TASK_DIR}/build.sh"
        left_delimiter = "[%"
        right_delimiter = "%]"
        
        data = <<EOH
#!/bin/bash
mv $NOMAD_TASK_DIR/coredns-dir/coredns $NOMAD_ALLOC_DIR/coredns-mod
chown ${var.uid}:${var.gid} $NOMAD_ALLOC_DIR/coredns-mod
chmod +x $NOMAD_ALLOC_DIR/coredns-mod
EOH
          
      }
      
      config {
        image   = "busybox:latest"
        command = "sh"
        args = ["${NOMAD_TASK_DIR}/build.sh"]
      }
      
      resources {
        cpu    = 10
        memory = 10
      }
    }
    
    vault {
      policies = ["coredns"]
    }
    
    task "coredns" {
      driver = "docker"
      
      template {
        destination = "${NOMAD_ALLOC_DIR}/Corefile"
        left_delimiter = "[%"
        right_delimiter = "%]"
        
        data = <<EOH
# Rewrite direct queries (i.e. service.direct.subdomain) directly to Consul DNS
direct.{{ net_subdomain }}:53 {
  rewrite name substring .direct.{{ net_subdomain }} .service.consul answer auto
  forward . {{ coredns.upstream_dns }}
  errors
  cache 60
}

# Handle consul service itself
consul.{{ net_subdomain }}:53 {
  rewrite name substring consul.{{ net_subdomain }} consul.service.consul answer auto
  forward . {{ coredns.upstream_dns }}
  errors
  cache 60
}

# Query Consul catalog for services
{{ net_subdomain }}:53 {
  # CoreDNS Consul Catalog plugin must be compiled in!
  consul_catalog {{ coredns.enable_tag }} {
    # Use default endpoint
    # endpoint
    
    # Point to service proxy when specified
    service_proxy {{ coredns.srv_proxy_tag }} {{ coredns.srv_proxy }}
    
    # Use Consul Service metadata tag to define ACLs
    acl_metadata_tag {{ coredns.acl_metadata_tag }}
    
    # Set alias tag
    alias_tag {{ coredns.alias_tag }}
    
    # Set ACL ignore tag
    acl_ignore_tag {{ coredns.acl_ignore_tag }}
    
    # Define acl zones
    {{ coredns.acl_zones }}
    
    # Token needs permission to read services and nodes
[% with secret "secrets/data/coredns" %]
    token "[%- .Data.data.CONSUL_TOKEN -%]"
[% end %]
    
    # Set ttl
    ttl {{ coredns.ttl }}
  }
  
  cache 120
  # log
  errors
}

# This section is necessary - consul_catalog rewrites to consul domain!
consul:53 {
  forward . {{ coredns.upstream_dns }}
  
  errors
  # log
  cache 120
}

EOH
      }
      
      env {
        PUID = "${var.uid}"
        PGID = "${var.gid}"
      }
      
      config {
        image = "coredns/coredns:{{ coredns.vers }}"
        ports = ["dns"]
        entrypoint = ["${NOMAD_ALLOC_DIR}/coredns-mod"]
        args = ["-conf", "${NOMAD_ALLOC_DIR}/Corefile"] 
      }

      resources {
        cpu    = 25
        memory = 50
      }
    }
  }
}