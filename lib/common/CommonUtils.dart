String mealtimeLabel(String mealTime) {
  switch (mealTime) {
    case "BREAKFAST":
      return "Frühstück";
    case "BRUNCH":
      return "Brunch";
    case "LUNCH":
      return "Mittagessen";
    case "SNACK":
      return "Snack";
    case "DINNER":
      return "Abendessen";
    default:
      return "Mahlzeit";
  }
}