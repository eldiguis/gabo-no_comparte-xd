import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/nearby_store_repository.dart';
import 'data/product_catalog_repository.dart';
import 'models/garment.dart';
import 'models/nearby_store.dart';
import 'sensor_camera_guide.dart';
import 'ui_skeletons.dart';
import 'google_sign_in_web_stub.dart' as google_web
    if (dart.library.html) 'package:google_sign_in_web/web_only.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ModaApp());
}

const ink = Color(0xFF171717);
const paper = Color(0xFFFAF9F6);
const line = Color(0xFFE6E4DE);
const muted = Color(0xFF898780);
const lime = Color(0xFFD7FF55);
const googleClientId = String.fromEnvironment('GOOGLE_SIGN_IN_CLIENT_ID');

class ModaApp extends StatefulWidget {
  const ModaApp({super.key});

  @override
  State<ModaApp> createState() => _ModaAppState();
}

class _ModaAppState extends State<ModaApp> {
  bool signedIn = false;
  String customerName = '';
  bool firebaseConfigured = false;
  bool checkingSession = true;

  @override
  void initState() {
    super.initState();
    _initFirebase();
    _loadSavedSession();
  }

  Future<void> _loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLogged = prefs.getBool('signedIn') ?? false;
      final savedName = prefs.getString('customerName') ?? '';
      if (isLogged && mounted) {
        setState(() {
          signedIn = true;
          customerName = savedName.isNotEmpty ? savedName : 'Usuario MODO';
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() => checkingSession = false);
    }
  }

  Future<void> _handleSignIn(String name) async {
    setState(() {
      customerName = name;
      signedIn = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('signedIn', true);
      await prefs.setString('customerName', name);
    } catch (_) {}
  }

  Future<void> _handleSignOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('signedIn');
      await prefs.remove('customerName');
    } catch (_) {}
    if (mounted) {
      setState(() {
        signedIn = false;
        customerName = '';
      });
    }
  }

  Future<void> _initFirebase() async {
    if (!kIsWeb) {
      try {
        await Firebase.initializeApp();
        if (mounted) setState(() => firebaseConfigured = true);
      } catch (error, stackTrace) {
        debugPrint('Firebase initialization failed: $error\n$stackTrace');
      }
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Grupo5',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(seedColor: ink, surface: paper),
      fontFamily: 'Roboto',
    ),
    home: checkingSession
        ? const Scaffold(
            backgroundColor: paper,
            body: Center(
              child: CircularProgressIndicator(color: ink),
            ),
          )
        : signedIn
            ? ShopShell(
                customerName: customerName,
                firebaseConfigured: firebaseConfigured,
                onSignOut: _handleSignOut,
              )
            : LoginScreen(
                onAuthenticated: _handleSignIn,
              ),
  );
}

