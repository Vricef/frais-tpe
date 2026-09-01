import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_screen.dart';
import 'screens/startup_error_screen.dart';
import 'services/calculation_store.dart';
import 'services/entitlement.dart';
import 'services/purchase_service.dart';
import 'theme/app_theme.dart';
import 'widgets/ticket_card.dart';

/// Délai au-delà duquel l'initialisation de Firebase est considérée comme
/// perdue. Sans lui, un appel qui ne rend jamais la main laisse l'app sur
/// son écran de démarrage indéfiniment, sans erreur à afficher.
const _delaiInitialisation = Duration(seconds: 15);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Toute erreur de rendu est tracée plutôt que silencieuse.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Erreur Flutter : ${details.exception}');
  };

  // `runApp` est appelé immédiatement, avant toute initialisation
  // asynchrone. C'est le point important : tant que l'initialisation
  // précédait `runApp`, la moindre exception — ou le moindre appel qui ne
  // rendait pas la main — laissait l'écran de lancement natif affiché, noir
  // en thème sombre, sans le moindre message.
  runApp(FraisTpeApp());
}

/// Initialisation réelle de l'app. Isolée pour être remplaçable dans les
/// tests, qui n'ont ni Firebase ni données de locale à charger.
Future<void> initialiserApp() async {
  // Nécessaire avant tout DateFormat en fr_FR (dates de mise à jour des
  // grilles tarifaires) : sans ça, le formatage lève une exception.
  await initializeDateFormatting('fr_FR');
  await Firebase.initializeApp().timeout(
    _delaiInitialisation,
    onTimeout: () => throw TimeoutException(
      "Firebase n'a pas répondu en ${_delaiInitialisation.inSeconds} s.",
    ),
  );
}

class FraisTpeApp extends StatefulWidget {
  FraisTpeApp({
    super.key,
    Entitlement? entitlement,
    CalculationStore? store,
    Future<void> Function()? initialisation,
    this.achats,
  })  : entitlement = entitlement ?? Entitlement(),
        store = store ?? PrefsCalculationStore(),
        initialisation = initialisation ?? initialiserApp;

  /// État du déblocage par achat unique, partagé par tous les écrans.
  final Entitlement entitlement;

  /// Calculs sauvegardés, conservés localement sur l'appareil.
  final CalculationStore store;

  final Future<void> Function() initialisation;

  /// Service d'achat. `null` en laisse la création au démarrage, et
  /// seulement là où une boutique existe — les tests et l'aperçu web n'en
  /// ont pas, et l'instancier y échouerait.
  final PurchaseService? achats;

  @override
  State<FraisTpeApp> createState() => _FraisTpeAppState();
}

class _FraisTpeAppState extends State<FraisTpeApp> {
  PurchaseService? _achats;
  bool _achatsInternes = false;

  @override
  void initState() {
    super.initState();
    _achats = widget.achats;
    if (_achats == null && boutiqueSupportee) {
      _achats = PurchaseService(entitlement: widget.entitlement);
      _achatsInternes = true;
      // Démarré ici, et non à l'ouverture de l'écran de paiement : un
      // achat validé pendant que l'app était fermée est rejoué par la
      // boutique dès qu'on écoute, et serait perdu sinon.
      _achats!.demarrer();
    }
  }

  @override
  void dispose() {
    if (_achatsInternes) _achats!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Au-dessus de `MaterialApp` : l'écran de paiement est poussé par le
    // Navigator, dont les routes se construisent sous ce niveau.
    return FournisseurAchats(
      service: _achats,
      child: MaterialApp(
        title: 'Frais TPE',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        // Suit le réglage clair/sombre du téléphone.
        themeMode: ThemeMode.system,
        home: _Demarrage(
          initialisation: widget.initialisation,
          entitlement: widget.entitlement,
          store: widget.store,
        ),
      ),
    );
  }
}

/// Attend la fin de l'initialisation, et montre toujours quelque chose :
/// un écran d'attente, puis l'accueil ou l'explication de l'échec.
class _Demarrage extends StatefulWidget {
  const _Demarrage({
    required this.initialisation,
    required this.entitlement,
    required this.store,
  });

  final Future<void> Function() initialisation;
  final Entitlement entitlement;
  final CalculationStore store;

  @override
  State<_Demarrage> createState() => _DemarrageState();
}

class _DemarrageState extends State<_Demarrage> {
  late Future<void> _future = _lancer();

  Future<void> _lancer() async {
    try {
      await widget.initialisation();
      // Relu avant d'afficher quoi que ce soit : sans ça, l'app
      // s'ouvrirait verrouillée l'instant d'un achat déjà payé.
      await widget.entitlement.charger();
    } catch (e, pile) {
      debugPrint('Échec du démarrage : $e\n$pile');
      rethrow;
    }
  }

  void _reessayer() {
    // Corps en bloc et non en expression : `setState(() => _future = ...)`
    // renverrait le Future de l'assignation, ce que Flutter rejette.
    setState(() {
      _future = _lancer();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _EcranAttente();
        }
        if (snapshot.hasError) {
          return StartupErrorScreen(
            erreur: snapshot.error!,
            // Le détail technique n'a de sens que pendant le
            // développement ; l'utilisateur final n'en ferait rien.
            afficherDetail: kDebugMode,
            onReessayer: _reessayer,
          );
        }
        return HomeScreen(
          entitlement: widget.entitlement,
          store: widget.store,
        );
      },
    );
  }
}

class _EcranAttente extends StatelessWidget {
  const _EcranAttente();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8),
              TicketHeader(),
              Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      ),
    );
  }
}
