class WeatherModel {
  const WeatherModel({
    required this.icon,
    required this.status,
    required this.currentTemperature,
    required this.minTemperature,
    required this.maxTemperature,
    this.isSimulated = false,
  });

  final String icon;
  final String status;
  final double currentTemperature;
  final double minTemperature;
  final double maxTemperature;
  final bool isSimulated;
}
