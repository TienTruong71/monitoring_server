# Báo cáo Tuần 4 – Kiểm thử tổng thể, so sánh, chi phí, dọn dẹp, demo

**Đề tài:** Hệ thống giám sát mã nguồn mở Prometheus + Grafana trên AWS (Nhóm: Infrastructure)
**Thời gian:** ……/……/2026 – ……/……/2026
**Thành viên:** SV A – MSSV ……… · SV B – MSSV ………
**Region:** us-east-1 · **Account ID:** ………………

---

## 1. Mục tiêu tuần

- Kiểm thử end-to-end toàn hệ thống.
- Hoàn thiện bảng so sánh Prometheus + Grafana với Amazon CloudWatch.
- Báo cáo chi phí, đề xuất tối ưu, dọn dẹp tài nguyên.
- Hoàn thiện báo cáo, sơ đồ, video demo ≤ 10 phút.

## 2. Kiểm thử tổng thể

### 2.1 Danh sách test case

| # | Test case | Bước thực hiện | Kết quả mong đợi | Kết quả | Ảnh |
|---|---|---|---|---|---|
| TC01 | Service discovery thêm máy | Gắn tag `Monitoring=node` cho một máy đang chạy (hoặc gỡ tag của web-2) | Target xuất hiện / biến mất trong ≤ 60s | ☐ | 4.1 |
| TC02 | Máy bị stop | `Stop instance` web-2 trên console | Target biến mất khỏi danh sách (filter `running`); CloudWatch alarm INSUFFICIENT_DATA | ☐ | 4.2 |
| TC03 | Dịch vụ exporter chết | `systemctl stop node_exporter` trên db-1 | Slack NodeDown sau ~1 phút; CloudWatch vẫn OK | ☐ | 3.15 |
| TC04 | CPU cao | `stress-ng --cpu 2` trên web-1 | Slack HighCPUUsage; email SNS | ☐ | 3.11, 3.13 |
| TC05 | RAM cao | `stress-ng --vm 1 --vm-bytes 92%` trên web-2 | Slack HighRAMUsage; email SNS | ☐ | 3.14 |
| TC06 | Disk đầy | `fallocate -l 6G /tmp/fill` trên db-1 | Slack HighDiskUsage | ☐ | 4.3 |
| TC07 | Resolved | Dừng stress / xóa file | Slack RESOLVED; email OK | ☐ | 2.15 |
| TC08 | Inhibit | Có NodeDown (critical) trên một máy | Warning cùng `alertname`+`instance` không bị gửi | ☐ | – |
| TC09 | Khởi động lại monitor | `sudo reboot` máy monitor | Container tự chạy lại (`restart: unless-stopped`), dữ liệu cũ còn (volume) | ☐ | 4.4 |
| TC10 | Bảo mật | `curl <public-ip-target>:9100`; `curl <public-ip-monitor>:9093`; Prometheus không pass | Timeout / timeout / 401 | ☐ | 4.5 |

```bash
fallocate -l 6G /tmp/fill
rm /tmp/fill
```

> **[ẢNH 4.1] Service discovery khi thay đổi tag**
> - Chụp tại: **Prometheus → Status → Targets** trước và sau khi gỡ tag `Monitoring` của web-2 (ghép 2 ảnh)
> - Phải thấy: 3 target → 2 target
> - Lưu file: `images/w4-01-sd-tag-change.png`

![Ảnh 4.1](images/w4-01-sd-tag-change.png)

> **[ẢNH 4.2] Máy bị stop**
> - Chụp tại: **EC2 → Instances** (web-2 Stopped) và **Prometheus → Targets** cùng thời điểm
> - Phải thấy: web-2 không còn trong danh sách target
> - Lưu file: `images/w4-02-instance-stopped.png`

![Ảnh 4.2](images/w4-02-instance-stopped.png)

> **[ẢNH 4.3] Slack HighDiskUsage**
> - Chụp tại: **Slack → #alerts**
> - Phải thấy: FIRING `HighDiskUsage` của db-1, device `/dev/root` (hoặc `nvme0n1p1`)
> - Lưu file: `images/w4-03-slack-highdisk.png`

![Ảnh 4.3](images/w4-03-slack-highdisk.png)

> **[ẢNH 4.4] Stack tự khôi phục sau reboot**
> - Chụp tại: **terminal SSH vào monitor** sau reboot, lệnh `uptime && docker compose ps`
> - Phải thấy: uptime vài phút, 3 container Up
> - Lưu file: `images/w4-04-reboot-recovery.png`