class LoginScreen extends StatefulWidget {
  final ValueChanged<String> onAuthenticated;
  const LoginScreen({super.key, required this.onAuthenticated});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  StreamSubscription<GoogleSignInAuthenticationEvent>? googleSubscription;
  bool registering = false;
  bool googleReady = false;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _initializeGoogle();
  }

  Future<void> _initializeGoogle() async {
    if (googleClientId.isEmpty) return;
    try {
      await GoogleSignIn.instance.initialize(
        clientId: googleClientId,
      );
      googleSubscription = GoogleSignIn.instance.authenticationEvents.listen(
        (event) {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            widget.onAuthenticated(
              event.user.displayName ?? event.user.email.split('@').first,
            );
          }
        },
        onError: (Object error) => _message(
          'No se pudo iniciar con Google. Revisa la configuración OAuth.',
        ),
      );
      if (mounted) setState(() => googleReady = true);
    } catch (_) {
      if (mounted) setState(() => googleReady = false);
    }
  }

  @override
  void dispose() {
    googleSubscription?.cancel();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _continueWithGoogle() async {
    if (googleClientId.isEmpty) {
      _message('Falta configurar el OAuth Client ID de Google para esta app.');
      return;
    }
    if (kIsWeb) return; // Web uses the official Google-rendered button below.
    try {
      await GoogleSignIn.instance.authenticate();
    } catch (_) {
      _message(
        'No se pudo iniciar con Google. Comprueba la configuración de la app.',
      );
    }
  }

  void _submit() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    widget.onAuthenticated(
      registering && nameController.text.trim().isNotEmpty
          ? nameController.text.trim()
          : emailController.text.trim().split('@').first,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 760;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Padding(
                padding: EdgeInsets.all(wide ? 28 : 16),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(wide ? 24 : 18),
                    border: Border.all(color: line),
                  ),
                  child: wide
                      ? Row(
                          children: [
                            Expanded(flex: 11, child: _welcomeVisual()),
                            Expanded(flex: 9, child: _formPanel()),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(
                              flex: 5,
                              child: _welcomeVisual(compact: true),
                            ),
                            Expanded(
                              flex: 7,
                              child: SingleChildScrollView(
                                child: _formPanel(compact: true),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _welcomeVisual({bool compact = false}) => Stack(
    fit: StackFit.expand,
    children: [
      Image.network(
        photo('photo-1539109136881-3be0616acf4b', width: 1100),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (_, _, _) => Container(color: const Color(0xFFECEAE4)),
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xAA000000)],
            stops: [.35, 1],
          ),
        ),
      ),
      Positioned(
        left: 24,
        top: 20,
        child: Row(
          children: [
            const Text(
              'MODO',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                fontSize: 23,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
      Positioned(
        left: 26,
        right: 24,
        bottom: compact ? 18 : 36,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              compact
                  ? 'Tu estilo,\na tu manera.'
                  : 'Explore the\nbest collections.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                height: 1.02,
                letterSpacing: -1,
                fontSize: compact ? 25 : 38,
              ),
            ),
            const SizedBox(height: 8),
            if (!compact)
              const Text(
                'Descubre prendas pensadas para ti.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _formPanel({bool compact = false}) => Padding(
    padding: EdgeInsets.fromLTRB(
      compact ? 22 : 42,
      compact ? 20 : 42,
      compact ? 22 : 42,
      compact ? 20 : 34,
    ),
    child: Form(
      key: formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            registering ? 'Crea tu cuenta' : 'Bienvenido de nuevo',
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            registering
                ? 'Únete a MODO y encuentra tu próximo look.'
                : 'Inicia sesión para continuar descubriendo.',
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          SizedBox(height: compact ? 18 : 26),
          if (registering) ...[
            _input(
              nameController,
              'Nombre completo',
              Icons.person_outline,
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Escribe tu nombre'
                  : null,
            ),
            const SizedBox(height: 12),
          ],
          _input(
            emailController,
            'Correo electrónico',
            Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || !v.contains('@'))
                ? 'Escribe un correo válido'
                : null,
          ),
          const SizedBox(height: 12),
          _input(
            passwordController,
            'Contraseña',
            Icons.lock_outline,
            obscure: obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: muted,
              ),
              onPressed: () =>
                  setState(() => obscurePassword = !obscurePassword),
            ),
            validator: (v) => (v == null || v.length < 6)
                ? 'Usa al menos 6 caracteres'
                : null,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: ink,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: Text(
                registering ? 'CREAR CUENTA' : 'INICIAR SESIÓN',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider(color: line)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'o continúa con',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ),
              const Expanded(child: Divider(color: line)),
            ],
          ),
          const SizedBox(height: 14),
          if (kIsWeb && googleClientId.isNotEmpty && googleReady)
            Center(
              child: google_web.renderButton(
                configuration: google_web.GSIButtonConfiguration(
                  theme: google_web.GSIButtonTheme.outline,
                  shape: google_web.GSIButtonShape.pill,
                  size: google_web.GSIButtonSize.large,
                  text: google_web.GSIButtonText.continueWith,
                  locale: 'es',
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _continueWithGoogle,
                icon: const Text(
                  'G',
                  style: TextStyle(
                    color: Color(0xFF4285F4),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                label: const Text('Continuar con Google'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ink,
                  side: const BorderSide(color: line),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                Text(
                  registering
                      ? '¿Ya tienes cuenta? '
                      : '¿No tienes una cuenta? ',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                GestureDetector(
                  onTap: () => setState(() => registering = !registering),
                  child: Text(
                    registering ? 'Inicia sesión' : 'Regístrate',
                    style: const TextStyle(
                      color: ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _input(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboardType,
    validator: validator,
    decoration: InputDecoration(
      prefixIcon: Icon(icon, size: 19),
      suffixIcon: suffixIcon,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFFAFAF8),
      contentPadding: const EdgeInsets.symmetric(vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: ink, width: 1.2),
      ),
      errorStyle: const TextStyle(fontSize: 10),
    ),
  );
}

String photo(String source, {int width = 800}) {
  if (source.startsWith('https://') || source.startsWith('http://')) {
    return source;
  }
  return 'https://images.unsplash.com/$source?auto=format&fit=crop&w=$width&q=85';
}

class ShopShell extends StatefulWidget {
  final String customerName;
  final bool firebaseConfigured;
  final VoidCallback? onSignOut;
  const ShopShell({
    super.key,
    required this.customerName,
    this.firebaseConfigured = false,
    this.onSignOut,
  });
  @override
  State<ShopShell> createState() => _ShopShellState();
}

class _ShopShellState extends State<ShopShell> {
  int tab = 0;
  DateTime? lastBackPressTime;
  String category = 'Todo';
  int cartCount = 0;
  bool largeText = false;
  bool highContrast = false;
  bool reduceMotion = false;
  final Set<String> favorites = {};
  final List<Garment> catalogProducts = [];
  StreamSubscription<List<Garment>>? catalogSubscription;
  bool catalogLoading = true;
  String? catalogError;
  Uint8List? frontPhoto, sidePhoto;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (!widget.firebaseConfigured) {
      catalogLoading = false;
      catalogError = kIsWeb
          ? 'La configuración Firebase para web todavía no está agregada.'
          : 'No se pudo iniciar Firebase. Revisa la configuración de Android.';
      return;
    }
    catalogSubscription = ProductCatalogRepository().watchProducts().listen(
      (items) {
        if (!mounted) return;
        setState(() {
          catalogProducts
            ..clear()
            ..addAll(items);
          catalogLoading = false;
          catalogError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          catalogLoading = false;
          catalogError = 'No se pudo leer la colección productos de Firebase.';
        });
      },
    );
  }

  @override
  void dispose() {
    catalogSubscription?.cancel();
    super.dispose();
  }

  List<String> get catalogCategories {
    final categories =
        catalogProducts.map((product) => product.category).toSet().toList()
          ..sort();
    return ['Todo', ...categories];
  }

  List<Garment> get visibleProducts => category == 'Todo'
      ? catalogProducts
      : catalogProducts
            .where((product) => product.category == category)
            .toList();

  Widget catalogNotice({required String title, required String subtitle}) =>
      Container(
        margin: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        padding: const EdgeInsets.all(18),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            if (catalogLoading)
              const CircularProgressIndicator(color: ink)
            else
              const Icon(Icons.checkroom_outlined, size: 32, color: muted),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      );

  Future<void> _refreshCatalog() async {
    HapticFeedback.lightImpact();
    setState(() => catalogLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      setState(() => catalogLoading = false);
    }
  }

  List<Widget> homeProductSection() {
    if (catalogLoading) {
      return const [
        ProductGridSkeleton(count: 4, padding: EdgeInsets.fromLTRB(20, 0, 20, 8)),
      ];
    }
    if (catalogError != null || catalogProducts.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EditorialEmptyState(
            title: catalogError != null ? 'Error de conexión' : 'Colección en preparación',
            message: catalogError ?? 'Estamos preparando las prendas destacadas de esta semana.',
            actionLabel: 'REINTENTAR',
            onAction: _refreshCatalog,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (_, i) => productCardItem(catalogProducts[i]),
            childCount: catalogProducts.length < 6 ? catalogProducts.length : 6,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 18,
            childAspectRatio: .59,
          ),
        ),
      ),
    ];
  }

  List<Widget> shopProductSection() {
    if (catalogLoading) {
      return const [
        ProductGridSkeleton(count: 6, padding: EdgeInsets.fromLTRB(20, 8, 20, 28)),
      ];
    }
    if (catalogError != null || visibleProducts.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EditorialEmptyState(
            title: catalogError != null ? 'Error de catálogo' : 'No hay prendas disponibles',
            message: catalogError ?? 'Prueba cambiando de categoría o toca abajo para ver todas.',
            actionLabel: 'VER TODAS LAS PRENDAS',
            onAction: () {
              HapticFeedback.selectionClick();
              setState(() => category = 'Todo');
            },
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (_, i) => productCardItem(visibleProducts[i]),
            childCount: visibleProducts.length,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 18,
            childAspectRatio: .59,
          ),
        ),
      ),
    ];
  }

  Future<void> pickCapture(bool front) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: lime,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.sensors, size: 22, color: ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          front ? 'Foto Frontal con IA' : 'Foto Lateral con IA',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Usa el acelerómetro para calibrar el ángulo perpendicular a 90°',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.camera_alt, size: 20),
                label: const Text(
                  'Cámara con Sensor IA (Acelerómetro)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final Uint8List? bytes = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SensorCameraGuideScreen(
                        front: front,
                        picker: picker,
                      ),
                    ),
                  );
                  if (bytes != null) {
                    setState(() {
                      if (front) {
                        frontPhoto = bytes;
                      } else {
                        sidePhoto = bytes;
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ink,
                  side: const BorderSide(color: line),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text(
                  'Elegir de la Galería',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final image = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 88,
                  );
                  if (image == null) return;
                  final bytes = await image.readAsBytes();
                  setState(() {
                    if (front) {
                      frontPhoto = bytes;
                    } else {
                      sidePhoto = bytes;
                    }
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [home(), shop(), fittingRoom(), cart(), accountSettings()];
    final baseTheme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (tab != 0) {
          setState(() => tab = 0);
          return;
        }
        final now = DateTime.now();
        if (lastBackPressTime == null ||
            now.difference(lastBackPressTime!) > const Duration(seconds: 2)) {
          lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Presiona de nuevo para salir de MODO'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        SystemNavigator.pop();
      },
      child: Theme(
        data: baseTheme.copyWith(
          colorScheme: highContrast
              ? ColorScheme.fromSeed(
                  seedColor: ink,
                  surface: paper,
                  contrastLevel: 1,
                )
              : baseTheme.colorScheme,
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(largeText ? 1.15 : 1),
            disableAnimations: reduceMotion,
          ),
          child: Scaffold(
            body: SafeArea(
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide =
                      Tween<Offset>(
                        begin: const Offset(.035, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      );
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: KeyedSubtree(key: ValueKey(tab), child: screens[tab]),
              ),
            ),
            bottomNavigationBar: NavigationBar(
              height: 68,
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFECEAE4),
              selectedIndex: tab,
              onDestinationSelected: (value) {
                HapticFeedback.selectionClick();
                setState(() => tab = value);
              },
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: 'Inicio',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.shopping_bag_outlined),
                  selectedIcon: Icon(Icons.shopping_bag_rounded),
                  label: 'Tienda',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  selectedIcon: Icon(Icons.auto_awesome_rounded),
                  label: 'Probador IA',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: cartCount > 0,
                    label: Text('$cartCount'),
                    child: const Icon(Icons.shopping_basket_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: cartCount > 0,
                    label: Text('$cartCount'),
                    child: const Icon(Icons.shopping_basket_rounded),
                  ),
                  label: 'Bolsa',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Cuenta',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget accountSettings() => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MI PERFIL',
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Mi cuenta',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: lime,
                      foregroundColor: ink,
                      child: Icon(Icons.person_outline_rounded),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nombre de perfil',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.customerName.isEmpty
                                ? 'Usuario MODO'
                                : widget.customerName,
                            style: const TextStyle(
                              color: ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'Ajustes de cuenta',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(Icons.badge_outlined, color: ink),
                title: Text('Datos del perfil'),
                subtitle: Text('Consulta el nombre asociado a tu cuenta'),
              ),
              const Divider(height: 24),
              const Text(
                'Accesibilidad',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Texto grande'),
                subtitle: const Text('Aumenta el tamaño del texto en la app'),
                value: largeText,
                onChanged: (value) => setState(() => largeText = value),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Alto contraste'),
                subtitle: const Text('Refuerza el contraste de los colores'),
                value: highContrast,
                onChanged: (value) => setState(() => highContrast = value),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reducir movimiento'),
                subtitle: const Text('Limita las animaciones de la interfaz'),
                value: reduceMotion,
                onChanged: (value) => setState(() => reduceMotion = value),
              ),
              const SizedBox(height: 24),
              if (widget.onSignOut != null) ...[
                const Divider(),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: widget.onSignOut,
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    label: const Text(
                      'CERRAR SESIÓN',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    ],
  );

  Widget home() => RefreshIndicator(
    color: ink,
    backgroundColor: lime,
    onRefresh: _refreshCatalog,
    child: CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: header()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 22),
            child: hero(),
          ),
        ),
        SliverToBoxAdapter(
          child: sectionTitle(
            'Selección de la semana',
            'Ver todo',
            () {
              HapticFeedback.selectionClick();
              setState(() => tab = 1);
            },
          ),
        ),
        ...homeProductSection(),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: tryBanner(),
          ),
        ),
      ],
    ),
  );

  Widget header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
    child: Row(
      children: [
        const Text(
          'MODO',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(width: 7),
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(color: lime, shape: BoxShape.circle),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => setState(() => tab = 1),
          icon: const Icon(Icons.search_rounded),
        ),
        IconButton(
          onPressed: () => setState(() => tab = 3),
          icon: const Icon(Icons.shopping_basket_outlined),
        ),
      ],
    ),
  );

  Widget hero() => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      height: 405,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            photo('photo-1539109136881-3be0616acf4b', width: 1000),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, _, _) =>
                Container(color: const Color(0xFFD7D1C8)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC101010)],
                stops: [.4, 1],
              ),
            ),
          ),
          Positioned(top: 18, left: 18, child: _tag('COLECCIÓN  /  01')),
          Positioned(
            left: 22,
            right: 22,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VISTE A TU\nMANERA.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: .98,
                    fontSize: 38,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Piezas para todos tus días.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => setState(() => tab = 1),
                  icon: const Icon(Icons.arrow_forward, size: 17),
                  label: const Text('DESCUBRIR'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget sectionTitle(String title, String action, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),
            ),
            TextButton(
              onPressed: onTap,
              child: Text(action, style: const TextStyle(color: ink)),
            ),
          ],
        ),
      );

  Widget productCardItem(Garment p) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showProduct(p);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'garment_photo_${p.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.network(
                      photo(p.image, width: 600),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFFE3E0D8),
                        child: const Icon(
                          Icons.checkroom,
                          size: 58,
                          color: muted,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(top: 10, left: 10, child: _tag(p.tag)),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton.filledTonal(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(
                        () => favorites.contains(p.id)
                            ? favorites.remove(p.id)
                            : favorites.add(p.id),
                      );
                    },
                    icon: Icon(
                      favorites.contains(p.id)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 18,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: .9),
                      foregroundColor: ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            p.category,
            style: const TextStyle(
              fontSize: 9,
              color: muted,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                p.price,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget tryBanner() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: ink,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PRUÉBATE\nANTES DE ELEGIR.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 21,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tu look, visualizado con IA.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => setState(() => tab = 2),
                style: FilledButton.styleFrom(
                  backgroundColor: lime,
                  foregroundColor: ink,
                ),
                child: const Text('PROBAR AHORA'),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.auto_awesome, size: 54, color: lime),
      ],
    ),
  );

  Widget shop() => RefreshIndicator(
    color: ink,
    backgroundColor: lime,
    onRefresh: _refreshCatalog,
    child: CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: header()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Encuentra tu\npróximo favorito.',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                    height: 1.05,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: catalogCategories
                        .map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(c),
                              selected: category == c,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                setState(() => category = c);
                              },
                              selectedColor: ink,
                              labelStyle: TextStyle(
                                color: category == c ? Colors.white : ink,
                                fontWeight: FontWeight.w600,
                              ),
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: line),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        ...shopProductSection(),
      ],
    ),
  );

  Widget fittingRoom() => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(child: header()),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _tag('MODO LAB  /  BETA'),
                  const Spacer(),
                  const Icon(Icons.help_outline, size: 20),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Tu probador\ninteligente.',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1.03,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Sube dos fotos y descubre cómo te queda.',
                style: TextStyle(fontSize: 14, color: muted),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F7E6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD3E7B2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: lime,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.sensors, size: 18, color: ink),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Sensor Acelerómetro activo: calibra el ángulo recto (90°) al tomar la foto.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E5316),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: captureCard(true)),
                  const SizedBox(width: 12),
                  Expanded(child: captureCard(false)),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: line),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.tips_and_updates_outlined, size: 19),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Para un mejor resultado, usa ropa ajustada, buena luz y un fondo despejado.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'ELIGE UNA PRENDA',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 122,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: catalogProducts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => setState(() => selectedLook = i),
                    child: Container(
                      width: 88,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedLook == i ? ink : line,
                          width: selectedLook == i ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        photo(catalogProducts[i].image, width: 220),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(Icons.checkroom),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: frontPhoto != null && sidePhoto != null
                      ? () => showPreview()
                      : null,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text(
                    'GENERAR MI LOOK',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: .4,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: ink,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCFCEC8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              const Center(
                child: Text(
                  'Tus fotos solo se usan para generar la vista previa.',
                  style: TextStyle(color: muted, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  int selectedLook = 0;
  Widget captureCard(bool front) {
    final bytes = front ? frontPhoto : sidePhoto;
    return GestureDetector(
      onTap: () => pickCapture(front),
      child: Container(
        height: 212,
        decoration: BoxDecoration(
          color: const Color(0xFFECEBE5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: bytes == null ? line : ink,
            width: bytes == null ? 1 : 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(bytes, fit: BoxFit.cover)
            else
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    front ? Icons.person_outline : Icons.accessibility_new,
                    size: 42,
                    color: const Color(0xFFB5B3AB),
                  ),
                  const SizedBox(height: 12),
                  Icon(Icons.add_circle, size: 24, color: ink),
                  const SizedBox(height: 8),
                  Text(
                    'Añadir foto\n${front ? 'frontal' : 'lateral'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            Positioned(
              left: 9,
              top: 9,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  front ? '01  FRONTAL' : '02  LATERAL',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                  ),
                ),
              ),
            ),
            if (bytes != null)
              const Positioned(
                right: 9,
                top: 9,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: lime,
                  child: Icon(Icons.check, size: 14, color: ink),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> cartProductItems() {
    if (catalogProducts.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(18),
          child: Text('No se pudo recuperar el detalle de las prendas.'),
        ),
      ];
    }
    return List.generate(cartCount, (index) {
      final product = catalogProducts[index % catalogProducts.length];
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Image.network(
            photo(product.image, width: 160),
            width: 70,
            height: 86,
            fit: BoxFit.cover,
          ),
        ),
        title: Text(product.name),
        subtitle: Text(product.price),
        trailing: IconButton(
          onPressed: () => setState(() => cartCount--),
          icon: const Icon(Icons.close),
        ),
      );
    });
  }

  Widget cart() => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(child: header()),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Tu bolsa.',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ),
              Text(
                '$cartCount artículos',
                style: const TextStyle(color: muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      if (cartCount == 0)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shopping_bag_outlined,
                    size: 54,
                    color: muted,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tu bolsa está esperando.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Descubre prendas que van contigo.',
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => setState(() => tab = 1),
                    style: FilledButton.styleFrom(backgroundColor: ink),
                    child: const Text('IR A LA TIENDA'),
                  ),
                ],
              ),
            ),
          ),
        )
      else
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                ...cartProductItems(),
                const Divider(),
                ListTile(
                  title: const Text('Subtotal'),
                  trailing: Text(
                    'S/ ${cartCount * 149}.00',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => tab = 1),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          foregroundColor: ink,
                          side: const BorderSide(color: line),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('SEGUIR COMPRANDO'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: showCheckoutDialog,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          backgroundColor: ink,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('FINALIZAR COMPRA'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ],
  );

  void showCheckoutDialog() => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
          SizedBox(width: 10),
          Text(
            'Boleta de Venta',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MODO STORE S.A.C. - RUC 20608976541\nComprobante Electrónico (Demo)',
            style: TextStyle(color: muted, fontSize: 11),
          ),
          const Divider(height: 20),
          Text(
            'Cliente: ${widget.customerName.isEmpty ? 'Usuario MODO' : widget.customerName}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text('Prendas en orden: $cartCount artículos'),
          const SizedBox(height: 4),
          Text(
            'Total Pagado: S/ ${cartCount * 149}.00',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: ink,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '¡Pago procesado con éxito! Se ha registrado tu orden en el historial.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            setState(() => cartCount = 0);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('¡Compra finalizada exitosamente!'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          style: FilledButton.styleFrom(backgroundColor: ink),
          child: const Text('ACEPTAR'),
        ),
      ],
    ),
  );

  void showProduct(Garment product) {
    Navigator.of(context).push(
      _FadeSlideRoute<void>(
        builder: (_) => ProductDetailPage(
          product: product,
          isFavorite: favorites.contains(product.id),
          onToggleFavorite: () => setState(() {
            favorites.contains(product.id)
                ? favorites.remove(product.id)
                : favorites.add(product.id);
          }),
          onAddToCart: () => setState(() => cartCount++),
          onOpenCart: () => setState(() => tab = 3),
          onTryWithAi: () => setState(() => tab = 2),
        ),
      ),
    );
  }

  void showPreview() => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: paper,
      title: const Text('¡Listo para probar!'),
      content: const Text(
        'Tus dos capturas están preparadas. La generación IA se conectará cuando se integre el servicio de probador virtual.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ENTENDIDO'),
        ),
      ],
    ),
  );

  Widget _tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: lime,
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        letterSpacing: .8,
        fontWeight: FontWeight.w900,
        color: ink,
      ),
    ),
  );
}

