# 4 EXPERIMENTS

## 4.1 Experimental Design

### 4.1.1 Overview
The experiments conducted in this study focused on evaluating the performance and functionality of the EasyRide ride-sharing application based on its implemented features. The experimental design was structured to test the core functionality of route matching algorithms, real-time communication systems, and user interface components as implemented in the codebase.

### 4.1.2 Independent Variables
- **Route Matching Algorithm**: Testing the implemented `calculateMatchPercentage()` function with different proximity thresholds
- **Location Services**: Evaluation of the `LocationService` class functionality including GPS accuracy and permission handling
- **Network Conditions**: Testing app performance under various network connectivity scenarios
- **User Interface Components**: Evaluation of implemented UI components and navigation patterns
- **Real-time Communication**: Testing the implemented chat system using Firebase Firestore

### 4.1.3 Dependent Variables
- **Route Matching Accuracy**: Percentage of successful matches between driver and passenger routes using the implemented algorithm
- **Response Time**: Time taken for route calculations using the OSRM API integration
- **User Experience Metrics**: App startup time and interface responsiveness
- **System Performance**: Memory usage and CPU utilization during app operation
- **Data Accuracy**: Precision of location coordinates using the Geolocator plugin

### 4.1.4 Control Variables
- **Device Specifications**: Consistent testing on Android devices with GPS capabilities
- **Network Environment**: Controlled testing environment with internet connectivity
- **App Version**: Testing conducted on the same application version
- **Firebase Configuration**: Consistent Firebase project settings and rules

## 4.2 Experimental Setup

### 4.2.1 Hardware Configuration
- **Primary Testing Device**: Android smartphone with GPS capabilities
- **Network**: Internet connectivity for Firebase and map services
- **Storage**: Sufficient storage for app data and cached map tiles

### 4.2.2 Software Environment
- **Operating System**: Android 10+ for compatibility with location services
- **Flutter Framework**: Version 3.0.2+ as specified in pubspec.yaml
- **Firebase Backend**: Firestore database and authentication services
- **Map Services**: OpenStreetMap integration with flutter_map_tile_caching
- **Development Tools**: Android Studio and Flutter SDK

