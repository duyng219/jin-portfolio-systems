---
created: 2026-01-25
scope: JINLABS / Research-Eval
muc_dich: Pipeline đánh giá từ ý tưởng -> realtime
---

# Pipeline Đánh Giá (Tối thiểu)

## Stage 0: Giả thuyết & loại hệ thống
- Xác định: regime mục tiêu (strong trend / weak trend / sideways)
- Xác định: entry/exit + SL/TP/trailing
- Xác định: “cơ chế edge” (mất cân bằng cung-cầu, hành vi, cấu trúc thị trường), không kể chuyện.

## Stage 1: Quick Backtest (lọc rác)
Output tối thiểu:
- số lệnh, EV/trade, PF, winrate, AvgR, max DD
Gate:
- quá ít lệnh / EV yếu / không ổn định -> dừng hoặc refine

## Stage 2: Deep Backtest (mô hình chi phí thực tế)
Input:
- dataset sạch (ví dụ 2020–2025)
- chi phí: spread + commission + slippage + swap
Output:
- bảng phân phối R, streak, DD, MAE/MFE, time-in-trade
Gate:
- edge biến mất khi tính chi phí -> loại

## Stage 3: Monte Carlo / Resampling Stress
Mục tiêu:
- đo sequence risk + tail behavior (đặc biệt left-tail)
Output:
- worst-case DD theo percentile, longest losing streak theo percentile, proxy ruin risk
Gate:
- nếu tail risk vi phạm constraint -> loại hoặc thiết kế lại (không “gỡ lỗ”)

## Stage 4: Forward Test Filter (8 tiêu chí)
Mục tiêu:
- phát hiện overfit + mismatch execution
Output:
- bảng chấm điểm + Go/No-Go
Gate:
- fail hard criteria -> NO-GO

## Stage 5: Realtime Tracking
Mục tiêu:
- theo dõi drift, tái kiểm định định kỳ, kill-switch
Output:
- báo cáo tuần/tháng + cảnh báo lệch EV/ổn định
Gate:
- drift vượt ngưỡng -> pause + điều tra