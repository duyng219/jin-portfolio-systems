# JINQA - Algorithmic Trading System

> **Hệ thống Giao dịch Tự động Theo Thuật toán**  
> Multiple Strategies + Risk Management + Analytics

---

## Giới thiệu
JINLABS/JINQA (JIN QUANT ALGORITHMIC) là Portfolio các chiến lược tự động, gồm 3 subsystems độc lập:
  - MR (Mean Reversion) → Thị trường sideway/ranging
  - MO (Momentum) → Thị trường breakout
  - TF (Trend Following) → Thị trường trending
Đây là một kiến ​​trúc giao dịch dựa trên "danh mục các hệ thống giao dịch": nó không cố gắng tạo ra một chiến lược duy nhất để giao dịch trong mọi điều kiện thị trường, mà phân tách nó thành nhiều hệ thống con, mỗi hệ thống được tối ưu hóa cho một trạng thái (regime) cụ thể. 
Triết lý cốt lõi: Thị trường là một hệ thống phi tuyến tính và nhiễu là điều mặc định, lợi thế không đến từ việc dự đoán chính xác mọi giao dịch, mà đến từ giao dịch tại “vùng bất đối xứng kỳ vọng” (edge of expectation asymmetry), đi theo bối cảnh phù hợp với chu kỳ thị trường (cycle/regime/phase), quản lý rủi ro (risk sizing) phù hợp, cắt rủi ro đuôi trái (right-tail risk) thật nhanh và khai thác đuôi phải (left-tail), và lặp lại quy trình nhiều lần bằng quy luật số lớn (the law of large numbers).

