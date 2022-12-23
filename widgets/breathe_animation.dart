/// A breath animation that displays a circle that grows and shrinks based on seconds to show the user breathing
/// Allows the content team to create a breathing animation with color transitions, audio cues, and any combination of timing and text.
///
/// Features a private "Hole Painter" customer painter class. This is so we can change the color of the circle and have any kind of background be seen behind the circle
/// Often we'd change the color from red to blue and the background might be a soccer field image or it would be a contrasting color
/// The Hole Painter class let us achieve the growing and shrinking animation while having background show through the hole
/// An example of this is found on YouTube: https://youtu.be/DAljUK7S0HI

class BreatheAnimation extends StatefulWidget {
  final int animationIndex;
  final int iterations;
  final AnimationOrientation orientation;
  final Curve curve;
  final List<BreathStep> breathSteps;
  final Function(BuildContext)? onAnimationEnd;
  final Function(BuildContext)? onLastStep;
  final String? backgroundMediaUrl;

  BreatheAnimation({
    required this.animationIndex,
    required this.iterations,
    required this.orientation,
    required this.curve,
    required this.breathSteps,
    this.onAnimationEnd,
    this.onLastStep,
    this.backgroundMediaUrl,
  });

  @override
  State<BreatheAnimation> createState() => BreatheAnimationState();
}

