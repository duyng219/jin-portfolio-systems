---
created: 2026-01-25
scope: JINLABS / Foundations
system_id: SYS01
doc_type: discretionary_baseline
source: notion_export_cleaned
original_title: stra01-jinpa-core
loai_giao_dich: Cấu trúc + Hành vi giá + Khối lượng
quant_qual: Qual
status: Thử nghiệm
ten_chien_luoc: Ji Price Action
version: 1
---

# SYS01 — JINPA Core (Price Action)

***Ghi chú chiến lược***
- **Thiết lập giao dịch chất lượng** là tìm kiếm các vùng giá có sự **chênh lệch rõ ràng** giữa lực mua và lực bán, sau đó giao dịch theo hướng của xung lực đang gia tăng và thắng thế.
    - **Kỳ vọng lợi nhuận:** Giao dịch chất lượng phải có khả năng tạo ra **lợi nhuận ngay lập tức** (immediate profit potential).
    - **Đồng thuận thị trường:** Các vùng giá này thường là nơi sự đồng thuận của thị trường được hình thành, dẫn đến sự xuất hiện của một xu hướng rõ ràng.
    **Vị trí vào lệnh tối ưu** (Vị trí trong sóng)
    - **Vị trí tốt nhất:** Nên tìm kiếm điểm vào lệnh tại **khu vực nửa đầu của con sóng** hoặc **ngay sau khi con sóng vừa bắt đầu**. Đây là những vùng cung cấp lợi nhuận tiềm năng tối đa.
    - **Vị trí kém:** Những điểm vào lệnh nằm ở cuối con sóng sẽ không mang lại lợi nhuận tốt và không cung cấp lợi thế đủ mạnh để vượt qua chi phí giao dịch.
    - **Vùng giá buôn (Giá tốt):** Là các khu vực gần điểm bắt đầu của con sóng (thường là các vùng tích lũy/hỗ trợ/kháng cự mạnh). Xây dựng vị thế tại đây sẽ mang lại lợi nhuận tối đa, mặc dù rất khó thực hiện.
    **Khu vực vào lệnh tối ưu trên khung nhỏ**
    - **Tại vùng giá buôn (khung lớn):** Tương ứng với trạng thái đi ngang hoặc tích lũy trên khung nhỏ.
    - **Giai đoạn đầu sóng (khung lớn):** Tương ứng với một **xu hướng mới được hình thành** trên khung thời gian nhỏ.
    **Tổng kết:** Thiết lập giao dịch dựa trên **hành động giá** phải đảm bảo chọn lọc những cơ hội tại nơi có sự **mất cân bằng xung lực rõ ràng**. Quan trọng nhất là phải vào lệnh ở vị trí càng gần **điểm bắt đầu của con sóng** càng tốt (tại các vùng giá buôn hoặc khi xu hướng mới hình thành trên khung giao dịch) để tối đa hóa lợi thế và lợi nhuận tiềm năng.

![Group 29.png](stra01-jinpa-core/Group_29.png)

## **INPUT**
*(Xác định giao dịch, tìm kiếm, chờ đợi các tín hiệu thị trường, đáp ứng được tất cả các rule trong system)*

### 1. **Xác định cấu trúc chu kỳ** (multi-TF)
***Giá đã từng đi đâu (cấu trúc quá khứ)? Giá đang ở đâu (cấu trúc hiện tại)? → Thiết lập ngưỡng Swing Core (high/low) & Bắt đầu chu kỳ đầu tiên***

*(Trend (tăng/giảm)? Or Sideway? .. Sóng đẩy? Sóng điều chỉnh? Vừa break cấu trúc?)
(**Chu kỳ giá (tăng/giảm)** bắt đầu khi **đảo chiều**, kết thúc khi **đảo chiều** lần tiếp theo)*

- Docs
    1. **Xác định xu hướng thị trường bằng cấu trúc giá**
        1. **Xu hướng tăng:** Các đỉnh cao hơn và đáy cao hơn, sóng đẩy dài hơn sóng điều chỉnh. Kết thúc khi giá phá vỡ đáy của con sóng tạo ra đỉnh cao nhất. (Xu hướng là khái niệm **tương đối theo cấp độ quan sát**.)
            **2 điểm xoay thấp** không phá được đỉnh trước đó → **Sideway**
        2. **Xu hướng giảm:** Các đáy thấp hơn và đỉnh thấp hơn, sóng đẩy dài hơn sóng điều chỉnh. Kết thúc khi giá phá vỡ đỉnh của con sóng tạo ra đáy thấp nhất.
            **2 điểm xoay cao** không phá được đáy trước đó → **Sideway**
        3. **Sideway:** Chuyển sang đi ngang khi sau bốn điểm xoay (bao gồm cao & thấp), không vượt được đỉnh cao nhất của xu hướng tăng hoặc đáy thấp nhất của xu hướng giảm. Giá sẽ di chuyển trong phạm vi của con sóng tạo ra điểm xoay cuối cùng đó. (Có thể được gọi là **sóng điều chỉnh phức tạp** của 1 xu hướng)
    2. **Xác định xu hướng thị trường bằng đa khung thời gian (Tính chất phân dạng)**
        1. **Sóng đẩy** của khung lớn (D1) thường tương ứng với một **xu hướng mạnh** trong khung nhỏ (H1).
        2. **Sóng điều chỉnh** của khung lớn (D1) thường tương ứng với một **xu hướng yếu** hoặc **đi ngang** trong khung nhỏ (H1).
    3. **Nhận diện trạng thái giá hiện tại**
        **Giai đoạn Tích lũy (Accumulation) → Bùng nổ (Expansion / Breakout) → Xu hướng (Trend / Impulse Move) → Điều chỉnh (Correction / Pullback) → Đi ngang (Range / Sideway) →** Lại tích lũy.
    4. **Sơ đồ chuẩn:**
        ***Market Model = 2 Chu kỳ** (Tăng - Giảm) → **3 Trạng thái** (Đi ngang - Xu hướng mạnh - Xu hướng yếu) → **4 Giai đoạn** (Nén - Mở rộng - Xung lực - Điều chỉnh) → **6 Thiết lập** (**2 Breakout:** Phá vỡ phạm vi - Phá vỡ tiếp diễn & **4 Reversal:** Đảo chiều sóng đơn - Đảo chiều sóng kép - Đảo chiều sóng từ chối tại biên -  Đảo chiều sóng phá vỡ giả tại biên)*
        1.  **Cycle (Chu kỳ hướng) = 2**
            •	**Bull cycle** (chu kỳ tăng)
            •	**Bear cycle** (chu kỳ giảm)
            - Đổi Cycle chỉ khi thỏa **2 bước**:
                1. **CLOSE** phá core swing + buffer
                2. Sau đó giá **giữ được +** **đóng thêm 1 nến** cùng phía,
            → Cycle chỉ nói **hướng lớn**: tăng hay giảm.
            **IF** cấu trúc HH–HL → **Bull cycle** (ưu tiên Buy setups)
            **IF** cấu trúc LL–LH → **Bear cycle** (ưu tiên Sell setups)
            **IF** không rõ → coi như **Range của chu kỳ nào** / đứng ngoài
        2.  **Regime (Trạng thái thị trường) = 3**
            •	**Range** (đi ngang)
            •	**Trend mạnh**
            •	**Trend yếu**
            → Regime trả lời: “Thị trường **dễ theo đà** hay **dễ hồi/đảo**?”
        3.  **Phase (Giai đoạn hành vi giá) = 4**
            •	**Compression (Nén)**
            •	**Expansion (Mở rộng)**
            •	**Impulse (Xung lực / chạy)**
            •	**Correction (Điều chỉnh / hồi)**
            → Phase trả lời: “Giá đang **co**, **nổ**, **chạy**, hay **hồi**?”

