/// Creates an animation of words and numbers moving in random around the screen for the user to memorize
/// Video example can be found on YouTube: https://youtu.be/wyshhICFKMw

class MemoryAnimation extends StatefulWidget {
  final int animationIndex;
  final List<String> words;
  final List<int> numbers;
  int? delayed;
  Function? onComplete;

  MemoryAnimation({
    required this.animationIndex,
    required this.words,
    required this.numbers,
    this.delayed,
    this.onComplete,
  });

  @override
  State<MemoryAnimation> createState() => _MemoryAnimationState();
}

class _MemoryAnimationState extends State<MemoryAnimation> {
  bool isCountingDown = true;
  bool showEndingText = false;
  List<String> countdownText = ['', '3', '2', '1', 'Begin', ''];
  int step = 0;
  late Timer timer;

  @override
  void initState() {
    super.initState();
    Wakelock.enable();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.delayed != null) {
        await Future.delayed(Duration(seconds: widget.delayed!));
      }

      timer = Timer.periodic(Duration(seconds: 1), (timer) async {
        setState(() {
          if (timer.tick < countdownText.length) {
            step++;
          }

          if (step == 5) {
            isCountingDown = false;
          }
        });

        if (timer.tick == 35) {
          setState(() {
            showEndingText = true;
          });
        }

        if (timer.tick == 38) {
          timer.cancel();

          if (widget.onComplete != null) {
            widget.onComplete!();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child: (isCountingDown || showEndingText)
            ? Center(
                key: ValueKey<int>(step),
                child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Text(
                    showEndingText
                        ? 'Your 30 second timer starts now'
                        : countdownText[
                            step.clamp(0, countdownText.length - 1)],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: showEndingText
                            ? 32
                            : step != 4
                                ? 70
                                : 45),
                  ),
                ),
              )
            : Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: MediaQuery.of(context).size.height * 0.10),
                child: SafeArea(
                  child: Stack(
                      children: [
                    widget.words
                        .map((text) => _MoveableText(text: text.capitalize()))
                        .toList(),
                    widget.numbers
                        .map((numbers) => _MoveableText(text: '$numbers'))
                        .toList(),
                  ].expand((x) => x).toList()),
                ),
              ),
      ),
    );
  }
}

class _MoveableText extends StatefulWidget {
  final String text;

  _MoveableText({required this.text});

  @override
  State<_MoveableText> createState() => _MoveableTextState();
}

class _MoveableTextState extends State<_MoveableText>
    with TickerProviderStateMixin {
  late final CatmullRomSpline path;

  late AnimationController controller;
  late Animation<double> animation;
  late AnimationController rotationController;
  late Animation<double> rotationAnimation;
  Random random = new Random();
  late bool shouldRotate;

  @override
  void initState() {
    super.initState();
    List<Offset> paths = _generatePaths();
    path = CatmullRomSpline(
      paths,
      startHandle: paths[1],
      endHandle: paths[paths.length - 2],
    );

    shouldRotate = random.nextDouble() > 0.45;
    controller = AnimationController(
        duration: Duration(seconds: random.nextInt(16).clamp(10, 15)),
        vsync: this);
    animation = CurvedAnimation(parent: controller, curve: Curves.linear);
    controller.repeat();
    controller.addListener(() => setState(() {}));

    rotationController = AnimationController(
        duration: Duration(seconds: random.nextInt(7).clamp(1, 7)),
        vsync: this);
    rotationAnimation =
        CurvedAnimation(parent: rotationController, curve: Curves.easeInOut);
    rotationController.repeat(reverse: true);
    rotationController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    controller.dispose();
    rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Offset position =
        path.transform(animation.value) * 2.0 - const Offset(1.0, 1.0);

    return Container(
      child: Align(
        alignment: Alignment(position.dx, position.dy),
        child: shouldRotate
            ? RotationTransition(
                turns: rotationAnimation,
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: 28,
                  ),
                ),
              )
            : Align(
                alignment: Alignment(position.dx, position.dy),
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: 28,
                  ),
                ),
              ),
      ),
    );
  }

  static List<Offset> _generatePaths() {
    Random random = new Random();
    List<Offset> paths = [];

    for (int i = 0; i < random.nextInt(18).clamp(11, 17); i++) {
      paths.add(Offset(random.nextDouble(), random.nextDouble()));
    }

    paths.add(paths[0]);

    return paths;
  }
}
