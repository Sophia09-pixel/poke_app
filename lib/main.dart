import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

void main() {
  runApp(const PokeApp());
}

class Pokemon {
  final String name;
  final List<String> types;
  final String? mainSprite;
  final Sprites sprites;
  Pokemon({
    required this.name,
    required this.types,
    required this.mainSprite,
    required this.sprites,
  });
  factory Pokemon.fromJson(Map<String, dynamic> json) {
    return Pokemon(
      name: json['name'],
      types: (json['types'] as List)
          .map((t) => t['type']['name'] as String)
          .toList(),
      mainSprite: json['sprites']['other']['official-artwork']['front_default'],
      sprites: Sprites.fromJson(json['sprites']),
    );
  }
}

class Sprites {
  final String? frontDefault;
  final String? backDefault;
  final String? frontShiny;
  final String? backShiny;
  Sprites({
    this.frontDefault,
    this.backDefault,
    this.frontShiny,
    this.backShiny,
  });
  factory Sprites.fromJson(Map<String, dynamic> json) {
    return Sprites(
      frontDefault: json['front_default'],
      backDefault: json['back_default'],
      frontShiny: json['front_shiny'],
      backShiny: json['back_shiny'],
    );
  }
  // Retorna todas as imagens não nulas em umalista
  List<String> get allImages {
    return [
      frontDefault,
      backDefault,
      frontShiny,
      backShiny,
    ].whereType<String>().toList();
  }
}

class PokemonItemList {
  final String name;
  final String url;
  PokemonItemList({required this.name, required this.url});
  factory PokemonItemList.fromJson(Map<String, dynamic> json) {
    return PokemonItemList(name: json['name'], url: json['url']);
  }
  String get imageUrl {
    final id = url.split("/")[url.split("/").length - 2];
    return "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png";
  }
}

class PokeApp extends StatelessWidget {
  const PokeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokédex',
      theme: ThemeData(primarySwatch: Colors.red),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pokédex"), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // AQUI SERÃO ADICIONADOS OS CAMPONENTES DA TELA
              const Icon(Icons.catching_pokemon, size: 100, color: Colors.red),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.list),
                label: const Text("Lista de Pokémons"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PokemonListScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.search),
                label: const Text("Pesquisar Pokémon"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PokemonSearchScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PokemonListScreen extends StatefulWidget {
  const PokemonListScreen({super.key});
  @override
  State<PokemonListScreen> createState() => _PokemonListScreenState();
}

class _PokemonListScreenState extends State<PokemonListScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<PokemonItemList> _pokemons = [];

  int _offset = 0;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchPokemons();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_loading &&
          _hasMore) {
        _fetchPokemons();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pokédex")),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: _pokemons.length + 1,
        itemBuilder: (context, index) {
          if (index < _pokemons.length) {
            final pokemon = _pokemons[index];
            return ListTile(
              leading: Image.network(pokemon.imageUrl),
              title: Text(pokemon.name.toUpperCase()),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _hasMore
                    ? const CircularProgressIndicator()
                    : const Text("Todos os Pokémons carregados"),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _fetchPokemons() async {
    setState(() => _loading = true);
    const int limit = 20;
    final response = await http.get(
      Uri.parse(
        "https://pokeapi.co/api/v2/pokemon?limit=$limit&offset=$_offset",
      ),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      final List<PokemonItemList> newPokemons = results
          .map((json) => PokemonItemList.fromJson(json))
          .toList();
      setState(() {
        _offset += limit;
        _pokemons.addAll(newPokemons);
        _hasMore = newPokemons.isNotEmpty;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }
}

class PokemonSearchScreen extends StatefulWidget {
  const PokemonSearchScreen({super.key});
  @override
  State<PokemonSearchScreen> createState() => _PokemonSearchScreenState();
}

class _PokemonSearchScreenState extends State<PokemonSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  // Objeto com o Pokemon pesquisado
  Pokemon? _pokemon;
  // Indica que a tela estará carregando os dados
  bool _loading = false;
  // Armazena a mensagem de erro caso aconteça algum
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PokeApp")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Campos dos formularios
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Digite o número do Pokémon",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              // Botao para realizar a busca
              ElevatedButton(
                onPressed: _searchPokemon,
                child: const Text("Buscar"),
              ),
              const SizedBox(height: 20),
              // Animacao de carregando quando estiver pesquisando
              if (_loading) const CircularProgressIndicator(),
              // Se tiver erro exibe a mensagem
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              // Se recuperar o pokemon irá chamar o método para exibi-lo
              if (_pokemon != null) _buildPokemonCard(_pokemon!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPokemonCard(Pokemon pokemon) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Exibir os dados do Pokemon Pesquisado
            if (pokemon.mainSprite != null)
              Image.network(pokemon.mainSprite!, height: 300),
            Text(
              pokemon.name.toUpperCase(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: pokemon.types
                  .map(
                    (type) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Chip(label: Text(type)),
                    ),
                  )
                  .toList(),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // duas imagens por linha
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: pokemon.sprites.allImages.length,
              itemBuilder: (context, index) {
                final url = pokemon.sprites.allImages[index];
                return Image.network(url, fit: BoxFit.contain);
              },
            ),
          ],
        ),
      ),
    );
  }

  //Funcao que irá realizar a busca
  Future<void> _searchPokemon() async {
    final id = int.tryParse(_controller.text);
    if (id == null) {
      setState(() => _error = "Digite um número válido!");
      return;
    }
    // Altera o estado
    setState(() {
      _loading = true;
      _error = null;
      _pokemon = null;
    });

    try {
      final response = await http.get(
        Uri.parse("https://pokeapi.co/api/v2/pokemon/$id"),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => _pokemon = Pokemon.fromJson(data));
      } else {
        setState(() => _error = "Pokémon não encontrado!");
      }
    } catch (e) {
      setState(() => _error = "Erro de conexão!");
    } finally {
      setState(() => _loading = false);
    }
  }
}
