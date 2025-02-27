locals {
  enabled                            = module.this.enabled
  account_map                        = module.account_map.outputs.full_account_map
  s3_bucket                          = module.config_bucket.outputs
  is_global_collector_region         = join("", data.aws_region.this[*].name) == var.global_resource_collector_region
  create_iam_role                    = var.create_iam_role && local.is_global_collector_region
  config_iam_role_template           = "arn:${local.partition}:iam::${join("", data.aws_caller_identity.this[*].account_id)}:role/${module.aws_config_label.id}"
  config_iam_role_from_state         = local.create_iam_role ? null : join("", module.global_collector_region[*].outputs.aws_config_iam_role)
  config_iam_role_external           = var.iam_role_arn != null ? var.iam_role_arn : local.config_iam_role_from_state
  config_iam_role_arn                = local.create_iam_role ? local.config_iam_role_template : local.config_iam_role_external
  central_resource_collector_account = local.account_map[var.central_resource_collector_account]
  delegated_accounts                 = var.delegated_accounts != null ? var.delegated_accounts : toset(values(local.account_map))
  partition                          = join("", data.aws_partition.this[*].partition)
}

data "aws_caller_identity" "this" {
  count = local.enabled ? 1 : 0
}

data "aws_region" "this" {
  count = local.enabled ? 1 : 0
}

data "aws_partition" "this" {
  count = local.enabled ? 1 : 0
}

module "aws_config_label" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  attributes = ["config"]

  context = module.this.context
}

module "utils" {
  source  = "cloudposse/utils/aws"
  version = "1.1.0"

  context = module.this.context
}

module "conformance_pack" {
  source  = "cloudposse/config/aws//modules/conformance-pack"
  version = "0.17.0"

  count = local.enabled ? length(var.conformance_packs) : 0

  name                = var.conformance_packs[count.index].name
  conformance_pack    = var.conformance_packs[count.index].conformance_pack
  parameter_overrides = var.conformance_packs[count.index].parameter_overrides

  depends_on = [
    module.aws_config
  ]

  context = module.this.context
}

module "aws_config" {
  source  = "cloudposse/config/aws"
  version = "0.17.0"

  s3_bucket_id     = local.s3_bucket.config_bucket_id
  s3_bucket_arn    = local.s3_bucket.config_bucket_arn
  create_iam_role  = local.create_iam_role
  iam_role_arn     = local.config_iam_role_arn
  create_sns_topic = true

  global_resource_collector_region   = var.global_resource_collector_region
  central_resource_collector_account = local.central_resource_collector_account
  child_resource_collector_accounts  = local.delegated_accounts

  context = module.this.context
}
