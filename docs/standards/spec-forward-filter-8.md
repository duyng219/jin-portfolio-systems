---
created: 2026-01-25
scope: JINLABS / Forward Filter
muc_dich: Bộ lọc Go/No-Go trước khi đưa realtime
---

# Forward Test Validation Filter (8 tiêu chí)

## Luật cứng
Fail 1 tiêu chí hard -> NO-GO.
Không được “bù” bằng cách tăng rủi ro hay gỡ lỗ.

## Template bảng đánh giá (bắt buộc)
Các cột:
- tiêu_chí | đo_lường | ngưỡng | pass/fail | ghi_chú | hành_động

## 8 tiêu chí

1) EV trên 30 lệnh gần nhất (hard)
- Đo: EV_30
- Ngưỡng: > 0 (hoặc > buffer dương sau khi trừ chi phí)

2) Độ lệch EV_out so với EV_backtest (hard)
- Đo: |EV_out - EV_bt| / |EV_bt|
- Ngưỡng: <= X% (mặc định bảo thủ: 30–50%, tùy system)

3) Rolling Edge Stability (hard)
- Đo: rolling EV variance + tần suất EV lật âm
- Ngưỡng: không lật âm quá thường xuyên; variance không “nổ”

4) Entry Match Rate (hard)
- Đo: tỷ lệ entry forward khớp logic backtest
- Ngưỡng: >= Y% (gợi ý 85–95% tùy độ phức tạp)

5) Slippage (hard)
- Đo: slippage mean + worst-case so với model
- Ngưỡng: nằm trong biên mô hình; worst-case không phá hệ

6) Run-up Consistency (soft -> có thể nâng thành hard)
- Đo: MFE distribution (forward vs backtest)
- Ngưỡng: không xấu đi mạnh kiểu “profit vanish”

7) R Distribution (hard)
- Đo: histogram R + tail behavior
- Ngưỡng: left-tail không dày lên đáng kể; median/mean không sập

8) Ổn định PF / Winrate / RR (hard)
- Đo: PF_out, WR_out, AvgR_out theo thời gian
- Ngưỡng: nằm trong band drift cho phép

## Output bắt buộc cuối cùng
- Bảng 8 tiêu chí (đủ cột)
- Kết luận: GO / NO-GO / PAPER-EXTEND
- Next actions (tối đa 3 việc) nếu NO-GO