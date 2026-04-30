resource "google_project_service" "certapi" {
  project = var.project_id
  service = "certificatemanager.googleapis.com"
  disable_on_destroy = false
}

# -----------------------------
# EXTERNAL LB (GLOBAL SSL CERT)
# -----------------------------
data "google_compute_ssl_certificate" "external_ssl" {
  count   = var.lb_type == "external" ? 1 : 0
  name    = var.existing_ssl_name
  project = var.project_id
}

# -----------------------------
# INTERNAL LB (REGIONAL SSL CERT)
# -----------------------------
data "google_compute_region_ssl_certificate" "internal_ssl" {
  count   = var.lb_type == "internal" ? 1 : 0
  name    = var.existing_ssl_name
  project = var.project_id
  region  = var.region
}

locals {
  is_internal = var.lb_type == "internal"
  is_external = var.lb_type == "external"
}

# -----------------------------
# Instance Group (COMMON)
# -----------------------------
resource "google_compute_instance_group" "instance_group" {
  project   = var.project_id
  name      = "${var.name}-umig"
  zone      = var.zone
  instances = var.instances
  network   = var.network

  named_port {
    name = var.backend_port_name
    port = var.port
  }
  # lifecycle {
  #   ignore_changes = [ named_port ]
  # }
}

# -----------------------------
# HEALTH CHECK
# -----------------------------
resource "google_compute_health_check" "external_hc" {
  count   = local.is_external ? 1 : 0
  project = var.project_id
  name    = "${var.name}-hc"

  tcp_health_check {
    port = var.port
  }
}

resource "google_compute_region_health_check" "internal_hc" {
  count   = local.is_internal ? 1 : 0
  project = var.project_id
  region  = var.region
  name    = "${var.name}-hc"

  tcp_health_check {
    port = var.port
  }
}

# -----------------------------
# BACKEND SERVICE
# -----------------------------
resource "google_compute_backend_service" "external_backend" {
  count                  = local.is_external ? 1 : 0
  project                = var.project_id
  name                   = "${var.name}-backend"
  port_name              = var.backend_port_name
  protocol               = var.protocol
  load_balancing_scheme  = "EXTERNAL"
  connection_draining_timeout_sec = 300
  health_checks          = [google_compute_health_check.external_hc[0].id]
  session_affinity = "NONE"
  timeout_sec = 30

  backend {
    group           = google_compute_instance_group.instance_group.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
    max_utilization = 1.0
  }
  security_policy = google_compute_security_policy.ext_policy[0].id
}

resource "google_compute_region_backend_service" "internal_backend" {
  count                  = local.is_internal ? 1 : 0
  project                = var.project_id
  region                 = var.region
  name                   = "${var.name}-backend"
  protocol               = var.protocol
  load_balancing_scheme  = "INTERNAL_MANAGED"
  port_name              = var.backend_port_name
  connection_draining_timeout_sec = 300
  health_checks          = [google_compute_region_health_check.internal_hc[0].id]
  session_affinity = "NONE"
  timeout_sec = 30

  backend {
    group           = google_compute_instance_group.instance_group.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
    max_utilization = 1.0
  }
}

# -----------------------------
# URL MAP
# -----------------------------
resource "google_compute_url_map" "external_url_map" {
  count           = local.is_external ? 1 : 0
  project         = var.project_id
  name            = "${var.name}-url-map"
  default_service = google_compute_backend_service.external_backend[0].id
}

resource "google_compute_region_url_map" "internal_url_map" {
  count           = local.is_internal ? 1 : 0
  project         = var.project_id
  region          = var.region
  name            = "${var.name}-url-map"
  default_service = google_compute_region_backend_service.internal_backend[0].id
}

# -----------------------------
# HTTPS PROXY
# -----------------------------
resource "google_compute_target_https_proxy" "external_proxy" {
  count            = local.is_external ? 1 : 0
  project          = var.project_id
  name             = "${var.name}-proxy"
  url_map          = google_compute_url_map.external_url_map[0].id
  ssl_certificates = local.is_external ? [data.google_compute_ssl_certificate.external_ssl[0].self_link] : []
}

resource "google_compute_region_target_https_proxy" "internal_proxy" {
  count            = local.is_internal ? 1 : 0
  project          = var.project_id
  region           = var.region
  name             = "${var.name}-proxy"
  url_map          = google_compute_region_url_map.internal_url_map[0].id
  ssl_certificates = local.is_internal ? [data.google_compute_region_ssl_certificate.internal_ssl[0].self_link] : []
}

# -----------------------------
# IP ADDRESS
# -----------------------------
resource "google_compute_global_address" "external_ip" {
  count        = local.is_external ? 1 : 0
  project      = var.project_id
  name         = "${var.name}-ip"
  address_type = "EXTERNAL"
}

resource "google_compute_address" "internal_ip" {
  count        = local.is_internal ? 1 : 0
  project      = var.project_id
  region       = var.region
  name         = "${var.name}-internal-ip"
  address_type = "INTERNAL"
  subnetwork   = var.subnetwork
}

# -----------------------------
# FORWARDING RULE
# -----------------------------
resource "google_compute_global_forwarding_rule" "external_fr" {
  count                  = local.is_external ? 1 : 0
  project                = var.project_id
  name                   = "${var.name}-fr"
  target                 = google_compute_target_https_proxy.external_proxy[0].id
  port_range             = "443"
  ip_protocol            = "TCP"
  load_balancing_scheme  = "EXTERNAL"
  ip_address             = google_compute_global_address.external_ip[0].address
}

resource "google_compute_forwarding_rule" "internal_fr" {
  count                  = local.is_internal ? 1 : 0
  project                = var.project_id
  region                 = var.region
  name                   = "${var.name}-fr"
  target                 = google_compute_region_target_https_proxy.internal_proxy[0].id
  port_range             = "443"
  ip_protocol            = "TCP"
  load_balancing_scheme  = "INTERNAL_MANAGED"
  network                = var.network
  subnetwork             = var.subnetwork
  ip_address             = google_compute_address.internal_ip[0].address
}

## cloud Armour policy for External ONLY
resource "google_compute_security_policy" "ext_policy" {
  count                  = local.is_external ? 1 : 0
  name    = "${var.name}-cloud-policy"
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
}