# Báo cáo Tuần 2 – Triển khai chức năng lõi trên AWS

**Đề tài:** Hệ thống giám sát mã nguồn mở Prometheus + Grafana trên AWS (Nhóm: Infrastructure)
**Thời gian:** ……/……/2026 – ……/……/2026
**Thành viên:** SV A – MSSV ……… · SV B – MSSV ………
**Region:** us-east-1 · **Account ID:** ………………

---

## 1. Mục tiêu tuần

- Tạo 4 EC2 (1 monitor + 3 target) đúng giới hạn Learner Lab.
- Cài node_exporter có basic auth trên 3 target.
- Chạy Prometheus, Alertmanager, Grafana bằng Docker Compose trên EC2 monitor.
- Prometheus tự phát hiện target qua `ec2_sd_configs`.
- Kiểm thử từng thành phần: target UP, dashboard, cảnh báo Slack.

## 2. Tạo EC2

### 2.1 Thông số

| Name | Instance type | AMI | EBS | Security Group | Tag bổ sung |
|---|---|---|---|---|---|
| monitor | t3.medium | Ubuntu 22.04 LTS | 20 GB gp3 | sg-monitor | – |
| web-1 | t3.micro | Ubuntu 22.04 LTS | 8 GB gp3 | sg-target | `Monitoring=node` |
| web-2 | t3.micro | Ubuntu 22.04 LTS | 8 GB gp3 | sg-target | `Monitoring=node` |
| db-1 | t3.micro | Ubuntu 22.04 LTS | 8 GB gp3 | sg-target | `Monitoring=node` |

Chung cho cả 4 máy: VPC `prom-monitoring-vpc`, public subnet, Auto-assign public IP: Enable, Key pair `vockey`, **Advanced details → IAM instance profile: `LabInstanceProfile`**, tag `Project=prom-monitoring`, `Owner=<MSSV>`.

### 2.2 Cho phép container đọc IMDS trên máy monitor

Prometheus và Grafana chạy trong Docker cần đi qua thêm một "hop" mạng để tới Instance Metadata Service, nên phải tăng hop limit lên 2 để lấy được credentials của LabInstanceProfile. Chạy trong CloudShell:

```bash
aws ec2 modify-instance-metadata-options \
  --instance-id <id-may-monitor> \
  --http-endpoint enabled \
  --http-put-response-hop-limit 2
```

> **[ẢNH 2.1] Danh sách 4 EC2 đang chạy**
> - Chụp tại: **EC2 → Instances** (lọc tag `Project = prom-monitoring`)
> - Phải thấy: 4 instance trạng thái **Running**, cột Instance type, Availability Zone, Private IP; Account ID và Region ở góc trên phải
> - Lưu file: `images/w2-01-ec2-list.png`

![Ảnh 2.1](images/w2-01-ec2-list.png)

> **[ẢNH 2.2] IAM role và tag của một máy target**
> - Chụp tại: **EC2 → Instances → web-1 → tab Details** (phần IAM Role) và **tab Tags**
> - Phải thấy: IAM Role `LabRole`; tag `Monitoring=node`, `Project`, `Owner`
> - Lưu file: `images/w2-02-ec2-role-tags.png`

![Ảnh 2.2](images/w2-02-ec2-role-tags.png)

> **[ẢNH 2.3] Metadata options của máy monitor**
> - Chụp tại: **CloudShell** sau khi chạy lệnh ở mục 2.2, hoặc **EC2 → monitor → Actions → Instance settings → Modify instance metadata options**
> - Phải thấy: `HttpPutResponseHopLimit: 2`
> - Lưu file: `images/w2-03-imds-hop-limit.png`

![Ảnh 2.3](images/w2-03-imds-hop-limit.png)

> **[ẢNH 2.4] EBS volumes**
> - Chụp tại: **EC2 → Elastic Block Store → Volumes**
> - Phải thấy: 4 volume gp3 (20 + 8 + 8 + 8 = 44 GB), trạng thái In-use
> - Lưu file: `images/w2-04-ebs.png`

