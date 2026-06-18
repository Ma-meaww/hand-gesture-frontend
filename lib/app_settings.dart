class AppSettings {
  static final Map<String, String> gestureCommandMap = {
    'ONE_FINGER': 'CURSOR_MOVE',
    'THUMB': 'CLICK',
    'OPEN_PALM_UP': 'SCROLL_UP',
    'OPEN_PALM_DOWN': 'SCROLL_DOWN',
    'FIST': 'OPEN_THAIJO',
    'TWO_FINGER': 'THAIJO_SUBMIT_SEARCH',
  };

  static int debounceTimeMs = 500;
  static int cursorThrottleMs = 80;
  static int smoothingWindow = 5;

  static String commandForGesture(String gesture) {
    return gestureCommandMap[gesture] ?? 'NONE';
  }

  static void setCommand(String gesture, String command) {
    gestureCommandMap[gesture] = command;
  }

  static void resetDefaults() {
    gestureCommandMap['ONE_FINGER'] = 'CURSOR_MOVE';
    gestureCommandMap['THUMB'] = 'CLICK';
    gestureCommandMap['OPEN_PALM_UP'] = 'SCROLL_UP';
    gestureCommandMap['OPEN_PALM_DOWN'] = 'SCROLL_DOWN';
    gestureCommandMap['FIST'] = 'OPEN_THAIJO';
    gestureCommandMap['TWO_FINGER'] = 'THAIJO_SUBMIT_SEARCH';

    debounceTimeMs = 500;
    cursorThrottleMs = 100;
    smoothingWindow = 5;
  }
}