### **2. Nhận diện trạng thái, giai đoạn (market state module) & Kỳ vọng tiếp theo**
**2 CHU KỲ (CYCLE) → 3 TRẠNG THÁI (REGIME) → 4 GIAI ĐOẠN (PHASE) → 6 THIẾT LẬP (SETUPS)**
*Mỗi phase ưu tiên 1–2 setup chính, còn lại là nhánh phụ.*

**(1) RANGE – NÉN (Compression / Range) *→ “**Kỳ vọng Breakout”*

- (if) Event-Test biên mà **không close ngoài biên +** có rejection → ***revs-pmr***
- (if) **Có break biên** rồi rút mạnh vào lại range → ***revs-pfb***
- (if) Range **nén sát biên** (build-up) **và** có **close ngoài biên + giữ được** → ***bres-pmb →*** **chuyển sang Phase (2)**

**→** *(setup) Chỉ giao dịch quanh biên(vùng buôn, cơ hội). ****Không chase giữa range. Ưu tiên (1st) **revs-pmr →** (2nd) **revs-pfb**. Khi thấy “nén sát biên”, chuyển sang mindset **chuẩn bị mở rộng/breakout** với (3rd) **bres-pmb** **→** (4th) **Reset / bỏ:** biên không rõ, range nhiễu, hoặc giá đi giữa range không phản ứng ở biên.*

**(2) RANGE – MỞ RỘNG (Expansion / Breakout khỏi range) → “***Kỳ vọng bước vào Trend”*

- (if) Giá mở rộng/breakout khỏi biên/phạm vi → ***bres-pmb***
- (if) Sau breakout hình thành base nhỏ/nén vi mô → chuẩn bị ***bres-pma*** (bước chuyển sang Trend Strong(xung lực tiếp diễn))

***→** (setup) Breakout “thật” khi CLOSE ngoài biên (không dùng wick). Giao dịch **ở vùng ngoài vừa phá** theo setup (1st) **bres-pmb** và nếu xuất hiện “micro-base” sau đó, ưu tiên continuation bằng (2nd) **bres-pma***

**(3) TREND STRONG – XUNG LỰC (Impulse / Imbalance) *→**  “Kỳ vọng Pullback & Tìm vùng buôn, cơ hội”*

- (if) Có impulse rõ và hình thành micro-base/nén vi mô → ***bres-pma***
- (if) Pullback nông(nhẹ), lực ngược suy yếu dần → vẫn ưu tiên ***bres-pma*** (đợi base rồi break)
- (if) Pullback sâu, bắt đầu “ăn lại” nhiều của impulse → **chuyển sang Phase (4)**

**→** *(setup) Chỉ tập trung continuation: **đợi micro-base → break theo xu hướng** thì giao dịch theo setup (1st) **bres-pma** và “kỳ vọng chuẩn bị cho **tình huống điều chỉnh** (2nd) **tìm vùng buôn**”. Mục tiêu là bám sóng đẩy (Trend mạnh thì gần như chỉ cần pma: “đợi base nhỏ → break theo trend”)*

**(4) TREND WEAK  – ĐIỀU CHỈNH (Correction / Pullback sâu) *→ “**Kỳ vọng xu hướng tiếp diễn (Phá vỡ theo hướng cũ)”*

**Core rule:** *Bắt “reversal của sóng hồi” để bắt tiếp diễn trend cũ; fail thì reset.*

- (if) ****Correction 1-leg + cuối hồi có base-nhỏ trong vùng buôn ****→ ***revs-ppf***
- (if) Correction đơn fail và hình thành nhịp hồi lần 2 (double-leg) + base-nhỏ → ***revs-pps***
- (else) All thất bại → 3 Khả năng:
    1. **Break cấu trúc ngược** → **Đảo chiều / Cycle mới**
    2. Bị kẹt, swing không phá → **quay về Range–Compression (Phase 1)**
    3. Hỗn loạn/nhiễu → **đứng ngoài**

**→** *Ưu tiên reversal sóng hồi để bắt tiếp diễn trend (ppf/pps). Nếu không “đẹp” = thoát nhanh + vẽ box tích lũy + reset bối cảnh (quay lại Phase 1).*

***Trong tích lũy (Accumulation-acc) dùng revs-pmr, revs-pfb ở biên trên. Chỉ dùng revs-pfb ở biên dưới.
Trong phân phối (Distribution-dis) dùng revs-pmr, revs-pfb ở biên dưới. Chỉ dùng revs-pfb ở biên trên.***

***Khi xác định được trạng thái, giai đoạn hiện tại thì nhận diện “vùng buôn, cơ hội” (kết hợp với xem động lượng, khối lượng để hỗ trợ điểm vào) → tìm điểm setup & áp dụng các setup đã thiết lập** (cố gắng tìm setup trong vùng này là tối ưu nhất)*

