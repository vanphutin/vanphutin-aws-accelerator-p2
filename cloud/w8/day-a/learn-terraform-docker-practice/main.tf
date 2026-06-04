locals {
  template_file_path = "${path.module}/templates/index.html.tpl"
}

module "nginx_websites" {
  source = "./modules/nginx-web"

  for_each = var.websites

  # map key sẽ là site_name ("marketing", "developer", "finance")
  site_name = each.key

  # map value chứa các thuộc tính tương ứng
  host_port       = each.value.port
  site_title      = each.value.site_title
  bg_color        = each.value.bg_color
  welcome_message = each.value.welcome_message

  admin_name         = var.admin_name
  html_template_path = local.template_file_path
}