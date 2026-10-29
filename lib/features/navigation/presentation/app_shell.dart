import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../updates/app_update_page.dart';
import '../../../core/auth/ai_auth_session.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/config/ai_service_config.dart';
import '../../skincare/data/skincare_repository.dart';
import '../../skincare/data/skincare_ai_service.dart';
import '../../skincare/application/skincare_reminders.dart';
import '../../skincare/presentation/skincare_page.dart';
import '../../kitchen/data/kitchen_repository.dart';
import '../../kitchen/data/kitchen_ai_service.dart';
import '../../kitchen/presentation/kitchen_page.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/weather_service.dart';
import '../../home/presentation/home_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../wardrobe/data/clothing_image_parameter_service.dart';
import '../../wardrobe/data/preorder_analysis_service.dart';
import '../../wardrobe/data/wardrobe_image_service.dart';
import '../../wardrobe/data/wardrobe_repository.dart';
import '../../wardrobe/domain/models/preorder_item.dart';
import '../../wardrobe/presentation/outfit_page.dart';
import '../../wardrobe/presentation/preorder_form_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.controller,
    this.aiAuthSession,
    this.kitchenRepository,
    this.kitchenAiService,
    this.homeRepository,
    this.wardrobeRepository,
    this.wardrobeImageService,
    this.clothingImageParameterService =
        const UnconfiguredClothingImageParameterService(),
    this.preorderAnalysisService = const UnconfiguredPreorderAnalysisService(),
  });

  final AppController controller;
  final AiAuthSession? aiAuthSession;
  final KitchenRepository? kitchenRepository;
  final KitchenAiService? kitchenAiService;
  final HomeRepository? homeRepository;
  final WardrobeRepository? wardrobeRepository;
  final WardrobeImageService? wardrobeImageService;
  final ClothingImageParameterService clothingImageParameterService;
  final PreorderAnalysisService preorderAnalysisService;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _selectedDestination = 'home';
  final _skinRepository = SkincareRepository();
  late final _skinAi = SkincareAiService(
    tokenProvider: widget.aiAuthSession?.validAccessToken,
  );
  late final _skinReminders = SkincareReminders(_skinRepository);
  final _skinKey = GlobalKey<SkincarePageState>();
  bool _skinEnabled = false;
  Future<void> _syncSkinModule() async {
    final enabled = widget.controller.skincareModuleEnabled;
    if (enabled == _skinEnabled) return;
    _skinEnabled = enabled;
    try {
      await _skinReminders.reschedule(enabled: enabled);
    } catch (_) {
      /* Page reports scheduling failures on entry. */
    }
  }

  void _openSkinNotification(String period) {
    if (!mounted || !widget.controller.skincareModuleEnabled) return;
    setState(() => _selectedDestination = 'skincare');
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _skinKey.currentState?.startPeriod(period),
    );
  }

  Future<void> _initializeSkinReminders() async {
    try {
      await _skinReminders.initialize();
      _skinReminders.onTap = _openSkinNotification;
      await _skinReminders.reschedule(
        enabled: widget.controller.skincareModuleEnabled,
      );
      _skinEnabled = widget.controller.skincareModuleEnabled;
      if (_skinReminders.launchPeriod != null) {
        _openSkinNotification(_skinReminders.launchPeriod!);
      }
    } catch (_) {
      /* Unsupported platforms keep the local planner available. */
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncSkinModule);
    _skinReminders.onTap = null;
    super.dispose();
  }

  late final WardrobeRepository _wardrobeRepository;
  late final WardrobeImageService _wardrobeImageService;
  int _wardrobeRevision = 0;
  late final _kitchenRepository =
      widget.kitchenRepository ?? KitchenRepository();
  late final _kitchenAiService =
      widget.kitchenAiService ??
      ProxyKitchenAiService(
        endpoint: AiServiceConfig.kitchenRecommendationProxyUrl,
        accessTokenProvider: widget.aiAuthSession?.validAccessToken,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdatePrompt.check(context);
      }
    });
    widget.controller.addListener(_syncSkinModule);
    _initializeSkinReminders();
    _wardrobeRepository = widget.wardrobeRepository ?? WardrobeRepository();
    _wardrobeImageService =
        widget.wardrobeImageService ?? DeviceWardrobeImageService();
  }

  void _notifyWardrobeChanged() {
    if (mounted) {
      setState(() => _wardrobeRevision++);
    }
  }

  Future<void> _applyTodayWeatherToOutfit() async {
    final weather = await const MockWeatherService().getCurrentWeather();
    await _wardrobeRepository.applyTemperatureForDate(
      date: DateTime.now(),
      minTemperature: weather.minTemperature,
      maxTemperature: weather.maxTemperature,
      weatherType: weather.status,
    );
  }

  Future<void> _quickAddPreorder() async {
    final savedItem = await Navigator.of(context).push<PreorderItem>(
      MaterialPageRoute(
        builder: (context) => PreorderFormPage(
          repository: _wardrobeRepository,
          imageService: _wardrobeImageService,
        ),
      ),
    );
    if (savedItem != null) {
      _notifyWardrobeChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = <_AppDestination>[
      _AppDestination(
        id: 'home',
        label: '首页',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        page: HomePage(
          key: const PageStorageKey('home'),
          homeRepository: widget.homeRepository,
          wardrobeRepository: _wardrobeRepository,
          onQuickAddPreorder: _quickAddPreorder,
          dataRevision: _wardrobeRevision,
        ),
      ),
      if (widget.controller.outfitModuleEnabled)
        _AppDestination(
          id: 'outfit',
          label: '穿搭',
          icon: Icons.checkroom_outlined,
          selectedIcon: Icons.checkroom,
          page: OutfitPage(
            key: const PageStorageKey('outfit'),
            repository: _wardrobeRepository,
            imageService: _wardrobeImageService,
            imageParameterService: widget.clothingImageParameterService,
            preorderAnalysisService: widget.preorderAnalysisService,
            showFemaleCategories:
                widget.controller.profileGender == ProfileGender.female,
            onDataChanged: _notifyWardrobeChanged,
            onDailyOutfitSaved: _applyTodayWeatherToOutfit,
          ),
        ),
      if (widget.controller.kitchenModuleEnabled)
        _AppDestination(
          id: 'kitchen',
          label: '厨房',
          icon: Icons.kitchen_outlined,
          selectedIcon: Icons.kitchen,
          page: KitchenPage(
            key: const PageStorageKey('kitchen'),
            repository: _kitchenRepository,
            aiService: _kitchenAiService,
          ),
        ),
      if (widget.controller.skincareModuleEnabled)
        _AppDestination(
          id: 'skincare',
          label: '护肤',
          icon: Icons.spa_outlined,
          selectedIcon: Icons.spa,
          page: SkincarePage(
            key: _skinKey,
            repository: _skinRepository,
            ai: _skinAi,
            reminders: _skinReminders,
          ),
        ),
      _AppDestination(
        id: 'profile',
        label: '我的',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        page: ProfilePage(
          key: const PageStorageKey('profile'),
          controller: widget.controller,
          aiAuthSession: widget.aiAuthSession,
        ),
      ),
    ];

    var selectedIndex = destinations.indexWhere(
      (destination) => destination.id == _selectedDestination,
    );
    if (selectedIndex < 0) {
      selectedIndex = 0;
      _selectedDestination = destinations.first.id;
    }

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: selectedIndex,
          children: [for (final destination in destinations) destination.page],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedDestination = destinations[index].id;
          });
        },
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _AppDestination {
  const _AppDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}
