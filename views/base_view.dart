/// A base view class meant to be extended by other views

class BaseView<T extends BaseViewModel> extends StatefulWidget {
  final Widget Function(BuildContext context, T viewmodel, Widget? child)
      builder;

  /// Helper functions that can be triggered
  final Function(T)? afterLayout; // Triggered after the view has been setup
  final Function(T)?
      beforeLayout; // Called before the app has been setup but as soon as its injected into the widget tree
  final Function(T)? onDispose; // When the view is disposed
  final Function(T)?
      onResumed; // The application is visible and responding to user input
  final Function(T)?
      onInactive; // The application is in an inactive state and is not receiving user input.
  final Function(T)?
      onPaused; //The application is not currently visible to the user, not responding to user input, and running in the background
  final Function(T)?
      onDetached; // The application is still hosted on a flutter engine but is detached from any host views
  final Function(T)?
      onResumeFromBackground; // When the app is returned to the foreground from being in the background, this is triggered (useful for users returning to the app to check if a certain state has changed since their last visit)

  const BaseView({
    required this.builder,
    this.afterLayout,
    this.beforeLayout,
    this.onDispose,
    this.onResumed,
    this.onInactive,
    this.onPaused,
    this.onDetached,
    this.onResumeFromBackground,
  });

  @override
  _BaseViewState<T> createState() => _BaseViewState<T>();
}

class _BaseViewState<T extends BaseViewModel> extends State<BaseView<T>>
    with WidgetsBindingObserver {
  T viewmodel = locator<T>();
  bool triggerFunctionAfterResumeFromBackground = false;

  @override
  void initState() {
    if (widget.beforeLayout != null) {
      widget.beforeLayout!(viewmodel);
      WidgetsBinding.instance.addObserver(this);
    }

    if (widget.afterLayout != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        widget.afterLayout!(viewmodel);
      });
    }
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        if (widget.onResumed != null) {
          widget.onResumed!(viewmodel);
        }
        if (widget.onResumeFromBackground != null &&
            triggerFunctionAfterResumeFromBackground) {
          widget.onResumeFromBackground!(viewmodel);
          triggerFunctionAfterResumeFromBackground = false;
        }
        break;
      case AppLifecycleState.inactive:
        if (widget.onInactive != null) {
          widget.onInactive!(viewmodel);
        }
        break;
      case AppLifecycleState.paused:
        if (widget.onPaused != null) {
          widget.onPaused!(viewmodel);
        }

        if (widget.onResumeFromBackground != null) {
          triggerFunctionAfterResumeFromBackground = true;
        }
        break;
      case AppLifecycleState.detached:
        if (widget.onDetached != null) {
          widget.onDetached!(viewmodel);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // We set the context for the current context so we can inject context if needed. This has been a lifesaver in some places
    locator<BuildContextService>().setContext(context);
    return ChangeNotifierProvider<T>.value(
        value: viewmodel, child: Consumer<T>(builder: widget.builder));
  }

  @override
  void dispose() {
    if (widget.onDispose != null) {
      widget.onDispose!(viewmodel);
    }

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
