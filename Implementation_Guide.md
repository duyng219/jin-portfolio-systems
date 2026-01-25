# JINLABS v2.1.0 - Implementation

## Bắt đầu Implementation
### Option 1: Bắt đầu với JINPA (Manual Trading)
```
1. Navigate: JINLABS/JINPA/
2. Điền SPEC_JINPA-SYSTEM.md
3. Implement _core/managers/
4. Code jinpa-manual.mq5
5. Config configs/*.json
6. Test
```
### Option 2: Bắt đầu với JINQA (Algo Trading)
```
1. Chọn subsystem: MR, MO, hoặc TF
2. Navigate: JINLABS/JINQA/MR/stra101-mr-revs/
3. Điền SPEC_stra101-mr-revs.md
4. Implement setups/
5. Code orchestration
6. Config JINQA/configs/
7. Backtest
```

## Tài liệu Tham khảo
Xem `ARCHITECTURE_REVISED.md` để hiểu:
- Triết lý thiết kế
- Quy ước đặt tên
- Include patterns
- Development workflow
- Best practices

## Lưu ý Quan trọng
1. **JINPA và JINQA độc lập**
   - Mỗi hệ thống có _core/ riêng
   - KHÔNG share code giữa hai hệ thống
2. **Subsystems độc lập**
   - MR, MO, TF hoạt động riêng biệt
   - Mỗi subsystem có logic regime riêng
   - _shared/ chưa dùng (reserved)
3. **Follow naming conventions**
   - EA files: dấu gạch ngang (-)
   - Include files: dấu gạch dưới (_)
   - Xem ARCHITECTURE.md section 3
4. **Git workflow**
   - .gitignore đã setup
   - logs/ và *.ex5 sẽ bị ignore
   - Commit code, không commit logs

---

**Version**: 2.1.0  
**Created**: 2026-01-23  
**Author**: DuyQuant
