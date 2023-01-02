data "aws_availability_zones" "available" {
  state = "available"
}
data "aws_route53_zone" "mydomain" {
  name         = "sanjos.tech."
  private_zone = false
}
