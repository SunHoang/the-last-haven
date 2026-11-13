# Cấu trúc dữ liệu game

## Căn cứ

Game mở đầu tại `scenes/base/Base.tscn`. Bảng điều khiển căn cứ có lối vào Trạm Khám Phá, Cổng Thử Thách, Nông Trại, Xưởng Gỗ, Sân Huấn Luyện và Bến Viễn Chinh. Cổng Thử Thách mở danh sách trận hiện có. Nông Trại và Xưởng Gỗ đã có thể giao tối đa hai quái; sản lượng chờ tăng tự động, được lưu theo chu kỳ và cập nhật khi rời công trình. Người chơi thu hoạch để chuyển sản lượng vào kho. Bến Viễn Chinh hỗ trợ gửi 1–3 quái đến Rừng Cổ Đại trong 15/30/120 phút; tiến độ và phần thưởng được xử lý khi đến hạn, kể cả sau khi mở lại game.

Hồ sơ lưu công nhân bằng `instance_id` để phân biệt nhiều cá thể cùng loài. Tiến độ từng công trình gồm danh sách nhân công, giờ cập nhật gần nhất và sản lượng chờ thu hoạch; kho chung nằm trong `resources`. Save cũ được bổ sung hoặc nâng cấp các trường này khi tải lên, không xóa tiến trình hiện có. Nghề và bonus công trình được khai báo trên Monster Resource (`profession`, `utility_building`, `utility_bonus_percent`, `utility_bonus_resource`) để thêm quái mới mà không sửa công thức giao việc.

Sân Huấn Luyện dùng `training_exp` của từng cá thể. Bảng EXP và giới hạn sao được đọc từ `data/training_progression.tres`, không đặt trong script giao diện. Người dùng đã chốt các mốc 100, 500, 2.000, 5.000, 10.000, 20.000, 35.000, 60.000 và 100.000 EXP cho các mốc 1★→2★ đến 9★→10★ ngày 12/11/2026. Nếu thiếu một ngưỡng hợp lệ, giao diện khóa nút nâng sao thay vì nâng miễn phí. Nâng sao trừ EXP khỏi đúng cá thể; chỉ số chiến đấu dùng đường cong Star trong GDD.

Tinh chất Huấn luyện nằm trong cùng Resource dữ liệu, có năm mức EXP cấu hình thử nghiệm 50/200/500/1.500/5.000. Dùng vật phẩm chỉ cộng EXP vào cá thể đang chọn; không tự tăng sao. Save hiện có được migration lên schema 5; lần đầu vào Sân Huấn Luyện sẽ nhận một Tinh chất Huấn Luyện cơ bản làm vật phẩm hướng dẫn thử tính năng. Có thể đổi các giá trị EXP và tắt/quản lý phần quà này khi cân bằng kinh tế game.

Quái đang làm việc tại Nông Trại hoặc Xưởng Gỗ nhận EXP huấn luyện theo thời gian. Mốc hiện tại là 30 EXP/giờ cho mỗi cá thể đang làm việc, là giá trị cấu hình thử nghiệm (`base_work_exp_per_hour`) và áp dụng tối đa 24 giờ offline. Save schema 4 lưu thời điểm tính gần nhất cùng phần EXP lẻ để không mất tiến độ giữa các lần cập nhật. Schema 5 bổ sung trạng thái Viễn Chinh và kết quả gần nhất.

## Viễn Chinh thụ động

Vùng và phần thưởng được định nghĩa trong `data/expeditions/`, dùng các Resource ở `scripts/data/expedition_region_data.gd` và `scripts/data/expedition_catalog_data.gd`. Rừng Cổ Đại là vùng mẫu; thời lượng, thưởng mỗi 30 phút, EXP huấn luyện và bonus nghề đều có thể chỉnh trong Resource. Chỉ quái không làm việc mới được gửi đi. Quái đang đi không thể tham chiến. Khi chuyến hoàn tất, phần thưởng được tự cộng vào tài nguyên và lưu vào `last_expedition_result`.

## Danh mục quái

Mỗi quái có một tệp riêng trong `data/monsters/`, ví dụ `mossling.tres`. Tệp này chứa chỉ số cơ bản, hệ, độ hiếm, nội tại, kỹ năng và phần thưởng khi bị đánh bại. Kỹ năng và vật phẩm rơi là Resource con nằm trong cùng tệp.

Sau khi tạo quái mới, thêm tệp đó vào danh sách `monsters` trong `data/monsters/catalog.tres`. ID quái phải duy nhất.

## Dữ liệu trận

Mỗi trận có một tệp riêng trong `data/encounters/`, ví dụ `ancient_forest_tutorial_01.tres`. Tệp trận chỉ tham chiếu `monster_id` trong danh mục, cùng cấp sao và các ghi đè tùy chọn. Vì vậy, chỉnh chỉ số ở tệp quái sẽ cập nhật mọi trận dùng ID đó.

