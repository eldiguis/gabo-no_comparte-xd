# MODO

Plataforma de moda fashion-tech con catálogo interactivo, probador virtual guiado por sensores acelerómetros e inteligencia artificial, experiencia Swipe to Match, geolocalización de tiendas y panel de administración web en tiempo real.

---

## Funcionalidades

- **Inicio Editorial**: Imagen editorial destacada, banners de acceso rápido a probador IA / Swipe to Match y selección semanal de tendencias con imágenes de alta definición.
- **Tienda y Catálogo Completo (50 prendas)**: Catálogo sincronizado en tiempo real con Cloud Firestore. Navegación fluida por categorías principales (*Hombre, Mujer, Niños, Niñas, Accesorios*) y subfiltros por tipo de producto (*Camisas, Polos, Casacas & Blazers, Poleras & Chompas, Jeans, Pantalones, Shorts & Bermudas, Vestidos, Billeteras, Bolsos & Mochilas, Lentes, Gorros, Calzado*).
- **Detalle de Prenda con Tallas y Colores Dinámicos**: Ficha técnica con composición de material, calce, cuidados, precio con descuento y reseñas. Mapeo inteligente de variantes: los accesorios sin tallas de confección (billeteras, lentes, mochilas, bolsos) presentan selección exclusiva de colores, mientras que las prendas de vestir disponen de tallas numéricas o alfanuméricas.
- **Swipe to Match (Outfit Matcher)**: Generador interactivo de cápsulas de moda combinando prendas superiores e inferiores con gestos táctiles (*swipe*). Incluye cálculo de precio combinado, puntaje de afinidad estética (93%–98%), bloqueo/anclaje de prendas favoritas y envío directo del conjunto a la bolsa o al probador IA.
- **Probador Virtual IA con Sensor Acelerómetro**:
  - Calibración de postura en ángulo recto (90° pitch/roll) utilizando el sensor acelerómetro del dispositivo móvil para asegurar capturas frontales y laterales ortogonales.
  - Soporte de cámara in-app y galería con silueta guía.
  - Configuración personalizada de API Keys para modelos generativos de Google AI Studio (Gemini) y NanoBanana.
- **Bolsa de Compras y Boleta Digital**: Gestión de cantidades, cálculo instantáneo de totales y checkout de demostración con emisión de boleta electrónica digital detallada (MODO STORE S.A.C.).
- **Tiendas Cercanas (Huancayo)**: Detección de ubicación del usuario en primer plano y cálculo de distancia geodésica a sucursales autorizadas en Huancayo:
  - *MODO — Real Plaza Huancayo* (Av. Ferrocarril 1035)
  - *MODO — Open Plaza Huancayo* (Av. Evitamiento Norte s/n, El Tambo)
  - *MODO — Centro Huancayo* (Jr. Puno 150)
  - Consulta de stock/inventario por tienda y redirección a mapas para navegación GPS.
- **Cuenta y Configuración**: Perfil de usuario persistente en Firestore, inicio de sesión seguro con Google OAuth y credenciales tradicionales, guías interactivas de onboarding y opciones de accesibilidad (texto grande, alto contraste y reducción de movimiento).
- **Panel de Administración Web (`web/index.html`)**:
  - Interfaz de backoffice para la gestión de catálogo de prendas en Firestore.
  - **Gestor de Categorías**: Creación, renombrado global en lote y eliminación de categorías.
  - Sembrador automático del catálogo oficial de 50 prendas (`seed_data.js`).
  - Modo Administrador Local / Demo para despliegues o pruebas sin dependencia de red.

---

## Stack Tecnológico

- **Framework**: Flutter SDK `^3.13.5` (Dart 3)
- **Backend & Auth**: Firebase Authentication, Cloud Firestore, Google Sign-In
- **Hardware & Sensores**: `sensors_plus` (acelerómetro), `camera`, `geolocator`
- **Almacenamiento Local**: `shared_preferences`
- **Utilidades**: `image_picker`, `url_launcher`, `http`
- **Frontend Web**: HTML5 semántico, CSS3 moderno con variables de diseño, JavaScript nativo (compat v10 Firebase) y GSAP

---

## Estructura Modular del Proyecto

```
lib/
  app/                          Configuración y temas de la aplicación (app.dart)
  core/                         Componentes base compartidos
    network/                    Stubs de red y Google Sign-In web
    theme/                      Paleta de colores oficial (Deep Ink, Electric Lime, Warm Paper)
    widgets/                    Botones circulares, transiciones de pantalla y skeletons UI
  features/                     Módulos desacoplados por dominio
    admin/                      Pantalla de administración de catálogo
    auth/                       Repositorio de autenticación y pantalla de login
    catalog/                    Modelos de prendas (Garment), repositorio Firestore y detalle
    fitting_room/               Probador virtual, sensor acelerómetro y servicios de IA
    onboarding/                 Diálogos de tutorial y guías visuales de usuario
    shell/                      Contenedor principal con barra de navegación (ShopShell)
    stores/                     Modelos de tiendas de Huancayo, geolocalización y repositorio
    swipe_to_match/             Modelos de cápsulas (CapsuleOutfit) y pantalla interactiva
  main.dart                     Punto de entrada de la aplicación
scripts/                        Scripts de inicialización y semillas JSON del catálogo
test/                           Suite de pruebas unitarias y de widgets
web/                            Panel web administrativo (index.html, app.js, seed_data.js)
```

---

## Requisitos Previos

- Flutter SDK `^3.13.5` o superior instalado y configurado en el `PATH`.
- Android SDK (API 34+ recomendada) o Xcode para iOS.
- Proyecto activo en Firebase con **Authentication** (Google y Correo/Contraseña) y **Cloud Firestore** habilitados.

---

## Configuración e Instalación

1. Clonar el repositorio y acceder al directorio del proyecto:

   ```bash
   git clone https://github.com/eldiguis/MODO.git
   cd MODO/flutter_application_1
   ```

2. Descargar las dependencias:

   ```bash
   flutter pub get
   ```

3. Colocar el archivo de credenciales de Firebase `android/app/google-services.json`. *(Nota: este archivo contiene claves de proyecto y está ignorado en el control de versiones; solicítalo al equipo de desarrollo).*

4. Verificar que las colecciones `productos`, `tiendas` y `admins` existan en Firestore. Puedes sembrar los datos iniciales ejecutando los scripts en `scripts/` o utilizando el botón **"Sembrar 50 Prendas"** del panel web administrativo.

---

## Ejecución

### Aplicación Móvil

```bash
flutter run
```

### Panel Web de Administración

Puedes servir la carpeta `web/` con cualquier servidor HTTP local o abrir `web/index.html` directamente en tu navegador:

```bash
cd web
python -m http.server 8080
```

---

## Compilación y Empaquetado

Para validar la calidad del código y generar el paquete de distribución para Android:

```bash
flutter analyze
flutter build apk --release
```

El instalador final se generará en:
`build/app/outputs/flutter-apk/app-release.apk`

---

## Pruebas Automatizadas

El proyecto incluye 33 pruebas unitarias y de widgets que validan el correcto funcionamiento de los módulos sin requerir llamadas reales a la red:

```bash
flutter test
```

---

## Versión y Registro de Cambios

- **Versión Actual:** `1.2.0` (Build `12`)
- **Etiqueta Git:** `v1.2.0`

---

## Licencia

Este proyecto está bajo la Licencia MIT. Consulta el archivo [LICENSE](LICENSE) para más detalles.
