---
created: 2026-01-25
scope: JINLABS / Metrics
muc_dich: Spec tối thiểu cho hệ 15 metrics
---

# 15 Metrics (Spec tối thiểu)

## A) Edge & Expectancy (lợi thế)
1) EV_per_trade: kỳ vọng mỗi lệnh (PnL hoặc R)
2) ProfitFactor (PF): tổng lãi / tổng lỗ
3) Avg_R: trung bình R-multiple
4) Winrate: tỷ lệ thắng
5) Payoff: AvgWin / AvgLoss

## B) Risk & Tail (đuôi rủi ro)
6) MaxDrawdown (giá trị & %)
7) Thời gian hồi DD (DD duration / time under water)
8) Max Losing Streak (chuỗi thua dài nhất)
9) TailLoss Quantiles (ví dụ 5% lệnh tệ nhất theo R)
10) DD severity metric (Ulcer Index hoặc tương đương; nếu tối giản có thể để optional)

## C) Execution & Realism (thực chiến)
11) Spread thực trả (effective)
12) Slippage (mean & worst-case)
13) Swap impact (tổng swap / theo ngày / theo lệnh)

## D) Stability & Robustness (ổn định)
14) Rolling EV Stability (rolling window mean/variance)
15) Segment Consistency (hiệu suất theo năm/regime bucket)

## Thứ tự tính (dependency)
- Cần dữ liệu per-trade: PnL và R trước.
- Tính EV/PF/winrate/payoff.
- Tính equity curve -> DD + streak.
- Tính rolling + phân đoạn (year/regime).

## Format report tối thiểu cho mỗi metric
- value | threshold | diễn giải | dấu hiệu hỏng | hành động