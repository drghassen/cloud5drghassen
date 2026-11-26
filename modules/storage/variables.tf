# Module storage : entrées typées, documentées et validées.
variable "name_prefix" {
  description = "Prefix used to name storage resources"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to storage resources"
  type        = map(string)
  default     = {}
}