![Ảnh 4.4](images/w4-04-reboot-recovery.png)

> **[ẢNH 4.5] Kiểm thử bảo mật**
> - Chụp tại: **terminal máy cá nhân**
> - Phải thấy: 9100 và 9093 timeout; `curl http://<ip>:9090/api/v1/targets` trả về **401 Unauthorized**
> - Lưu file: `images/w4-05-security-test.png`

![Ảnh 4.5](images/w4-05-security-test.png)

## 3. So sánh Prometheus + Grafana và Amazon CloudWatch

| Tiêu chí | Prometheus + Grafana (tự triển khai) | Amazon CloudWatch |
|---|---|---|
| Mô hình | Pull – Prometheus scrape `/metrics` | Push – hypervisor / Agent đẩy metric |
| Độ phân giải mặc định | 15 giây (`scrape_interval`) | 5 phút (basic), 1 phút (detailed, có phí) |
| RAM / Disk | Có sẵn từ node_exporter | Cần cài CloudWatch Agent (custom metric, có phí) |
| Độ trễ cảnh báo đo được (CPU) | … phút (mục 7.2 tuần 3) | … phút |
| Mức giám sát | Dịch vụ + hệ điều hành (phát hiện exporter/app chết) | Hạ tầng (máy ảo, status check); dịch vụ cần thêm custom metric |
| Ngôn ngữ truy vấn | PromQL (rate, aggregation, subquery…) | Metric Math, Metrics Insights (SQL-like) |
| Service discovery | `ec2_sd_configs` theo tag | Tự có cho mọi tài nguyên AWS |
| Kênh cảnh báo | Alertmanager: Slack, Telegram, email, webhook…; group/inhibit/silence | SNS: email, SMS, Lambda, HTTP; Chatbot cho Slack |
| Lưu trữ | Phụ thuộc EBS, mặc định 15 ngày | 15 tháng (giảm độ phân giải theo thời gian) |
| Vận hành | Tự cài, cập nhật, backup, HA | Managed, không cần bảo trì |
| Bảo mật | Tự cấu hình basic auth, SG, TLS | Tích hợp IAM |
| Đa nền tảng | On-prem, multi-cloud, Kubernetes | Chủ yếu AWS (Agent cài được on-prem) |
| Dashboard | Grafana: phong phú, kho dashboard cộng đồng, đọc được cả CloudWatch | CloudWatch Dashboard: cơ bản hơn |
| Chi phí (3 máy, 24/7) | Mục 4.2 | Mục 4.2 |
| Phù hợp | Hệ thống lớn, nhiều môi trường, cần metric ứng dụng chi tiết | Hệ thống nhỏ/vừa thuần AWS, muốn ít vận hành |

## 4. Chi phí

### 4.1 Chi phí thực tế trong Learner Lab

| Thời điểm | Số tiền đã dùng (Learner Lab) |
|---|---|
| Đầu tuần 1 | $…… |
| Cuối tuần 2 | $…… |
| Cuối tuần 4 | $…… |

> **[ẢNH 4.6] Ngân sách đã dùng trong Learner Lab**
> - Chụp tại: **trang Learner Lab (AWS Academy)**, phần trên cùng bên phải *Used $x of $50* (hoặc AWS Details)
> - Phải thấy: số tiền đã dùng, ngày giờ
> - Lưu file: `images/w4-06-learner-lab-budget.png`

![Ảnh 4.6](images/w4-06-learner-lab-budget.png)

> **[ẢNH 4.7] Chi phí theo dịch vụ (nếu Learner Lab cho phép)**
> - Chụp tại: **Billing and Cost Management → Cost Explorer**, group by **Service**, khoảng thời gian 4 tuần
> - Phải thấy: EC2-Instances, EC2-Other (EBS), CloudWatch, SNS, S3
> - Lưu file: `images/w4-07-cost-explorer.png`
> - Nếu bị chặn quyền: chụp thông báo lỗi và ghi chú "Learner Lab không cấp quyền Cost Explorer"

![Ảnh 4.7](images/w4-07-cost-explorer.png)

### 4.2 Ước tính chạy 24/7 trong 1 tháng (730 giờ, us-east-1, giá on-demand tham khảo)

