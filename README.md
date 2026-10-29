# Hệ thống giám sát Prometheus + Grafana trên AWS

Đề tài môn Điện toán đám mây (GVHD: Huỳnh Xuân Phụng) – nhóm Trương Thành Tiến (22110245), Lê Nguyễn Thiên Phúc (22110201).

Một máy EC2 `monitor` chạy Prometheus, Alertmanager và Grafana bằng Docker Compose; ba máy `web-1`, `web-2`, `db-1` chạy node_exporter. Prometheus tự phát hiện target qua `ec2_sd_configs` (tag `Monitoring=node`), cảnh báo gửi về Slack; CloudWatch Agent, Alarm và SNS được dựng song song để so sánh.

![Sơ đồ kiến trúc](docs/architecture.png)

## Cấu trúc repo

| Đường dẫn | Nội dung |
|---|---|
| [`docker-compose.yml`](docker-compose.yml) | Stack Prometheus v2.46.0, Alertmanager v0.25.0, Grafana 10.0.5 trên máy monitor |
| [`prometheus/`](prometheus/) | `prometheus.yml` (ec2_sd_configs, basic auth) và alert rule |
| [`alertmanager/`](alertmanager/) | Định tuyến cảnh báo và template Slack |
| [`grafana/`](grafana/) | Provisioning datasource Prometheus/CloudWatch và dashboard Node Exporter Full |
| [`node_exporter/`](node_exporter/) | Script cài node_exporter v1.12.1 có basic auth trên target |
| [`infra/stack.yml`](infra/stack.yml) | Template CloudFormation dựng lại toàn bộ hạ tầng |
| [`scripts/`](scripts/) | Script tạo secrets, cài CloudWatch Agent, tạo alarm, kiểm thử stack |
| [`hashpw.py`](hashpw.py) | Sinh bcrypt cho basic auth |
| [`docs/architecture.drawio`](docs/architecture.drawio) | Sơ đồ kiến trúc (nguồn draw.io) |
| [`docs/resource-plan.md`](docs/resource-plan.md) | Danh sách tài nguyên, đối chiếu giới hạn Learner Lab, phiên bản phần mềm |
| [`docs/week1-setup.md`](docs/week1-setup.md) | Các bước dựng VPC / Security Group / S3 tuần 1 và lỗi gặp phải |
| [`docs/reports/`](docs/reports/) | Báo cáo 4 tuần và ảnh minh chứng (`images/`) |

## Báo cáo theo tuần

| Tuần | Nội dung |
|---|---|
| [Tuần 1](docs/reports/week1.md) | Tìm hiểu dịch vụ, thiết kế kiến trúc, dựng VPC / SG / S3 |
| [Tuần 2](docs/reports/week2.md) | Tạo EC2, node_exporter, stack Docker, kiểm thử từng thành phần |
| [Tuần 3](docs/reports/week3.md) | CloudWatch Agent / Dashboard / Alarm / SNS, Grafana + CloudWatch, stress test, IaC |
| [Tuần 4](docs/reports/week4.md) | Kiểm thử tổng thể, so sánh, chi phí, dọn dẹp |

## Bí mật không nằm trong repo

`secrets/`, `prometheus/web.yml`, `.env` và key `*.pem` nằm trong [`.gitignore`](.gitignore). Tạo lại trên máy monitor bằng [`scripts/setup_secrets.sh`](scripts/setup_secrets.sh).
