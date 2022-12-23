
# Video Resources
Breathe animation video: https://youtu.be/DAljUK7S0HI
Memory animation video: https://youtu.be/wyshhICFKMw

# How the app is architected
We use MVVM with Provider and Dependancy injection. MVVM for architecting logic, Provider for statemanagement, and Dependancy Injection for services.
- Widgets are the smallest form of functionality
- Screens are a collection of views and widgets
- Services handle one off data functions
- See below for MVVM

## How to use MVVM

- MVVM stands for Model, View, View Model
- The Model is the structure for data to be represented inside our app
- The View is what the user will see. Our widgets will live here
- The ViewModel connects the View to the Model and handles all the logic between the two. Below you'll see an example using MVVM with the counter app.

### The View
The following code contains something you might not have seen before: a BaseView<CounterViewModel> builder.
This is a custom view model to enforce state management - it also exposes some helper functions to us (more on that later)
This view is ONLY handling display logic. It only displays widgets based on the state of the view model - hence why it's the view. Anything the user can interact with, should live here. Any business logic should live inside the view model. This BaseView<CounterViewModel> gives us access to the CounterViewModel.

```dart
class CounterView extends StatefulWidget {
  const CounterView({Key? key}) : super(key: key);

  @override
  State<CounterView> createState() => _CounterViewState();
}

class _CounterViewState extends State<CounterView> {
  @override
  Widget build(BuildContext context) {
    return BaseView<CounterViewModel>(builder: (
      BuildContext context,
      CounterViewModel viewmodel,
      Widget? _,
    ) {
      if (viewmodel.state == ViewState.busy) {
        return const CircularProgressIndicator();
      }

      if (viewmodel.state == ViewState.error) {
        return Column(
          children: [
            const Text('Sorry, something went wrong. Try again'),
            TextButton(
              onPressed: () {
                viewmodel.fakeAPIcall();
              },
              child: const Text('Try again'),
            ),
          ],
        );
      }

      return SizedBox(
        height: 300,
        child: Column(
          children: [
            Text('${viewmodel.totalCount}'),
            TextButton(
              onPressed: () {
                viewmodel.increment();
              },
              child: const Text('increment'),
            ),
            TextButton(
              onPressed: () {
                viewmodel.decrement();
              },
              child: const Text('Decrement'),
            ),
            TextButton(
              onPressed: () {
                viewmodel.fakeAPIcall();
              },
              child: const Text('fake API call'),
            ),
          ],
        ),
      );
    });
  }
}
```

### The View Model
The ViewModel allows the view to interact with the Model. 
This counter VM exposes certain functions to the view and allows the view to trigger certain functions. Down lower and you'll see it's also interacting with a service. These services are injected in to viewmodels. They're used throughout the app and live as one-off functions. We'll talk more about services later. For the now - you can see this view model interacts with a model called CounterModel. This model holds all the data that we'll want to display to the user - but it may not look EXACTLY like the data in the model. Often the model will hold data like the user's first name, but sometimes we need to modify that data without touching the model. This is where the ViewModel shines.
All of our VMs will be instantiated through GetIt. This will allow us to inject ViewModels into other ViewModels and expose services while maintaining the state. Most times you won't have to do this BUT the times you do - you'll be happy it's there. This also allows for MUCH more code re-use.


```dart
class CounterViewModel extends BaseViewModel {
  CounterModel model = CounterModel(totalCount: 0);

  int get totalCount => model.totalCount;

  void init() async {
    setState(ViewState.busy);
    await Future.delayed(const Duration(seconds: 3));
    setState(ViewState.idle);
  }

  void increment() {
    model.totalCount++;
    notifyListeners();
  }

  void decrement() {
    model.totalCount--;
    notifyListeners();
  }

  void fakeAPIcall(Map<String, dynamic> body) async {
    try {
        setState(ViewState.busy);
        locator<Session>().session = await locator<ApiService>().loginVersionTwo(body);
        model.totalCount = 99;
        setState(ViewState.idle);
    } catch (exception) {
        setState(ViewState.error);
    }
  }
}
```

### The Model
Pretty basic model - nothing special here. Just a basic model that holds data.

```dart
class CounterModel {
  int totalCount;

  CounterModel({
    required this.totalCount,
  });

  factory CounterModel.initial() {
    return CounterModel(totalCount: 0);
  }
}
```

### Services
Services are similar to view models in that they only expose functionality and occasionally return values but the main diference is they aren't related to any views at all. Rather they are focused on specific types of functionality. Where the counter view model is concerned about incrementing and decerementing the values in a model so it can display it to the front end - a service is focused on business logic that doesn't directly involve a view. For example - we might have a service that handles local storage with Hive. We can use a service that simplifies the storage process. Where we would normally need to open a box, insert the data, close the box, and return the result, we can instead just create a service function that inserts data into that box.

- The init function is used for initializing the service (not always needed but is when there's setup required)
- _openBox is a function that is used often so we put that into it's own function
- getSomeStoredData calls the _openBox function to create the connection to the stored data
- Then it starts going through it's logic to get the desired result. In this case - it checks if the stored data is fresh. If not - delete it

```dart
class HiveService {
  /// HiveService constructor.
  HiveService();

  /// Initialize Hive path and adapters
  Future<void> init() async {
    final Directory appDocumentDirectory = await path_provider.getApplicationDocumentsDirectory();
    Hive.init(appDocumentDirectory.path);

    Hive.registerAdapter(SomeAdapterHere());
  }

  Future<Box<T>> _openBox<T>(String boxName) async {
    if (!Hive.isBoxOpen(boxName)) {
      return await Hive.openBox<T>(boxName);
    }
    return Hive.box<T>(boxName);
  }

  Future<SomeObject?> getSomeStoredData(String parameter) async {
    // Query hive
    final Box<SomeObject> _someObject = await _openBox<SomeObject>(kDrawDatesBox);

    final SomeObject? _someObject_ = _someObject.get(parameter);
    if (_someObject_ == null) {
      return await getFreshData();
    }

    /// Checking if the data is fresh or not.
    final DateTime lastUpdated = DateTime.parse(_someObject.lastUpdated!);
    final int minutesSinceLastUpdate = lastUpdated.difference(DateTime.now()).inMinutes * -1;

    // If the data was pulled in the last hour, display it
    if (minutesSinceLastUpdate < kWinningNumbersCacheMinutes) {
        return _someObject;
    } else {
        // If not, delete the bad data and pull the new data
        _someObject.delete();
        return await getFreshData();
    }
  }
}
```

### Including the VM and Services in the dependency inject
We can to be able to call these VMs and Services from anywhere so we'll need them to be apart of a service locator. Luckily for us - there's a package called "GetIt" which does exactly this. Navigate to [APP_ROOT]/locator.dart and include the two services inside of the setupLocator function

```dart
GetIt locator = GetIt.instance;

void setupLocator() {
  locator.registerLazySingleton(() => CounterViewModel());
  locator.registerLazySingleton(() => HiveService());
}
```

Now we can call these sevices anywhere like this:

```dart
SomeData _someData = await locator<HiveService>().getSomeStoredData();
```

and boom. We now have decoupled services and VMs that can be injected anywhere.
You'll be injecting services WAY more often than ViewModels but there are some cases where you'll need to inject a view model here or there.
The part is - this follows the singleton design pattern that there's only one reference to the VMs and the services so the state is always maintained and predictable throughout the entire app.
