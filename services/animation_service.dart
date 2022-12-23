// A service to consume animation instructions and display them in sequential order
// The goal was to make it so this service could be injected anywhere (launch from any screen, any button, from a background process, deeplink, etc)
// The way it works is you call the service via locator<AnimationFlowService>().buildAnimationFlow(animations) then call startAnimationFlow.
// The reason for this seperation is so we can pre-load the animations before a user needs to access it - allowing for a smoother experience.
// In the MVP, we would load the animations on demand but later I split them into two functions. The main use is we pre-loaded the animations on the "routine" screen where users would typically find the button to launch these animations. This way when they launch - the API call is already finished and they can get right into their excercises.
// In summary - we create a collection of animations, add them to a collection, and programatically navigate from one animation to another
class AnimationFlowService {
  int currentAnimation = 0;
  List<Widget> animationSteps = [];
  List<AnimationModel> animations = [];
  Function(BuildContext)? animationsCompleteCallback;
  bool muteAnimationAudio = false;
  int _animationStepCounter = 0;
  List<Image> _cachedAnimationImages = [];

  void serviceOptions({
    Function(BuildContext)? onAllAnimationsComplete,
    bool? shouldMuteAnimationAudio,
  }) {
    if (onAllAnimationsComplete != null) {
      animationsCompleteCallback = onAllAnimationsComplete;
    }

    muteAnimationAudio = shouldMuteAnimationAudio ?? false;
  }

  // * Function to launch the animations in a consistent way using the current context
  void startAnimationFlow(BuildContext context) {
    if (animationSteps.length > 0) {
      currentAnimation = 0;
      goToNextScreen(context);
    } else {
      throw 'Cannot start animation flow - animation steps collection is empty.';
    }
  }

  // * Moves the animations along to the next animation as long as there's another animations queued up. If not - the animation callback is triggered, set to null to avoid any weird states, and the the navigation service routes the user back to the homescreen.
  void goToNextScreen(BuildContext context) async {
    if (currentAnimation < animationSteps.length) {
      debugPrint(
          'Going to next animation: ${currentAnimation + 1} of ${animationSteps.length}');

      Navigator.pushReplacement(
        context,
        FadeRoute(
          widget: animationSteps[currentAnimation],
          duration: Duration(milliseconds: 750),
        ),
      );

      currentAnimation++;
    } else {
      debugPrint('All animations complete!');

      if (animationsCompleteCallback != null) {
        animationsCompleteCallback!(context);

        // * Don't want to get into weird states so we destroy the function after we use it.
        animationsCompleteCallback = null;
      } else {
        locator<NavigationService>().popToHomescreen(context);
      }
    }
  }

  // * We had an engineer testing screen and this let us test features more quickly as well as trigger certain states
  Future<void> buildEngineerScreenTestingFlow() async {
    animations = [];
    Map<String, dynamic> response = await locator<ApiService>().send(
      url:
          '${Constants.contentfulEndpoint}${Constants.dailyFlowsEndpoint}?age=-1&hrv=-1',
      method: 'GET',
      headers: locator<ApiService>().defaultHeaders,
    );
    buildAnimationFlow(response['animationSteps']);
  }

