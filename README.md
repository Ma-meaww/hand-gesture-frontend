# hand-gesture-frontend

แอป Flutter (Android) สำหรับโปรเจกต์ **ระบบควบคุมคอมพิวเตอร์ด้วยท่าทางมือผ่านสมาร์ตโฟน**

ตรวจจับท่ามือด้วย MediaPipe, รับ Voice-to-Text แล้วส่งคำสั่งไปยัง backend บนคอมพิวเตอร์ผ่าน WebSocket

> **คู่กับ:** [hand-gesture-pc-controller](https://github.com/Ma-meaww/hand-gesture-pc-controller) — Python WebSocket server ที่รับคำสั่งและควบคุมคอมพิวเตอร์

---

## ภาพรวมระบบ

```
┌─────────────────────────────────────────────────────────────────┐
│                      THIS REPO (Flutter)                        │
│                                                                 │
│  Camera  →  hand_tracking_service.dart                          │
│              │                                                  │
│              ▼                                                  │
│         gesture_classifier_service.dart  ←  gesture_mapping.dart│
│              │                                                  │
│              ▼                                                  │
│         websocket_service.dart  ──→  command_message.dart       │
│                                                                 │
│  Microphone  →  voice_service.dart  →  TEXT  →  websocket       │
│                                                                 │
│  Pages:  gesture_control_page  |  settings_page  |  voice_command_page │
└───────────────────────────────┬─────────────────────────────────┘
                                │  Wi-Fi  ws://192.168.x.x:8765
                                ▼
                   hand-gesture-pc-controller
                    (Python WebSocket Server)
```

---

## Gesture → Command Mapping

| ท่ามือ (Gesture)               | Command ที่ส่ง          | ผลลัพธ์บนคอม              |
|-------------------------------|------------------------|--------------------------|
| ชี้นิ้วชี้ + ขยับมือ          | `CURSOR_MOVE`          | เลื่อนเมาส์              |
| Pinch (นิ้วชี้ + นิ้วโป้ง)    | `CLICK`                | คลิกซ้าย                 |
| Pinch ค้าง                    | `CONFIRM`              | กด Enter                 |
| ฝ่ามือหันลง + เลื่อนลง        | `SCROLL_DOWN`          | Scroll หน้าลง            |
| ฝ่ามือหันขึ้น + เลื่อนขึ้น    | `SCROLL_UP`            | Scroll หน้าขึ้น          |
| ปุ่ม Voice บนหน้าจอ           | `THAIJO_INPUT_SEARCH`  | ส่งข้อความจาก STT        |
| ปุ่ม ThaiJO บนหน้าจอ          | `OPEN_THAIJO`          | เปิดเว็บ ThaiJO          |

ดู mapping ทั้งหมดได้ที่ `lib/models/gesture_mapping.dart`

---

## Project Structure

```
hand-gesture-frontend/
├── lib/
│   ├── main.dart
│   │
│   ├── config/
│   │   └── app_config.dart              # WebSocket URL, timeout, ค่าคงที่
│   │
│   ├── models/
│   │   ├── command_message.dart         # โครงสร้าง JSON ที่ส่งไป backend
│   │   └── gesture_mapping.dart        # ตาราง gesture → command
│   │
│   ├── pages/
│   │   ├── gesture_control_page.dart   # หน้าหลัก: camera feed + gesture HUD
│   │   ├── settings_page.dart          # ตั้งค่า IP, sensitivity, gesture
│   │   └── voice_command_page.dart     # หน้า Voice-to-Text สำหรับ ThaiJO
│   │
│   ├── services/
│   │   ├── camera_service.dart                # เปิด/ปิดกล้อง, stream frames
│   │   ├── gesture_classifier_service.dart    # แปลง landmarks → gesture name
│   │   ├── gesture_settings_service.dart      # โหลด/บันทึก gesture config
│   │   ├── hand_tracking_service.dart         # MediaPipe hand landmarks
│   │   ├── training_sample_service.dart       # เก็บ sample สำหรับ training
│   │   ├── voice_service.dart                 # Speech-to-Text
│   │   └── websocket_service.dart             # WebSocket client + reconnect
│   │
│   └── widgets/
│       ├── command_button.dart          # ปุ่มส่ง command แบบ manual
│       ├── connection_status_card.dart  # แสดงสถานะการเชื่อมต่อ
│       └── training_panel.dart         # UI สำหรับ collect training data
│
├── dev_tools/
│   └── mock_ws_server.py               # Mock WebSocket server สำหรับทดสอบ Flutter โดยไม่ต้องเปิดคอม
│
├── assets/images/                      # ไอคอนและรูปภาพ
├── test/
│   └── widget_test.dart
└── pubspec.yaml
```

---

## Requirements

- Flutter 3.x
- Android 8.0 (API 26) ขึ้นไป
- ทดสอบบนอุปกรณ์จริงเท่านั้น (ต้องใช้กล้องจริง)
- มือถือและคอมอยู่ Wi-Fi เดียวกัน
- รัน [hand-gesture-pc-controller](https://github.com/Ma-meaww/hand-gesture-pc-controller) บนคอมก่อน

---

## Installation & Run

```bash
flutter pub get

# รันบนอุปกรณ์จริง
flutter run

# Build APK
flutter build apk --release
```

**ทดสอบโดยไม่ต้องเปิดคอม (ใช้ mock server)**
```bash
# เปิด terminal บนคอม
python dev_tools/mock_ws_server.py
# แล้วใส่ IP คอมใน Settings ของแอป
```

---

## วิธีใช้งาน

1. รัน `python main.py` บนคอมพิวเตอร์ก่อน
2. เปิดแอป → ไปที่ Settings → กรอก IP ของคอม (เช่น `192.168.1.42`)
3. กลับหน้าหลัก → กด Connect
4. ยกมือขึ้นให้กล้องเห็น — แอปจะแสดง gesture ที่ตรวจพบและสถานะ ACK

---

## ThaiJO Flow

```
1. กดปุ่ม ThaiJO          →  ส่ง OPEN_THAIJO
2. กดปุ่ม Voice แล้วพูด   →  STT แปลงเป็นข้อความ
3. แอปส่ง THAIJO_INPUT_SEARCH (พร้อม text)
4. ทำท่า Pinch ค้าง        →  ส่ง THAIJO_SUBMIT_SEARCH
5. ใช้ท่า CURSOR_MOVE + CLICK เลือกบทความบนคอม
```

---

## WebSocket Protocol

รูปแบบ JSON ที่แอปส่ง (ดูโครงสร้างใน `lib/models/command_message.dart`):

```json
{
  "type": "command",
  "command": "CURSOR_MOVE",
  "gesture": "INDEX_FINGER",
  "x": 0.52,
  "y": 0.34,
  "text": null,
  "timestamp": 1718000000000
}
```

รายละเอียดเต็มดูได้ที่ [PROTOCOL.md](https://github.com/Ma-meaww/hand-gesture-pc-controller/blob/main/PROTOCOL.md)

---

## Related

- [hand-gesture-pc-controller](https://github.com/Ma-meaww/hand-gesture-pc-controller) — Python backend
