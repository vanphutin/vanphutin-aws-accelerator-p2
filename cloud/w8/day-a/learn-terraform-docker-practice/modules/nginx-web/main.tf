resource "docker_image" "nginx" {
  name         = "nginx:alpine"
  keep_locally = true
}

resource "local_file" "index_html" {
  filename = "${path.module}/index-${var.site_name}.html"

  content  = templatefile(var.html_template_path, {
    site_title      = var.site_title
    bg_color        = var.bg_color
    welcome_message = var.welcome_message
    admin_name      = var.admin_name
    port            = var.host_port
  })
}

resource "docker_container" "nginx" {
  name  = lower("nginx-${var.site_name}")
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.host_port
  }

  volumes {
    host_path      = abspath(local_file.index_html.filename)
    container_path = "/usr/share/nginx/html/index.html"
    read_only      = true
  }

  depends_on = [local_file.index_html]
}