class BreatheAnimationState extends State<BreatheAnimation>
    with TickerProviderStateMixin {
  late Animation<double> _sizeAnimation;
  late AnimationController _sizeAnimationController;

  late Animation<double> _holdSizeAnimation;
  late AnimationController _holdSizeAnimationController;

  late Animation<Color?> _colorAnimation;
  late Animation<Color?> _backgroundColorAnimation;
  late AnimationController _colorAnimationController;

  List<Color?> circleColors = [];
  List<Color?> backgroundColors = [];

  bool fadeIn = false;
  bool breath = false;
  bool startOnExhale = false;
  int animationTime = 300;
  int currentBreathCount = 0;
  int currentIteration = 0;
  int currentStep = 0;
  int currentStepBreathTime = 0;
  bool shadowExpandedFlag = false;
  bool showShadow = false;
  double smallScreenSizeMultiplier =
      locator<DeviceDetailsService>().isSmallScreen ? 0.8 : 1;
  bool isLongHold = false;

  AudioPlayer audioPlayer = AudioPlayer();

  String instruction = '';

  late Timer timer;

  @override
  void initState() {
    super.initState();
    Wakelock.enable();
    buildColorsList(widget.breathSteps, widget.iterations);

    _sizeAnimationController =
        AnimationController(duration: Duration(seconds: 4), vsync: this);
    _holdSizeAnimationController =
        AnimationController(duration: Duration(seconds: 4), vsync: this);
    _colorAnimationController =
        AnimationController(duration: Duration(milliseconds: 250), vsync: this);

    final _curvedAnimation = CurvedAnimation(
      parent: _sizeAnimationController,
      curve: widget.curve,
    );
    final _holdCurveAnimation = CurvedAnimation(
      parent: _holdSizeAnimationController,
      curve: Curves.linear,
    );

    changeColor(
      beginColor: Colors.black,
      endColor: circleColors[currentStep + 1],
      backgroundBeginColor: Colors.black,
      backgroundEndColor: backgroundColors[currentStep + 1],
    );

    setState(() {
      currentStep = 0;
      currentIteration = 0;
      currentStepBreathTime = widget.breathSteps[0].duration;
      instruction = widget.breathSteps[0].text;
      breath = widget.breathSteps[0].type == BreathType.exhale;
      startOnExhale = shouldStartAsExhale(widget.breathSteps);

      isLongHold = widget.breathSteps[currentStep].isLongHold == true;

      if (!isLongHold) {
        generateBreathDots(widget.breathSteps[0].duration);
      }

      _sizeAnimation = Tween<double>(
              begin: startOnExhale ? 1.0 : 0.8, end: startOnExhale ? 0.8 : 1.0)
          .animate(_curvedAnimation)
        ..addListener(() {
          setState(() {});
        });

      _holdSizeAnimation =
          Tween<double>(begin: 0.8, end: 1.0).animate(_holdCurveAnimation)
            ..addListener(() {
              setState(() {});
            });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(Duration(milliseconds: animationTime));

      setState(() {
        fadeIn = true;
      });

      timer = Timer.periodic(Duration(seconds: 1), (timer) async {
        if (locator<EnvironmentSetupModel>().enableLogging) {
          debugPrint('-----------');
          debugPrint(
              'current breath: $currentBreathCount / ${widget.breathSteps[currentStep].duration}');
          debugPrint(
              'current step: $currentStep / ${widget.breathSteps.length}');
          debugPrint(
              'current iteration: $currentIteration / ${widget.iterations}');
        }

        if (isLongHold) {
          setState(() {
            showShadow = true;
            shadowExpandedFlag = !shadowExpandedFlag;
          });

          if (shadowExpandedFlag) {
            _holdSizeAnimationController.forward();
          } else {
            _holdSizeAnimationController.reverse();
          }
        }

        // Fires only on the last breath of the last step of the last iteration
        if (currentIteration == widget.iterations - 1 &&
            (currentBreathCount == widget.breathSteps[currentStep].duration ||
                currentBreathCount == -1) &&
            currentStep == widget.breathSteps.length - 1) {
          if (locator<EnvironmentSetupModel>().enableLogging) {
            debugPrint('Animation done');
          }
          timer.cancel();

          setState(() {
            currentBreathCount = 99;
          });

          if (widget.onAnimationEnd != null) {
            widget.onAnimationEnd!(context);
          }
        }

        bool secondLastBreath = ((currentIteration == widget.iterations - 1 &&
            (currentBreathCount ==
                    widget.breathSteps[currentStep].duration - 1 ||
                currentBreathCount == -1) &&
            currentStep == widget.breathSteps.length - 1));

        // Fires only on the last breath of the last step
        if ((currentBreathCount == widget.breathSteps[currentStep].duration ||
                currentBreathCount == -1) &&
            currentStep == widget.breathSteps.length - 1) {
          if (locator<EnvironmentSetupModel>().enableLogging) {
            debugPrint('LAST BREATH OF LAST STEP IN ITERATION');
          }

          if (currentIteration == 0) {
            circleColors[0] = circleColors.last;
            backgroundColors[0] = backgroundColors.last;
          }

          setState(() {
            currentBreathCount = 0;
            currentStep = 0;
            currentIteration++;
          });
        }

        //  Fires only on the last breath of the current step
        if (currentBreathCount == widget.breathSteps[currentStep].duration ||
            currentBreathCount == -1) {
          if (locator<EnvironmentSetupModel>().enableLogging) {
            debugPrint('LAST BREATH OF CURRENT STEP');
          }

          setState(() {
            currentBreathCount = 0;
            currentStep++;
          });
        }

        // Fires only on the last breath of each step except on the final iteration
        if (currentBreathCount ==
                widget.breathSteps[currentStep].duration - 1 &&
            currentStep != widget.breathSteps.length &&
            currentIteration != widget.iterations &&
            !secondLastBreath) {
          Future.delayed(Duration(milliseconds: 775), () {
            setState(() {
              currentBreathCount = -1;
            });
          });
        }

        // Fires only on the first breath of the current step
        if (currentBreathCount == 0) {
          setState(() {
            instruction = widget.breathSteps[currentStep].text;
            currentStepBreathTime = widget.breathSteps[currentStep].duration;
            isLongHold = widget.breathSteps[currentStep].isLongHold == true;

            _sizeAnimationController.duration =
                Duration(seconds: currentStepBreathTime);

            if (widget.breathSteps[currentStep].type == BreathType.inhale) {
              breath = true;

              if (startOnExhale) {
                _sizeAnimationController.reverse();
              } else {
                _sizeAnimationController.forward();
              }
            }

            if (widget.breathSteps[currentStep].type == BreathType.exhale) {
              breath = false;

              if (startOnExhale) {
                _sizeAnimationController.forward();
              } else {
                _sizeAnimationController.reverse();
              }
            }

            if (currentStep != 0 ||
                (currentStep == 0 && currentIteration > 0)) {
              changeColor(
                beginColor: circleColors[currentStep],
                endColor: circleColors[currentStep + 1],
                backgroundBeginColor: backgroundColors[currentStep],
                backgroundEndColor: backgroundColors[currentStep + 1],
              );
            }
          });

          if (widget.breathSteps[currentStep].audioUrl != null &&
              !locator<AnimationFlowService>().muteAnimationAudio) {
            AudioPlayer audioPlayer = AudioPlayer();

            if (widget.breathSteps[currentStep].cachedAudioUrl != null) {
              audioPlayer.play(DeviceFileSource(
                  widget.breathSteps[currentStep].cachedAudioUrl!));
            } else {
              audioPlayer
                  .play(UrlSource(widget.breathSteps[currentStep].audioUrl!));
            }
          }
        }

        // Fires only on the first breath of the last step
        if (currentBreathCount == 0 &&
            currentStep == widget.breathSteps.length - 1) {
          if (widget.onLastStep != null) {
            widget.onLastStep!(context);
          }
        }

        setState(() {
          currentBreathCount++;
        });
      });
    });
  }

  @override
  void dispose() {
    timer.cancel();
    _holdSizeAnimationController.dispose();
    _sizeAnimationController.dispose();
    _colorAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.orientation == AnimationOrientation.landscape) {
      return Container(
        height: MediaQuery.of(context).size.height,
        color: widget.backgroundMediaUrl != null
            ? Colors.transparent
            : widget.breathSteps[0].backgroundColor != null
                ? _backgroundColorAnimation.value
                : Colors.white,
        child: Stack(
          children: [
            if (widget.backgroundMediaUrl != null)
              Positioned(
                bottom: 0,
                top: 0,
                left: 0,
                right: 0,
                child: Image.network(
                  widget.backgroundMediaUrl!,
                  key: ValueKey("backgroundMedia_${widget.animationIndex}"),
                  fit: BoxFit.cover,
                ),
              ),
            SingleChildScrollView(
              child: buildLandscapeLayout(),
            ),
          ],
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height,
      color: widget.backgroundMediaUrl != null
          ? Colors.transparent
          : widget.breathSteps[0].backgroundColor != null
              ? _backgroundColorAnimation.value
              : Colors.white,
      child: Stack(
        children: [
          if (widget.backgroundMediaUrl != null)
            Positioned(
              bottom: 0,
              top: 0,
              left: 0,
              right: 0,
              child: Image.network(
                widget.backgroundMediaUrl!,
                key: ValueKey("backgroundMedia_${widget.animationIndex}"),
                fit: BoxFit.cover,
              ),
            ),
          SingleChildScrollView(
            child: buildPortraitLayout(),
          ),
        ],
      ),
    );
  }

  List<Widget> generateBreathDots(int breathSeconds) {
    List<Widget> breaths = [];

    for (int i = 0; i < breathSeconds; i++) {
      breaths.add(Padding(
        padding: const EdgeInsets.all(5.0),
        child: _BreathDot(currentBreathCount > i, _colorAnimation.value),
      ));
    }

    return breaths;
  }

  Widget buildPortraitLayout() {
    return Material(
        color: widget.backgroundMediaUrl != null
            ? Colors.transparent
            : widget.breathSteps[0].backgroundColor != null
                ? _backgroundColorAnimation.value
                : Colors.white,
        child: Container(
            height: MediaQuery.of(context).size.height,
            padding: EdgeInsets.all(30),
            child: AnimatedOpacity(
              duration: Duration(milliseconds: animationTime),
              opacity: fadeIn ? 1 : 0,
              child: SafeArea(
                  child: Column(
                key: ValueKey<int>(0),
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: Duration(seconds: currentStepBreathTime),
                    curve: widget.curve,
                    height: breath
                        ? MediaQuery.of(context).size.height * 0.10
                        : (MediaQuery.of(context).size.height * 0.10 + 50),
                  ),
                  Stack(
                    children: [
                      AnimatedOpacity(
                        opacity: isLongHold ? 1 : 0,
                        duration: Duration(seconds: 1),
                        child: AnimatedContainer(
                          duration: Duration(
                              seconds:
                                  (isLongHold) ? 1 : currentStepBreathTime),
                          curve: widget.curve,
                          width: breath ? 270 : 200,
                          height: breath ? 270 : 200,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(
                              color: Colors.black,
                              width: breath ? 70 : 20,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: CustomPaint(
                              painter: _HolePainter(
                                circleSize: (_holdSizeAnimation.value *
                                        (180 * (breath ? 1 : 0.8))) *
                                    smallScreenSizeMultiplier,
                                ringColor:
                                    _colorAnimation.value!.withOpacity(0.66),
                                blur: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: Duration(
                            seconds: (isLongHold) ? 1 : currentStepBreathTime),
                        curve: widget.curve,
                        width: breath ? 270 : 200,
                        height: breath ? 270 : 200,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(
                            color: Colors.black,
                            width: breath ? 70 : 20,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: CustomPaint(
                            painter: _HolePainter(
                              circleSize: (_sizeAnimation.value * 135) *
                                  smallScreenSizeMultiplier,
                              ringColor: _colorAnimation.value,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  AnimatedContainer(
                    duration: Duration(seconds: currentStepBreathTime),
                    curve: widget.curve,
                    height: breath ? 70 : 90,
                  ),
                  Container(
                    width: 200,
                    height: 50,
                    child: !(isLongHold)
                        ? Wrap(
                            alignment: WrapAlignment.center,
                            runAlignment: WrapAlignment.center,
                            children: generateBreathDots(
                                widget.breathSteps[currentStep].duration),
                          )
                        : Container(),
                  ),
                  SizedBox(height: 25),
                  Container(
                    height: 100,
                    width: 250,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: 100),
                        child: StyledText(
                          key: ValueKey<int>(currentStep),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _colorAnimation.value,
                            fontSize: 20,
                          ),
                          text: instruction,
                          tags: {
                            'b': StyledTextTag(
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              )),
            )));
  }

  Widget buildLandscapeLayout() {
    return Material(
      color: widget.backgroundMediaUrl != null
          ? Colors.transparent
          : widget.breathSteps[0].backgroundColor != null
              ? _backgroundColorAnimation.value
              : Colors.white,
      child: Container(
        padding: EdgeInsets.all(30),
        child: AnimatedOpacity(
          duration: Duration(milliseconds: animationTime),
          opacity: fadeIn ? 1 : 0,
          child: SafeArea(
            child: AnimatedSwitcher(
                duration: Duration(seconds: 1),
                child: Column(
                  key: ValueKey<int>(0),
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                        height: locator<DeviceDetailsService>().isSmallScreen
                            ? 0
                            : 50),
                    RotatedBox(
                      quarterTurns: 3,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                              height: MediaQuery.of(context).size.width * 0.25),
                          Container(
                            width: 200,
                            height: 50,
                            child: !(isLongHold)
                                ? Wrap(
                                    alignment: WrapAlignment.center,
                                    runAlignment: WrapAlignment.center,
                                    children: generateBreathDots(widget
                                        .breathSteps[currentStep].duration),
                                  )
                                : Container(),
                          ),
                          SizedBox(height: 25),
                          Container(
                            height: 100,
                            width: 250,
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: Duration(milliseconds: 100),
                                child: StyledText(
                                  key: ValueKey<int>(currentStep),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _colorAnimation.value,
                                    fontSize: 20,
                                  ),
                                  text: instruction,
                                  tags: {
                                    'b': StyledTextTag(
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: Duration(seconds: currentStepBreathTime),
                      curve: widget.curve,
                      height: breath
                          ? MediaQuery.of(context).size.height * 0.10
                          : (MediaQuery.of(context).size.height * 0.10 + 50),
                    ),
                    Stack(
                      children: [
                        AnimatedOpacity(
                          opacity: isLongHold ? 1 : 0,
                          duration: Duration(seconds: 1),
                          child: AnimatedContainer(
                            duration: Duration(
                                seconds:
                                    (isLongHold) ? 1 : currentStepBreathTime),
                            curve: widget.curve,
                            width: breath ? 270 : 200,
                            height: breath ? 270 : 200,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              border: Border.all(
                                color: Colors.black,
                                width: breath ? 70 : 20,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: CustomPaint(
                                painter: _HolePainter(
                                  circleSize: (_holdSizeAnimation.value *
                                          (180 * (breath ? 1 : 0.8))) *
                                      smallScreenSizeMultiplier,
                                  ringColor:
                                      _colorAnimation.value!.withOpacity(0.66),
                                  blur: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: Duration(
                              seconds:
                                  (isLongHold) ? 1 : currentStepBreathTime),
                          curve: widget.curve,
                          width:
                              (breath ? 270 : 200) * smallScreenSizeMultiplier,
                          height:
                              (breath ? 270 : 200) * smallScreenSizeMultiplier,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(
                              color: Colors.transparent,
                              width: (breath ? 70 : 20) *
                                  smallScreenSizeMultiplier,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: CustomPaint(
                              painter: _HolePainter(
                                circleSize: (_sizeAnimation.value * 135) *
                                    smallScreenSizeMultiplier,
                                ringColor: _colorAnimation.value,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    AnimatedContainer(
                      duration: Duration(seconds: currentStepBreathTime),
                      curve: widget.curve,
                      height: breath ? 70 : 90,
                    ),
                  ],
                )),
          ),
        ),
      ),
    );
  }

  void changeColor(
      {Color? beginColor,
      Color? endColor,
      Color? backgroundBeginColor,
      Color? backgroundEndColor}) {
    _colorAnimationController.reset();

    _colorAnimation = ColorTween(
            begin: beginColor ?? Colors.black, end: endColor ?? Colors.black)
        .animate(_colorAnimationController)
      ..addListener(() {
        setState(() {});
      });
    _backgroundColorAnimation = ColorTween(
            begin: backgroundBeginColor ?? Colors.white,
            end: backgroundEndColor ?? Colors.white)
        .animate(_colorAnimationController)
      ..addListener(() {
        setState(() {});
      });

    _colorAnimationController.forward();
  }

  bool shouldStartAsExhale(List<BreathStep> steps) {
    if (steps.length > 1) {
      return widget.breathSteps[0].type == BreathType.exhale ||
          (widget.breathSteps[0].type == BreathType.hold &&
              widget.breathSteps[1].type == BreathType.exhale);
    }

    return widget.breathSteps.first.type == BreathType.exhale;
  }

  void buildColorsList(List<BreathStep> steps, int totalIterations) {
    circleColors.add(steps[0].ringColor);
    backgroundColors.add(steps[0].backgroundColor);

    for (int i = 0; i <= totalIterations; i++) {
      steps.forEach((step) {
        circleColors.add(step.ringColor);
        backgroundColors.add(step.backgroundColor);
      });
    }
  }
}

class _BreathDot extends StatelessWidget {
  bool isColored = false;
  Color? dotColor;

  _BreathDot(this.isColored, this.dotColor);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        color: isColored
            ? (dotColor ?? Colors.black)
            : (dotColor ?? Colors.grey).withOpacity(0.5),
        borderRadius: BorderRadius.circular(100),
      ),
    );
  }
}

class _HolePainter extends CustomPainter {
  double circleSize;
  Color? ringColor;
  bool? blur;

  _HolePainter({
    required this.circleSize,
    this.ringColor,
    this.blur,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    paint.color = ringColor ?? Colors.black;

    if (blur == true) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 16.0);
    }

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()
          ..addOval(Rect.fromCircle(center: Offset(0, 0), radius: circleSize)),
        Path()
          ..addOval(Rect.fromCircle(
              center: Offset(0, 0),
              radius: circleSize - ((circleSize * 1.1) - 75)))
          ..close(),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
