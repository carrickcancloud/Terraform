# Declares the inputs for the CloudWatch Dashboard module.

variable "dashboard_name" {
  description = "The name that will appear for the dashboard in the CloudWatch console."
  type        = string
}

variable "dashboard_body" {
  description = "The JSON document that defines the dashboard's layout and widgets."
  type        = string
}
