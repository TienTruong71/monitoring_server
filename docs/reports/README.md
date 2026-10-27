# Báo cáo đề tài – Prometheus + Grafana trên AWS

| Tuần | Nội dung |
|---|---|
| [Tuần 1](week1.md) | Tìm hiểu dịch vụ, thiết kế kiến trúc, dựng VPC / SG / S3 |
| [Tuần 2](week2.md) | Tạo EC2, node_exporter, stack Docker, kiểm thử từng thành phần |
| [Tuần 3](week3.md) | CloudWatch Agent / Dashboard / Alarm / SNS, Grafana + CloudWatch, stress test, bảo mật, IaC |
| [Tuần 4](week4.md) | Kiểm thử tổng thể, so sánh, chi phí, dọn dẹp, video demo |

## Cách thêm ảnh

Chụp đúng trang ghi trong khung **[ẢNH x.y]**, lưu vào `docs/reports/images/` với đúng tên file ghi ở dòng *Lưu file*. Ảnh sẽ tự hiển thị trong báo cáo. Mọi ảnh console phải thấy **Account ID**, **Region** và **thời gian**.

## Checklist ảnh minh chứng

### Tuần 1

| ☐ | Ảnh | Nội dung | Chụp tại | File |
|---|---|---|---|---|
| ☐ | 1.1 | Console Learner Lab đã đăng nhập | trang **Console Home** (`https://us-east-1.console.aws.amazon.com/console/home?region=us-east-1`) | `images/w1-01-console-home.png` |
| ☐ | 1.2 | Xác thực danh tính bằng CLI | **CloudShell** (biểu tượng `>_` trên thanh console) sau khi chạy: | `images/w1-02-cloudshell-identity.png` |
| ☐ | 1.3 | Màn hình preview "VPC and more" | **VPC → Create VPC**, phần **Preview** bên phải trước khi bấm Create | `images/w1-03-vpc-preview.png` |
| ☐ | 1.4 | VPC đã tạo kèm tag | **VPC → Your VPCs → chọn `prom-monitoring-vpc` → tab Tags** | `images/w1-04-vpc-tags.png` |
| ☐ | 1.5 | Route table của public subnet | **VPC → Route tables → chọn route table public → tab Routes** | `images/w1-05-route-table.png` |
| ☐ | 1.6 | Inbound rules của sg-monitor | **EC2 → Security Groups → sg-monitor → tab Inbound rules** | `images/w1-06-sg-monitor.png` |
| ☐ | 1.7 | Inbound rules của sg-target | **EC2 → Security Groups → sg-target → tab Inbound rules** | `images/w1-07-sg-target.png` |
| ☐ | 1.8 | S3 bucket | **S3 → Buckets → chọn bucket → tab Properties** (cuộn tới Tags) | `images/w1-08-s3-bucket.png` |
| ☐ | 1.9 | LabRole / LabInstanceProfile | **IAM → Roles → tìm `LabRole`** → tab Summary | `images/w1-09-labrole.png` |
| ☐ | 1.10 | Tag Editor – tổng hợp tài nguyên đã gắn tag | **Resource Groups & Tag Editor → Tag Editor** → Regions: us-east-1, Resource types: All, Tag key `Project` = `prom-monitoring` → Search | `images/w1-10-tag-editor.png` |

### Tuần 2

