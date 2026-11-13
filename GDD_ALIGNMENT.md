# Đối chiếu dự án với Game Design Document v0.2

Ngày rà soát: 12/11/2026. Tài liệu dùng làm chuẩn là **THE LAST HAVEN – Game Design Document v0.2**. Các quyết định [ĐÃ CHỐT] được xem là yêu cầu. Các mục [ĐỀ XUẤT] hoặc [CHƯA QUYẾT ĐỊNH] được giữ ở dạng số liệu/cấu hình thử nghiệm, không coi là luật cuối.

## Đã khớp hoặc vừa chỉnh theo GDD

- Dự án chạy single-player, có trận theo lượt, thanh lượt theo SPD, đội và đối thủ cấu hình theo dữ liệu encounter; lõi tính toán chiến đấu được tách một phần vào `battle_simulator.gd`.
- Đường cong Star trong chiến đấu đã khớp hệ số HP/ATK/DEF và SPD từ 1★ đến 10★ của GDD. Rarity hiện cộng nhẹ chỉ số.
- Thu phục đã chuyển về hành động trong trận: tiêu hao lượt và Monster Contract đã chọn; dùng xác suất theo Rarity, HP còn lại và loại hợp đồng; thất bại không kết thúc trận và cộng 5 điểm phần trăm cho lần thử tiếp theo. Không còn luồng 3 lượt thu phục hậu chiến.
- Auto thường chỉ dùng đòn thường/Kỹ năng 1. Auto toàn phần là tùy chọn riêng và mới được dùng Kỹ năng 2. Auto không tự thu phục.
- Khắc chế 5 nguyên tố: khắc ×1,5, bị khắc ×0,5, trung tính ×1,0.
- Đội mở đầu mới gồm Mossling và Thornback; encounter hướng dẫn gặp một Barkbeetle; Capture Spot mẫu gặp Aquafin và cấp 3 Hợp đồng Cơ bản một lần. Hồ sơ save hiện có được migration giữ nguyên, không bị xóa hay thay đội tự động.
- Bảng EXP tăng sao dùng các mốc số trong GDD; người dùng đã chốt bảng này ngày 12/11/2026. Tinh chất Huấn luyện có đủ năm mức EXP; UI tiêu thụ từng vật phẩm và cộng EXP vào cá thể được chọn.
- Nông Trại và Xưởng Gỗ lưu nhân công bằng `instance_id`, sản lượng cập nhật tự động theo thời gian, có giới hạn tích lũy thử nghiệm 24 giờ.

## Còn thiếu so với phạm vi GDD/MVP