- **PHÂN TÍCH XUNG LỰC - ĐỘNG LƯỢNG (VOLUME)**
    **Giá có thể đi đâu tiếp theo (dự đoán dựa trên động lượng) tiếp diễn, suy yếu, hay đảo chiều?**
    Xác định **xung lực – động lượng (volume)** chỉ để phục vụ hỗ trợ **điểm vào lệnh trong vùng buôn/cơ hội đã và đang xác định.**
    Chỉ phân tích động lượng **sau khi đã xác định được cấu trúc–xu hướng–trạng thái thị trường và đang ở giai đoạn xác định vùng buôn**
    *(Xung lực/động lượng chỉ là công cụ lọc — không phải công cụ quyết định xu hướng. Nếu chưa có xu hướng rõ → KHÔNG phân tích động lượng.)*

    - Docs
        **Quy luật nổ lực & kết quả (Effort and Result)**
        Trong thị trường tài chính, **nỗ lực** được **thể hiện bằng khối lượng** trong khi **kết quả** được **thể hiện bởi giá**
        - Hành động **giá** phải phản ánh hành động khối lượng
        - Không có **nỗ lực** thì không sinh ra **kết quả**.
        - Nổ lực phải đi kèm với kết quả (phe mua nổ lực nhiều thì giá sẽ tăng còn nếu như phe mua nổ lực nhiều mà giá không tăng thì đó là dấu hiệu bất thường có thể đảo chiều)
            - Nỗ lực có kết quả tương xứng (Hài Hòa) là dấu hiệu tiếp diễn xu hướng
            - Nỗ lực không mang lại kết quả (Phân Kỳ) là dấu hiệu đảo chiều xu hướng
                - Do thiếu sự quan tâm của dòng tiền lớn (SM) khiến xu hướng không bền vững.
                - Do dòng tiền lớn (SM) chặn giá để gom hàng hoặc xả hàng.
        - Mục tiêu: Đánh giá sự chi phối của người mua và người bán thông qua sự phân kỳ và hội tụ giữa giá và khối lượng.
        - Nỗ lực = Khối lượng | Kết quả = Giá (Di chuyển)
        **Hài Hoà và Phân Kỳ**
        - Không phải lúc nào Nỗ Lực cũng mang lại Kết Quả tương xứng và ngược lại
            - Nỗ Lực nhiều -> Kết Quả: Giá di chuyển nhiều = Hài Hoà -> Tiếp diễn
            - Nỗ Lực nhiều -> Kết Quả: Giá di chuyển ít = Phân Kỳ (Smart Money đè giá) -> Đảo chiều
            - Nỗ lực ít -> Kết quả: Giá di chuyển nhiều = Phân Kỳ (thiếu sự quan tâm) -> Đảo chiều
---

- Docs
    1. **Chu kỳ giá (Tăng/Giảm)** bắt đầu khi **đảo chiều**, kết thúc khi **đảo chiều** lần tiếp theo.
        **1. Sideway (không xu hướng)**
        - **2 setup “thực tế”**: dùng để giao dịch ngay trong trạng thái sideway.
        - **2 setup “kỳ vọng”**: chuẩn bị cho tình huống sideway **bùng nổ mạnh** → xuất hiện trend mạnh mới.
        **2. Trend**
            1. **Mạnh**
               - **2 setup “thực tế”**: giao dịch theo hướng của xu hướng mạnh hiện tại.
               - **2 setup “kỳ vọng”**: chuẩn bị cho khả năng thị trường **yếu dần** → có thể chuyển sang điều chỉnh hoặc sideway.
            2. **Yếu**
               - **2 setup “thực tế”**: giao dịch trong giai đoạn điều chỉnh hoặc xu hướng yếu.
               - Sau đó → **kỳ vọng tiếp diễn xu hướng cho đến khi kết thúc chu kỳ “đảo chiều”.**
    
    2. Đặc điểm trạng thái
        1. Dấu hiệu Range (Sideway – tích lũy phẳng) 
            Đặc điểm: 2 swing high không phá + 2 swing low không phá trong N bars; Volume co hẹp; Lực mua bán cân bằng.
        2. Dấu hiệu Expansion (phá vỡ – bùng nổ)
            Đặc điểm: Biến động tăng đột ngột; MACD histogram mở rộng mạnh; Giá thoát zone; Nhiều mô hình breakout hợp lệ.          
        3. Dấu hiệu Impulse (xu hướng – đẩy mạnh)       
            Đặc điểm: Momentum tăng; Break cấu trúc; Nến thân lớn; Volume mở rộng; Imbalance xuất hiện.      
        4. Dấu hiệu Correction (pullback – hồi – điều chỉnh)       
            Đặc điểm: Nến nhỏ; Momentum ngược yếu; Sóng hồi nông ~ sâu tùy market regime; Vol giảm; Đi về vùng giá buôn.
            
    ***⇒ If - Giá không tạo ra sóng điều chỉnh đơn** → 1 là **sẽ tạo ra sóng điều chỉnh kép →** 2 là **sẽ đảo chiều xu hướng →** 3 là **sẽ chuyển trạng thái thành sideway ⇒** **vẽ hộp tích lũy** (Dù bất kỳ trường hợp sau nào xảy ra thì cái kỳ vọng đầu tiên của mình đã bị mất → Cắt lỗ thật nhanh).* Ví dụ: Nếu đang giai đoạn tích lũy → kỳ vọng bùng nổ; Nếu đang xu hướng → kỳ vọng điều chỉnh để tìm cơ hội; Nếu đang đi ngang thì sẽ quay lại tích lũy. 
    
    → Mục đích: tìm cơ hội (vùng giá buôn / vùng cơ hội).
    **Thiếu “điều kiện vô hiệu” (invalid) cho từng phase**
    Đây là thứ giúp EA và bạn tránh overtrade. Ví dụ tối thiểu:
    - Range-Compression invalid nếu range quá rộng / quá nhiễu
    - PMA invalid nếu “micro-base” kéo quá dài → chuyển sang Range
    - PPF invalid nếu pullback quá sâu (vượt ngưỡng bạn chọn)
    Chỉ cần 1–2 điều kiện invalid/phase là hệ thống cứng hẳn.
    

### 3. Trade Setups

**I. CORE PRICE ACTION SETUPS**

*(2 nhóm lớn, 6 setups)*

**A. BREAKOUT SETUPS (THEO ĐÀ) →** *Giao dịch phá vỡ theo đà (Breakout – Momentum) - Hiệu quả khi thị trường mạnh*