![Ảnh 2.4](images/w2-04-ebs.png)

## 3. Cài node_exporter trên 3 target

### 3.1 Tạo mật khẩu basic auth (trên máy cá nhân)

```bash
pip install -r requirements.txt
python hashpw.py node_exporter <mat-khau-exporter>
```

Kết quả dạng `node_exporter: $2b$12$...` (chuỗi bcrypt) dùng cho biến `BASIC_AUTH`.

### 3.2 Cài đặt (trên từng máy web-1, web-2, db-1)

Kết nối SSH từ máy cá nhân bằng key `labsuser.pem`:

1. **Learner Lab → AWS Details → Download PEM**, lưu `labsuser.pem` vào thư mục `monitoring-lab`.
2. Lấy **Public IPv4** của từng máy tại **EC2 → Instances**.
3. Trên Windows, giới hạn quyền file key một lần (nếu ssh báo *permissions too open*):
   ```powershell
   icacls labsuser.pem /inheritance:r /grant:r "${env:USERDOMAIN}\${env:USERNAME}:R"
   icacls labsuser.pem /remove:g "BUILTIN\Users" "BUILTIN\Administrators" "NT AUTHORITY\SYSTEM"
   ```
4. Chép script lên máy, SSH vào, chạy các lệnh cài đặt và kiểm tra bên dưới.
5. Lặp lại cho `web-2` và `db-1`.

> Yêu cầu: `sg-target` mở cổng **22** cho **My IP** (đã cấu hình ở Tuần 1). Nếu IP mạng nhà thay đổi, cập nhật lại rule này.

```bash
scp -i labsuser.pem node_exporter/install.sh ubuntu@<public-ip>:~
ssh -i labsuser.pem ubuntu@<public-ip>
sudo BASIC_AUTH='node_exporter: $2b$12$kveKcNaBf1tlN2rZiCMD5.uzrBhp8xALakSN56JHr8.v6mAYBxUwe' bash install.sh
systemctl status node_exporter --no-pager
curl -s -u node_exporter:admin@123 localhost:9100/metrics | grep node_cpu_seconds_total | head -3
curl -s -o /dev/null -w "%{http_code}\n" localhost:9100/metrics
```

Script [`node_exporter/install.sh`](../../node_exporter/install.sh) tải bản phát hành đúng kiến trúc CPU (amd64/arm64), tạo `/etc/node_exporter/web-config.yml` chứa user bcrypt và đăng ký systemd service `node_exporter` chạy dưới user `nobody`.

> **[ẢNH 2.5] node_exporter chạy và yêu cầu xác thực**
> - Chụp tại: **terminal SSH vào web-1**
> - Phải thấy: `systemctl status` = **active (running)**; lệnh curl có user/pass trả về metric; lệnh curl không có pass trả về **401**
> - Lưu file: `images/w2-05-node-exporter-status.png`

![Ảnh 2.5](images/w2-05-node-exporter-status.png)

## 4. Triển khai stack giám sát trên EC2 monitor

### 4.1 Cài Docker và lấy mã nguồn

```bash
ssh -i labsuser.pem ubuntu@<public-ip-monitor>
sudo apt update && sudo apt install -y docker.io docker-compose-v2 git
sudo usermod -aG docker ubuntu && newgrp docker
git clone <url-repo> monitoring-lab && cd monitoring-lab
git checkout feature/aws_project
```

### 4.2 Tạo file bí mật (không commit lên Git)

| File | Nội dung |
|---|---|
| `secrets/exporter_pass` | Mật khẩu node_exporter (dạng thường) |
| `secrets/prometheus_pass` | Mật khẩu user `admin` của Prometheus (dạng thường) |
| `secrets/slack_url` | Slack Incoming Webhook URL |
| `prometheus/web.yml` | `basic_auth_users:` + dòng `admin: <bcrypt>` sinh bằng `hashpw.py admin <mat-khau>` |
| `.env` | `GF_SECURITY_ADMIN_PASSWORD=...` và `PROM_WEB_PASS=<mat-khau-admin-prometheus>` |