| Hạng mục | Cách tính | USD/tháng |
|---|---|---|
| EC2 monitor t3.medium | 730 × $0.0416 | ~30.37 |
| EBS monitor 20 GB gp3 | 20 × $0.08 | ~1.60 |
| **Chi phí riêng của Prometheus + Grafana** | | **~31.97** |
| Detailed Monitoring 3 máy | 3 × 7 metric × $0.30 | ~6.30 |
| Custom metric CWAgent | 9 metric × $0.30 | ~2.70 |
| CloudWatch Alarms | 9 alarm × $0.10 | ~0.90 |
| CloudWatch Dashboard | 3 dashboard đầu miễn phí | 0.00 |
| SNS email | 1.000 email đầu miễn phí | 0.00 |
| **Chi phí riêng của CloudWatch** | | **~9.90** |
| 3 máy target t3.micro + 24 GB gp3 *(chung cho cả hai)* | 3 × 730 × $0.0104 + 24 × $0.08 | ~24.70 |

Giá trên lấy theo bảng giá công khai; kiểm tra lại bằng **AWS Pricing Calculator** và đính kèm link estimate.

> **[ẢNH 4.8] AWS Pricing Calculator**
> - Chụp tại: `https://calculator.aws/` → *My Estimate* sau khi thêm EC2, EBS, CloudWatch, SNS
> - Phải thấy: tổng chi phí tháng theo từng dịch vụ, region us-east-1
> - Lưu file: `images/w4-08-pricing-calculator.png`

![Ảnh 4.8](images/w4-08-pricing-calculator.png)

**Nhận xét:** với quy mô 3 máy, CloudWatch rẻ hơn vì Prometheus cần một EC2 riêng. Chi phí CloudWatch tăng tuyến tính theo số máy và số metric, trong khi một máy Prometheus t3.medium có thể giám sát hàng trăm target, nên Prometheus có lợi hơn khi số máy lớn hoặc cần nhiều metric chi tiết.

### 4.3 Tối ưu chi phí

| Biện pháp | Tác động |
|---|---|
| Stop toàn bộ EC2 sau mỗi buổi lab | Chỉ trả EBS khi không dùng |
| Hạ máy monitor xuống t3.small khi tải thấp | Giảm ~50% chi phí EC2 monitor |
| Giới hạn `--storage.tsdb.retention.time` | Giảm dung lượng EBS cần dùng |
| Chỉ bật Detailed Monitoring / Agent cho máy cần so sánh | Giảm custom metric |
| Dùng CloudFormation để xóa / dựng lại nhanh | Không để sót tài nguyên tính phí |

## 5. Dọn dẹp tài nguyên

| # | Tài nguyên | Thao tác | Đã xóa |
|---|---|---|---|
| 1 | CloudWatch Alarms | CloudWatch → Alarms → chọn tất cả → Delete | ☐ |
| 2 | CloudWatch Dashboard | Dashboards → Delete | ☐ |
| 3 | SNS topic + subscription | SNS → Topics → Delete | ☐ |
| 4 | 4 EC2 | EC2 → Instances → Terminate (EBS root tự xóa) | ☐ |
| 5 | EBS volume / snapshot còn sót | EC2 → Volumes / Snapshots | ☐ |
| 6 | Elastic IP (nếu có) | EC2 → Elastic IPs → Release | ☐ |
| 7 | S3 bucket | Empty → Delete | ☐ |
| 8 | Security Groups, VPC | VPC → Your VPCs → Delete VPC (xóa kèm subnet, IGW, route table) | ☐ |
| 9 | CloudFormation stack (nếu dùng) | `aws cloudformation delete-stack --stack-name prom-monitoring` | ☐ |

> **[ẢNH 4.9] EC2 đã terminate**
> - Chụp tại: **EC2 → Instances** (bỏ filter mặc định để thấy cả máy đã terminate)
> - Phải thấy: 4 máy trạng thái **Terminated**, Account ID, Region
> - Lưu file: `images/w4-09-ec2-terminated.png`

![Ảnh 4.9](images/w4-09-ec2-terminated.png)

> **[ẢNH 4.10] Không còn volume và VPC**
> - Chụp tại: **EC2 → Volumes** và **VPC → Your VPCs** (ghép 2 ảnh)
> - Phải thấy: không còn volume của đề tài, chỉ còn default VPC
> - Lưu file: `images/w4-10-cleanup-ebs-vpc.png`

