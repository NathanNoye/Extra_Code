/// Navigation Utils - decoupled navigation
/// A utility class that makes navigation simpler
///
/// The simplest use is to call [goToTab] with the index of the tab or by
/// using the named indexes
/// This will tell the tab controller to navigate to that page
///
/// calling [popToRoot] will continue to pop until it can't anymore
/// At this point it should be at the root screen on which ever tab
/// the app was on before navigating away from that tab
/// ex: You start on the routine tab and then go to another page and then another
/// sub page. Calling popToRoot will pop you until you get back to routine page
///
/// calling [popToHomescreen] will continue to pop until it can't anymore
/// and then it will navigate to the main tab.
///
/// caling [openActivity] will open the details page of the activity
/// from anywhere. Typically should only be used by clicking on
/// a notification

class NavigationService with ChangeNotifier {
  static PageController? pageController;

  static const int homePage = routine;
  int launchPage = routine;

  // Static instance members to represent each tab index on the root screen
  static const int profile = 0;
  static const int routine = 1;
  static const int onDemand = 2;
  static const int resources = 3;
  static const int journal = 4;
  static const int dailyFlows = 5;
  static const int networkdetails = 6;
  static const int stressScoreDetails = 7;
  static const int stressTips = 8;
  static const int lifestyleTips = 9;
  static const int frequentlyAskedQuestionsGroupScreen = 10;
  static const int lifestyleTypeDetails = 11;
  static const int allExperts = 12;
  static const int trainingLog = 13;
  static const int trainingLogAllHistory = 14;

  // Initial value will also be the initial screen
  int currentPage = homePage;

  // Value will always be with respect to bottom navigation bar tab.
  int parentPage = homePage;

  int getCurrentTab() {
    return currentPage;
  }

  PageController getPageController() => pageController!;

  void goToTab(int index) {
    currentPage = index;

    //We are dealing with only the bottom navigation bar (4) tabs as parentPage.
    if (index < 4) {
      parentPage = index;
    }
    if (pageController != null && pageController!.hasClients) {
      pageController!.jumpToPage(index);
    }

    locator<AnalyticsService>().screenOpened(index);

    locator<RootViewModel>().rebuildWidgets();

    notifyListeners();
  }

  void init(PageController controller) {
    pageController = controller;

    if (!kReleaseMode)
      debugPrint('Navigator initialized - Current tab: $homePage');
  }

  void gotoDailyFlow(BuildContext context) {
    popToRoot(context);
    Navigator.push(
      context,
      FadeRoute(
        duration: Duration(seconds: 2),
        widget: DailyFlowsScreen(
          type: FlowTypes.wakeUp,
        ),
      ),
    );
  }

  void popToHomescreen(BuildContext context) {
    popToRoot(context);
    goToTab(NavigationService.homePage);
  }

  void popToRoot(BuildContext context) {
    while (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }
}