Các đường dẫn trên đã nằm trong [`.gitignore`](../../.gitignore).

### 4.3 Khởi chạy

```bash
docker compose up -d
docker compose ps
```

### 4.4 Giải thích cấu hình chính

**[`docker-compose.yml`](../../docker-compose.yml)**

| Service | Cổng | Ghi chú |
|---|---|---|
| prometheus | 9090 | Bật `--web.config.file` (basic auth) và `--web.enable-lifecycle` (reload qua API) |
| alertmanager | 127.0.0.1:9093 | Alertmanager không có xác thực nên chỉ bind localhost, truy cập qua SSH tunnel |
| grafana | 2404 → 3000 | Provision sẵn datasource và dashboard |

**[`prometheus/prometheus.yml`](../../prometheus/prometheus.yml) – job `node-aws`**

| Thành phần | Ý nghĩa |
|---|---|
| `ec2_sd_configs.region / port` | Gọi API EC2 ở us-east-1, scrape cổng 9100 |
| `filters tag:Monitoring=node` | Chỉ lấy instance có tag này → thêm/bớt máy không cần sửa cấu hình |
| `filters instance-state-name=running` | Bỏ qua máy đang stopped |
| `refresh_interval: 60s` | Cập nhật danh sách target mỗi phút |
| `relabel __meta_ec2_private_ip → __address__` | Scrape qua private IP (đi trong VPC, không ra Internet) |
| `relabel __meta_ec2_tag_Name → hostname` | Hiển thị tên máy dễ đọc trên Grafana/Slack |
| `relabel instance_id, instance_type, az, project, owner` | Gắn thêm ngữ cảnh AWS vào mọi metric |

**[`prometheus/rules/node_exporter.yml`](../../prometheus/rules/node_exporter.yml)**

| Alert | Điều kiện | `for` | Severity |
|---|---|---|---|
| NodeDown | `up == 0` | 1m | critical |
| HighCPUUsage | CPU > 80% | 5m | warning |
| HighRAMUsage | RAM > 90% | 5m | warning |
| HighDiskUsage | Dung lượng trống < 20% (bỏ qua tmpfs/overlay/squashfs) | 5m | warning |
| NetworkTrafficSpike | Inbound > 5× trung bình 1h và > 10 MB/s | 5m | critical |
| HighConnectionCount | TCP established > 5000 | 5m | warning |

**[`alertmanager/alertmanager.yml`](../../alertmanager/alertmanager.yml)**

| Thành phần | Ý nghĩa |
|---|---|
| `group_by: [alertname, instance]` | Gom cảnh báo cùng loại trên cùng máy thành 1 tin |
| `group_wait: 15s` | Chờ 15s gom các alert đến cùng lúc trước khi gửi lần đầu |
| `group_interval: 1m` | Khoảng cách gửi cập nhật cho một nhóm đã gửi |
| `repeat_interval: 4h` | Nhắc lại nếu alert vẫn còn sau 4 giờ |
| `routes severity=critical` | Critical → receiver `slack-critical` (màu đỏ) |
| `inhibit_rules` | Khi có critical thì chặn warning cùng `alertname` + `instance` |
| `send_resolved: true` | Gửi thông báo khi sự cố đã hết |

> **[ẢNH 2.6] Các container đang chạy**
> - Chụp tại: **terminal SSH vào monitor**, lệnh `docker compose ps`
> - Phải thấy: prometheus, alertmanager, grafana trạng thái **Up**, cổng `0.0.0.0:9090`, `127.0.0.1:9093`, `0.0.0.0:2404`
> - Lưu file: `images/w2-06-docker-compose-ps.png`

![Ảnh 2.6](images/w2-06-docker-compose-ps.png)

