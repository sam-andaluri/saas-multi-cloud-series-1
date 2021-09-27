resource "aws_waf_geo_match_set" "geo_match_set" {
  name = "geo_match_set"
  dynamic "geo_match_constraint" {
    for_each = ["AB", "CD"]
    content {
      type  = "Country"
      value = geo_match_constraint.value
    }
  }
}
