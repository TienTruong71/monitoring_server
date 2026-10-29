# Kế hoạch tài nguyên và giới hạn Learner Lab

Lập ở tuần 1 trước khi dựng hạ tầng (nội dung mục 2 và 3 của báo cáo tuần 1). Region: `us-east-1`.

## Dịch vụ AWS sử dụng

| Dịch vụ | Vai trò trong đề tài |
|---|---|
| Amazon EC2 | 1 máy monitor chạy Prometheus/Grafana/Alertmanager (Docker), 3 máy target chạy node_exporter |
| Amazon EBS (gp3) | Ổ đĩa gốc cho EC2, lưu dữ liệu TSDB của Prometheus và Grafana |
| Amazon VPC | Mạng riêng, public subnet, Internet Gateway, Security Group |
| IAM (LabRole / LabInstanceProfile) | Cho EC2 gọi `ec2:DescribeInstances` (service discovery) và CloudWatch; không tạo IAM user/role mới |
| Amazon CloudWatch | Metric EC2 (basic/detailed), CloudWatch Agent cho RAM/Disk, Dashboard, Alarm – dùng để so sánh |
| Amazon SNS | Gửi email khi CloudWatch Alarm kích hoạt |
| Amazon S3 | Lưu backup cấu hình và dashboard export |

## Danh sách EC2 dự kiến

| Tài nguyên | Loại | vCPU | EBS |
|---|---|---|---|
| monitor | t3.medium | 2 | 20 GB gp3 |
| web-1 | t3.micro | 2 | 8 GB gp3 |
| web-2 | t3.micro | 2 | 8 GB gp3 |
| db-1 | t3.micro | 2 | 8 GB gp3 |
| **Tổng** | **4 EC2** | **8 vCPU** | **44 GB** |

## Đối chiếu giới hạn Learner Lab

| Ràng buộc | Giới hạn | Thiết kế | Đạt |
|---|---|---|---|
| Số EC2 của đề tài | ≤ 4 | 4 | ✔ |
| Loại instance | nano → large | micro, medium | ✔ |
| vCPU đồng thời / Region | ≤ 32 | 8 | ✔ |
| Tổng EBS | ≤ 100 GB, gp2/gp3 | 44 GB gp3 | ✔ |
| Region | us-east-1 / us-west-2 | us-east-1 | ✔ |
| IAM | Chỉ LabRole / LabInstanceProfile | LabInstanceProfile | ✔ |

## Phiên bản phần mềm (ghim cố định)

| Thành phần | Phiên bản | Nơi khai báo |
|---|---|---|
| Prometheus | v2.46.0 | [`docker-compose.yml`](../docker-compose.yml) |
| Alertmanager | v0.25.0 | [`docker-compose.yml`](../docker-compose.yml) |
| Grafana | 10.0.5 | [`docker-compose.yml`](../docker-compose.yml) |
| node_exporter | v1.12.1 | [`node_exporter/install.sh`](../node_exporter/install.sh) |

## Mô hình thu thập: pull và push

- **Prometheus – pull:** Prometheus chủ động scrape `/metrics` của từng target theo `scrape_interval` (15s).
- **CloudWatch – push:** hypervisor (metric mặc định) và CloudWatch Agent đẩy metric lên CloudWatch; chu kỳ mặc định 5 phút, detailed monitoring 1 phút.
- Metric mặc định của CloudWatch không có RAM và Disk usage, nên cần CloudWatch Agent (custom metric, có tính phí).

## Quy ước tag

| Key | Value |
|---|---|
| Project | `prom-monitoring` |
| Owner | MSSV |
| Name | `monitor` / `web-1` / `web-2` / `db-1` / tên tài nguyên |
| Monitoring | `node` (chỉ 3 máy target – Prometheus `ec2_sd_configs` lọc theo tag này) |
