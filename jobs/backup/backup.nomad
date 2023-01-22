job "backup" {
  datacenters = ["{{ dc_name }}"]
  
  # Batch type to support periodic
  type        = "batch"
  
  periodic {
    cron             = "@daily"
    prohibit_overlap = true
  }

  group "postgres" {
    count = 1
    
    service  {
      name = "backup-postgres"
      
      meta {
        coredns-consul = "allow private"
      }
    }

    task "teslamate-local" {
      driver = "docker"
      
      config {
        image = "{{ backup.postgres.local.image }}:{{ backup.postgres.local.vers }}"
        cap_drop = ["all"]
      }
      
      vault {
        policies = ["service-teslamate", "backup-postgres"]
      }
      
      template {
        destination = "secrets/env.txt"
        left_delimiter = "[%"
        right_delimiter = "%]"
        change_mode = "noop"
        env         = true
        data = <<EOH
[% with secret "secrets/data/backup/postgres/minio" %]
MINIO_HOST=[% .Data.data.MINIO_HOST %]
MINIO_ACCESSKEY=[% .Data.data.MINIO_ACCESS_KEY %]
MINIO_SECRETKEY=[% .Data.data.MINIO_SECRET_KEY %]
MINIO_BUCKET=[% .Data.data.MINIO_BUCKET %]
FILENAME=teslamate_backup
[% end %]

[% range service "teslamate-db" %]
POSTGRES_HOST=[% .Address %]
POSTGRES_PORT=[% .Port %]
[% end %]

[% with secret "secrets/data/teslamate/config" %]
POSTGRES_DATABASE=[% .Data.data.DATABASE_NAME %]
POSTGRES_USER=[% .Data.data.DATABASE_USER %]
POSTGRES_PASSWORD=[% .Data.data.DATABASE_PASS %]
[% end %]
EOH
      }
    }
    
    task "teslamate-backblaze" {
      driver = "docker"
      
      config {
        image = "{{ backup.postgres.remote.image }}:{{ backup.postgres.remote.vers }}"
        cap_drop = ["all"]
      }
      
      vault {
        policies = ["service-teslamate", "backup-postgres"]
      }
      
      template {
        destination = "secrets/env.txt"
        left_delimiter = "[%"
        right_delimiter = "%]"
        change_mode = "noop"
        env         = true
        data = <<EOH
[% with secret "secrets/data/backup/postgres/backblaze" %]
MINIO_HOST=[% .Data.data.MINIO_HOST %]
MINIO_ACCESSKEY=[% .Data.data.MINIO_ACCESS_KEY %]
MINIO_SECRETKEY=[% .Data.data.MINIO_SECRET_KEY %]
MINIO_BUCKET=[% .Data.data.MINIO_BUCKET %]
ENCRYPTION_PASSWORD=[% .Data.data.ENCRYPTION_PASSWORD %]
FILENAME=teslamate_backup
[% end %]

[% range service "teslamate-db" %]
POSTGRES_HOST=[% .Address %]
POSTGRES_PORT=[% .Port %]
[% end %]

[% with secret "secrets/data/teslamate/config" %]
POSTGRES_DATABASE=[% .Data.data.DATABASE_NAME %]
POSTGRES_USER=[% .Data.data.DATABASE_USER %]
POSTGRES_PASSWORD=[% .Data.data.DATABASE_PASS %]
[% end %]
EOH
      }
    }
  } # group
} # job