### 4.2.3 Testing Infrastructure
```
Implemented Architecture:
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │────│  Firebase       │────│  Map Services   │
│   (Client)      │    │  Firestore      │    │  (OpenStreetMap)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ LocationService │    │  ChatService    │    │ RouteService    │
│ (Geolocator)    │    │ (Firestore)     │    │ (OSRM API)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 4.2.4 Data Collection Tools
- **Flutter Inspector**: For UI performance analysis
- **Firebase Console**: For monitoring Firestore operations
- **Geolocator Plugin**: For GPS accuracy measurement
- **Flutter Test Framework**: For automated testing

## 4.3 Procedure

### 4.3.1 Route Matching Algorithm Testing

#### Step 1: Route Data Preparation
1. **Create Test Routes**: Generate route datasets using the implemented `RouteService.calculateRoute()` method
2. **Define Matching Criteria**: Use the implemented proximity thresholds in `calculateMatchPercentage()` function
3. **Prepare Driver Routes**: Create driver routes using the `Driver` model class
4. **Prepare Passenger Routes**: Create passenger routes with different patterns

#### Step 2: Algorithm Execution
1. **Initialize Route Service**: Load the implemented `RouteService` class with test data
2. **Execute Matching Algorithm**: Run the implemented `calculateMatchPercentage()` function
3. **Record Results**: Document match percentages and processing time
4. **Validate Results**: Compare algorithm output with expected results

#### Step 3: Performance Analysis
```dart
// Actual test procedure using implemented RouteService
Future<void> testRouteMatching() async {
  for (var driverRoute in testDriverRoutes) {
    for (var passengerRoute in testPassengerRoutes) {
      final startTime = DateTime.now();
      final matchPercentage = RouteService.calculateMatchPercentage(
        driverRoute.points, 
        passengerRoute.points
      );
      final endTime = DateTime.now();
      final processingTime = endTime.difference(startTime).inMilliseconds;
      
      // Record metrics
      results.add({
        'driverRoute': driverRoute.id,
        'passengerRoute': passengerRoute.id,
        'matchPercentage': matchPercentage,
        'processingTime': processingTime
      });
    }
  }
}
```

### 4.3.2 Location Services Testing

#### Step 1: GPS Accuracy Testing
1. **Device Calibration**: Ensure GPS is properly calibrated on test devices
2. **Location Sampling**: Use the implemented `getCurrentLocation()` method
3. **Accuracy Measurement**: Compare GPS coordinates with known reference points
4. **Error Analysis**: Calculate average deviation from actual locations

#### Step 2: Location Service Performance
1. **Current Location Retrieval**: Test the implemented `getCurrentLocation()` function
2. **Location Streaming**: Evaluate the implemented `getLocationStream()` method
3. **Address Resolution**: Test the implemented `searchLocation()` function
4. **Distance Calculation**: Validate the implemented `calculateDistance()` method

#### Step 3: Permission Handling
1. **Permission Request**: Test the implemented `checkLocationPermission()` method
2. **Permission Denial**: Evaluate app behavior when location access is denied
3. **Permission Recovery**: Test app response when permissions are granted after denial

### 4.3.3 Real-time Communication Testing

#### Step 1: Chat System Performance
1. **Message Delivery**: Test the implemented `sendMessage()` method
2. **Real-time Updates**: Evaluate the implemented `getMessagesStream()` method
3. **Offer System**: Test the implemented offer creation and acceptance workflow
4. **Error Handling**: Test error recovery mechanisms in ChatService

#### Step 2: Firebase Integration Testing
1. **Authentication Flow**: Test the implemented Firebase authentication methods
2. **Data Synchronization**: Evaluate real-time data updates using Firestore streams
3. **Offline Capability**: Test app behavior when network connectivity is lost
4. **Data Consistency**: Verify data integrity using Firestore transactions

### 4.3.4 User Interface Testing

#### Step 1: Navigation Performance
1. **View Transitions**: Measure time for switching between implemented views
2. **Map Rendering**: Test the implemented flutter_map integration with tile caching
3. **UI Responsiveness**: Evaluate touch response time using Flutter Inspector
4. **Memory Usage**: Monitor app memory consumption during usage

#### Step 2: User Experience Evaluation
1. **Profile Creation**: Test the implemented ProfileCreationView
2. **Route Setup**: Evaluate the implemented RouteSetupWidget
3. **Driver-Passenger Matching**: Test the implemented matching interface
4. **Chat Interface**: Evaluate the implemented ChatView

### 4.3.5 Cross-Platform Compatibility Testing

#### Step 1: Android Platform Testing
1. **Device Compatibility**: Test on various Android devices and screen sizes
2. **OS Version Testing**: Evaluate performance across different Android versions
3. **Hardware Integration**: Test GPS, camera, and storage access using implemented plugins
4. **App Store Compliance**: Verify app meets Google Play Store requirements

#### Step 2: Performance Benchmarking
1. **Startup Time**: Measure app initialization using the implemented main.dart
2. **Memory Efficiency**: Monitor RAM usage during typical usage scenarios
3. **Battery Impact**: Measure battery consumption during location tracking
4. **Network Efficiency**: Evaluate data usage for map tiles and Firebase operations

### 4.3.6 Data Collection and Analysis

#### Step 1: Metrics Collection
1. **Performance Metrics**: Collect response times using implemented services
2. **User Interaction Data**: Track user actions using implemented UI components
3. **Error Logging**: Document system errors using Flutter's error handling
4. **Network Performance**: Monitor API call success rates using implemented HTTP clients

#### Step 2: Statistical Analysis
1. **Descriptive Statistics**: Calculate means and standard deviations of collected metrics
2. **Correlation Analysis**: Identify relationships between different performance metrics
3. **Regression Testing**: Verify that changes don't break existing functionality
4. **Comparative Analysis**: Compare performance across different test scenarios

### 4.3.7 Quality Assurance Procedures

#### Step 1: Automated Testing
1. **Unit Tests**: Test individual functions using the implemented Flutter test framework
2. **Widget Tests**: Verify UI components using the existing test/widget_test.dart structure
3. **Integration Tests**: Test interactions between different implemented services
4. **Performance Tests**: Automated benchmarking of critical app functions

#### Step 2: Manual Testing
1. **User Acceptance Testing**: Real users test the implemented features
2. **Usability Testing**: Evaluate app ease of use using implemented UI components
3. **Accessibility Testing**: Ensure app is usable by people with disabilities
4. **Security Testing**: Verify data protection using implemented Firebase security rules

This experimental procedure focuses on testing the actual implemented features of the EasyRide app, ensuring that all testing procedures are based on real code functionality rather than theoretical capabilities. 