## 5. Kiểm thử từng thành phần

### 5.1 Prometheus – service discovery và targets

Mở `http://<public-ip-monitor>:9090` (đăng nhập `admin`).

> **[ẢNH 2.7] Service Discovery**
> - Chụp tại: **Prometheus → Status → Service Discovery → `node-aws`** (bấm *show more*)
> - Phải thấy: Discovered labels `__meta_ec2_*` (instance_id, private_ip, tag_Name) và Target labels sau relabel
> - Lưu file: `images/w2-07-prom-service-discovery.png`

![Ảnh 2.7](images/w2-07-prom-service-discovery.png)

> **[ẢNH 2.8] Targets UP**
> - Chụp tại: **Prometheus → Status → Targets**
> - Phải thấy: job `node-aws` 3/3 **UP** (private IP 10.0.1.x:9100), job `prometheus` 1/1 UP, cột Last Scrape
> - Lưu file: `images/w2-08-prom-targets.png`

![Ảnh 2.8](images/w2-08-prom-targets.png)

> **[ẢNH 2.9] Truy vấn PromQL**
> - Chụp tại: **Prometheus → Graph**, chạy `up{job="node-aws"}` (tab Table) và `100 - (avg by (hostname) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` (tab Graph)
> - Phải thấy: 3 series có label `hostname`, `instance_id`, `instance_type`
> - Lưu file: `images/w2-09-prom-query.png`

![Ảnh 2.9](images/w2-09-prom-query.png)

> **[ẢNH 2.10] Alert rules đã nạp**
> - Chụp tại: **Prometheus → Alerts**
> - Phải thấy: 6 rule ở trạng thái Inactive (xanh)
> - Lưu file: `images/w2-10-prom-alerts.png`

![Ảnh 2.10](images/w2-10-prom-alerts.png)

### 5.2 Grafana – dashboard

Mở `http://<public-ip-monitor>:2404`, đăng nhập `admin` / mật khẩu trong `.env`.

> **[ẢNH 2.11] Datasource Prometheus hoạt động**
> - Chụp tại: **Grafana → Connections → Data sources → Prometheus → Save & test**
> - Phải thấy: thông báo **Data source is working**
> - Lưu file: `images/w2-11-grafana-datasource.png`

![Ảnh 2.11](images/w2-11-grafana-datasource.png)

> **[ẢNH 2.12] Dashboard Node Exporter Full**
> - Chụp tại: **Grafana → Dashboards → Node Exporter Full**, biến Job = `node-aws`, Host = web-1
> - Phải thấy: CPU, RAM, Disk, Network, Uptime có số liệu
> - Lưu file: `images/w2-12-grafana-dashboard.png`

![Ảnh 2.12](images/w2-12-grafana-dashboard.png)

### 5.3 Alertmanager – gửi thử cảnh báo Slack

```bash
ssh -i labsuser.pem -L 9093:localhost:9093 ubuntu@<public-ip-monitor>
docker compose exec alertmanager amtool alert add TestAlert \
  severity=warning instance=test hostname=test \
  --annotation=summary="Test alert from Alertmanager" \
  --alertmanager.url=http://localhost:9093
```

Sau đó kiểm thử thật bằng cách dừng node_exporter trên một máy:

```bash
sudo systemctl stop node_exporter
sudo systemctl start node_exporter
```

> **[ẢNH 2.13] Giao diện Alertmanager qua SSH tunnel**
> - Chụp tại: trình duyệt `http://localhost:9093` (trên máy cá nhân, đang mở tunnel)
> - Phải thấy: alert `TestAlert` hoặc `NodeDown` đang active
> - Lưu file: `images/w2-13-alertmanager-ui.png`

![Ảnh 2.13](images/w2-13-alertmanager-ui.png)

