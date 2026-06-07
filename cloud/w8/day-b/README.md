# Giáo trình Docker thực chiến

Bộ tài liệu này được viết bằng tiếng Việt, theo lộ trình từ cơ bản đến chuyên gia. Nội dung tập trung vào Docker trong công việc DevOps thực tế: build image, chạy container, quản lý storage/network, viết Dockerfile, Compose, registry, security, monitoring, production, Kubernetes foundation, phỏng vấn và project hoàn chỉnh.

## Cây chapter

- [Giới thiệu Docker](01-gioi-thieu-docker/README.md)
- [Cài đặt môi trường](02-cai-dat-moi-truong/README.md)
- [Docker cơ bản](03-docker-co-ban/README.md)
- [Docker Images](04-images/README.md)
- [Docker Containers](05-containers/README.md)
- [Docker Storage và Volumes](06-volumes/README.md)
- [Docker Networks](07-networks/README.md)
- [Dockerfile](08-dockerfile/README.md)
- [Docker Compose](09-docker-compose/README.md)
- [Docker Registry](10-registry/README.md)
- [Debugging và Troubleshooting](11-debugging/README.md)
- [Docker Security](12-security/README.md)
- [Monitoring Docker](13-monitoring/README.md)
- [Docker Production](14-production/README.md)
- [Kubernetes Foundation](15-kubernetes-foundation/README.md)
- [Best Practices](16-best-practices/README.md)
- [Docker Interview](17-interview/README.md)
- [Real-world Projects](18-real-world-projects/README.md)

## Nguyên tắc học

- Luôn chạy command thật và đọc output.
- Luôn hiểu từng tham số của command Docker trước khi dùng trong production.
- Không dùng `latest` cho release quan trọng.
- Không lưu dữ liệu quan trọng trong writable layer của container.
- Không đưa secret vào Dockerfile, image hoặc Git.
