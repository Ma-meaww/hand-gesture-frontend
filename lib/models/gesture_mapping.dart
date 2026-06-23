class GestureMapping {
  String oneFingerCommand;
  String thumbCommand;
  String openPalmUpCommand;
  String openPalmDownCommand;
  String fistCommand;
  String twoFingerCommand;

  double smoothingWindow;
  double debounceTime;

  GestureMapping({
    this.oneFingerCommand = 'CURSOR_MOVE',
    this.thumbCommand = 'CLOSE_BROWSER',
    this.openPalmUpCommand = 'SCROLL_UP',
    this.openPalmDownCommand = 'SCROLL_DOWN',
    this.fistCommand = 'OPEN_THAIJO',
    this.twoFingerCommand = 'THAIJO_SUBMIT_SEARCH',
    this.smoothingWindow = 5,
    this.debounceTime = 300,
  });

  factory GestureMapping.defaults() {
    return GestureMapping(
      oneFingerCommand: 'CURSOR_MOVE',
      thumbCommand: 'CLOSE_BROWSER',
      fistCommand: 'OPEN_THAIJO',
      openPalmUpCommand: 'SCROLL_UP',
      openPalmDownCommand: 'SCROLL_DOWN',
      twoFingerCommand: 'THAIJO_SUBMIT_SEARCH',
      smoothingWindow: 5,
      debounceTime: 300,
    );
  }

  String commandForGesture(String gesture) {
    switch (gesture) {
      case 'ONE_FINGER':
        return oneFingerCommand;
      case 'THUMB':
        return thumbCommand;
      case 'OPEN_PALM_UP':
        return openPalmUpCommand;
      case 'OPEN_PALM_DOWN':
        return openPalmDownCommand;
      case 'FIST':
        return fistCommand;
      case 'TWO_FINGER':
        return twoFingerCommand;
      default:
        return 'NONE';
    }
  }
}
