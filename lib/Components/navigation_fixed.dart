import 'package:flutter/material.dart';
import 'package:money_control/Components/bottom_nav_bar.dart';
import 'package:money_control/Screens/analytics.dart';
import 'package:money_control/Screens/homescreen.dart';
import 'package:money_control/Screens/settings.dart';

class RootNavigator extends StatefulWidget {
  const RootNavigator({super.key});

  @override
  State<RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<RootNavigator> {
  final int _selectedIndex = 0;

  late final List<Widget> _pages = [
    const BankingHomeScreen(),
    const AnalyticsScreen(),
    const SettingsScreen(),
  ];

  PreferredSizeWidget? _getAppBar() {
    switch (_selectedIndex) {
      case 0:
        return AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text("Banking Home"),
          // Add your custom appbar widgets here for BankingHomeScreen
        );
      case 1:
        return AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text("Analysis"),
          centerTitle: true,
          // Add your AnalyticsScreen's appbar customizations
        );
      case 2:
        return AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text("Settings"),
          centerTitle: true,
          // Add your SettingsScreen's appbar customizations
        );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _getAppBar(),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavBar(currentIndex: _selectedIndex),
    );
  }
}
