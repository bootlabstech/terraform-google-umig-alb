variable "name" {
  type        = string
  description = "The name of the instance group"
  
}
variable "description" {
  type        = string
  description = "description of the instance group"
  default = "Application load balancer for unmanaged instance"
}
variable "zone" {
  type        = string
  description = "The zone that this instance group should be created in."
  
}
variable "project_id" {
  type        = string
  description = " The ID of the project in which the resource belongs. If it is not provided, the provider project is used."
  
}
variable "network" {
  type        = string
  description = "The URL of the network the instance group is in. If this is different from the network where the instances are in, the creation fails."

}
variable "port" {
  type        = string
  description = "The name which the port will be mapped to."


}
variable "named_port_name_port" {
  type        = string
  description = "The port number to map the name to."
  default     = "https"
}
variable "instances" {
  type        = list(string)
  description = "The list of instances in the group, in self_link format. When adding instances they must all be in the same network and zone as the instance group."

}
variable "enable_named_port" {
  type        = bool
  description = "enable the port"
  default     = false
}
variable "ssl_certificates" {
    type=list(string)
    description = "SSL certificate"     
}