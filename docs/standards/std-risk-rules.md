---
created: 2026-01-25
scope: JINLABS / Risk
muc_dich: Luật rủi ro cứng cho tất cả hệ thống
---

# Luật rủi ro (Hard Constraints)

## 1) Nguyên lý cốt lõi
Cắt left-tail trước: mọi rủi ro phải bị chặn bởi ngưỡng rõ ràng.
Mở right-tail sau: để lợi nhuận chạy bằng quản lý lệnh thắng, không phải bằng “gỡ lỗ”.

## 2) Ngưỡng mặc định (có thể cấu hình nhưng phải explicit)
- Trần rủi ro tổng (các lệnh đang mở): 5% Equity (mặc định).
- Trần drawdown tháng bạn chịu được: < 30% (coi như hard gate khi deploy).
- Rủi ro mỗi lệnh: parameter hóa (ví dụ 0.1%–1.0%), mặc định bảo thủ.

## 3) Định nghĩa rủi ro (bắt buộc dùng SL-based)
Với mỗi lệnh i:
- Risk_i = |Entry_i - SL_i| * Giá trị tick đã điều chỉnh * Volume_i
Tổng rủi ro tiềm năng:
- TotalPotentialRisk = Σ Risk_i

Gate mở lệnh mới:
- Nếu TotalPotentialRisk + NewTradeRisk > Equity * TotalRiskCap -> CHẶN

## 4) Các cổng chặn bắt buộc (Required Gates)
- Gate A: Lệnh mới phải có StopLoss (trừ khi hệ thống có cơ chế hard-stop khác và được định nghĩa rõ).
- Gate B: Tổng rủi ro theo SL không vượt cap.
- Gate C: Multi-position chỉ được mở nếu lệnh trước đã “được bảo vệ”:
  - Buy: SL >= Entry (hoặc trailing stop đã ở profit)
  - Sell: SL <= Entry (hoặc trailing stop đã ở profit)
- Gate D (khuyến nghị): Cổng chi phí giao dịch:
  - Chặn nếu spread/commission/slippage vượt ngưỡng cho phép.

## 5) Kill Switch (dừng khẩn)
Dừng mở lệnh mới nếu:
- Equity DD vượt ngưỡng cấu hình.
- Chuỗi thua vượt ngưỡng + volatility regime bất thường (định nghĩa rõ theo system).
- Trade context lỗi lặp lại (OrderSend fail, invalid stops, requote…) quá số lần.

## 6) Logging bắt buộc cho mọi gate
Mỗi lần gate phải log:
- gate_name, allowed/block, reason_code
- Equity, TotalPotentialRisk, NewTradeRisk, cap_value
- pos_count, symbol, strategy_id, session_id