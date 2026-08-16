import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:recipeapp_frontend/StorageRepository.dart';
import 'package:recipeapp_frontend/recipe/RecipeRepository.dart';
import 'package:recipeapp_frontend/session/SessionCubit.dart';
import 'package:recipeapp_frontend/shopping/ShoppingListRepository.dart';
import 'package:recipeapp_frontend/user/UserRepository.dart';

import 'AppNavigator.dart';
import 'Environment.dart';
import 'api/AuthClient.dart';
import 'auth/AuthRepository.dart';
import 'meal_plan/MealPlanApiClient.dart';
import 'meal_plan/MealPlanRepository.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

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

  // Set environment depending on whether it's release or debug
  //bool isProduction = bool.fromEnvironment('dart.vm.product');
  Environment.setEnvironment(isProduction: true);

  final secureStorage = FlutterSecureStorage();
  final dio = Dio();

  final fileStorage = StorageRepository(
      dio: dio, secureStorage: secureStorage, baseUrl: Environment.recipeApiBaseUrl);

  final authRepository = AuthRepository(
    authClient: AuthClient(
        dio: dio,
        secureStorage: secureStorage,
        baseUrl: Environment.authBaseUrl),
    storage: secureStorage,
  );

  runApp(MyApp(
    authRepository: authRepository,
    dio: dio,
    secureStorage: secureStorage,
    storageRepository: fileStorage,
  ));
}

class MyApp extends StatelessWidget {
  final AuthRepository authRepository;
  final Dio dio;
  final FlutterSecureStorage secureStorage;
  final StorageRepository storageRepository;

  const MyApp(
      {super.key,
      required this.authRepository,
      required this.dio,
      required this.secureStorage,
      required this.storageRepository});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider(
          create: (context) => RecipeRepository(
            apiClient: RecipeApiClient(
                dio: dio,
                secureStorage: secureStorage,
                baseUrl: Environment.recipeApiBaseUrl,
                storageRepository: storageRepository),
          ),
        ),
        RepositoryProvider(
          create: (context) => ShoppingListRepository(
            apiClient: ShoppingListApiClient(
                dio: dio,
                secureStorage: secureStorage,
                baseUrl: Environment.shoppingListApiBaseUrl,
                storageRepository: storageRepository),
          ),
        ),
        RepositoryProvider(
          create: (context) => MealPlanRepository(
            apiClient: MealPlanApiClient(
                dio: dio,
                secureStorage: secureStorage,
                baseUrl: Environment.mealPlanApiBaseUrl,
                storageRepository: storageRepository),
          ),
        ),
        RepositoryProvider(
          create: (context) => UserRepository(
              apiClient: UserApiClient(
            dio: dio,
            secureStorage: secureStorage,
            baseUrl: Environment.authBaseUrl,
          )),
        ),
        RepositoryProvider(
            create: (context) => StorageRepository(
                dio: dio,
                secureStorage: secureStorage,
                baseUrl: Environment.recipeApiBaseUrl))
      ],
      child: BlocProvider(
          create: (context) => SessionCubit(
                authRepo: authRepository,
                userRepository: context
                    .read<UserRepository>(),
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
