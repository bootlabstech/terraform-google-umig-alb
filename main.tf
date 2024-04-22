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
  ssl_certificates = var.is_prod_project ? [google_compute_ssl_certificate.prod.id] : [google_compute_ssl_certificate.non-prod.id]
  name    = "${var.name}-target-proxy"
  url_map = google_compute_url_map.url_map.id
  depends_on = [
    google_compute_ssl_certificate.non-prod,
    google_compute_ssl_certificate.prod,
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


resource "google_compute_ssl_certificate" "non-prod" {
  project = var.project_id
  name        = "m-devsecops-com-1"
  private_key = file ("m-devsecops.com.key.txt")
  certificate = file ("m-devsecops.com.cer.txt")
}
resource "google_compute_ssl_certificate" "prod" {
  project = var.project_id
  name        = "mahindra-com-1"
  private_key = file ("mahindrawildcard3_18_2024key.pem")
  certificate = file ("mahindrawildcard3_18_2024certs.pem")
}


