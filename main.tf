resource "google_project_service" "certapi" {
  project = var.project_id
  service = "certificatemanager.googleapis.com"
}

resource "google_compute_instance_group" "instance_group" {
  project     = var.project_id
  name        = "${var.name}-umig"
  description = var.description
  zone        = var.zone
  instances   = var.instances
  network     = var.network
  dynamic "named_port" {
    for_each = var.enable_named_port ? [{}] : []
    content {
      name = "https"
      port = var.port
    }
  }
  named_port {
          name = "https" 
          port = var.port
        }
   
}

resource "google_compute_global_address" "default" {
  project      = var.project_id
  name       = "${var.name}-ip"
  ip_version = "IPV4"
  address_type = "EXTERNAL"
}
resource "google_compute_health_check" "default" {
    project         = var.project_id
  name               = "${var.name}-health-check"
  check_interval_sec = 5
  healthy_threshold  = 2
  tcp_health_check {
    port               = var.port
    port_specification = "USE_FIXED_PORT"
    proxy_header       = "PROXY_V1"
    
  }
  timeout_sec         = 5
  unhealthy_threshold = 2
}

resource "google_compute_backend_service" "default" {
  project               = var.project_id
  name                            = "${var.name}-back-end"
  connection_draining_timeout_sec = 0
  health_checks                   = [google_compute_health_check.default.id]
  load_balancing_scheme           = "EXTERNAL"
  port_name                       = "https"
  protocol                        = "HTTPS"
  session_affinity                = "NONE"
  timeout_sec                     = 30
  backend {
    group           = google_compute_instance_group.instance_group.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
    max_utilization  = 0.8
    
  }
  security_policy = google_compute_security_policy.policy.id
}

resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  project               = var.project_id
  name                  = "${var.name}-forwarding-rule"
  target                = google_compute_target_https_proxy.target-proxy.id
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  ip_address            = google_compute_global_address.default.address
   depends_on = [
    google_compute_target_https_proxy.target-proxy
  ]
}

resource "google_compute_target_https_proxy" "target-proxy" {
  project = var.project_id
  ssl_certificates = var.ssl_certificates 
  name    = "${var.name}-target-proxy"
  url_map = google_compute_url_map.url_map.id
  depends_on = [
    # google_compute_ssl_certificate.non-prod,
    # google_compute_ssl_certificate.prod,
    google_compute_url_map.url_map
  ]
  
}

resource "google_compute_url_map" "url_map" {
  project         = var.project_id
  name            = "${var.name}-url-map"
  default_service = google_compute_backend_service.default.id
  depends_on = [
    google_compute_backend_service.default
  ]
}
resource "google_compute_security_policy" "policy" { 
     name = "${var.name}-cloud-policy"
     project = var.project_id
       rule {
            action   = "deny(403)"
           priority = "2147483647"
            match {
           versioned_expr = "SRC_IPS_V1"
          config {
               src_ip_ranges = ["*"]
           }
           }
           description = "default rule"
       }
        rule {
           action   = "allow" 
           preview  = false 
           priority = 1000 

           match {
              versioned_expr = "SRC_IPS_V1" 

               config {
                   src_ip_ranges = [
                       "103.21.244.0/22",
                      "103.22.200.0/22",
                       "103.31.4.0/22",
                       "108.162.192.0/18",
                       "141.101.64.0/18",
                       "173.245.48.0/20",
                       "188.114.96.0/20",
                       "190.93.240.0/20",
                       "197.234.240.0/22",
                       "198.41.128.0/17",
                    ] 
                }
            }
        }
        rule {
           action      = "allow" 
           description = "rule 2" 
           preview     = false 
           priority    = 1001 

           match {
               versioned_expr = "SRC_IPS_V1" 

               config {
                   src_ip_ranges = [
                       "104.16.0.0/13",
                       "104.24.0.0/14",
                       "131.0.72.0/22",
                       "162.158.0.0/15",
                       "172.64.0.0/13",
                    ] 
                }
            }
        }

        # (1 unchanged block hidden)
    }




