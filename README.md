# hand-gesture-frontend

แอป Flutter (Android) สำหรับโปรเจกต์ **ระบบควบคุมคอมพิวเตอร์ด้วยท่าทางมือผ่านสมาร์ตโฟน**

ตรวจจับท่ามือด้วย MediaPipe, รับ Voice-to-Text แล้วส่งคำสั่งไปยัง backend บนคอมพิวเตอร์ผ่าน WebSocket

> **คู่กับ:** [hand-gesture-pc-controller](https://github.com/Ma-meaww/hand-gesture-pc-controller) — Python WebSocket server ที่รับคำสั่งและควบคุมคอมพิวเตอร์

---

## ภาพรวมระบบ

```
┌─────────────────────────────────────────────────────────────────┐
│                       THIS REPO (Flutter)                       │
│                                                                 │
│   Camera  →  MediaPipe  →  Gesture Detector  →  Command Builder │
│                             (Hand Landmarks)                    │
│                                                                 │
│   Microphone  →  Speech-to-Text  →  Text input for ThaiJO      │
│                                                                 │
│   UI Screen  →  Connect Screen (IP input)                       │
│             →  Control Screen (gesture feedback + status)       │
│                                                                 │
│   WebSocket Client  ──→  ws://192.168.x.x:8765                  │
└───────────────────────────────────┬─────────────────────────────┘
                                    │  Wi-Fi
                                    ▼
                     hand-gesture-pc-controller
                      (Python WebSocket Server)
```

---

## Gesture → Command Mapping

| ท่ามือ (Gesture)              | Command ที่ส่ง         | ผลลัพธ์บนคอม              |
|------------------------------|----------------------|--------------------------|
| ชี้นิ้วชี้ + ขยับมือ         | `CURSOR_MOVE`        | เลื่อนเมาส์              |
| Pinch (นิ้วชี้ + นิ้วโป้ง)   | `CLICK`              | คลิกซ้าย                 |
| Pinch ค้าง                   | `CONFIRM`            | กด Enter                 |
| ฝ่ามือหันลง + เลื่อนลง       | `SCROLL_DOWN`        | Scroll หน้าลง            |
| ฝ่ามือหันขึ้น + เลื่อนขึ้น   | `SCROLL_UP`          | Scroll หน้าขึ้น          |
| ปุ่ม Voice บนหน้าจอ           | `THAIJO_INPUT_SEARCH` | ส่งข้อความจาก STT        |
| ปุ่ม ThaiJO บนหน้าจอ         | `OPEN_THAIJO`        | เปิดเว็บ ThaiJO          |

---

## Project Structure

```
hand-gesture-frontend/
├── lib/
│   ├── main.dart                   # Entry point
│   ├── screens/
│   │   ├── connect_screen.dart     # หน้าใส่ IP และเชื่อมต่อ
│   │   └── control_screen.dart     # หน้าหลัก: camera feed + gesture feedback
│   ├── services/
│   │   ├── websocket_service.dart  # WebSocket client
│   │   └── speech_service.dart     # Speech-to-Text
│   └── gesture/
│       └── gesture_detector.dart   # แปลง hand landmarks → command
│
├── android/                        # Android-specific config
├── assets/images/                  # ไอคอนและรูปภาพ
├── pubspec.yaml
└── PROTOCOL.md  ← ดู hand-gesture-pc-controller/PROTOCOL.md
```

---

## Requirements

- Flutter 3.x
- Android 8.0 (API 26) ขึ้นไป
- มือถือและคอมอยู่ Wi-Fi เดียวกัน
- ติดตั้ง [hand-gesture-pc-controller](https://github.com/Ma-meaww/hand-gesture-pc-controller) และ run server บนคอมก่อน

---

## Dependencies หลัก (`pubspec.yaml`)

| Package | ใช้ทำอะไร |
|---------|-----------|
| `camera` | เปิดกล้องและ stream frames |
| `google_mlkit_pose_detection` หรือ MediaPipe plugin | ตรวจจับ hand landmarks |
| `web_socket_channel` | WebSocket client |
| `speech_to_text` | Voice-to-Text สำหรับ ThaiJO search |

---

## Installation & Run

```bash
# ติดตั้ง dependencies
flutter pub get

# รันบนอุปกรณ์จริง (แนะนำ — ต้องใช้กล้องจริง)
flutter run

# Build APK
flutter build apk --release
```

> ⚠️ ต้องทดสอบบนอุปกรณ์จริงเท่านั้น เพราะต้องใช้กล้องและอยู่บน Wi-Fi เดียวกับคอม

---

## วิธีใช้งาน

1. รัน `python main.py` บนคอมพิวเตอร์ก่อน ([hand-gesture-pc-controller](https://github.com/Ma-meaww/hand-gesture-pc-controller))
2. เปิดแอปบนมือถือ
3. กรอก IP ของคอม เช่น `192.168.1.42` (port `8765`)
4. กด Connect
5. ยกมือขึ้นให้กล้องเห็น — แอปจะแสดง gesture ที่ตรวจพบและ status การส่งคำสั่ง

---

## ThaiJO Search Flow

```
1. กดปุ่ม ThaiJO บนหน้าจอ    →  ส่ง OPEN_THAIJO
2. กดปุ่ม Voice แล้วพูด       →  STT แปลงเป็นข้อความ
3. แอปส่ง THAIJO_INPUT_SEARCH  →  คำค้นพิมพ์ใน browser บนคอม
4. ทำท่า Pinch ค้าง            →  ส่ง THAIJO_SUBMIT_SEARCH → กดค้นหา
5. ใช้ท่า CURSOR_MOVE + CLICK  →  เลือกบทความบนคอม
```

---

## WebSocket Protocol

รูปแบบ JSON ที่แอปส่งไป:

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

รายละเอียดเต็มดูได้ที่ [PROTOCOL.md](https://github.com/Ma-meaww/hand-gesture-pc-controller/blob/main/PROTOCOL.md) ใน repo backend

---

## Related

- [hand-gesture-pc-controller](https://github.com/Ma-meaww/hand-gesture-pc-controller) — Python backend ที่รับคำสั่งและควบคุมคอม
