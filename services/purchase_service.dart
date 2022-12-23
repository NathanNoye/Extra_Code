/// A service that implements RevenueCat and purchases from 3rd parties (ie PayPal from our website)
/// This service locks and unlocks widgets based on their subscription status.
/// It also allows us users to subscribe via revenue cat from within the app
/// If they subscribed via PayPal on the website, this service also handles unlocking the widgets for them
/// This also allows us to create promo codes and purchase hidden products (50% off for life, 1 month free, etc) without needing to go through the usual Apple and Google channels since both platforms handle it diferently and we wanted one promo code for each platform.

class PurchaseService {
  List<Offering> offers = [];
  Offering? currentOffer;
  bool isInitialized = false;
  bool checkSubscriptionStatusOnNextResume = false;
  bool isSubscribeFlowOpen = false;

  bool get canShowPurchaseService =>
      locator<DeviceDetailsService>().isPhysicalDevice!;

  Future<PurchaseService> init() async {
    if (isInitialized) {
      return this;
    }

    offers = [];
    currentOffer = null;
    isInitialized = false;

    if (!locator<DeviceDetailsService>().isPhysicalDevice!) {
      return this;
    }

    await Purchases.setDebugLogsEnabled(
        locator<EnvironmentSetupModel>().enableLogging);
    await Purchases.setup(
        locator<EnvironmentSetupModel>().credentials.revenueCatKey,
        appUserId: locator<SessionService>().userInfo!.userId);
    isInitialized = true;
    await fetchOffers();
    await getSubscriptionStatus();
    return this;
  }

  Future fetchOffers() async {
    if (!isInitialized) {
      await init();
      return;
    }

    offers = [];
    Offerings offerings = await Purchases.getOfferings();
    offers = offerings.all.entries.map((e) => e.value).toList();

    currentOffer = offerings.current;
    offers = currentOffer == null ? [] : [currentOffer!];
  }

  Future getSubscriptionStatus() async {
    if (!locator<DeviceDetailsService>().isPhysicalDevice!) {
      return;
    }

    if (!isInitialized) {
      await init();
      return;
    }

    if (locator<SessionService>().userInfo!.subscriptionProvider ==
            SubscriptionProvider.paypal &&
        locator<SessionService>().userInfo!.isPremium) {
      locator<SessionService>().unlockPremiumWidgets();
      return;
    }

    await Purchases.invalidatePurchaserInfoCache();
    PurchaserInfo purchaserInfo = await Purchases.getPurchaserInfo();
    locator<SessionService>().userInfo?.purchaserInfo = purchaserInfo;

    offers.forEach((offer) {
      if (purchaserInfo.activeSubscriptions.isNotEmpty) {
        List<Package> _currentPackage = offer.availablePackages
            .where((element) =>
                element.product.identifier ==
                purchaserInfo.activeSubscriptions.first)
            .toList();

        if (_currentPackage.isNotEmpty) {
          locator<SessionService>().userInfo?.currentPackage =
              _currentPackage.first;
        }
      }
    });

    if (purchaserInfo.entitlements.active.isNotEmpty) {
      locator<SessionService>().unlockPremiumWidgets();

      if (locator<SessionService>().userInfo?.currentPackage == null) {
        Product product = (await Purchases.getProducts(
                [purchaserInfo.activeSubscriptions.first]))
            .first;
        locator<SessionService>().userInfo?.currentProduct = product;
      }
    } else {
      locator<SessionService>().lockPremiumWidgets();
    }
  }

  Future purchasePackage(Package package, {UpgradeInfo? upgradeInfo}) async {
    // This service must be run on a physical device
    if (!locator<DeviceDetailsService>().isPhysicalDevice!) {
      return;
    }

    if (!isInitialized) {
      throw 'Purchase Service is not yet initilized';
    }

    try {
      await Purchases.invalidatePurchaserInfoCache();
      PurchaserInfo purchaserInfo =
          await Purchases.purchasePackage(package, upgradeInfo: upgradeInfo);
      List<EntitlementInfo> entitlements =
          purchaserInfo.entitlements.active.values.toList();
      locator<SessionService>().userInfo?.purchaserInfo = purchaserInfo;

      if (entitlements.isNotEmpty ||
          purchaserInfo.activeSubscriptions.isNotEmpty) {
        locator<SessionService>().unlockPremiumWidgets();
        locator<AnalyticsService>().userSubscribed(package);
        locator<UserEventsService>()
            .logEvent(eventName: UserEvent.subscriptionCompleted, eventMeta: {
          "package_id": package.identifier,
          "product_title": package.product.title,
          "price": package.product.price
        });
        locator<SessionService>().userInfo?.currentPackage = package;
      }
    } on PlatformException catch (e, stack) {
      PurchasesErrorCode errorCode = PurchasesErrorHelper.getErrorCode(e);

      locator<ErrorService>().captureException(
        e,
        stack,
        debuggingMessage:
            'An error occurred in the purchasePackage function: ${describeEnum(errorCode)}',
      );

      throw errorCode;
    }
  }