1. **Phá vỡ phạm vi - trạng thái nén (Range Breakout)**
    - ***bres-pmb (breakout setup-pattern marginal breakout)*** (mô hình **phá vỡ biên –** *tích lũy/nén sát biên*)
        1. **Context (bối cảnh) →** (1) Có **range/sideway rõ** (thường hình thành sau một nhịp chạy) và xuất hiện trạng thái **nén – co hẹp;** (2) Giá **tích lũy sát một biên** (upper hoặc lower) → kỳ vọng **mở rộng phá biên** theo hướng biên đang bị “mài mòn”.
        2. **Pattern (mẫu hình) →** (3) Range đang **thu hẹp dần** (biên độ dao động giảm) + nhiều lần **test cùng một biên** và bật lại yếu dần (lực cản bị hao mòn) + giá “đè” sát biên: **đỉnh/đáy sau tiến gần biên** hơn (cảm giác bị ép); (4) **Volume thu hẹp** về trước(Avg 20bar H2) + **nến 1 đóng ngoài biên** + **nến 2 phải duy trì** 'đóng **hoàn toàn ngoài range**' + nến tiếp theo **không được reclaim ngược vào biên quá 45% thân nến 1** liên tục trong N nến và **volume mở rộng** so với nền nén trước đó. (chỉ cần một nến quay thân vào trong range là break thất bại)

            *(Optional filters (tích lũy động lượng): Các nhịp hồi ngược ngắn dần / không kéo ra xa biên + MACD histogram (nếu dùng) tích lũy theo hướng phá (mở rộng nhẹ dần về phía breakout))*

        3. **Trigger (điểm vào) →** (5) **Entry = nến close ngoài biên range/base** theo hướng phá vỡ. *(Không dùng wick chọc ra rồi đóng lại.)*
        4. **Risk (dừng lỗ) →** (6) **SL = ở phía trong range** (phía đối diện biên breakout) hoặc **dưới/ trên đáy/đỉnh của base nén** + buffer/ATR. *(Mục tiêu: nếu quay lại sâu vào range → breakout thất bại → thoát - kỳ vọng lúc xung lực lúc này đã hết)*
        5. **Target (kỳ vọng) →** (7) **TP1 = độ rộng range** (measured move) hoặc vùng cấu trúc gần nhất; **TP2 = trailing stop** để ăn continuation nếu breakout chạy mạnh.
        6. **Invalid (điều kiện loại bỏ) →** (8) Chỉ **wick** vượt biên nhưng **close vẫn trong range** → chưa breakout (không vào); (9) Breakout xảy ra nhưng **bị kéo lại đóng vào trong range ngay** (false break) → chuyển logic **revs-pfb;** (10) Range quá nhiễu / không có nén sát biên / không có dấu hiệu “ép biên” → bỏ.

        - ***bres-pmb_subtype (breakout setup-pattern marginal breakout -subtype)*** (mô hình **phá vỡ biên –** *không cần tích lũy đẹp* / *impulse breakout*)

            *(Thường bị bỏ qua vì điểm vào không “đẹp” theo tư duy thông thường)*

            1. **Context →** (1) Có **range/sideway rõ** (thường sau một xu hướng mới hình thành hoặc sau sideway dài); (2) Thị trường xuất hiện **xung lực theo hướng chính** (tin tức/động lượng quay lại) khiến giá **phá thẳng** mà không nén sát biên “đẹp”.
            2. **Pattern →** (3) Có **1 nến breakout thân lớn** hoặc chuỗi nến cùng hướng thể hiện **momentum đột ngột +** giá **close ngoài biên range/base** rõ ràng (không phải wick) + sau phá vỡ, giá **không bị kéo ngược sâu** vào range ngay lập tức (không fail liền).

                *(Optional filters (để tránh bẫy): Nến breakout có thân ≥ mức “bình thường” (ví dụ ≥ 1.2–1.5× median body/ATR) + Breakout xảy ra cùng hướng với cấu trúc lớn hơn (multi-TF đồng thuận - H1H2&1D))*

            3. **Trigger →** (4) **Entry = nến breakout** đóng ngoài biên **range** (close outside) theo hướng phá vỡ (*không chờ retest*).
            4. **Risk →** (5) **SL = phía trong range** (ngay dưới/ trên biên breakout) + buffer/ATR *(vì không có base nén đẹp, SL thường dựa vào “biên range” là hợp lý nhất).*
            5. **Target →** (6) **TP1 = measured move** theo độ rộng range hoặc vùng cấu trúc gần nhất; **TP2 = trailing stop** để ăn continuation nếu breakout chạy luôn (đúng tinh thần “momentum”).
            6. **Invalid →** (7) Breakout chỉ bằng **wick** nhưng close vẫn trong range → không vào; (8) **Nến đóng ngoài biên nhưng ngay sau đó đóng lại vào range** (fail breakout) → chuyển sang **revs-pfb;** (9) Breakout xảy ra **ngược hướng cấu trúc lớn hơn** (multi-TF lệch) → bỏ hoặc giảm size (tuỳ rule hệ thống).
