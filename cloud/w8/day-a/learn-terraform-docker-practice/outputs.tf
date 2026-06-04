output "website_urls" {
  description = "Danh sách URL truy cập vào các trang web đã deploy"
  value       = { for k, v in module.nginx_websites : k => v.website_url }
}