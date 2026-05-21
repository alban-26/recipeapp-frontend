class Environment {
  static late String recipeApiBaseUrl;
  static late String shoppingListApiBaseUrl;
  static late String authBaseUrl;
  static late String mealPlanApiBaseUrl;

  static void setEnvironment({required bool isProduction}) {
    if (isProduction) {
      recipeApiBaseUrl = 'https://loveyourmeal.cloud';     // Docker IP for release
      shoppingListApiBaseUrl = 'https://loveyourmeal.cloud';
      mealPlanApiBaseUrl = 'https://loveyourmeal.cloud';
      authBaseUrl = 'https://loveyourmeal.cloud';
    } else {
      recipeApiBaseUrl = 'http://10.0.2.2:8000';          // Android emulator -> host
      shoppingListApiBaseUrl = 'http://10.0.2.2:8000';
      mealPlanApiBaseUrl = 'http://10.0.2.2:8000';
      authBaseUrl = 'http://10.0.2.2:8000';
    }
  }
}