![Ảnh 4.10](images/w4-10-cleanup-ebs-vpc.png)

> **[ẢNH 4.11] Tag Editor sau khi dọn dẹp**
> - Chụp tại: **Resource Groups & Tag Editor → Tag Editor**, tìm tag `Project = prom-monitoring`
> - Phải thấy: *No resources found*
> - Lưu file: `images/w4-11-tag-editor-empty.png`

![Ảnh 4.11](images/w4-11-tag-editor-empty.png)

## 6. Video demo (≤ 10 phút)

| Phút | Nội dung | Màn hình |
|---|---|---|
| 0:00–1:00 | Giới thiệu đề tài, sơ đồ kiến trúc, 8 luồng | `docs/architecture.png` |
| 1:00–2:00 | Console: Account ID, Region, 4 EC2, tag, SG | EC2 → Instances, Security Groups |
| 2:00–3:00 | Prometheus: Service Discovery, Targets UP, Alerts | Prometheus UI |
| 3:00–4:30 | Grafana: Node Exporter Full, dashboard so sánh | Grafana |
| 4:30–6:30 | Chạy stress-ng → Slack FIRING → RESOLVED | Terminal + Slack |
| 6:30–8:00 | CloudWatch Dashboard, Alarm, email SNS | CloudWatch, hộp thư |
| 8:00–9:00 | Dừng node_exporter: Prometheus báo, CloudWatch không báo | Slack + CloudWatch |
| 9:00–10:00 | Bảng so sánh, chi phí, kết luận | Báo cáo |

Link video: ………………

## 7. Kết luận

**Kết quả đạt được:**
- Triển khai Prometheus + Grafana + Alertmanager bằng Docker trên EC2, giám sát 3 EC2 qua node_exporter với service discovery theo tag.
- Cảnh báo Slack hoạt động cho 6 rule (node, CPU, RAM, Disk, network).
- Triển khai CloudWatch song song và so sánh bằng số liệu đo thực tế.
- Tuân thủ giới hạn Learner Lab: 4 EC2, 8 vCPU, 44 GB gp3, chỉ dùng LabInstanceProfile, gắn tag đầy đủ.

**Hạn chế:** ………
**Hướng phát triển:** HA cho Prometheus (2 replica hoặc Thanos/Amazon Managed Prometheus), TLS cho Grafana qua ALB/ACM, giám sát ứng dụng bằng exporter riêng (nginx, mysql), Blackbox exporter cho kiểm tra HTTP.

## 8. Danh sách sản phẩm nộp

| Sản phẩm | Vị trí | Trạng thái |
|---|---|---|
| Mã nguồn / cấu hình | Repo Git, nhánh `feature/aws_project` | ☐ |
| Sơ đồ kiến trúc | `docs/architecture.drawio`, `docs/architecture.png` | ☐ |
| Báo cáo 4 tuần | `docs/reports/week1.md` → `week4.md` | ☐ |
| Ảnh minh chứng | `docs/reports/images/` | ☐ |
| Bảng so sánh với CloudWatch | Mục 3 | ☐ |
| Báo cáo chi phí | Mục 4 | ☐ |
| Video demo ≤ 10 phút | Link mục 6 | ☐ |

## 9. Nhật ký công việc (Worklog)

| Ngày | Thành viên | Công việc | Số giờ |
|---|---|---|---|
| ……/…… | SV A | Kiểm thử TC01–TC05, đo chi phí, Pricing Calculator | … |
| ……/…… | SV A | Dọn dẹp tài nguyên, viết phần chi phí và so sánh | … |
| ……/…… | SV B | Kiểm thử TC06–TC10, bảng so sánh | … |
| ……/…… | SV B | Tổng hợp báo cáo, quay và dựng video demo | … |
| | | **Tổng SV A** | **… (≥ 8)** |
| | | **Tổng SV B** | **… (≥ 8)** |

**Tổng 4 tuần:** SV A …… giờ · SV B …… giờ

## 10. Phần có AI hỗ trợ

| Nội dung | Công cụ AI | Mức độ | SV đã kiểm chứng |
|---|---|---|---|
| Khung báo cáo 4 tuần, danh sách ảnh minh chứng | Claude | Sinh khung, SV điền số liệu thực tế | ……… |
| Bảng so sánh, ước tính chi phí | Claude | Tham khảo, SV đối chiếu Pricing Calculator | ……… |
