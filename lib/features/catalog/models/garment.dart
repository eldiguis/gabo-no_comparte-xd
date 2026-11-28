class Garment {
  const Garment({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.image,
    required this.tag,
    this.store = '',
    this.sizes = const [],
    this.color = '',
    this.colors = const [],
    this.type = '',
    this.material = '',
    this.fit = '',
    this.description = '',
  });

  final String id;
  final String name;
  final String category;
  final String price;
  final String image;
  final String tag;
  final String store;
  final List<String> sizes;
  final String color;
  final List<String> colors;
  final String type;
  final String material;
  final String fit;
  final String description;

  String get storeId => store;
  String get tienda => store;

  /// Retorna si el producto cuenta con tallas de vestir o calzado.
  /// Accesorios como billeteras, lentes, mochilas, bolsos, etc., no tienen tallas de ropa.
  bool get hasSizes {
    final n = name.toLowerCase();
    final isNoSizeAccessory = n.contains('billetera') ||
        n.contains('lentes') ||
        n.contains('bolso') ||
        n.contains('mochila') ||
        n.contains('cartera') ||
        n.contains('reloj') ||
        n.contains('pañuelo') ||
        n.contains('bufanda');
    if (isNoSizeAccessory) return false;

    if (isAccessory) {
      if (sizes.any((s) {
        final lower = s.toLowerCase();
        return lower == 'única' || lower == 'unica' || lower == 'talla única';
      })) {
        return false;
      }
      return sizes.isNotEmpty && !sizes.every((s) => s.toLowerCase().contains('unic'));
    }
    return true;
  }

  /// Tallas disponibles validadas según la categoría y tipo de prenda
  List<String> get availableSizes {
    if (!hasSizes) return const [];

    if (sizes.isNotEmpty) {
      final isCalzado = _isShoe;
      if (isCalzado && sizes.any((s) => int.tryParse(s) != null)) {
        return sizes;
      }
      if (!isCalzado && !isAccessory) {
        return sizes;
      }
      if (isAccessory) {
        return sizes;
      }
    }

    if (_isShoe) {
      return const ['36', '37', '38', '39', '40', '41', '42', '43'];
    }
    return const ['S', 'M', 'L', 'XL', 'XXL'];
  }

  /// Colores disponibles para este producto
  List<String> get availableColors {
    if (colors.isNotEmpty) return colors;
    if (color.trim().isNotEmpty) {
      if (color.contains('/')) {
        return color.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
      if (color.contains(',')) {
        return color.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
      return [color.trim()];
    }
    if (isAccessory) return const ['Negro', 'Café', 'Azul Marino'];
    return const ['Original'];
  }

  bool get hasColors => availableColors.isNotEmpty;

  /// Clasificación y tipo de producto para filtrado y etiquetas
  String get productType {
    if (type.trim().isNotEmpty) return type.trim();
    final n = name.toLowerCase();
    if (n.contains('camisa') || n.contains('sobrecamisa')) return 'Camisas';
    if (n.contains('polo') || n.contains('camiseta')) return 'Polos';
    if (n.contains('casaca') || n.contains('bomber') || n.contains('chaqueta') || n.contains('blazer')) {
      return 'Casacas & Blazers';
    }
    if (n.contains('polera') || n.contains('hoodie') || n.contains('chompa') || n.contains('cardigan') || n.contains('sweater')) {
      return 'Poleras & Chompas';
    }
    if (n.contains('jean') || n.contains('denim')) return 'Jeans';
    if (n.contains('pantalón') || n.contains('pantalon') || n.contains('jogger') || n.contains('cargo')) {
      return 'Pantalones';
    }
    if (n.contains('bermuda') || n.contains('short')) return 'Shorts & Bermudas';
    if (n.contains('vestido') || n.contains('enterizo')) return 'Vestidos';
    if (n.contains('falda')) return 'Faldas';
    if (n.contains('billetera')) return 'Billeteras';
    if (n.contains('bolso') || n.contains('mochila') || n.contains('cartera')) return 'Bolsos & Mochilas';
    if (n.contains('lentes')) return 'Lentes';
    if (n.contains('gorro') || n.contains('gorra')) return 'Gorros';
    if (n.contains('cinturón') || n.contains('cinto')) return 'Cinturones';
    if (n.contains('zapatilla') || n.contains('zapato') || n.contains('bota') || n.contains('calzado')) {
      return 'Calzado';
    }
    return isAccessory ? 'Accesorios' : 'Prendas';
  }

  bool get _isShoe {
    final c = category.toLowerCase();
    final n = name.toLowerCase();
    return c.contains('calzado') ||
        c.contains('zapato') ||
        c.contains('zapatilla') ||
        n.contains('zapatilla') ||
        n.contains('zapato') ||
        n.contains('bota') ||
        n.contains('mocasín') ||
        n.contains('mocasin') ||
        n.contains('sandalia');
  }

  bool get isAccessory {
    final c = category.toLowerCase();
    final n = name.toLowerCase();
    return c.contains('accesorio') ||
        c.contains('bolso') ||
        c.contains('mochila') ||
        c.contains('cartera') ||
        n.contains('bolso') ||
        n.contains('mochila') ||
        n.contains('cartera') ||
        n.contains('billetera') ||
        n.contains('gorro') ||
        n.contains('gorra') ||
        n.contains('cinturón') ||
        n.contains('cinto') ||
        n.contains('reloj') ||
        n.contains('lentes') ||
        n.contains('pañuelo') ||
        n.contains('bufanda');
  }

  factory Garment.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final category =
        _stringValue(data['category'] ?? data['categoria']) ?? 'Otros';

    final rawSizes = data['sizes'] ?? data['tallas'];
    List<String> parsedSizes = [];
    if (rawSizes is List) {
      parsedSizes = rawSizes
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (rawSizes is String && rawSizes.trim().isNotEmpty) {
      parsedSizes = rawSizes
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final rawColors = data['colors'] ?? data['colores'];
    List<String> parsedColors = [];
    if (rawColors is List) {
      parsedColors = rawColors
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final colorStr = _stringValue(data['color']) ?? '';
    final typeStr = _stringValue(data['type'] ?? data['tipo']) ?? '';
    final materialStr = _stringValue(data['material']) ?? '';
    final fitStr = _stringValue(data['fit'] ?? data['corte']) ?? '';
    final descStr = _stringValue(data['description'] ?? data['descripcion']) ?? '';

    return Garment(
      id: id,
      name: _stringValue(data['name'] ?? data['nombre']) ?? 'Prenda sin nombre',
      category: category,
      price: _priceValue(data['price'] ?? data['precio']),
      image:
          _stringValue(
            data['image'] ??
                data['imageUrl'] ??
                data['image_url'] ??
                data['imagen'] ??
                data['foto'],
          ) ??
          '',
      tag: _stringValue(data['tag'] ?? data['etiqueta']) ?? category,
      store: _stringValue(
        data['store'] ??
            data['storeId'] ??
            data['store_id'] ??
            data['storeName'] ??
            data['tienda'] ??
            data['tiendaId'] ??
            data['tienda_id'] ??
            data['tiendaNombre'],
      ) ?? '',
      sizes: parsedSizes,
      color: colorStr,
      colors: parsedColors,
      type: typeStr,
      material: materialStr,
      fit: fitStr,
      description: descStr,
    );
  }

  static String? _stringValue(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static String _priceValue(Object? value) {
    if (value is num) {
      return 'S/ ${value == value.roundToDouble() ? value.toInt() : value}';
    }
    return _stringValue(value) ?? 'Consultar';
  }
}