  void buildAnimationFlow(List<dynamic> collection) async {
    animations = [];
    animationSteps = [];
    currentAnimation = 0;
    _animationStepCounter = 0;
    _cachedAnimationImages = [];

    if (collection is List<AnimationModel>) {
      animations.addAll(collection);
    } else {
      for (final Map<String, dynamic> step in collection) {
        AnimationModel model = AnimationModel.fromJson(step);
        if (model.type != AnimationTypes.undefined) {
          if (model.audioUrl != null &&
              locator<DailyFlowViewModel>().useCaching) {
            File fetchedFile =
                await DefaultCacheManager().getSingleFile(model.audioUrl!);
            model.cachedAudio = fetchedFile.path;
          }

          animations.add(model);
        }
      }
    }

    for (int a = 0; a < animations.length; a++) {
      AnimationModel animation = animations[a];
      _animationStepCounter++;

      switch (animation.type) {
        case AnimationTypes.breathe:
          _cacheImage(
            _animationStepCounter,
            animationImageUrl: animation.backgroundMediaUrl,
            backgroundImageUrl: animation.backgroundMediaUrl,
          );

          if (animation.breathSteps != null &&
              animation.breathSteps!.isNotEmpty) {
            for (int i = 0; i < animation.breathSteps!.length; i++) {
              if (animation.breathSteps![i].audioUrl != null &&
                  locator<DailyFlowViewModel>().useCaching) {
                File fetchedFile = await DefaultCacheManager()
                    .getSingleFile(animation.breathSteps![i].audioUrl!);
                animation.breathSteps![i].cachedAudioUrl = fetchedFile.path;
              }
            }
          }

          animationSteps.add(
            BreatheAnimation(
              animationIndex: _animationStepCounter,
              iterations: animation.iterations,
              orientation: animation.orientation,
              curve: animation.animationCurve,
              breathSteps: animation.breathSteps!,
              onAnimationEnd: (context) {
                goToNextScreen(context);
              },
            ),
          );
          break;
        case AnimationTypes.pursuit:
          _cacheImage(
            _animationStepCounter,
            animationImageUrl: animation.animationImageUrl,
            backgroundImageUrl: animation.backgroundMediaUrl,
          );

          animationSteps.add(
            PursuitAnimation(
              animationIndex: _animationStepCounter,
              milliseconds: animation.pursuitMillisecondsToComplete!,
              iterations: animation.iterations,
              positions: animation.positions!,
              endAtStart: animation.pursuitSaccadeCoordinatesEndAtStart!,
              curve: animation.animationCurve,
              audioUrl: animation.audioUrl,
              cachedAudioUrl: animation.cachedAudio,
              superSmooth: animation.pursuitSuperSmooth,
              animationImageUrl: animation.animationImageUrl,
              backgroundMediaUrl: animation.backgroundMediaUrl,
              animationImageWidth: animation.animationImageWidth,
              animationImageHeight: animation.animationImageHeight,
              onAnimationEnd: (context) {
                goToNextScreen(context);
              },
            ),
          );
          break;
        case AnimationTypes.saccade:
          _cacheImage(
            _animationStepCounter,
            animationImageUrl: animation.animationImageUrl,
            backgroundImageUrl: animation.backgroundMediaUrl,
          );

          animationSteps.add(
            SaccadeAnimation(
              animationIndex: _animationStepCounter,
              milliseconds: animation.saccadeHoldTime!,
              iterations: animation.iterations,
              positions: animation.positions!,
              endAtStart: animation.pursuitSaccadeCoordinatesEndAtStart!,
              audioUrl: animation.audioUrl,
              cachedAudioUrl: animation.cachedAudio,
              onAnimationEnd: (context) {
                goToNextScreen(context);
              },
              animationImageUrl: animation.animationImageUrl,
              backgroundMediaUrl: animation.backgroundMediaUrl,
              animationImageWidth: animation.animationImageWidth,
              animationImageHeight: animation.animationImageHeight,
            ),
          );
          break;
        case AnimationTypes.gazestabilization:
          _cacheImage(
            _animationStepCounter,
            animationImageUrl: animation.animationImageUrl,
            backgroundImageUrl: animation.backgroundMediaUrl,
          );

          animationSteps.add(
            GazeStabilizationAnimation(
              animationIndex: _animationStepCounter,
              milliseconds: animation.gazeStabilizationHoldTime!,
              audioUrl: animation.audioUrl,
              cachedAudioUrl: animation.cachedAudio,
              onAnimationEnd: (context) {
                goToNextScreen(context);
              },
              animationImageUrl: animation.animationImageUrl,
              backgroundMediaUrl: animation.backgroundMediaUrl,
              animationImageWidth: animation.animationImageWidth,
              animationImageHeight: animation.animationImageHeight,
            ),
          );
          break;
        case AnimationTypes.text:
          animationSteps.add(
            TextAnimation(
              animationIndex: _animationStepCounter,
              milliseconds: animation.textDisplayTime!,
              text: animation.animatedTextText!,
              orientation: animation.orientation,
              audioUrl: animation.audioUrl,
              cachedAudioUrl: animation.cachedAudio,
              onAnimationEnd: (context) {
                goToNextScreen(context);
              },
            ),
          );
          break;
        case AnimationTypes.video:
          animationSteps.add(
            VideoAnimation(
              url: animation.videoUrl!,
              backgroundColor: animation.videoBackgroundColor!,
              onAnimationEnd: (context) {
                goToNextScreen(context);
              },
            ),
          );
          break;
        case AnimationTypes.vor:
          _cacheImage(
            _animationStepCounter,
            animationImageUrl: animation.animationImageUrl,
            backgroundImageUrl: animation.backgroundMediaUrl,
          );

          animationSteps.add(
            VorAnimation(
              animationIndex: _animationStepCounter,
              milliseconds: animation.vorHoldTimeMilliseconds!,
              audioUrl: animation.audioUrl,
              onAnimationEnd: (context) {
                goToNextScreen(context);
              },
              animationImageUrl: animation.animationImageUrl,
              backgroundMediaUrl: animation.backgroundMediaUrl,
              animationImageWidth: animation.animationImageWidth,
              animationImageHeight: animation.animationImageHeight,
            ),
          );
          break;
        default:
          break;
      }
    }

    _cachedAnimationImages.forEach((element) {
      precacheImage(element.image, locator<BuildContextService>().context);
    });
  }

  void _cacheImage(int imageId,
      {String? animationImageUrl, String? backgroundImageUrl}) {
    if (animationImageUrl != null) {
      _cachedAnimationImages.add(Image.network(
        animationImageUrl,
        key: ValueKey("animationImage_$imageId"),
      ));
    }
    if (backgroundImageUrl != null) {
      _cachedAnimationImages.add(Image.network(
        backgroundImageUrl,
        key: ValueKey("backgroundMedia_$imageId"),
      ));
    }
  }
}
