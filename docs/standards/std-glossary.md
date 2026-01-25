---
created: 2026-01-25
scope: JINLABS / Glossary
muc_dich: Định nghĩa chuẩn thuật ngữ để người và AI hiểu đúng
---

# Từ điển thuật ngữ JINLABS (Glossary)

## 1. Left-tail / Right-tail
- Left-tail (đuôi trái): các kịch bản thua lỗ cực đoan, kéo tài khoản vào drawdown sâu hoặc “chết hệ”.
- Right-tail (đuôi phải): các kịch bản thắng lớn, “outlier wins”, là nguồn lợi nhuận chính của hệ bất đối xứng.
- Triết lý JINLABS: chặn left-tail bằng risk gate + SL-based exposure; mở right-tail bằng cách để lệnh thắng chạy, không giới hạn lợi nhuận.

## 2. Bất đối xứng (Asymmetry)
- “Mất ít khi sai, ăn nhiều khi đúng”.
- Không phải “ăn nhiều bằng cách tăng khối lượng khi đang thua”.
- Bất đối xứng đúng: risk nhỏ, lợi nhuận có thể lớn, kỳ vọng dương khi mẫu đủ lớn.

## 3. Edge (lợi thế kỳ vọng)
- Edge = Expected Value dương bền vững dưới chi phí thực tế.
- Edge không phải cảm giác, không phải 1 chuỗi thắng ngắn.
- Edge phải nhìn bằng phân phối, tail behavior, và ổn định theo thời gian/regime.

## 4. EV (Expected Value)
- EV/trade: kỳ vọng trung bình mỗi lệnh.
- Có thể đo bằng PnL hoặc R-multiple.
- EV dương nhưng không ổn định / dễ sập khi tính chi phí => edge yếu hoặc overfit.

## 5. R-multiple (R)
- R = PnL / Risk_initial.
- Risk_initial thường là khoảng cách Entry đến SL nhân với giá trị tick và volume.
- R giúp so sánh các lệnh công bằng giữa các khối lượng/tài sản khác nhau.

## 6. PF (Profit Factor)
- PF = tổng lãi / tổng lỗ.
- PF cao nhưng chỉ dựa vào ít lệnh hoặc tail quá dày => không đáng tin.
- PF phải đi kèm: số lệnh đủ lớn + DD/tail trong giới hạn.

## 7. Drawdown (DD) & Time Under Water
- DD: mức giảm từ đỉnh equity xuống đáy tạm thời.
- Time under water: thời gian cần để hồi lại đỉnh.
- JINLABS coi DD là “chi phí tồn tại”. DD vượt trần = vi phạm triết lý.

## 8. Sequence Risk (rủi ro chuỗi)
- Cùng một tập lệnh, nhưng thứ tự thắng/thua khác nhau tạo DD khác nhau.
- Monte Carlo / resampling dùng để đo rủi ro này.
- Mục tiêu: hệ phải “sống được” với kịch bản xấu hợp lý, không phải đẹp trên backtest.

## 9. Tail Risk
- Rủi ro từ các sự kiện hiếm nhưng phá hệ (fat tails, gap, spike).
- Tail risk không được “giải” bằng gỡ lỗ; phải chặn bằng cấu trúc risk + execution controls.

## 10. Regime (chế độ thị trường)
- Strong trend: xu hướng mạnh, chạy dài.
- Weak trend: xu hướng yếu, hồi nhiều, dễ whipsaw.
- Sideways: dao động, mean reversion hoặc breakout giả.
- Portfolio of systems: phân bổ hệ theo nhiều regime để giảm tương quan và ổn định equity curve.

## 11. Diversification / Không tương quan
- Triết lý JINLABS: tránh drawdown đồng pha, thay vào đó **ghép nhiều hệ ít tương quan** để đạt hiệu suất bền vững ở cấp portfolio.
- Đa dạng hóa đúng: khác regime + khác logic + khác driver lợi nhuận, không chỉ đổi điểm vào.
- “Không tương quan” thực chiến: chuỗi lệnh/return không đồng pha trong drawdown.
- Mục tiêu: giảm xác suất “tất cả cùng chết một lúc”.

## 12. Gate (cổng chặn)
- Gate = điều kiện bắt buộc trước khi cho phép hành động tăng rủi ro.
- Gate quan trọng nhất: SessionGate, RiskGate (SL-based), PositionGate (BE/profit protection).
- Mọi gate phải log: allowed/block + reason + số liệu.

## 13. SL-based exposure (rủi ro theo SL)
- Tổng rủi ro tiềm năng = Σ (khoảng cách tới SL * tick value * volume).
- Là định nghĩa rủi ro “thật” để chặn over-leverage.
- Nếu không có SL hoặc SL không hợp lệ => coi như rủi ro không kiểm soát.

## 14. Overfit
- Hệ “hợp quá” với dữ liệu quá khứ: đẹp trong backtest nhưng sập khi forward.
- Dấu hiệu: EV_out lệch mạnh; entry mismatch; R distribution bị méo; chi phí làm edge biến mất.
- Cách xử: đơn giản hóa, tăng robustness, test phân đoạn, stress MC, không “tối ưu thêm”.

## 15. Drift (lệch hành vi)
- Drift = hệ thay đổi chất lượng theo thời gian: EV giảm, tail dày lên, slippage tăng, entry lệch.
- Drift không phải “xui”. Drift là tín hiệu cần pause/điều tra.
- Realtime tracking phải có ngưỡng cảnh báo và kill-switch.

## 16. Go/No-Go
- Go: đạt tiêu chí hard trong forward + rủi ro nằm trong trần.
- No-Go: fail bất kỳ hard criterion nào.
- Paper-Extend: chưa đủ mẫu hoặc chưa chắc chắn, kéo dài forward/paper để thu thêm dữ liệu.