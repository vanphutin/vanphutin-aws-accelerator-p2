# Debugging và Troubleshooting

## Mục tiêu chapter

Chapter này cung cấp kiến thức thực chiến về **Debugging và Troubleshooting**, đi từ khái niệm đến command, lỗi thường gặp, best practices và bài tập tự luyện.

## Danh sách bài học

- [Workflow debug Docker](01-debug-workflow.md)
- [Image Pull Error](02-image-pull-error.md)
- [Port Conflict](03-port-conflict.md)
- [Volume Issue](04-volume-issue.md)
- [DNS Issue](05-dns-issue.md)
- [OOMKilled và CrashLoop](06-oom-crashloop.md)

## Cách học đề xuất

1. Đọc README để hiểu phạm vi.
2. Học lần lượt các bài đánh số.
3. Gõ lại command thay vì chỉ đọc.
4. Sau mỗi bài, dùng `docker ps`, `docker images`, `docker volume ls`, `docker network ls` để quan sát trạng thái Docker.
5. Dọn tài nguyên lab khi hoàn tất để tránh chiếm port và dung lượng đĩa.