> **[ẢNH 2.14] Cảnh báo NodeDown trên Prometheus**
> - Chụp tại: **Prometheus → Alerts** khoảng 1 phút sau khi stop node_exporter
> - Phải thấy: `NodeDown` chuyển **Pending → Firing** (đỏ) cho máy bị dừng
> - Lưu file: `images/w2-14-prom-nodedown-firing.png`

![Ảnh 2.14](images/w2-14-prom-nodedown-firing.png)

> **[ẢNH 2.15] Tin nhắn Slack FIRING và RESOLVED**
> - Chụp tại: **Slack → kênh #alerts**
> - Phải thấy: tin **FIRING** NodeDown (đỏ) và tin **RESOLVED** sau khi start lại, có timestamp
> - Lưu file: `images/w2-15-slack-nodedown.png`

![Ảnh 2.15](images/w2-15-slack-nodedown.png)

### 5.4 Kiểm tra bảo mật mạng

Từ máy cá nhân, thử truy cập trực tiếp node_exporter của target qua public IP (phải bị chặn bởi sg-target):

```bash
curl -m 5 http://<public-ip-web-1>:9100/metrics
```

> **[ẢNH 2.16] Truy cập 9100 từ Internet bị chặn**
> - Chụp tại: **terminal máy cá nhân**
> - Phải thấy: `Connection timed out`
> - Lưu file: `images/w2-16-sg-blocked.png`

![Ảnh 2.16](images/w2-16-sg-blocked.png)

## 6. Kết quả tuần 2

| Hạng mục | Kết quả |
|---|---|
| 4 EC2 running, gắn LabInstanceProfile, đúng tag | ☐ |
| node_exporter có basic auth trên 3 target | ☐ |
| Stack Docker chạy ổn định | ☐ |
| Service discovery tìm thấy 3 target, tất cả UP | ☐ |
| Dashboard Grafana hiển thị đủ 3 máy | ☐ |
| Cảnh báo NodeDown gửi Slack (firing + resolved) | ☐ |
| Port 9100 không truy cập được từ Internet | ☐ |

## 7. Khó khăn và cách giải quyết

| Khó khăn | Nguyên nhân | Cách giải quyết |
|---|---|---|
| ……… | ……… | ……… |

## 8. Nhật ký công việc (Worklog)

| Ngày | Thành viên | Công việc | Số giờ |
|---|---|---|---|
| ……/…… | SV A | Tạo 4 EC2, cấu hình IMDS, EBS, kiểm tra giới hạn | … |
| ……/…… | SV A | Cài node_exporter + basic auth trên 3 target, kiểm tra SG | … |
| ……/…… | SV B | Cài Docker, tạo secrets, chạy stack, cấu hình `ec2_sd_configs` | … |
| ……/…… | SV B | Kiểm thử targets, dashboard Grafana, cảnh báo Slack | … |
| | | **Tổng SV A** | **… (≥ 8)** |
| | | **Tổng SV B** | **… (≥ 8)** |

## 9. Phần có AI hỗ trợ

| Nội dung | Công cụ AI | Mức độ | SV đã kiểm chứng |
|---|---|---|---|
| Chuyển `static_configs` sang `ec2_sd_configs` + relabel | Claude | Sinh cấu hình, SV kiểm tra trên Service Discovery | ……… |
| Sửa rule HighDiskUsage, inhibit_rules, bind 127.0.0.1 cho Alertmanager | Claude | Gợi ý sửa lỗi, SV kiểm tra bằng promtool/amtool | ……… |
| Script install.sh hỗ trợ amd64/arm64 | Claude | Sinh mã, SV chạy thử trên EC2 | ……… |

## 10. Kế hoạch tuần 3

- Bật Detailed Monitoring, cài CloudWatch Agent (RAM/Disk) trên 3 target.
- Tạo CloudWatch Dashboard, Alarm + SNS email.
- Thêm datasource CloudWatch trên Grafana.
- Kiểm thử tải bằng `stress-ng`, đo độ trễ cảnh báo của hai hệ thống.
- Viết IaC (CloudFormation) để dựng lại hạ tầng.
