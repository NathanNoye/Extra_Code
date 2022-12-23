/// Base viewmodel for other viewmodels to implement
/// extends ChangeNotifier so we can use Provider as our state management
/// The base viewmodels gives access to the ViewState enum which describes the state of any viewmodel at a high level
/// The states can be: [initial, idle, busy, error, success]

class BaseViewModel extends ChangeNotifier {
  ViewState _state = ViewState.idle;

  ViewState get state => _state;

  /// Covers the main four states: idle, busy, error, and success
  void setState(ViewState viewState) {
    _state = viewState;
    try {
      notifyListeners();
    } catch (exception, stackTrace) {
      locator<ErrorService>().captureException(
        exception,
        stackTrace,
        debuggingMessage: 'Thrown from inside BaseViewModel > setState',
      );
    }
  }

  /// Helper function to rebuild a viewmodel. One of the best parts of this arch style is since the viewmodel is a singleton and injectable, we can update the viewmodel of any widget from anywhere
  /// An example of this is we had a progress calendar widget and we could update your progress from a totally seperate widget without needing to pass any reference - we just had to inject the viewmodel, make the update to the VMs state, then call the rebuild function and when the user eventually returned to where the progress widget was - it was already updated.
  void rebuildWidgets() {
    notifyListeners();
  }
}
