variable "github_org" {
  type        = string
  description = "GitHub Organization or Username"
}

variable "product" {
  description = "The name of the product or project. This will be used to name resources consistently."
  type        = string
}

variable "environment" {
  type        = string
  description = "Account environment"
}

variable "repository" {
  type        = string
  description = "The github repository URL for the project. This is used for documentation and tracking purposes."
}

variable "tags" {
  type        = map(string)
  description = "Custom tags to apply to resources. These will be merged with default tags defined in the module."
}
