import java.util.Properties

// Secrets de signature, hors du dépôt : android/key.properties, créé
// depuis android/key.properties.exemple. Sans lui, seul le build debug
// fonctionne — un AAB signé en debug est refusé par la Play Console.
val proprietesSignature = Properties().apply {
    val fichier = rootProject.file("key.properties")
    if (fichier.exists()) fichier.inputStream().use { load(it) }
}
val signatureConfiguree = proprietesSignature.getProperty("storeFile") != null

plugins {
    id("com.android.application")
    // Lit android/app/google-services.json et en génère les ressources que
    // firebase_core attend au démarrage.
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.fraistpe.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identifiant déposé sur Play Console et App Store Connect. Il ne
        // change plus : Google le lie définitivement à la fiche du store.
        applicationId = "com.fraistpe.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signatureConfiguree) {
            create("release") {
                storeFile = file(proprietesSignature.getProperty("storeFile"))
                storePassword = proprietesSignature.getProperty("storePassword")
                keyAlias = proprietesSignature.getProperty("keyAlias")
                keyPassword = proprietesSignature.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Sans key.properties, on retombe sur la clé de debug : le
            // build passe, mais l'artefact est refusé à l'import sur la
            // Play Console. L'avertissement ci-dessous évite de le
            // découvrir au moment de l'import.
            signingConfig = if (signatureConfiguree) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "android/key.properties absent : build signé avec la clé " +
                        "de debug, non publiable."
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