| ☐ | Ảnh | Nội dung | Chụp tại | File |
|---|---|---|---|---|
| ☐ | 2.1 | Danh sách 4 EC2 đang chạy | **EC2 → Instances** (lọc tag `Project = prom-monitoring`) | `images/w2-01-ec2-list.png` |
| ☐ | 2.2 | IAM role và tag của một máy target | **EC2 → Instances → web-1 → tab Details** (phần IAM Role) và **tab Tags** | `images/w2-02-ec2-role-tags.png` |
| ☐ | 2.3 | Metadata options của máy monitor | **CloudShell** sau khi chạy lệnh ở mục 2.2, hoặc **EC2 → monitor → Actions → Instance settings → Modify instance metadata options** | `images/w2-03-imds-hop-limit.png` |
| ☐ | 2.4 | EBS volumes | **EC2 → Elastic Block Store → Volumes** | `images/w2-04-ebs.png` |
| ☐ | 2.5 | node_exporter chạy và yêu cầu xác thực | **terminal SSH vào web-1** | `images/w2-05-node-exporter-status.png` |
| ☐ | 2.6 | Các container đang chạy | **terminal SSH vào monitor**, lệnh `docker compose ps` | `images/w2-06-docker-compose-ps.png` |
| ☐ | 2.7 | Service Discovery | **Prometheus → Status → Service Discovery → `node-aws`** (bấm *show more*) | `images/w2-07-prom-service-discovery.png` |
| ☐ | 2.8 | Targets UP | **Prometheus → Status → Targets** | `images/w2-08-prom-targets.png` |
| ☐ | 2.9 | Truy vấn PromQL | **Prometheus → Graph**, chạy `up{job="node-aws"}` (tab Table) và `100 - (avg by (hostname) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` (tab Graph) | `images/w2-09-prom-query.png` |
| ☐ | 2.10 | Alert rules đã nạp | **Prometheus → Alerts** | `images/w2-10-prom-alerts.png` |
| ☐ | 2.11 | Datasource Prometheus hoạt động | **Grafana → Connections → Data sources → Prometheus → Save & test** | `images/w2-11-grafana-datasource.png` |
| ☐ | 2.12 | Dashboard Node Exporter Full | **Grafana → Dashboards → Node Exporter Full**, biến Job = `node-aws`, Host = web-1 | `images/w2-12-grafana-dashboard.png` |
| ☐ | 2.13 | Giao diện Alertmanager qua SSH tunnel | trình duyệt `http://localhost:9093` (trên máy cá nhân, đang mở tunnel) | `images/w2-13-alertmanager-ui.png` |
| ☐ | 2.14 | Cảnh báo NodeDown trên Prometheus | **Prometheus → Alerts** khoảng 1 phút sau khi stop node_exporter | `images/w2-14-prom-nodedown-firing.png` |
| ☐ | 2.15 | Tin nhắn Slack FIRING và RESOLVED | **Slack → kênh #alerts** | `images/w2-15-slack-nodedown.png` |
| ☐ | 2.16 | Truy cập 9100 từ Internet bị chặn | **terminal máy cá nhân** | `images/w2-16-sg-blocked.png` |

### Tuần 3

| ☐ | Ảnh | Nội dung | Chụp tại | File |
|---|---|---|---|---|
| ☐ | 3.1 | Bật Detailed Monitoring | **EC2 → Instances → web-1 → tab Monitoring** | `images/w3-01-detailed-monitoring.png` |
| ☐ | 3.2 | Metric mặc định không có RAM/Disk | **CloudWatch → Metrics → All metrics → EC2 → Per-Instance Metrics**, tìm theo instance id của web-1 | `images/w3-02-cw-default-metrics.png` |
| ☐ | 3.3 | CloudWatch Agent đang chạy | **terminal SSH vào web-1**, lệnh `amazon-cloudwatch-agent-ctl -a status` | `images/w3-03-cw-agent-status.png` |
| ☐ | 3.4 | Custom metrics CWAgent | **CloudWatch → Metrics → All metrics → CWAgent → InstanceId** | `images/w3-04-cwagent-metrics.png` |
| ☐ | 3.5 | CloudWatch Dashboard | **CloudWatch → Dashboards → prom-monitoring-compare** (time range 1h) | `images/w3-05-cw-dashboard.png` |
| ☐ | 3.6 | SNS subscription đã xác nhận | **SNS → Topics → prom-monitoring-alerts → tab Subscriptions** | `images/w3-06-sns-subscription.png` |
| ☐ | 3.7 | Danh sách CloudWatch Alarms | **CloudWatch → Alarms → All alarms** | `images/w3-07-cw-alarms.png` |
| ☐ | 3.8 | Datasource CloudWatch hoạt động | **Grafana → Connections → Data sources → CloudWatch → Save & test** | `images/w3-08-grafana-cw-datasource.png` |
| ☐ | 3.9 | Dashboard so sánh trên Grafana | **Grafana → Dashboards → Prometheus vs CloudWatch** trong lúc chạy stress | `images/w3-09-grafana-compare.png` |
| ☐ | 3.10 | Terminal chạy stress-ng | **terminal SSH vào web-1**, chạy `stress-ng` cùng `htop` (chia đôi màn hình) | `images/w3-10-stress-cpu.png` |
| ☐ | 3.11 | Slack nhận HighCPUUsage | **Slack → #alerts** | `images/w3-11-slack-highcpu.png` |
| ☐ | 3.12 | Alarm CloudWatch chuyển In alarm | **CloudWatch → Alarms → web-1-HighCPU** (tab History) | `images/w3-12-cw-alarm-state.png` |
| ☐ | 3.13 | Email SNS | **hộp thư email** đã subscribe | `images/w3-13-sns-email.png` |
| ☐ | 3.14 | Slack nhận HighRAMUsage | **Slack → #alerts** | `images/w3-14-slack-highram.png` |
| ☐ | 3.15 | CloudWatch không phát hiện node_exporter bị dừng | **CloudWatch → Alarms → db-1-StatusCheck** cùng thời điểm Slack đang báo NodeDown cho db-1 | `images/w3-15-cw-statuscheck-ok.png` |
| ☐ | 3.16 | Bí mật không bị đẩy lên Git | **trang repo trên GitHub/GitLab**, thư mục gốc nhánh `feature/aws_project` | `images/w3-16-git-no-secrets.png` |
| ☐ | 3.17 | CloudFormation stack | **CloudFormation → Stacks → prom-monitoring → tab Resources** | `images/w3-17-cloudformation.png` |

