import 'package:flutter/material.dart';

// เพิ่ม: import package สำหรับแปลงเสียงเป็นข้อความ
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/websocket_service.dart';

class VoiceCommandPage extends StatefulWidget {
  const VoiceCommandPage({super.key});

  @override
  State<VoiceCommandPage> createState() => _VoiceCommandPageState();
}

class _VoiceCommandPageState extends State<VoiceCommandPage> {
  final TextEditingController textController = TextEditingController();

  // เพิ่ม: ตัวแปรสำหรับใช้งาน Speech-to-Text
  final stt.SpeechToText speech = stt.SpeechToText();

  // เพิ่ม: เช็กว่าตอนนี้กำลังฟังเสียงอยู่ไหม
  bool isListening = false;

  // เพิ่ม: เก็บข้อความเดิมก่อนเริ่มกดไมค์รอบใหม่
  String textBeforeListening = '';

  @override
  void dispose() {
    // เพิ่ม: หยุดไมค์ก่อนออกจากหน้านี้
    speech.stop();

    textController.dispose();
    super.dispose();
  }

  void sendVoiceText() {
    final text = textController.text.trim();

    if (text.isEmpty) {
      webSocketService.statusText.value = 'กรุณาพิมพ์ข้อความก่อนส่ง';
      return;
    }

    webSocketService.sendCommand(
      command: 'THAIJO_INPUT_SEARCH',
      text: text,
    );
  }

  void submitThaiJoSearch() {
    webSocketService.sendCommand(
      command: 'THAIJO_SUBMIT_SEARCH',
      gesture: 'PINCH_CONFIRM',
    );
  }

  // เพิ่ม: ฟังก์ชันกดไมค์
  // กดครั้งแรก = เริ่มฟังเสียง
  // กดอีกครั้ง = หยุดฟังเสียง
  Future<void> toggleListening() async {
    print('Mic button pressed');

    if (!isListening) {
      final available = await speech.initialize(
        onStatus: (status) {
          print('Speech status: $status');

          // แก้: ไม่อัปเดต textBeforeListening ตรงนี้แล้ว
          // เพราะถ้าอัปเดตตอน speech status เปลี่ยน อาจทำให้ข้อความซ้อนหรือเพี้ยนได้
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() {
                isListening = false;
              });
            }
          }
        },
        onError: (error) {
          print('Speech error: ${error.errorMsg}');

          String message = 'เกิดข้อผิดพลาดจากไมค์';

          if (error.errorMsg == 'error_speech_timeout') {
            message = 'ไม่ได้ยินเสียงพูด ลองกดไมค์แล้วพูดใหม่อีกครั้ง';
          }

          webSocketService.statusText.value = message;

          if (mounted) {
            setState(() {
              isListening = false;
            });
          }
        },
      );

      if (!available) {
        webSocketService.statusText.value = 'ไม่สามารถใช้ไมค์ได้';
        return;
      }

      // เพิ่ม: เก็บข้อความเดิมก่อนเริ่มฟังรอบใหม่
      // เช่น ตอนนี้มี "hello" อยู่ในช่อง
      // พอกดไมค์แล้วพูด "world" จะกลายเป็น "hello world"
      textBeforeListening = textController.text.trimRight();

      setState(() {
        isListening = true;
      });

      webSocketService.statusText.value = 'กำลังฟังเสียง...';

      speech.listen(
        localeId: 'th_TH',
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: true,

        // แก้: เดิมใช้ textController.text = result.recognizedWords;
        // ทำให้ข้อความเก่าถูกลบ
        // ตอนนี้เปลี่ยนเป็นเอาข้อความเดิม + ข้อความที่พูดใหม่มาต่อกัน
        onResult: (result) {
          final spokenText = result.recognizedWords.trim();

          if (spokenText.isEmpty) return;

          String finalText;

          if (textBeforeListening.isEmpty) {
            finalText = spokenText;
          } else {
            finalText = '$textBeforeListening $spokenText';
          }

          setState(() {
            textController.value = TextEditingValue(
              text: finalText,
              selection: TextSelection.collapsed(
                offset: finalText.length,
              ),
            );
          });
        },
      );
    } else {
      await speech.stop();

      setState(() {
        isListening = false;
      });

      webSocketService.statusText.value = 'หยุดฟังเสียงแล้ว';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Command'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /*
              ลบของเดิมออก:

              const Icon(
                Icons.mic,
                size: 80,
              ),

              เพราะมันเป็นแค่รูปไอคอน กดไม่ได้
            */

            // เพิ่มใหม่: ทำไอคอนไมค์ให้เป็นปุ่มกดได้
            InkWell(
              onTap: toggleListening,
              borderRadius: BorderRadius.circular(60),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: isListening
                      ? Colors.red.withOpacity(0.15)
                      : Colors.black.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isListening ? Icons.mic_off : Icons.mic,
                  size: 70,
                  color: isListening ? Colors.red : Colors.black,
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'หน้าป้อนคำสั่งด้วยเสียง',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'กดปุ่มไมค์เพื่อพูดให้ข้อความขึ้นในช่อง หรือพิมพ์ข้อความเองก็ได้',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            TextField(
              controller: textController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'ข้อความคำสั่ง',
                hintText: 'เช่น machine learning',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(237, 243, 114, 88),
                foregroundColor: Colors.white,
              ),
              onPressed: sendVoiceText,
              icon: const Icon(Icons.send),
              label: const Text('Send Text'),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: submitThaiJoSearch,
              icon: const Icon(Icons.search),
              label: const Text('Submit ThaiJO Search'),
            ),

            const SizedBox(height: 20),

            ValueListenableBuilder<String>(
              valueListenable: webSocketService.statusText,
              builder: (context, status, child) {
                return Text(
                  status,
                  textAlign: TextAlign.center,
                );
              },
            ),

            const SizedBox(height: 8),

            ValueListenableBuilder<String>(
              valueListenable: webSocketService.lastAck,
              builder: (context, ack, child) {
                return Text(
                  'Last ACK: $ack',
                  textAlign: TextAlign.center,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}