import 'package:flutter_test/flutter_test.dart';

import 'package:mausam_personalized/models/homepage_response.dart';
import 'package:mausam_personalized/models/weather_data.dart';
import 'package:mausam_personalized/widgets/scenic_weather_hero.dart';

void main() {
  group('Weather Code & Authority Integration Tests', () {
    test('IMD codes map correctly to visual states', () {
      expect(
        resolveWeatherVisualState(
          condition: '',
          weatherCode: '1',
          codeSystem: WeatherCodeSystem.imd,
        ),
        WeatherVisualState.sunny,
      );
      expect(
        resolveWeatherVisualState(
          condition: '',
          weatherCode: '2',
          codeSystem: WeatherCodeSystem.imd,
        ),
        WeatherVisualState.partlyCloudy,
      );
      expect(
        resolveWeatherVisualState(
          condition: '',
          weatherCode: '3',
          codeSystem: WeatherCodeSystem.imd,
        ),
        WeatherVisualState.cloudy,
      );
      expect(
        resolveWeatherVisualState(
          condition: '',
          weatherCode: '4',
          codeSystem: WeatherCodeSystem.imd,
        ),
        WeatherVisualState.thunderstorm,
      );
      expect(
        resolveWeatherVisualState(
          condition: 'Haze',
          weatherCode: '5',
          codeSystem: WeatherCodeSystem.imd,
          tempC: 29.0,
          rainMm: 0.0,
          visibilityKm: 14.68,
        ),
        WeatherVisualState.fog,
      );
      expect(
        resolveWeatherVisualState(
          condition: '',
          weatherCode: '6',
          codeSystem: WeatherCodeSystem.imd,
        ),
        WeatherVisualState.fog,
      );
      expect(
        resolveWeatherVisualState(
          condition: '',
          weatherCode: '7',
          codeSystem: WeatherCodeSystem.imd,
        ),
        WeatherVisualState.snow,
      );
      expect(
        resolveWeatherVisualState(
          condition: '',
          weatherCode: '8',
          codeSystem: WeatherCodeSystem.imd,
        ),
        WeatherVisualState.drizzle,
      );
      expect(
        resolveWeatherVisualState(
          condition: '',
          weatherCode: '9',
          codeSystem: WeatherCodeSystem.imd,
        ),
        WeatherVisualState.heavyRain,
      );
    });

    test('WMO forecast codes retain correct meanings', () {
      expect(
        resolveWeatherVisualState(
          condition: '',
          weatherCode: '0',
          codeSystem: WeatherCodeSystem.wmo,
        ),
        WeatherVisualState.sunny,
      );
      expect(
        resolveWeatherVisualState(
          condition: '',
          weatherCode: '1',
          codeSystem: WeatherCodeSystem.wmo,
        ),
        WeatherVisualState.sunny,
      );
      expect(
        resolveWeatherVisualState(
          condition: '',
          weatherCode: '2',
          codeSystem: WeatherCodeSystem.wmo,
        ),
        WeatherVisualState.partlyCloudy,
      );
      expect(
        resolveWeatherVisualState(
          condition: '',
          weatherCode: '3',
          codeSystem: WeatherCodeSystem.wmo,
        ),
        WeatherVisualState.cloudy,
      );
      expect(
        resolveWeatherVisualState(
          condition: '',
          weatherCode: '45',
          codeSystem: WeatherCodeSystem.wmo,
        ),
        WeatherVisualState.fog,
      );
      expect(
        resolveWeatherVisualState(
          condition: '',
          weatherCode: '51',
          codeSystem: WeatherCodeSystem.wmo,
        ),
        WeatherVisualState.drizzle,
      );
      expect(
        resolveWeatherVisualState(
          condition: '',
          weatherCode: '61',
          codeSystem: WeatherCodeSystem.wmo,
        ),
        WeatherVisualState.rain,
      );
      expect(
        resolveWeatherVisualState(
          condition: '',
          weatherCode: '65',
          codeSystem: WeatherCodeSystem.wmo,
        ),
        WeatherVisualState.heavyRain,
      );
      expect(
        resolveWeatherVisualState(
          condition: '',
          weatherCode: '71',
          codeSystem: WeatherCodeSystem.wmo,
        ),
        WeatherVisualState.snow,
      );
      expect(
        resolveWeatherVisualState(
          condition: '',
          weatherCode: '95',
          codeSystem: WeatherCodeSystem.wmo,
        ),
        WeatherVisualState.thunderstorm,
      );
    });

    test('HomepageResponse preserves weatherCode in model', () {
      final response = HomepageResponse(
        city: 'Hyderabad',
        temperature: 29.0,
        humidity: 65.0,
        windSpeed: 10.0,
        condition: 'Haze',
        cards: const [],
        source: 'IMD',
        weatherCode: '5',
      );

      expect(response.weatherCode, '5');
      expect(response.source, 'IMD');
    });

    test('WeatherData preserves weatherCode and weatherCodeSystem', () {
      const weather = WeatherData(
        city: 'Hyderabad',
        state: 'Telangana',
        temperatureC: 29.0,
        feelsLikeC: 31.0,
        humidity: 60,
        weatherCondition: 'Haze',
        weatherConditionDetail: 'Hazy conditions',
        windSpeedKmh: 12.0,
        windDirection: 'NE',
        rainfallProbability: 10.0,
        visibilityKm: 14.68,
        weatherCode: '5',
        weatherCodeSystem: WeatherCodeSystem.imd,
      );

      expect(weather.weatherCode, '5');
      expect(weather.weatherCodeSystem, WeatherCodeSystem.imd);

      final updated = weather.copyWith(weatherCode: '3');
      expect(updated.weatherCode, '3');
      expect(updated.weatherCodeSystem, WeatherCodeSystem.imd);
    });

    test('Weather image mapping selects snowy.png exclusively for snow conditions', () {
      expect(weatherImageAsset(WeatherVisualState.snow), 'assets/images/snowy.png');
      expect(weatherImageAsset(WeatherVisualState.sunny), 'assets/images/sunny.png');
      expect(weatherImageAsset(WeatherVisualState.partlyCloudy), 'assets/images/partly_cloudy.png');
      expect(weatherImageAsset(WeatherVisualState.rain), 'assets/images/rainy.png');
      expect(weatherImageAsset(WeatherVisualState.heavyRain), 'assets/images/rainy.png');
      expect(weatherImageAsset(WeatherVisualState.thunderstorm), 'assets/images/thunderstorm.png');
      expect(weatherImageAsset(WeatherVisualState.fog), 'assets/images/foggy.png');

      // Condition strings
      expect(weatherImageAssetFor(condition: 'Snow Showers'), 'assets/images/snowy.png');
      expect(weatherImageAssetFor(condition: 'Blizzard'), 'assets/images/snowy.png');
      expect(weatherImageAssetFor(condition: 'Clear Sunny'), 'assets/images/sunny.png');
      expect(weatherImageAssetFor(condition: 'Heavy Rain'), 'assets/images/rainy.png');
    });
  });
}