### Tuần 4

| ☐ | Ảnh | Nội dung | Chụp tại | File |
|---|---|---|---|---|
| ☐ | 4.1 | Service discovery khi thay đổi tag | **Prometheus → Status → Targets** trước và sau khi gỡ tag `Monitoring` của web-2 (ghép 2 ảnh) | `images/w4-01-sd-tag-change.png` |
| ☐ | 4.2 | Máy bị stop | **EC2 → Instances** (web-2 Stopped) và **Prometheus → Targets** cùng thời điểm | `images/w4-02-instance-stopped.png` |
| ☐ | 4.3 | Slack HighDiskUsage | **Slack → #alerts** | `images/w4-03-slack-highdisk.png` |
| ☐ | 4.4 | Stack tự khôi phục sau reboot | **terminal SSH vào monitor** sau reboot, lệnh `uptime && docker compose ps` | `images/w4-04-reboot-recovery.png` |
| ☐ | 4.5 | Kiểm thử bảo mật | **terminal máy cá nhân** | `images/w4-05-security-test.png` |
| ☐ | 4.6 | Ngân sách đã dùng trong Learner Lab | **trang Learner Lab (AWS Academy)**, phần trên cùng bên phải *Used $x of $50* (hoặc AWS Details) | `images/w4-06-learner-lab-budget.png` |
| ☐ | 4.7 | Chi phí theo dịch vụ (nếu Learner Lab cho phép) | **Billing and Cost Management → Cost Explorer**, group by **Service**, khoảng thời gian 4 tuần | `images/w4-07-cost-explorer.png` |
| ☐ | 4.8 | AWS Pricing Calculator | `https://calculator.aws/` → *My Estimate* sau khi thêm EC2, EBS, CloudWatch, SNS | `images/w4-08-pricing-calculator.png` |
| ☐ | 4.9 | EC2 đã terminate | **EC2 → Instances** (bỏ filter mặc định để thấy cả máy đã terminate) | `images/w4-09-ec2-terminated.png` |
| ☐ | 4.10 | Không còn volume và VPC | **EC2 → Volumes** và **VPC → Your VPCs** (ghép 2 ảnh) | `images/w4-10-cleanup-ebs-vpc.png` |
| ☐ | 4.11 | Tag Editor sau khi dọn dẹp | **Resource Groups & Tag Editor → Tag Editor**, tìm tag `Project = prom-monitoring` | `images/w4-11-tag-editor-empty.png` |
