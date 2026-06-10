class GestureMapping {
  String openPalmUpCommand;
  String openPalmDownCommand;
  String openPalmRightCommand;
  String openPalmLeftCommand;
  String twoFingerCommand;
  String fistCommand;
  String pinchCommand;

  double smoothingWindow;
  double debounceTime;

  GestureMapping({
    this.openPalmUpCommand = 'SCROLL_UP',
    this.openPalmDownCommand = 'SCROLL_DOWN',
    this.openPalmRightCommand = 'NONE',
    this.openPalmLeftCommand = 'NONE',
    this.twoFingerCommand = 'NONE',
    this.fistCommand = 'OPEN_THAIJO',
    this.pinchCommand = 'CLICK',
    this.smoothingWindow = 5,
    this.debounceTime = 300,
  });
}