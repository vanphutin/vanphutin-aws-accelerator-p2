# Docker Security

## Mục tiêu chapter

Chapter này cung cấp kiến thức thực chiến về **Docker Security**, đi từ khái niệm đến command, lỗi thường gặp, best practices và bài tập tự luyện.

## Danh sách bài học

- [Mô hình bảo mật Docker](01-security-model.md)
- [Rootless Docker và User Namespace](02-rootless-user-namespace.md)
- [Quản lý secrets](03-secrets.md)
- [Image Scanning với Trivy](04-image-scanning-trivy.md)
- [Docker Bench Security](05-docker-bench.md)
- [Lab hardening container](06-lab-hardening.md)

## Cách học đề xuất

1. Đọc README để hiểu phạm vi.
2. Học lần lượt các bài đánh số.
3. Gõ lại command thay vì chỉ đọc.
4. Sau mỗi bài, dùng `docker ps`, `docker images`, `docker volume ls`, `docker network ls` để quan sát trạng thái Docker.
5. Dọn tài nguyên lab khi hoàn tất để tránh chiếm port và dung lượng đĩa.