class ProductDetailPage extends StatefulWidget {
  final Garment product;
  final VoidCallback onAddToCart;
  final VoidCallback onTryWithAi;
  final VoidCallback? onOpenCart;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  const ProductDetailPage({
    super.key,
    required this.product,
    required this.onAddToCart,
    required this.onTryWithAi,
    this.onOpenCart,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  String size = 'M';
  int quantity = 1;
  int imageIndex = 0;
  late bool localFavorite;

  @override
  void initState() {
    super.initState();
    localFavorite = widget.isFavorite;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final images = [
      p.image,
      // Product images come from the selected Firestore document.
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Detalles',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onOpenCart?.call();
                      },
                      icon: const Icon(Icons.shopping_basket_outlined),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 360,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'garment_photo_${p.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            photo(images[imageIndex], width: 950),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: const Color(0xFFECEAE4),
                              child: const Icon(
                                Icons.checkroom,
                                size: 72,
                                color: muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        top: 12,
                        child: CircleButton(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 12,
                        child: CircleButton(
                          icon: localFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          onTap: () {
                            setState(() => localFavorite = !localFavorite);
                            widget.onToggleFavorite?.call();
                          },
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 12,
                        child: Column(
                          children: [
                            for (var i = 0; i < images.length; i++)
                              GestureDetector(
                                onTap: () => setState(() => imageIndex = i),
                                child: Container(
                                  margin: const EdgeInsets.only(top: 7),
                                  width: 48,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: imageIndex == i
                                          ? ink
                                          : Colors.white,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.network(
                                    photo(images[i], width: 140),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const ColoredBox(color: line),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.category,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 10,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.name.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Row(
                      children: [
                        Icon(Icons.star, color: ink, size: 15),
                        SizedBox(width: 4),
                        Text(
                          '4.8  Ratings',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          '1.5k reseñas  •  3.4k vendidos',
                          style: TextStyle(color: muted, fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          p.price,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 21,
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Text(
                          'S/ 320.00',
                          style: TextStyle(
                            color: muted,
                            decoration: TextDecoration.lineThrough,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          color: const Color(0xFFF1F0ED),
                          child: const Text(
                            '15% OFF',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Una pieza versátil, cómoda y fácil de combinar. Diseñada para acompañarte en cualquier ocasión.',
                      style: TextStyle(color: muted, fontSize: 12, height: 1.5),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'TALLA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['S', 'M', 'L', 'XL', 'XXL']
                          .map(
                            (value) => ChoiceChip(
                              label: Text(value),
                              selected: size == value,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                setState(() => size = value);
                              },
                              selectedColor: ink,
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: size == value ? ink : line,
                              ),
                              labelStyle: TextStyle(
                                color: size == value ? Colors.white : ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        widget.onTryWithAi();
                      },
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Probarme esta prenda con IA'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ink,
                        side: const BorderSide(color: line),
                        minimumSize: const Size(double.infinity, 44),
                        shape: const StadiumBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).push(
                          _FadeSlideRoute<void>(
                            builder: (_) => NearbyStoresPage(product: p),
                          ),
                        );
                      },
                      icon: const Icon(Icons.location_on_outlined, size: 17),
                      label: const Text('Ver tiendas cercanas con stock'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ink,
                        side: const BorderSide(color: line),
                        minimumSize: const Size(double.infinity, 44),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: line)),
          ),
          child: Row(
            children: [
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: quantity > 1
                          ? () {
                              HapticFeedback.selectionClick();
                              setState(() => quantity--);
                            }
                          : null,
                      icon: const Icon(
                        Icons.remove,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    Text(
                      '$quantity',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => quantity++);
                      },
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      for (var i = 0; i < quantity; i++) {
                        widget.onAddToCart();
                      }
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${widget.product.name} añadido a la bolsa'),
                          duration: const Duration(seconds: 2),
                          action: SnackBarAction(
                            label: 'VER BOLSA',
                            textColor: lime,
                            onPressed: () => widget.onOpenCart?.call(),
                          ),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: ink,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'AÑADIR A LA BOLSA',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: .4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NearbyStoresPage extends StatefulWidget {
  const NearbyStoresPage({super.key, required this.product});

  final Garment product;

  @override
  State<NearbyStoresPage> createState() => _NearbyStoresPageState();
}

class _NearbyStoresPageState extends State<NearbyStoresPage> {
  bool loading = true;
  String? error;
  bool permissionPermanentlyDenied = false;
  List<NearbyStore> stores = const [];

  Future<void> loadStores() async {
    setState(() {
      loading = true;
      error = null;
      permissionPermanentlyDenied = false;
    });
    try {
      final result = await NearbyStoreRepository(
        source: FirestoreNearbyStoreDataSource(),
        locationProvider: const GeolocatorUserLocationProvider(),
      ).findStoresForProduct(widget.product.id);
      if (!mounted) return;
      setState(() {
        stores = result;
        loading = false;
      });
    } on LocationUnavailableException catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.message;
        permissionPermanentlyDenied = exception.permissionPermanentlyDenied;
        loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        error = 'No se pudo consultar tiendas e inventario en Firebase.';
        loading = false;
      });
      debugPrint('Nearby store lookup failed: $exception');
    }
  }

  @override
  void initState() {
    super.initState();
    loadStores();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: paper,
    appBar: AppBar(
      title: const Text('Tiendas cercanas'),
      backgroundColor: paper,
    ),
    body: SafeArea(
      child: loading
          ? const StoreListSkeleton()
          : error != null
          ? _message(
              icon: Icons.location_disabled_outlined,
              title: 'No pudimos obtener tu ubicación',
              subtitle:
                  '$error\nActiva el servicio de ubicación y permite el acceso mientras usas la app.',
              action: permissionPermanentlyDenied
                  ? 'ABRIR AJUSTES'
                  : 'INTENTAR DE NUEVO',
              onPressed: permissionPermanentlyDenied
                  ? Geolocator.openAppSettings
                  : loadStores,
            )
          : stores.isEmpty
          ? _message(
              icon: Icons.store_mall_directory_outlined,
              title: 'No hay tiendas con stock cercano',
              subtitle:
                  'Aún no encontramos inventario disponible para ${widget.product.name}. La disponibilidad se consulta en Firebase.',
              action: 'ACTUALIZAR',
              onPressed: loadStores,
            )
          : RefreshIndicator(
              color: ink,
              backgroundColor: lime,
              onRefresh: loadStores,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.all(18),
                children: [
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ordenadas por distancia desde tu ubicación.',
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 14),
                  for (final store in stores)
                    Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: line),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: lime,
                        foregroundColor: ink,
                        child: Icon(Icons.storefront_outlined),
                      ),
                      title: Text(
                        store.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${store.address}\n${_distanceLabel(store.distanceMeters)} · Stock: ${store.quantity}'
                        '${store.openingHours == null ? '' : '\n${store.openingHours}'}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
              ],
            ),
          ),
    ),
  );

  Widget _message({
    required IconData icon,
    required String title,
    required String subtitle,
    required String action,
    required VoidCallback onPressed,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: muted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onPressed, child: Text(action)),
        ],
      ),
    ),
  );

  String _distanceLabel(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} km'
      : '${meters.round()} m';
}

class _FadeSlideRoute<T> extends PageRouteBuilder<T> {
  _FadeSlideRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slide = Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: SlideTransition(position: slide, child: child),
            );
          },
        );
}
class CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const CircleButton({super.key, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .93),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Icon(icon, size: 18, color: ink),
      ),
    ),
  );
}
