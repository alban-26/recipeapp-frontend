import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:recipeapp_frontend/StorageRepository.dart';
import 'package:recipeapp_frontend/recipe/RecipeRepository.dart';
import 'package:recipeapp_frontend/session/SessionCubit.dart';
import 'package:recipeapp_frontend/shopping/ShoppingListRepository.dart';
import 'package:recipeapp_frontend/user/UserRepository.dart';

import 'AppNavigator.dart';
import 'Environment.dart';
import 'api/AuthClient.dart';
import 'api/AuthInterceptor.dart';
import 'api/TokenStore.dart';
import 'auth/AuthRepository.dart';
import 'meal_plan/MealPlanApiClient.dart';
import 'meal_plan/MealPlanRepository.dart';
import 'offline/ConnectionStatus.dart';
import 'offline/LocalStore.dart';
import 'offline/OfflineData.dart';
import 'offline/SyncQueue.dart';
import 'offline/SyncScheduler.dart';
import 'recipe/import/RecipeLinkImporter.dart';
import 'recipe/import/SharedRecipeLinks.dart';

final ThemeData appTheme = ThemeData(
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
/*    selectedItemColor: Colors.blueAccent.shade200,
    unselectedItemColor: CupertinoColors.systemGrey4,*/
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
  ),
  useMaterial3: true,
  colorScheme: ColorScheme(
    brightness: Brightness.light,
    primary: Colors.orangeAccent.shade200,
    onPrimary: Colors.white,
    secondary: Colors.orangeAccent.shade200,
    onSecondary: Colors.white,
    background: Color(0xFFFFF9C4),
    onBackground: Color(0xFF424242),
    surface: Colors.white,
    onSurface: Color(0xFF424242),
    error: Colors.redAccent,
    onError: Colors.white,
  ),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Environment.setEnvironment(isProduction: true);

  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final tokenStore = TokenStore(secureStorage);

  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    sendTimeout: const Duration(seconds: 20),
  ));

  // Eigene Instanz OHNE Interceptor, ausschliesslich fuer den Refresh-Call.
  final refreshDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  // GENAU EINMAL, direkt nach dem Dio-Konstruktor und VOR dem ersten
  // API-Client. authBaseUrl ist fest - der Refresh geht damit immer an den
  // Auth-Service, egal welcher Request den 401 ausgeloest hat.
  dio.interceptors.add(AuthInterceptor(
    dio: dio,
    refreshDio: refreshDio,
    tokenStore: tokenStore,
    authBaseUrl: Environment.authBaseUrl,
  ));

  // --- Offline-Modus --------------------------------------------------------
  // Merkt sich anhand der echten Requests, ob der Server erreichbar ist.
  final connectionStatus = ConnectionStatus();
  dio.interceptors.add(ConnectivityInterceptor(connectionStatus));

  // Lokale Ablage (Listen, Rezepte, Bilder) und die Warteschlange fuer
  // Aenderungen, die noch zum Server muessen.
  final localStore = await LocalStore.open();
  final syncQueue = SyncQueue(store: localStore);
  await syncQueue.load();
  final offlineData = OfflineData(store: localStore, queue: syncQueue);

  final fileStorage = StorageRepository(
      dio: dio,
      secureStorage: secureStorage,
      baseUrl: Environment.recipeApiBaseUrl,
      imageCache: localStore);

  final authRepository = AuthRepository(
    authClient: AuthClient(
        dio: dio,
        secureStorage: secureStorage,
        baseUrl: Environment.authBaseUrl),
    tokenStore: tokenStore,
  );

  // Die Repositories entstehen HIER und nicht erst bei Bedarf im Widget-Baum:
  // das ShoppingListRepository meldet seine Handler bei der Warteschlange an,
  // und die muessen stehen, bevor zum ersten Mal synchronisiert wird.
  final recipeRepository = RecipeRepository(
    apiClient: RecipeApiClient(
        dio: dio,
        secureStorage: secureStorage,
        baseUrl: Environment.recipeApiBaseUrl,
        storageRepository: fileStorage),
    store: localStore,
  );
  final shoppingListRepository = ShoppingListRepository(
    apiClient: ShoppingListApiClient(
        dio: dio,
        secureStorage: secureStorage,
        baseUrl: Environment.shoppingListApiBaseUrl,
        storageRepository: fileStorage),
    store: localStore,
    queue: syncQueue,
    connectionStatus: connectionStatus,
  );
  final mealPlanRepository = MealPlanRepository(
    apiClient: MealPlanApiClient(
        dio: dio,
        secureStorage: secureStorage,
        baseUrl: Environment.mealPlanApiBaseUrl,
        storageRepository: fileStorage),
    store: localStore,
  );
  final userRepository = UserRepository(
      apiClient: UserApiClient(
    dio: dio,
    secureStorage: secureStorage,
    baseUrl: Environment.authBaseUrl,
  ));

  offlineData.onReset(recipeRepository.resetCache);
  offlineData.onReset(shoppingListRepository.resetCache);
  offlineData.onReset(mealPlanRepository.resetCache);

  // Reicht wartende Aenderungen nach, sobald der Server wieder erreichbar ist.
  final syncScheduler = SyncScheduler(
    queue: syncQueue,
    status: connectionStatus,
    // Erst wenn feststeht, dass die lokalen Daten zum angemeldeten Konto
    // gehoeren (das prueft der SessionCubit beim Start).
    hasSession: () async =>
        offlineData.isReady && await tokenStore.hasSession(),
    probe: () async {
      await userRepository.getUser();
    },
  )..start();

  // Rezept-Import: Links aus anderen Apps ("Teilen") und das Laden fremder Seiten.
  final sharedRecipeLinks = SharedRecipeLinks();
  await sharedRecipeLinks.start();
  final recipeLinkImporter = RecipeLinkImporter();

  runApp(MyApp(
    authRepository: authRepository,
    storageRepository: fileStorage,
    tokenStore: tokenStore,
    recipeRepository: recipeRepository,
    shoppingListRepository: shoppingListRepository,
    mealPlanRepository: mealPlanRepository,
    userRepository: userRepository,
    connectionStatus: connectionStatus,
    syncQueue: syncQueue,
    syncScheduler: syncScheduler,
    offlineData: offlineData,
    sharedRecipeLinks: sharedRecipeLinks,
    recipeLinkImporter: recipeLinkImporter,
  ));
}

