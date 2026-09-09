locals {
  env              = "dev"
  region           = "weu"
  instance         = "01"
  base_sufix       = "${local.env}-${local.region}-${local.instance}"
  base_suffix_flat = "${local.env}${local.region}${local.instance}"
}