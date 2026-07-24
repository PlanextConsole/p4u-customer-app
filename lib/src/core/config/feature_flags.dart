/// Customer app feature flags.
/// Food module code is kept; set [kFoodModuleEnabled] to true to show it again.
const bool kFoodModuleEnabled = bool.fromEnvironment(
  'FOOD_MODULE_ENABLED',
  defaultValue: false,
);