  Future purchaseProduct(Product product, {UpgradeInfo? upgradeInfo}) async {
    // This service must be run on a physical device
    if (!locator<DeviceDetailsService>().isPhysicalDevice!) {
      return;
    }

    if (!isInitialized) {
      throw 'Purchase Service is not yet initilized';
    }

    try {
      await Purchases.invalidatePurchaserInfoCache();
      PurchaserInfo purchaserInfo = await Purchases.purchaseProduct(
          product.identifier,
          upgradeInfo: upgradeInfo);

      List<EntitlementInfo> entitlements =
          purchaserInfo.entitlements.active.values.toList();

      locator<SessionService>().userInfo?.purchaserInfo = purchaserInfo;

      if (entitlements.isNotEmpty ||
          purchaserInfo.activeSubscriptions.isNotEmpty) {
        locator<SessionService>().unlockPremiumWidgets();
        locator<AnalyticsService>().userSubscribedViaProduct(product);
        locator<UserEventsService>()
            .logEvent(eventName: UserEvent.subscriptionCompleted, eventMeta: {
          "product_id": product.identifier,
          "product_title": product.title,
          "price": product.price
        });
        locator<SessionService>().userInfo?.currentProduct = product;
      }
    } on PlatformException catch (e, stack) {
      PurchasesErrorCode errorCode = PurchasesErrorHelper.getErrorCode(e);

      locator<ErrorService>().captureException(
        e,
        stack,
        debuggingMessage:
            'An error occurred in the purchaseProduct function: ${describeEnum(errorCode)}',
      );

      throw errorCode;
    }
  }

  Future<Product> purchaseProductById(String id) async {
    try {
      Product product = (await Purchases.getProducts([id])).first;
      await locator<PurchaseService>().purchaseProduct(product);
      return product;
    } catch (e) {
      rethrow;
    }
  }

  Future insertPromoCode(PromoCodeModel model, double price) async {
    try {
      await locator<ApiService>().send(
        url: '${Constants.promoCodeEndpoint}',
        method: 'POST',
        headers: locator<ApiService>().defaultHeaders,
        body: {
          'promo_code': model.code,
          'title': model.title,
          'price': price,
          'apple_store_id': model.appleStoreId ?? 'no_id_given',
          'google_store_id': model.googleStoreId ?? 'no_id_given',
          'max_uses': model.maxUses,
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  Future restorePurchases() async {
    // This service must be run on a physical device
    if (!locator<DeviceDetailsService>().isPhysicalDevice!) {
      return;
    }

    if (!isInitialized) {
      throw 'Purchase Service is not yet initilized';
    }

    try {
      PurchaserInfo restoredInfo = await Purchases.restoreTransactions();
      List<EntitlementInfo> entitlements =
          restoredInfo.entitlements.active.values.toList();

      if (entitlements.isNotEmpty ||
          restoredInfo.activeSubscriptions.isNotEmpty) {
        locator<SessionService>().unlockPremiumWidgets();
        locator<ApiService>().send(
          url: Constants.subscriptionEndpoint,
          method: 'PUT',
          headers: locator<ApiService>().defaultHeaders,
          body: {"subscription_level": 2},
        );
      } else {
        throw PurchasesErrorCode.missingReceiptFileError;
      }
    } on PlatformException catch (e, stack) {
      PurchasesErrorCode errorCode = PurchasesErrorHelper.getErrorCode(e);
      locator<ErrorService>().captureException(
        e,
        stack,
        debuggingMessage:
            'An error occurred in the restorePurchases function: ${describeEnum(errorCode)}',
      );
      throw errorCode;
    }
  }

  Future<PromoCodeModel?> getPromoCodeDetails(String promoCode) async {
    try {
      Map<String, dynamic> response = await locator<ApiService>().send(
          url: Constants.promoCodeEndpoint,
          method: 'GET',
          headers: locator<ApiService>().defaultHeaders,
          queryParameters: {'promoCode': promoCode});

      if (response.containsKey('isValid') && response['isValid'] == false) {
        return null;
      }

      return PromoCodeModel.fromJson(response['promoCodeDetails']);
    } catch (e) {
      throw e;
    }
  }

  void showPremiumContentModal(
      BuildContext context, Function(BuildContext) onSuccess) {
    NuroDialog.show(
      context,
      title: '<b>Subscription Required</b>',
      body: "Please subscribe to use this feature",
      titleAligment: TextAlign.center,
      bodyAlignment: TextAlign.center,
      buttonText: 'View details',
      secondaryButtonText: 'Maybe next time',
      onTap: () async {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubscribeDetailsScreen(
              onSuccess: (context) {
                onSuccess(context);
              },
            ),
          ),
        );
      },
      picture:
          Image(image: AssetImage('${Constants.imageRoot}brain_chevron.png')),
    );
  }

  Future showSubscriptionHasEndedModal(
      BuildContext context, Package package) async {
    await locator<HiveService>()
        .storeBoolean(Constants.wasShowResubscribeModal, true);
    locator<NavigationService>().popToHomescreen(context);
    NuroDialog.show(
      context,
      title: '<b>Your subscription has ended</b>',
      body:
          "To keep going, sign back up to continue building better brain health!",
      bodyAlignment: TextAlign.center,
      buttonText: 'Subscribe again',
      secondaryButtonText: 'No thank you',
      onTap: () async {
        await purchasePackage(package);
      },
      picture:
          Image(image: AssetImage('${Constants.imageRoot}brain_chevron.png')),
    );
  }
}
