import 'package:flutter/material.dart';

import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/websocket_service.dart';

class VoiceCommandPage extends StatefulWidget {
  const VoiceCommandPage({super.key});

  @override
  State<VoiceCommandPage> createState() => _VoiceCommandPageState();
}

class _VoiceCommandPageState extends State<VoiceCommandPage> {
  final TextEditingController textController = TextEditingController();

  final stt.SpeechToText speech = stt.SpeechToText();

  bool isListening = false;

  String textBeforeListening = '';

  @override
  void dispose() {
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

    webSocketService.sendCommand(command: 'THAIJO_INPUT_SEARCH', text: text);
  }

  void submitThaiJoSearch() {
    webSocketService.sendCommand(
      command: 'THAIJO_SUBMIT_SEARCH',
      gesture: 'PINCH_CONFIRM',
    );
  }

  Future<void> toggleListening() async {
    debugPrint('Mic button pressed');

    if (!isListening) {
      final available = await speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');

          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() {
                isListening = false;
              });
            }
          }
        },
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');

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
              selection: TextSelection.collapsed(offset: finalText.length),
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

  static const Color reginaBeige = Color(0xFFFFF5D7);
  static const Color coralPink = Color.fromARGB(255, 246, 151, 203);
  static const Color sleutheYellow = Color(0xFFFEB300);
  static const Color pinkLeaf = Color(0xFFFFAAAB);
  static const Color warmBrown = Color(0xFF6B4E3D);
  static const Color softBrown = Color(0xFF9A7B5F);

  Widget _softCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.76),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pinkLeaf.withOpacity(0.45)),
        boxShadow: [
          BoxShadow(
            color: warmBrown.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Voice Command',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: warmBrown,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [reginaBeige, Color(0xFFFFE4B8), Color(0xFFFFD1D2)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            child: Column(
              children: [
                const SizedBox(height: 6),

                InkWell(
                  onTap: toggleListening,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 126,
                    height: 126,
                    decoration: BoxDecoration(
                      color: isListening
                          ? coralPink.withOpacity(0.20)
                          : Colors.white.withOpacity(0.72),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isListening
                            ? coralPink.withOpacity(0.65)
                            : pinkLeaf.withOpacity(0.55),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: warmBrown.withOpacity(0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      isListening ? Icons.mic_rounded : Icons.mic_off_rounded,
                      size: 62,
                      color: isListening ? coralPink : warmBrown,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  isListening ? 'Listening...' : 'Microphone is off',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isListening ? coralPink : warmBrown,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Tap the microphone to speak, or type your search text manually.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: softBrown,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 18),

                _softCard(
                  child: TextField(
                    controller: textController,
                    minLines: 3,
                    maxLines: 5,
                    style: const TextStyle(
                      color: warmBrown,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Search Text',
                      hintText: 'เช่น machine learning',
                      labelStyle: const TextStyle(color: softBrown),
                      hintStyle: TextStyle(color: softBrown.withOpacity(0.65)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.64),
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: pinkLeaf.withOpacity(0.45),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: pinkLeaf.withOpacity(0.45),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: coralPink,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            elevation: 4,
                            backgroundColor: coralPink,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: sendVoiceText,
                          icon: const Icon(Icons.send_rounded),
                          label: const Text(
                            'Send Text',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      elevation: 3,
                      backgroundColor: sleutheYellow,
                      foregroundColor: warmBrown,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: submitThaiJoSearch,
                    icon: const Icon(Icons.search_rounded),
                    label: const Text(
                      'Submit ThaiJO Search',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                ValueListenableBuilder<String>(
                  valueListenable: webSocketService.statusText,
                  builder: (context, status, child) {
                    return _softCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Text(
                        status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: softBrown,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