class MyApp extends StatelessWidget {
  final AuthRepository authRepository;
  final StorageRepository storageRepository;
  final TokenStore tokenStore;
  final RecipeRepository recipeRepository;
  final ShoppingListRepository shoppingListRepository;
  final MealPlanRepository mealPlanRepository;
  final UserRepository userRepository;
  final ConnectionStatus connectionStatus;
  final SyncQueue syncQueue;
  final SyncScheduler syncScheduler;
  final OfflineData offlineData;
  final SharedRecipeLinks sharedRecipeLinks;
  final RecipeLinkImporter recipeLinkImporter;

  const MyApp({
    super.key,
    required this.authRepository,
    required this.storageRepository,
    required this.tokenStore,
    required this.recipeRepository,
    required this.shoppingListRepository,
    required this.mealPlanRepository,
    required this.userRepository,
    required this.connectionStatus,
    required this.syncQueue,
    required this.syncScheduler,
    required this.offlineData,
    required this.sharedRecipeLinks,
    required this.recipeLinkImporter,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: recipeRepository),
        RepositoryProvider.value(value: shoppingListRepository),
        RepositoryProvider.value(value: mealPlanRepository),
        RepositoryProvider.value(value: userRepository),
        RepositoryProvider.value(value: storageRepository),
        RepositoryProvider.value(value: connectionStatus),
        RepositoryProvider.value(value: syncQueue),
        RepositoryProvider.value(value: syncScheduler),
        RepositoryProvider.value(value: sharedRecipeLinks),
        RepositoryProvider.value(value: recipeLinkImporter),
      ],
      child: BlocProvider(
          create: (context) => SessionCubit(
                authRepo: authRepository,
                userRepository: context.read<UserRepository>(),
                tokenStore: tokenStore,
                offlineData: offlineData,
              ),
          child: MaterialApp(
            theme: appTheme,
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.system,
            locale: const Locale('de'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('de'),
              Locale('en'),
            ],
            home: AppNavigator(),
          )),
    );
  }
}