`data/encounters/catalog.tres` liệt kê những trận có thể chọn. Khi thêm trận, tạo Encounter Resource rồi thêm nó vào danh sách này; màn chọn trận và màn đội hình sẽ dùng giới hạn, năng lượng, số vòng và danh sách địch của Encounter đã chọn.

Màn hướng dẫn, trận trinh sát và trận hộ vệ mẫu dùng cùng hệ thống. Người chơi chọn đội bằng các ô đánh dấu ở màn hình chuẩn bị; số thành viên được chọn có thể từ 1 đến `max_allies`. Danh sách `enemies` quyết định số địch, từ 1 đến `max_enemies`. Các giới hạn này được cấu hình trong Encounter Resource. Hệ thống lượt, mục tiêu, chỉ số UI và hàng đợi dùng danh sách động; có thể tăng hai giới hạn lên 5 hoặc 6 trong Resource rồi bổ sung dữ liệu quái. Các thẻ chiến đấu chuyển sang vùng cuộn khi đội lớn hơn.

## Đội và dữ liệu lưu

`data/player/default_roster.tres` chỉ dùng làm đội mặc định khi chưa có tệp lưu. Tiến trình người chơi được ghi riêng vào `user://the_last_haven_save.json`; tệp này không nằm trong dự án và không bị ghi đè bởi dữ liệu quái hay màn chơi. Save mới dùng `schema_version`; save cũ được nâng cấp tuần tự bằng hàm migration mà không xóa tiến trình.

Đội hiện tại, Training EXP, vật phẩm, Monster Contract và quái thu phục được lưu trong hồ sơ người chơi. Quái thu phục sẽ vào đội nếu còn chỗ theo giới hạn `max_allies`; nếu đội đã đầy thì vào `storage`.

Thu phục là hành động trong trận, tiêu hao lượt của quái đang hành động và một Monster Contract đã chọn (Basic, Advanced hoặc Master). Chỉ địch còn sống, có cờ `capturable` và không phải Mythical mới có thể bị thu phục. Tỉ lệ dùng công thức GDD: `clamp(P_gốc(Rarity) × (1,6 − HP% địch) × hệ số hợp đồng + bonus thất bại, 5%, 90%)`. Thất bại tiêu hao hợp đồng, địch tiếp tục chiến đấu và lần thử tiếp theo trong cùng trận được cộng 5 điểm phần trăm. Thu phục thành công tạo cá thể mới, vào đội nếu còn chỗ theo giới hạn trận, nếu không thì vào kho.

Màn mở đầu mới dùng Mossling và Thornback; Capture Spot hướng dẫn gặp Aquafin và cấp ba Hợp đồng Cơ bản một lần. Save cũ được migration giữ nguyên; không tự xóa Aquafin đã có trong đội hoặc kho.

## Tệp JSON cũ

Các JSON prototype cũ đã được đánh dấu không còn dùng. Dữ liệu chiến đấu hiện lấy từ các Resource `.tres` nêu trên.

## Logic chiến đấu

`scenes/battle/Battle.tscn` dùng `scripts/battle/battle_screen.gd` để dựng giao diện và điều phối trận. Các phép tính không phụ thuộc giao diện đang được chuyển dần sang `scripts/battle/battle_simulator.gd`:

- `effective_stat` tính chỉ số sau hiệu ứng.
- `element_multiplier` tính hệ số khắc chế.
- `calculate_damage` tính sát thương khi được truyền hệ số ngẫu nhiên.
- `resolve_attack_command` xử lý một lệnh tấn công trên bản sao dữ liệu và trả về trạng thái cùng sự kiện sát thương, phản đòn hoặc hiệu ứng.
- `resolve_skill_command` xử lý sát thương, Bind, hồi máu, giải hiệu ứng xấu, Regen và khiên; trả về đội hình mới cùng sự kiện.
- `resolve_end_turn_command` xử lý Burn, Regen, hết thời lượng hiệu ứng và nội tại Tidal Rhythm/Forest Vitality.
- `apply_effect` áp dụng hoặc làm mới hiệu ứng trên bản sao quái.
- `advance_action_gauges` trả về thanh lượt mới và người hành động kế tiếp mà không sửa dữ liệu đầu vào.
- `choose_auto_action`, `choose_enemy_skill`, `preferred_target_index` và `heal_target_index` chứa luật chọn hành động/mục tiêu của AI. Auto thường chỉ chọn đòn thường và Kỹ năng 1; Auto toàn phần mới được phép tự chọn Kỹ năng 2. Thu phục luôn là quyết định thủ công.

`battle_screen.gd` áp dụng trạng thái trả về và hiển thị log. Đòn thường, mọi kỹ năng đang có và quyết định của AI đều dùng luật trong simulator; màn hình vẫn điều phối vòng đời lượt và lựa chọn mục tiêu thủ công của người chơi.