| Hệ thống | Trạng thái dự án hiện tại | Hướng theo GDD |
|---|---|---|
| Căn cứ và công trình | Màn menu thẻ công trình; Farm, Lumber Mill và Training có chức năng cơ bản; các công trình còn lại là màn placeholder | MVP cần căn cứ dạng Grid, đặt công trình, Building Data, mở khóa Blueprint sau Boss; không cần Free Placement lúc này |
| Đội quái và dữ liệu | Có 4 loài trong catalog, trong đó Barkbeetle là địch | MVP GDD nhắm 9 loài/5 nguyên tố; hiện còn thiếu Rocky, Crystole, Zappurr, Marinix, Flambristle, Pyroclaw và nhiều định nghĩa nội tại/kỹ năng |
| Chiến đấu | Prototype hoạt động, nhưng combat effect/AI còn hard-coded một phần, thiếu đầy đủ 13 chỉ số và kiến trúc registry/event/seed replay | Giữ phạm vi MVP 4 chỉ số lõi; chuyển thêm effect, passive và công thức sang dữ liệu/hook khi mở rộng |
| Vùng, Elite và Boss | Chưa có chuỗi vùng thực; encounter mẫu đều Ancient Forest; chưa có Boss hai pha/telegraph | Tạo 3 vùng theo thứ tự Ancient Forest → Rocky Mountains → Volcanic Region; 3 Boss và mở khóa vùng/Blueprint |
| Khám phá | Bến Viễn Chinh có vùng Rừng Cổ Đại mẫu, đội 1–3 quái, thời gian thực, thưởng tự nhận và save/migration; Trạm Khám Phá vẫn placeholder | Cần mở rộng vùng, Pending Storage và thưởng sâu hơn theo vùng/chuyên môn. Active Exploration dạng bản đồ nút/Supply Pack đã chốt về cơ chế; thông số bản đồ vẫn là đề xuất |
| Training | Có EXP từ trận, Base Work và Viễn Chinh, cùng Sân Huấn Luyện và Tinh chất | Activity-based Training cho Combat/Base Work/Expedition đã có prototype. Giá trị EXP/giờ, thưởng vùng và EXP tinh chất vẫn là cấu hình đề xuất cần cân bằng |
| Sản xuất/workforce | Mới có Farm và Lumber Mill, công thức tạm; chưa có chuỗi sản xuất chung/worker slots theo dữ liệu | GDD chốt Hybrid Assignment/Workforce; cần mở rộng các nghề và Yield pipeline, giới hạn/công thức hiện tại vẫn là số thử nghiệm |
| Kho và vật phẩm | Inventory là Dictionary đơn giản; storage quái là danh sách; chưa có 5 khu vực kho, reservation, overflow/Pending Storage hoặc item registry đầy đủ | Hybrid Inventory 5 vùng và các quy tắc quản lý đã chốt; dung lượng kho cụ thể còn mở |
| Roll/Summoning | Chưa có bàn triệu hồi, Soul Dust/Sigil hoặc pity | GDD chốt hướng Roll và Mythical chỉ qua Roll; mở Summoning Altar sau Boss 2; số liệu banner/pity cần theo cấu hình |
| UI/kiến trúc | UI dựng trong script; tiếng Việt còn trộn tiếng Anh ở một số tên nội bộ/khái niệm; thiếu Screen Registry, ViewModel, localization keys, theme tokens, input map | Chuyển dần theo các điểm mở rộng GDD; không cần viết lại toàn bộ trước khi hoàn thiện loop MVP |

## Các giới hạn cần giữ rõ

- Tên loài và kỹ năng 150 loài là đề xuất cần duyệt; chưa nên tạo hàng loạt trước khi chốt.
- EXP từ Work/Expedition, giới hạn offline, slot công trình chính thức, dung lượng kho, giá Contract, trần cá thể, tên Premium Currency và khắc chế đủ 10 nguyên tố vẫn là mục mở. EXP của tinh chất vẫn là số cấu hình đề xuất; ngưỡng Star đã được người dùng chốt theo bảng GDD.
- Multiplayer, Daily Boss theo cửa sổ giờ, Free Placement và Mobile nằm ở giai đoạn sau; không cần đưa vào MVP hiện tại.
- Nội dung UI chưa được Việt hóa hoàn toàn: các định danh dữ liệu như `food`, `fiber`, `Fisher` không nên hiện thẳng cho người chơi; cần xử lý nhất quán qua localization khi làm lượt UI.

## Thứ tự phát triển phù hợp

1. Hoàn thiện vòng chiến đấu + thu phục trong trận và giữ đội/Contract đúng save.
2. Thêm roster 9 loài MVP, rồi dữ liệu encounter theo vùng và Boss.
3. Xây chuỗi căn cứ Grid tối thiểu cùng mở khóa Blueprint.
4. Làm Passive Expedition và nguồn Training EXP từ Work/Expedition.
5. Hoàn thiện kho Hybrid, registry vật phẩm, rồi Summoning Altar.
6. Làm Active Exploration dạng nút/Supply Pack theo cơ chế đã chốt; giữ kích thước bản đồ và trọng số nút ở dạng cấu hình đề xuất.
7. Thay kiến trúc giao diện từng màn theo registry, ViewModel, localization và theme tokens.