2. **Phá vỡ tiếp diễn xu hướng (Trend Continuation Breakout)**
    - ***bres-pma (breakout setup-pattern micro accumulation)*** (mô hình **phá vỡ tích lũy vi mô –** *tiếp diễn xu hướng*)
        1. **Context →** (1) **Regime = Trend mạnh** hoặc vừa có **impulse rõ** theo một hướng (mất cân bằng mạnh); (2) Sau impulse, giá **không hồi sâu** mà chỉ “nghỉ” bằng một **base nhỏ** → kỳ vọng **tiếp diễn nhanh**.
        2. **Pattern→** (3) Hình thành **micro-base / base-nhỏ**: cụm nến đi ngang rất ngắn, biên hẹp (≥3 bar H2 thân nhỏ), tạo “hộp” rõ + trong micro-base, **lực ngược chiều yếu**: không tạo được swing ngược đáng kể, không kéo giá ra xa; (4) **Volume/**biến động **thu hẹp trong base** rồi **mở rộng** **lại khi phá**

            *(Optional filters: Biên độ micro-base nhỏ (ví dụ ≤ 0.5–0.8× ATR khung giao dịch) + MACD (nếu dùng): histogram co trong base rồi mở lại theo hướng xu hướng)*

        3. **Trigger →** (5) **Entry = nến close phá ra khỏi “base-nhỏ”** theo hướng xu hướng (close outside box.*(Không dùng wick chọc ra rồi quay lại).*
        4. **Risk →** (6) **SL = phía đối diện của base-nhỏ** (dưới đáy box cho buy / trên đỉnh box cho sell) + buffer/ATR. *(Vì micro-base nhỏ nên SL thường khá ngắn, RR tốt).*
        5. **Target →** (7) **TP1 = measured move**: lấy độ cao base-nhỏ hoặc đoạn impulse gần nhất làm tham chiếu; **TP2 = trailing stop** để bám continuation (đúng tinh thần “trend continuation”).
        6. **Invalid→** (8) Base-nhỏ **kéo quá dài** hoặc phình to thành range lớn → không còn PMA (chuyển sang logic range/pmb); (9) Giá **close phá box** nhưng **ngay sau đó đóng lại vào trong box** (fail breakout) → bỏ hoặc chuyển logic false break (tuỳ rule); (10) Sau impulse mà giá hồi sâu, cấu trúc yếu đi rõ → không phải PMA (chuyển sang nhóm pullback reversal ppf/pps).

**B. REVERSAL SETUPS (THEO HỒI) →** *Giao dịch đảo chiều sóng (Reversal – Counter Move)- Hiệu quả khi thị trường yếu / sideway*

1. **Đảo chiều sóng hồi trong xu hướng (Pullback Reversal)**
    - ***revs-ppf (reversal setup-pattern pullback first)*** (mô hình **đảo chiều sóng hồi 1 nhịp –** *tiếp diễn xu hướng*)

        *(Trong mỗi mô hình setup tùy mô hình sẽ áp dụng phân tích xung lực và động lượng)*

        1. **Context →** (1) **Có xu hướng rõ** đi cùng **volume mở rộng** (cycle tăng/giảm được xác nhận bằng cấu trúc); (2) Giá đang ở **nhịp điều chỉnh đầu tiên** có **volume thu hẹp** (ngược lực yếu) → kỳ vọng vào sớm ở “vùng buôn/discount” để bắt **tiếp diễn theo hướng trend**. (nếu pullback mà volume tăng dần + giá phá cấu trúc ngược → khả năng Cycle đổi/đảo chiều tăng).
        2. **Pattern →** (3) Pullback **1 nhịp** + ****cuối pullback xuất hiện **base-nhỏ** (≥3 bar H2 thân nhỏ) tạo “hộp” rõ; (4) **Volume giảm dần** (lực hồi yếu) + cuối base có dấu hiệu **lực ngược xu hướng suy yếu** hoặc **thất bại**. (Wick ngược chiều dài, nhiều lần test nhưng không đi tiếp + fb nhỏ trong base).

            *(Optional filters (tín hiệu suy yếu/failed counter-move): Momentum ngược chiều giảm dần (MACD histogram thu hẹp nếu dùng))*

        3. **Trigger →** (5) **Entry = nến close phá ra khỏi base-nhỏ theo hướng trend** (close outside box) (Uptrend: close phá **đỉnh base** → Buy / Downtrend: close phá **đáy base** → Sell).
        4. **Risk →** (6) **SL = dưới/ trên đáy/đỉnh base-nhỏ** (đối diện hướng vào) + buffer/ATR. *(Nếu muốn chặt hơn: SL đặt dưới/ trên swing low/high của pullback)*
        5. **Target →** (7) **TP1 = retest/đỉnh-đáy gần nhất** hoặc vùng cấu trúc (để khóa lợi nhuận ban đầu); **TP2 = trailing stop** để ăn continuation / “đuôi phải”.
        6. **Invalid →** (11) Pullback **quá sâu** hoặc lực hồi ngược xu hướng quá mạnh (trend yếu rõ) → không còn ppf (chuyển sang pps/range/đảo chiều); (12) Giá phá base bằng **wick** nhưng close không thoát hộp → chưa vào; (13) Break base xong **đóng lại vào trong base** (fail) → bỏ/thoát nhanh theo rule.
    - ***revs-pps (reversal setup-pattern pullback second)*** (mô hình **đảo chiều sóng hồi 2 nhịp –** *tiếp diễn xu hướng*)
        1. **Context →** (1) **Có xu hướng rõ** đi cùng **volume mở rộng;** (2) Giá đã có **pullback 1-leg (ppf) nhưng không tiếp diễn**, sau đó hình thành **pullback lần 2** (double-leg / ABC) → kỳ vọng bắt nhịp tiếp diễn sau khi lực ngược xu hướng “đánh thêm lần nữa nhưng thất bại”.
        2. **Pattern →** (3) Pullback **2 nhịp rõ + nhịp C không vượt sâu đang kể so với nhịp A** (A–B–C) + chưa vượt qua đường Swing Core + xuất hiện **base-nhỏ cuối nhịp** (≥3 bar H2 thân nhỏ); (4) **Volume giảm dần** + có dấu hiệu **lực ngược xu hướng suy yếu** ở nhịp C. (Đạp/đẩy lần 2 nhưng không đi tiếp + Wick ngược chiều dài / false break nhỏ quanh đáy/đỉnh của nhịp C)

            *(Optional filters: Momentum ngược chiều giảm dần (MACD histogram thu hẹp nếu dùng))*

        3. **Trigger →** (5) **Entry = nến đóng cửa (Close) phá ra khỏi base-nhỏ theo hướng xu hướng** (close outside box). (Uptrend: close phá **đỉnh base** → Buy / Downtrend: close phá **đáy base** → Sell)
        4. **Risk →** (6) **SL = dưới/ trên đáy/đỉnh nhịp C** hoặc **đối diện base-nhỏ** + buffer/ATR. *(Chọn 1 cách cố định cho hệ thống: SL theo swing C = chắc hơn; SL theo base = RR tốt hơn)*
        5. **Target →** (7) **TP1 = retest/đỉnh-đáy gần nhất** hoặc vùng cấu trúc quan trọng; **TP2 = trailing stop** để bám continuation / “đuôi phải”.
        6. **Invalid →** (8) Nhịp C **đi quá sâu** làm hỏng cấu trúc xu hướng (nguy cơ đảo chiều cao) → bỏ (chuyển sang logic cycle-change/range); (9) Giá phá base bằng **wick** nhưng close không thoát hộp → chưa vào;(10) Break base xong **đóng lại vào trong base** (fail) → bỏ/thoát nhanh theo rule; (11) Giá **không phá thì chuyển sang phase-1**;
2. **Đảo chiều sóng trong phạm vi - trạng thái nén (Range Edge Reversal)**
    - ***revs-pmr (reversal setup-pattern marginal rejection)*** (mô hình **từ chối tại biên** - *trend mới hình thành*)
        1. **Context →** (1) Có **range rõ** vừa hình thành sau một nhịp chạy (trend mới ⇒ chuyển range).
        2. **Pattern →** (2) Giá **test biên range + không close ngoài biên** (tối đa wick chọc ra) + có **rejection rõ** tại biên (ít nhất 1 nến từ chối); (3) **Volume không quá cao** (không phải panic) hoặc **volume spike** mà giá không đi thêm (effort > result) ⇒ hấp thụ ở biên.

            *(Optional filters: Có tín hiệu từ chối: pin bar, rejection wick, engulf trong range, hoặc 1–2 nến đảo chiều ngay tại biên)*

        3. **Trigger →** (4) Entry = **đóng cửa quay lại vào trong range** (close back inside) theo hướng đảo (Uptrend ⇒ buy biên dưới / Downtrend ⇒ sell biên trên)
        4. **Risk →** (5) SL = **đặt** **ngoài đuôi rejection** (vượt biên một chút) hoặc buffer/ATR
        5. **Target →** (6) TP = **mid-range** (an toàn) hoặc **biên đối diện** (tham hơn) hoặc TSL
        6. **Invalid →** (7) **Close ngoài biên với thân lớn/giữ được** ⇒ loại pmr (chuyển sang logic breakout (bres-pmb)) → (8) Range quá nhiễu / biên không rõ ⇒ bỏ

        - ***revs-pmr_subtype (reversal setup-pattern marginal rejection - subtype)*** (mô hình **từ chối tại biên** – *trend đã đi xa/exhaustion reversal* (*thiết lập hiếm)*)
            1. **Context →** (1) **Trend đã đi xa / kéo dài bất thường** và bắt đầu **chững lại** (dấu hiệu kiệt sức) → hình thành **range phân phối/tích lũy** quanh “vùng cực trị”. *(Mục tiêu: “mua quyền chọn” khả năng đảo chiều chu kỳ; không coi là đảo chiều chắc chắn).*
            2. **Pattern →** (2) Giá **test biên cực trị** của range (**biên trên** nếu trước đó uptrend, **biên dưới** nếu trước đó downtrend) + **không có close giữ được ngoài biên** (tối đa wick chọc ra) + có **rejection mạnh** tại biên (ít nhất 1 nến từ chối rõ).
            3. **Trigger →** (3) **Entry = đóng cửa quay lại vào trong range** (close back inside) theo hướng đảo:

                *(Vào nhỏ “scout”, add chỉ khi có break cấu trúc ngược trend cũ)*

                Uptrend đã đi xa & **chuyển range**  → **Sell** khi close back inside ở **biên trên**

                Downtrend đã đi xa & **chuyển range** → **Buy** khi close back inside ở **biên dưới**

            4. **Risk →** (4) **SL = ngoài extreme của rejection / ngoài vùng quét** (cao hơn đỉnh wick đối với sell, thấp hơn đáy wick đối với buy) + buffer/ATR.
            5. **Target →** (5) **TP1 = mid-range** (bắt phần hồi chắc nhất).

                **TP2 = biên đối diện / vùng buôn đối nghịch** nếu thị trường tiếp tục đảo mạnh.

                *(Nếu có cấu trúc đảo chiều xác nhận, có thể chuyển sang TSL để ăn “đuôi phải”).*

            6. **Invalid →** (6) **Close ngoài biên và giữ được** (follow-through rõ) → không phải pmr_subtype (đang breakout thật); (7) **Chưa có dấu hiệu exhaustion** (trend vẫn “chạy khỏe”, pullback nông, phá đỉnh/đáy tốt) → bỏ (không bắt đỉnh/đáy); (8) Range mới hình thành quá nhiễu / biên không rõ → bỏ.
    - ***revs-pfb (reversal setup-pattern false breakout)*** (mô hình **phá vỡ giả tại biên** – *break rồi đảo mạnh*)
        1. **Context →** (1) Có **range rõ** (biên trên/biên dưới xác định được) và giá đang ở vùng **biên range**. *(False break thường xuất hiện khi biên là nơi tập trung thanh khoản/stop orders.)*
        2. **Pattern →** (2) Nến **1 break biên** (wick hoặc close ngoài biên) + nến **2 đảo chiều reclaim** lại vào trong range với **xung lực kéo ngược ≥ 45% thân nến 1** và **volume của nến 1–2 gần tương đương** (bật lên rồi tụt ngay) hoặc không khác gì nền trước đó. (close back inside)

            *(Optional filters: Nến đảo chiều dạng engulf/strong close (đóng sâu vào trong range) + Cú rút ngược có momentum rõ (độ dài thân nến lớn hơn bình thường))*

        3. **Trigger →** (3) **Entry = nến đóng quay lại vào trong range** (close back inside) theo hướng đảo (cycle-up ⇒ phá xuống rồi rút vào range → Buy / cycle-down ⇒ phá lên rồi rút vào range → Sell)
        4. **Risk →** (4) **SL = ngoài extreme của cú phá giả** (ngoài vùng quét) hoặc buffer/ATR (Sell: trên đỉnh wick/đỉnh phá giả. Buy: dưới đáy wick/đáy phá giả.)
        5. **Target →** (5) **TP1 = mid-range** (ăn phần chắc nhất); **TP2 = biên đối diện** (RR thường rất tốt với setup này) hoặc c*ó thể chuyển sang TSL khi giá đi được 1R–2R để giữ “đuôi phải”.*
        6. **Invalid →** (6) Giá **phá biên và giữ được ngoài biên** (follow-through rõ, nhiều nến đóng ngoài biên) → **không phải pfb** (chuyển breakout: **bres-pmb**); (7) Break xong **quay lại yếu/không có nến đảo chiều rõ** → bỏ (không đủ lực đảo); (8) Range **không rõ / biên nhiễu** → bỏ.

**II. THUẬT NGỮ & TÌNH HUỐNG KHÔNG GIAO DỊCH**

- ***Thuật ngữ trong thiết lập***

    ***@*** *(điểm vào vị thế khá táo bạo)*

    ***↑ or —*** (vùng hỗ trợ uptrend)

    ***↓ or —*** (vùng hỗ trợ downtrend)

    **(◡) -** (xung lực mua thắng thế)

    **(◠) -** (xung lực bán thắng thế)

    ***Res. exit - resistance exit*** (đóng vị thế tại vùng kháng cự)

    ***Rev. exit - reversal exit*** (đóng vị thế tại điểm đảo chiều)

    ***T - tease break*** (phá vỡ mồi)

    ***F - false break*** (phá vỡ giả) - định nghĩa:…..

    ***R - real break*** (phá vỡ thật)

    ***W*** (mô hình tăng giá)

    ***M*** (mô hình giảm giá)

    ***Ww*** (mô hình Ww)

    ***Mm*** (mô hình Mm)

    ***shs*** - headandshoulders (mô hình vai đầu vai)

    ***testB/testS***  (buy/sell stop - Vị thế giao dịch phán đoán hoặc thăm dò)

    ***breakB/breakS*** (buy/sell market - Vị thế giao dịch khi mô hình biểu đồ hoàn thiện - breakout)

    ***base-nhỏ :*** (>= 3 nến H2 thân nhỏ & “thân nhỏ” = body ≤ 0.5 ATR(H1) (hoặc ≤ median body 20 nến))

    Tiêu chí “Impulse rõ” và “Pullback nông/sâu” phải có thước đo

    **volume-contract/expand:** “Khối lượng thu hẹp or mở rộng được đánh giá trên **cửa sổ 40 giờ**: tương đương **20 nến H2**, **40 nến H1**, và **2 nến D1** (xấp xỉ).”

- **Những tình huống không nên giao dịch**
    - Cú hồi quá ngắn, không cân xứng với sóng đẩy → dễ thất bại.
    - Sóng hồi mạnh gần bằng hoặc vượt lực đẩy trước → xu hướng thiếu ổn định.
    - Thị trường hỗn loạn, không rõ xung lực nào thắng thế → **nên đứng ngoài và chờ đợi** những chuyển động đẹp, có sự chênh lệch xung lực mua bán được thể hiện rõ ràng.
    - Nếu xu hướng đi quá nhanh, cú hồi không hài hòa → có thể bỏ lỡ, chờ cơ hội khác.

- Docs
    1. **Cách nhớ 1 câu/1 setup**

        **bres-pmb (pattern marginal breakout)** (mô hình **phá vỡ biên –** *tích lũy/nén sát biên*)**:** *“Range nén sát một biên (build-up) → phá biên bằng momentum và giữ được ngoài biên → vào theo hướng phá.”*

        **bres-pmb_subtype (pattern marginal breakout - subtype)** (mô hình **phá vỡ biên –** *không cần tích lũy đẹp* / *impulse breakout*)**:** *“Sau sideway dài, giá phá thẳng theo xung lực xu hướng chính (không cần nén đẹp) → vào theo cú phá nếu đóng ngoài biên.”*

        **bres-pma (pattern micro accumulation)** (mô hình **phá vỡ tích lũy vi mô –** *tiếp diễn xu hướng*)**:** *“Sau impulse mạnh, giá tạo micro-base rất nhỏ → phá micro-base ngay → vào continuation theo hướng xu hướng.”*

        **revs-ppf (pattern pullback first)** (mô hình **đảo chiều sóng hồi 1 nhịp –** *tiếp diễn xu hướng*)**:** *“Trend còn hướng rõ → hồi 1 nhịp về vùng buôn + tạo base nhỏ cuối hồi → vào khi phá base theo hướng trend.”*

        **revs-pps (pattern pullback second)** (mô hình **đảo chiều sóng hồi 2 nhịp –** *tiếp diễn xu hướng*)**:** *“Trend còn hướng rõ → hồi 2 nhịp (ABC) về vùng buôn + tạo base nhỏ ở nhịp cuối → vào khi phá base theo hướng trend.”*

        **revs-pmr (pattern marginal rejection)** (mô hình **từ chối tại biên** - *trend mới hình thành*)**:** *“Chạm biên nhưng không phá → bị từ chối → vào khi quay lại trong range.”*

        **revs-pmr_subtype (pattern marginal rejection - subtype)** (mô hình **từ chối tại biên** – *trend đã đi xa/exhaustion reversal* (*thiết lập hiếm)*)**:** *“Trend đã kiệt sức + chuyển range → canh biên cực trị →* *vào nhỏ theo rejection ở cực trị để bắt hồi; nếu break cấu trúc ngược trend cũ thì giữ/nhồi để ăn đảo chiều.” (mua quyền chọn (optionality) vào khả năng đảo chiều)*

        **revs-pfb (pattern false breakout)** (mô hình **phá vỡ giả tại biên** – *break rồi đảo mạnh*)**:** *“Phá biên để quét stop → rút mạnh quay lại range → vào theo hướng đảo.”*

    - **So sánh 3 kiểu Range dễ nhầm lẫn**
        1. **Từ chối biên (Range Edge Reversal = “chạm – từ chối – đảo chiều”) – KHÔNG phá**
            - Dành cho **thị trường yếu hoặc sideway chặt**
            - Giá **không phá biên,** giá chạm biên → từ chối → quay đầu.
            - Thường thấy pin bar, inside bar thất bại, volume hấp thụ.
            - Chạm biên → phản ứng ngay → đuôi nến → từ chối
            - Ví dụ:
                - Entry: break candle inside base
                - SL: sau đuôi rejection
                - Lợi nhuận vừa phải, Entry an toàn hơn, SL chặt hơn
                - RR khoảng *1:2–1:3*
                - Không có momentum mạnh

        2. **Phá vỡ giả (False Breakout / Liquidity Grab) - CÓ phá**
            - Giá **phá biên thật sự,** giá phá biên nhẹ → lấy thanh khoản → quay đầu mạnh (lấy thanh khoản → giật mạnh ngược)
            - Phá vỡ xảy ra nhưng không giữ được.
            - Xuất hiện **momentum đảo chiều**
            - Ví dụ:
                - Entry: nến engulfing hoặc momentum nến lớn
                - SL: đặt ngoài vùng bị quét
                - Lợi nhuận cực mạnh vì cú hồi sâu của sideway
                - RR thường *1:4–1:6*
                - Momentum mạnh, giá nhảy nhanh

        3.  **Breakout thật (Range Breakout Momentum)**
            - Giá phá biên bằng momentum.
            - Nến thân lớn.
            - Volume tăng.
            - Retest hoặc tiếp diễn.
            - → Đây là chiến lược Breakout Momentum.

    **→ Tìm 1 cơ sở khách quan để nhận biết break thật (giữ được) và phá giả (không giữ được)**

    → **Xác định xu hướng → xác định sóng hồi → xác định vùng giá buôn (phân tích xung lực động lượng) → tìm vùng cơ hội → áp dụng setup**

    - **Phân tích xung lực & động lượng**

        
        **Giá có thể đi đâu tiếp theo (dự đoán dựa trên động lượng) tiếp diễn, suy yếu, hay đảo chiều?**
        *(Khi đã có vùng cơ hội mới kiểm tra động lượng)*

        
        (Xác định **xung lực – động lượng (volume)** chỉ để phục vụ hỗ trợ **điểm vào lệnh trong xu hướng tăng/giảm đã xác định.** Chỉ phân tích động lượng **sau khi đã xác định được cấu trúc–xu hướng–trạng thái thị trường và đang ở giai đoạn xác định vùng buôn). Xung lực/động lượng chỉ là công cụ lọc — không phải công cụ quyết định xu hướng. Nếu chưa có xu hướng rõ → KHÔNG phân tích động lượng.**
        
        **Tìm kiếm xung lực nào đang suy yếu và xung lực nào đang mạnh lên → Động lượng có thể nhìn thấy qua việc quan sát độ dóc (góc) của chuyển động giá**
        
        1. Sóng giảm chậm lại, sóng tăng nhanh dần → **lực mua thắng thế (◡)**
        2. Sóng tăng chậm lại, sóng giảm nhanh dần →**lực bán thắng thế (◠)**
        
        Tập trung vào **“vùng cơ hội”** – nơi có khả năng hình thành đồng thuận cao (range edge, breakout zone, pullback zone).
        
        Bạn không dùng MACD để đoán tương lai, bạn dùng MACD để kiểm tra xem:
        
        - Phe mua/bán còn mạnh không?
        - Cú hồi có đang yếu đi không?
        - Có tín hiệu phe mua/bán quay trở lại không?
        - Động lượng *xác nhận*, *không dự đoán*.
        - Không nhìn MACD khi cấu trúc chưa rõ.
        
        ***Đánh giá lực cung/cầu hiện tại (Xung lực nào đang chiếm ưu thế?)***
        
        ***Chờ đợi dấu hiệu cho thấy xung lực cản (ngược xu hướng) suy yếu và xung lực đẩy (theo xu hướng) gia tăng sức mạnh trong nhịp điều chỉnh đầu tiên***
        
        **Khi histogram mở rộng → động lượng mạnh (lực đẩy tăng dần)**
        
        **Khi histogram thu hẹp → động lượng yếu (lực đẩy giảm dần)**
        
        **Khi histogram dương/âm nhưng thu hẹp lại dần -> giá đang tăng/giảm nhưng động lượng đã yếu, cảnh báo về sự suy kiệt (bán/mua bắt đầu chùn tay)**
        
        **Khi MACD histogram tăng/giảm lại (≥ 3 thanh) trong vùng giá buôn → xác nhận impulse mới**
        
        **Khi giá phá đỉnh/đáy swing → vùng giá buôn được xác nhận**
        

### 4. Mở vị thế giao dịch, xác định khối lượng lệnh & cắt lỗ

*(Vào lệnh tại vùng giá buôn, khóa cắt lỗ và mở lợi nhuận)*

**Entry → Volume (0,5-1%) → Stop-loss (2.5 x ATR) → Target (Trailingstop)**

SL = đáy vùng (hoặc 2.5×ATR), position sizing = 0.5–1% equity.

Định tính: Mặc định trung bình 0.5%/10.000$ - Cho phép tăng vị thế khi thắng giảm vị thế khi lỗ trong phạm vi 0.1 - 1.1% (mỗi lần tăng/giảm = 0.2)

Định lượng: Mặc định 0.5% - Trailing stop & cắt lỗ nhanh & không giới hạn lợi nhuận.

## OUTPUT

### 1. **Quản lý vị thế và Tư duy dài hạn**

1. **Nguyên tắc Quản lý:** Chỉ sử dụng **điểm dừng lỗ kéo theo (trailing stop loss)**, không đặt mục tiêu chốt lời cố định. Mục tiêu là để vị thế đi theo xu hướng xa nhất có thể, tận dụng **"đuôi phải lớn"** (lợi nhuận lý thuyết không giới hạn).
2. **Nguyên tắc Hành động:**
    - **Tránh giao dịch quá mức:** Việc liên tục quan sát biểu đồ và quản lý giao dịch quá mức không giúp kết quả tốt hơn, mà chỉ gây tâm lý bất ổn. Sau khi vào lệnh, kết quả do thị trường quyết định.
    - Không quan sát biểu đồ quá nhiều sau khi vào lệnh → tránh **over-management**.
    - Các điểm vào đã được thiết kế để có **lợi thế thống kê + rủi ro thấp** → chỉ cần kiên nhẫn để xu hướng chạy.
    - Một lệnh bị hit SL không đồng nghĩa xu hướng kết thúc → chỉ là xung lực chưa đủ mạnh.
3. **Tư duy về dừng lỗ:** Việc cắt lỗ ban đầu bị chạm không có nghĩa là xu hướng kết thúc, mà chỉ là **sự chênh lệch xung lực không còn rõ ràng**. Cần thoát ra, chờ đợi sự chênh lệch mới, và tìm kiếm cơ hội khác.
4. **Tầm quan trọng của Điểm vào:** Vị thế phải nằm ở các khu vực cơ hội, gần chân sóng (vùng giá buôn), nơi xu hướng mới bắt đầu, để tối đa hóa tiềm năng lợi nhuận.

### 2. **Sử dụng Đa Khung thời gian để Quản lý**

1. **Phương pháp Dời Dừng lỗ:** Sử dụng khung thời gian lớn hơn để dời dừng lỗ (trailing stop loss).
    - Dời SL theo các **vùng giá buôn (value area / demand-supply zone)**. **Conservative**: dời theo vùng giá buôn → giữ lệnh lâu, lợi nhuận lớn, nhưng SL xa hơn.
    - Hoặc dời theo **đỉnh – đáy quan trọng** của khung lớn. **Aggressive**: dời theo các đỉnh đáy nhỏ → sát xu hướng hơn, nhưng dễ bị đá ra sớm.
2. **Quy tắc Dời dừng lỗ:** Dời dừng lỗ theo **các vùng giá buôn** trên khung thời gian lớn. Việc giá phá vỡ vùng giá buôn này thường đồng nghĩa với việc con sóng đó kết thúc và trạng thái thị trường trên khung thời gian giao dịch chuyển đổi.
3. **Lợi ích:** Phương pháp này giúp nhà giao dịch **bám theo xu hướng tối đa** và **giữ tâm lý ổn định** bằng cách loại bỏ nhiễu từ các hành động giá trong khung thời gian nhỏ.
4. **Chiến lược tối ưu:**
    - Cố gắng giao dịch theo **sóng đẩy** của xu hướng trên khung thời gian lớn, vì chúng tạo ra xu hướng mạnh mẽ, kéo dài trên khung thời gian nhỏ.
    - Khi có vị thế trên **sóng hồi** của khung thời gian lớn, nên cân nhắc đóng lệnh sớm hơn nếu xuất hiện tín hiệu xung lực suy yếu.


```

FX: EURUSD, GBPUSD, EURJPY, GBPJPY, USDJPY
Metals/Crypto/Oil: XAUUSD, BTCUSD, USOIL
Indices: US100, JP225, US30, DE30

**USD cluster (FX & commodities chịu USD)**: EURUSD, GBPUSD, USDJPY, XAUUSD, USOIL, US30, US100
**JPY cluster**: USDJPY, EURJPY, GBPJPY, JP225
**EUR cluster**: EURUSD, EURJPY, DE30
**GBP cluster**: GBPUSD, GBPJPY
**Crypto cluster**: BTCUSD
**Indices cluster**: US100, US30, DE30, JP225 (có tương quan risk-on/risk-off)
