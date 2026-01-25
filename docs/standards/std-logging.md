---
created: 2026-01-25
scope: JINLABS / Logging
muc_dich: Log có cấu trúc để debug + audit + phân tích thống kê
---

# Logging Spec (Tối thiểu)

## 1) Mục tiêu
- Giải thích được: vì sao trade được phép hay bị chặn.
- Quan sát được: tái hiện được quyết định khi debug/live.
- Phân tích được: log parse được để thống kê sau này.

## 2) Level
- ERROR: lỗi thực thi, trade context lỗi, tham số sai
- WARN: trade bị chặn bởi gate, trạng thái bất thường
- INFO: sự kiện quan trọng (session start/stop, order placed/modified/closed, gate quyết định)
- DEBUG: chi tiết per-tick/per-bar (phải throttle để tránh spam)

## 3) Định danh phiên (Session & Run)
- session_id: tạo theo ngày hoặc theo lần chạy EA
- run_id: id duy nhất mỗi lần OnInit (tuỳ chọn)
- strategy_id: sysXX / straXXX

## 4) Format log (key=value, mỗi dòng 1 event)
Ví dụ:
ts=2026-01-25T21:10:00+09:00 level=INFO eid=JINLABS session_id=20260125-01 strategy_id=stra101 symbol=BTCUSD action=GATE_CHECK allowed=false reason=RISK_CAP equity=10000 risk_total=620 risk_new=120 cap=500

## 5) Field bắt buộc (minimum)
- ts, level, eid, session_id, strategy_id, symbol
- action, allowed, reason
- equity, risk_total, risk_new, cap
- pos_count, spread
- last_error (chỉ khi ERROR)

## 6) File logging
- Ghi ra: MQL5/Files/JINLABS/logs/
- Tên file: {eid}_{symbol}_{YYYYMMDD}_{session_id}.log
- Rotation: theo ngày là đủ

## 7) Quy tắc log
- Mọi gate phải log ở INFO hoặc WARN.
- Mọi thao tác trade phải log trước và sau.
- ERROR phải kèm last_error + function/context.