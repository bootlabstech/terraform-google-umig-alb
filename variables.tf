# -----------------------------
# COMMON VARIABLES
# -----------------------------
variable "project_id" {
  description = "The GCP project ID where all load balancer resources will be created."
  type        = string
}

variable "name" {
  description = "Base name used as a prefix for all load balancer resources."
  type        = string
}

variable "lb_type" {
  description = "Type of load balancer to create. Supported values: 'internal' or 'external'."
  type        = string

  validation {
    condition     = contains(["internal", "external"], var.lb_type)
    error_message = "The lb_type value must be either 'internal' or 'external'."
  }
}

variable "zone" {
  description = "Zone where the backend VM instances are running (used for unmanaged instance group)."
  type        = string
}

variable "instances" {
  description = "List of backend VM instance self-links to attach to the instance group."
  type        = list(string)
}

variable "network" {
  description = "VPC network self-link or name where the load balancer will be deployed."
  type        = string
}

variable "port" {
  description = "Port on which backend application is running on the VM instances."
  type        = number
}

variable "backend_port_name" {
  description = "Port name used by the backend service. Must match the named port defined in the instance group."
  type        = string
}

variable "protocol" {
  description = "Protocol used by the backend service (e.g., HTTP, HTTPS, TCP)."
  type        = string
}

variable "existing_ssl_name" {
  description = "List of SSL certificate self-links. Use REGIONAL certificates for internal LB and GLOBAL certificates for external LB."
  type        = string
}

# -----------------------------
# INTERNAL LB (ONLY USED IF lb_type = internal)
# -----------------------------
variable "region" {
  description = "Region where internal load balancer resources will be created. Required only when lb_type is 'internal'."
  type        = string
}

variable "subnetwork" {
  description = "Subnetwork self-link where the internal load balancer IP will be allocated. Required only for internal LB."
  type        = string
  default     = null
}

# -----------------------------
# EXTERNAL LB (ONLY USED IF lb_type = external)
# -----------------------------
variable "external_ip_address" {
  description = "Optional existing global external IP address to use for the external load balancer. If not provided, a new one will be created."
  type        = string
  default     = null
}