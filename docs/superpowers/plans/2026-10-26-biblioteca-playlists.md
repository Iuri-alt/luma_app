# Biblioteca, Favoritos e Playlists — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ligar a biblioteca às músicas reais do celular, com álbuns agrupados por letra, Favoritos e playlists persistentes, e reprodução básica com `just_audio`.

**Architecture:** Services em `lib/services/` fazem o trabalho (`MusicaService` lê o aparelho, `PastaService` guarda playlists em `shared_preferences`, `PlayerService` toca). `PastaService` e `PlayerService` são `ChangeNotifier`; as telas usam `ListenableBuilder`. Services são criados no `main` e passados por construtor, para os testes poderem trocar por versões falsas. Lógica pura (agrupar por letra, busca, reencontrar músicas) fica em `lib/functions/luma_functions.dart` e é testada sem plugin.

**Tech Stack:** Flutter, Dart `^3.12.2`, `on_audio_query` 2.9.0, `just_audio`, `shared_preferences`, `flutter_test`.

**Resultado da Task 1:** Android 16 (Redmi 23117RA68G). `on_audio_query` 2.9.0 funciona (permissão, 628 músicas, 45 álbuns). `just_audio` toca por `AudioSource.file(caminho)`. Mantido `on_audio_query`; build avisa que o plugin usa Kotlin Gradle Plugin e vai quebrar em versões futuras do Flutter.

**Spec:** `docs/superpowers/specs/2026-10-26-biblioteca-playlists-design.md`

> O projeto não é repositório git. Ao fim de cada task o passo "Checkpoint" roda `flutter analyze` e `flutter test`; se o usuário inicializar git, commitar nesse passo.

## Global Constraints

- Android é o alvo; testes de dispositivo no celular do usuário via USB com depuração ativada.
- Nomes de classes, métodos e variáveis em português, como no código atual. Cores sempre de `AppColors`. Comentários de seção em bloco (`// ====`) como nas telas existentes.
- Textos da tela em português: "Favoritos", "Buscar", "Nova playlist", "Renomear", "Excluir", "Adicionar à playlist", "Favoritar", "Desfavoritar", "Remover da playlist".
- Playlist "Favoritos" sempre existe, id fixo `favoritos`, não pode ser renomeada nem excluída.
- Álbuns do celular são só leitura.
- Fora do escopo: segundo plano/notificação (`audio_service`), shuffle, repeat, validação de login, troca de tema, nuvem.
- `on_audio_query` exporta classes chamadas `AlbumModel` e `PlaylistModel`. Para não conflitar, os modelos do Luma se chamam `AlbumDispositivoModel` e `PastaModel` (o spec dizia `AlbumModel`/`PlaylistModel`; mudança só de nome).
- `flutter analyze` sem problemas ao fim de cada task.

## Review Focus

1. Permissão negada (inclusive "não perguntar de novo"): biblioteca mostra mensagem e botão "Permitir acesso", sem tela em branco. Teste na Task 7.
2. Dados salvos corrompidos ou de formato antigo: app abre com só Favoritos vazio, não trava, e não apaga o texto original (guarda em `luma_pastas_v1_backup`). Teste na Task 3.
3. Nome de playlist vazio ou só espaços: recusado; o diálogo não fecha. Nome é salvo com `trim()`. Teste na Task 3 (service) e Task 7 (diálogo).
4. Arquivo de música apagado depois de listado: tocar não derruba o app; pula para a próxima e mostra SnackBar "Não foi possível tocar esta música". Verificação manual na Task 5.
5. Álbum sem nome ou `<unknown>`, e nomes começando com acento ou número: "Álbum Desconhecido", grupo por letra sem acento (`Ábaco` vai em `A`), número/símbolo em `#` (último grupo). Teste na Task 2.

---

### Task 1: Verificar plugins no celular (gate)

Decide se `on_audio_query` 2.9.0 serve ou se troca para `on_audio_query_forked`, e se o `just_audio` toca pelo caminho ou pela URI. Nada é construído antes disso.

**Files:**
- Modify: `pubspec.yaml` (dependências)
- Create (temporário, apagar no fim da task): `lib/spike_main.dart`

**Interfaces:**
- Produces: decisão registrada no topo deste plano (linha "Resultado da Task 1") sobre pacote de consulta e forma de abrir o áudio (`AudioSource.file(caminho)` ou `AudioSource.uri(Uri.parse('content://media/external/audio/media/$id'))`).

- [ ] **Step 1:** `flutter pub add just_audio shared_preferences`. Expected: `pubspec.yaml` lista os dois.
- [ ] **Step 2:** `adb devices` e `adb shell getprop ro.build.version.release`. Expected: celular aparece como `device`; anotar a versão do Android.
- [ ] **Step 3:** Escrever `lib/spike_main.dart`: um `MaterialApp` com um botão que chama `ArmazenamentoService().solicitarPermissao()`, depois `querySongs()` e `queryAlbums()`, mostra as contagens e o título da primeira música, e um botão que toca a primeira música com `just_audio` pelo caminho; se falhar, pela URI.
- [ ] **Step 4:** `flutter run -t lib/spike_main.dart` no celular. Expected: diálogo de permissão aparece uma vez; contagens > 0; som sai. Se a consulta falhar ou vier vazia em Android 13+, trocar `on_audio_query` por `on_audio_query_forked` no `pubspec.yaml` e nos imports, repetir o passo, e avisar o usuário.
- [ ] **Step 5:** Registrar o resultado no topo do plano, apagar `lib/spike_main.dart`.
- [ ] **Step 6: Checkpoint** — `flutter analyze` → "No issues found!".

---

### Task 2: Modelos e funções puras

**Files:**
- Modify: `lib/models/musica_model.dart`
- Create: `lib/models/album_dispositivo_model.dart`
- Modify: `lib/models/pasta_model.dart` (hoje vazio)
- Modify: `lib/functions/luma_functions.dart`
- Test: `test/models_test.dart`, `test/luma_functions_test.dart` (já existe; acrescentar)

**Interfaces:**
- Produces:
  - `MusicaModel` ganha `final int? albumId;` (opcional no construtor).
  - `class AlbumDispositivoModel { final int id; final String nome; final String artista; final int quantidadeMusicas; }`
  - `class MusicaRef { final int id; final String titulo; final String artista; final int duracao; factory MusicaRef.deMusica(MusicaModel m); Map<String, dynamic> toJson(); factory MusicaRef.fromJson(Map<String, dynamic> json); }` — em `pasta_model.dart`.
  - `class PastaModel { final String id; final String nome; final List<MusicaRef> musicas; final bool ehFavoritos; PastaModel copyWith({String? nome, List<MusicaRef>? musicas}); Map<String, dynamic> toJson(); factory PastaModel.fromJson(Map<String, dynamic> json); }`
  - `String normalizarTexto(String texto)` — minúsculas, sem acentos (á à â ã ä é ê è ë í ì î ï ó ò ô õ ö ú ù û ü ç ñ).
  - `Map<String, List<T>> agruparPorLetra<T>(List<T> itens, String Function(T) nome)` — chave é a primeira letra normalizada em maiúscula, ou `#` se não for A–Z; chaves em ordem alfabética com `#` por último; itens de cada grupo ordenados por `normalizarTexto(nome)`.
  - `({List<MusicaModel> encontradas, List<MusicaRef> refsAtualizadas}) resolverMusicas(List<MusicaRef> refs, List<MusicaModel> doAparelho)` — para cada ref, na ordem: acha por `id`; se não achar, por `titulo` + `artista` + `duracao` iguais e devolve a ref com o novo id; se nada bater, a ref fica em `refsAtualizadas` sem mudar e não entra em `encontradas`.

- [ ] **Step 1: Testes que falham**

```dart
// test/models_test.dart
test('PastaModel ida e volta em JSON', () {
  final p = PastaModel(id: '1', nome: 'Rock', ehFavoritos: false, musicas: [
    MusicaRef(id: 7, titulo: 'A', artista: 'B', duracao: 1000),
  ]);
  final volta = PastaModel.fromJson(jsonDecode(jsonEncode(p.toJson())));
  expect(volta.nome, 'Rock');
  expect(volta.musicas.single.id, 7);
  expect(volta.musicas.single.duracao, 1000);
});
```

```dart
// test/luma_functions_test.dart (acrescentar)
test('agruparPorLetra usa letra sem acento e # por último', () {
  final g = agruparPorLetra(['Zeca', 'ábaco', '1999', 'Abba', ''], (s) => s);
  expect(g.keys.toList(), ['A', 'Z', '#']);
  expect(g['A'], ['Abba', 'ábaco']);
  expect(g['#'], containsAll(['1999', '']));
});

test('normalizarTexto tira acento e caixa', () {
  expect(normalizarTexto('Canção ÁGUA'), 'cancao agua');
});

test('resolverMusicas acha por id, depois por metadados, e mantém perdidas', () {
  final aparelho = [
    MusicaModel(id: 1, titulo: 'X', artista: 'Y', album: 'Z', caminho: '/x', duracao: 10, tamanho: 1),
    MusicaModel(id: 99, titulo: 'Movida', artista: 'Y', album: 'Z', caminho: '/m', duracao: 20, tamanho: 1),
  ];
  final refs = [
    MusicaRef(id: 1, titulo: 'X', artista: 'Y', duracao: 10),
    MusicaRef(id: 5, titulo: 'Movida', artista: 'Y', duracao: 20),
    MusicaRef(id: 6, titulo: 'Sumiu', artista: 'Y', duracao: 30),
  ];
  final r = resolverMusicas(refs, aparelho);
  expect(r.encontradas.map((m) => m.id), [1, 99]);
  expect(r.refsAtualizadas.map((m) => m.id), [1, 99, 6]);
});
```

- [ ] **Step 2:** `flutter test` → FAIL (classes/funções não existem).
- [ ] **Step 3:** Implementar as interfaces acima.
- [ ] **Step 4:** `flutter test` → todos passam.
- [ ] **Step 5: Checkpoint** — `flutter analyze` limpo.

---

### Task 3: `PastaService` com persistência

**Files:**
- Create: `lib/services/pasta_service.dart`
- Test: `test/pasta_service_test.dart`

**Interfaces:**
- Consumes: `PastaModel`, `MusicaRef`, `MusicaModel` (Task 2).
- Produces: `class PastaService extends ChangeNotifier`
  - `static const chave = 'luma_pastas_v1';`
  - `Future<void> carregar()` — lê a chave; se ausente, cria só Favoritos (`id: 'favoritos'`, `nome: 'Favoritos'`, `ehFavoritos: true`). Se o JSON for inválido, copia o texto cru para `luma_pastas_v1_backup` e começa só com Favoritos. Favoritos é garantido mesmo que falte no JSON.
  - `PastaModel get favoritos`; `List<PastaModel> get playlists` (sem Favoritos, em ordem de criação).
  - `Future<PastaModel> criar(String nome)` — lança `ArgumentError` se `nome.trim()` vazio; id = `DateTime.now().microsecondsSinceEpoch.toString()`.
  - `Future<void> renomear(String id, String nome)` — `ArgumentError` se vazio ou se `id == 'favoritos'`.
  - `Future<void> excluir(String id)` — `ArgumentError` se `id == 'favoritos'`.
  - `Future<void> adicionarMusica(String pastaId, MusicaModel musica)` — ignora se já tem música com mesmo `id`.
  - `Future<void> removerMusica(String pastaId, int musicaId)`.
  - `bool ehFavorito(int musicaId)`; `Future<void> alternarFavorito(MusicaModel musica)`.
  - `Future<void> atualizarRefs(String pastaId, List<MusicaRef> refs)` — usado depois de `resolverMusicas`; só salva se algo mudou.
  - Toda mudança salva e chama `notifyListeners()`.

- [ ] **Step 1: Testes que falham** (com `SharedPreferences.setMockInitialValues({})` no `setUp`):

```dart
test('começa só com Favoritos', () async {
  final s = PastaService(); await s.carregar();
  expect(s.favoritos.id, 'favoritos');
  expect(s.playlists, isEmpty);
});

test('cria, renomeia, adiciona sem duplicar, remove e exclui', () async {
  final s = PastaService(); await s.carregar();
  final p = await s.criar('  Rock  ');
  expect(p.nome, 'Rock');
  await s.renomear(p.id, 'Rock BR');
  await s.adicionarMusica(p.id, musica(1));
  await s.adicionarMusica(p.id, musica(1));
  expect(s.playlists.single.musicas.length, 1);
  await s.removerMusica(p.id, 1);
  expect(s.playlists.single.musicas, isEmpty);
  await s.excluir(p.id);
  expect(s.playlists, isEmpty);
});

test('persiste entre instâncias', () async {
  final a = PastaService(); await a.carregar();
  await a.criar('Treino'); await a.alternarFavorito(musica(3));
  final b = PastaService(); await b.carregar();
  expect(b.playlists.single.nome, 'Treino');
  expect(b.ehFavorito(3), isTrue);
});

test('recusa nome vazio e proteger Favoritos', () async {
  final s = PastaService(); await s.carregar();
  expect(() => s.criar('   '), throwsArgumentError);
  expect(() => s.excluir('favoritos'), throwsArgumentError);
  expect(() => s.renomear('favoritos', 'X'), throwsArgumentError);
});

test('JSON corrompido não trava e guarda backup', () async {
  SharedPreferences.setMockInitialValues({PastaService.chave: '{quebrado'});
  final s = PastaService(); await s.carregar();
  expect(s.favoritos.musicas, isEmpty);
  final prefs = await SharedPreferences.getInstance();
  expect(prefs.getString('luma_pastas_v1_backup'), '{quebrado');
});
```

(`musica(int id)` é um helper do teste que cria um `MusicaModel` qualquer com esse id.)

- [ ] **Step 2:** `flutter test test/pasta_service_test.dart` → FAIL.
- [ ] **Step 3:** Implementar `PastaService`.
- [ ] **Step 4:** `flutter test` → passa.
- [ ] **Step 5: Checkpoint** — `flutter analyze` limpo.

---

### Task 4: `MusicaService` com álbuns e filtro de música

**Files:**
- Modify: `lib/services/musica_service.dart`

**Interfaces:**
- Consumes: `ArmazenamentoService`, `MusicaModel`, `AlbumDispositivoModel`.
- Produces (todos os métodos sobrescrevíveis, para testes usarem uma subclasse falsa):
  - `Future<bool> garantirPermissao()` — verifica; se não tiver, pede uma vez.
  - `Future<List<MusicaModel>> buscarMusicas()` — só `isMusic == true` (tira toques e áudios do WhatsApp), preenche `albumId`; lista vazia se sem permissão. Resultado guardado em memória; `recarregar()` limpa o cache.
  - `Future<List<AlbumDispositivoModel>> buscarAlbuns()` — de `queryAlbums()`; nome vazio ou `<unknown>` vira "Álbum Desconhecido"; artista nulo vira "Artista Desconhecido".
  - `List<MusicaModel> musicasDoAlbum(List<MusicaModel> todas, int albumId)` — filtra e ordena por título normalizado.
- [ ] **Step 1:** Implementar. (Depende do plugin; sem teste unitário. `musicasDoAlbum` é pura: acrescentar um teste em `test/luma_functions_test.dart` que confere filtro e ordem.)
- [ ] **Step 2:** `flutter test` → passa.
- [ ] **Step 3: Checkpoint** — `flutter analyze` limpo.

---

### Task 5: `PlayerService`

**Files:**
- Create: `lib/services/player_service.dart`

**Interfaces:**
- Consumes: `MusicaModel`; forma de abrir o áudio decidida na Task 1.
- Produces: `class PlayerService extends ChangeNotifier`
  - `MusicaModel? get atual`; `bool get tocando`; `Stream<Duration> get posicao`; `Duration get duracaoAtual`.
  - `Future<void> tocarFila(List<MusicaModel> fila, int indice)` — monta a fila no `AudioPlayer` (`setAudioSources(..., initialIndex: indice)`) e toca.
  - `Future<void> alternarPlayPause()`, `Future<void> proxima()`, `Future<void> anterior()`, `Future<void> irPara(Duration posicao)`.
  - `Stream<String> get erros` — emite "Não foi possível tocar esta música" quando o `just_audio` falha numa faixa; nesse caso pula para a próxima se houver.
  - `void dispose()` libera o `AudioPlayer`.
- [ ] **Step 1:** Implementar, ouvindo `currentIndexStream` e `playerStateStream` para atualizar `atual`/`tocando` e chamar `notifyListeners()`.
- [ ] **Step 2:** Verificação manual na Task 9 (precisa de tela). Aqui: `flutter analyze` limpo.

---

### Task 6: Navegação e injeção de services

**Files:**
- Modify: `lib/main.dart`, `lib/login_screen.dart`, `lib/main_screen.dart`, `lib/reproducao_screen.dart` (tirar `Drawer` e o botão de menu)
- Test: `test/widget_test.dart` (substituir o teste de contador)

**Interfaces:**
- Consumes: `MusicaService`, `PastaService`, `PlayerService`.
- Produces:
  - `MyApp({required MusicaService musicaService, required PastaService pastaService, required PlayerService playerService})`. `main()` cria os três, chama `await pastaService.carregar()` (com `WidgetsFlutterBinding.ensureInitialized()`), e roda o app.
  - `LoginScreen` recebe os três e faz `Navigator.pushReplacement` para `MainScreen`.
  - `MainScreen` recebe os três e repassa. Biblioteca é a aba 0. `BibliotecaScreen` recebe `VoidCallback aoIniciarReproducao`, que troca para a aba 1.
  - `ReproducaoScreen({required PlayerService playerService, required PastaService pastaService})`. `BibliotecaScreen({required MusicaService musicaService, required PastaService pastaService, required PlayerService playerService, required VoidCallback aoIniciarReproducao})`.
  - Para testes: `PlayerService` aceita `AudioPlayer?` opcional no construtor; teste de widget usa um `PlayerService` falso (subclasse que não toca nada).
- [ ] **Step 1: Teste que falha** — `test/widget_test.dart`: monta `MyApp` com `MusicaService` falso (retorna 1 álbum "Abbey Road" e 1 música), `PastaService` com prefs mock e `PlayerService` falso; toca "Login"; `pumpAndSettle`; espera `find.byType(MainScreen)` e `find.text('BIBLIOTECA')`; `Navigator.canPop` do `MainScreen` é `false`.
- [ ] **Step 2:** `flutter test test/widget_test.dart` → FAIL.
- [ ] **Step 3:** Implementar. Os fakes ficam em `test/fakes.dart` e são reaproveitados nas Tasks 7 e 8.
- [ ] **Step 4:** `flutter test` → passa.
- [ ] **Step 5: Checkpoint** — `flutter analyze` limpo.

---

### Task 7: Tela da biblioteca com dados reais

**Files:**
- Modify: `lib/biblioteca_screen.dart` (remove `AlbumFolder`, `NowPlayingTrack` e os mocks)
- Test: `test/biblioteca_screen_test.dart`

**Interfaces:**
- Consumes: Tasks 2–6.
- Produces: tela navega para `ListaMusicasScreen` (Task 8) com `ListaMusicasScreen.album(...)` ou `ListaMusicasScreen.pasta(...)`.

Comportamento:
- Ao abrir: `garantirPermissao()`; se `false`, mostra "O Luma precisa de acesso às suas músicas" e botão "Permitir acesso" que tenta de novo.
- Ordem: busca, botão "Nova playlist", seção "Favoritos" (um item), seção "Playlists" (se houver), álbuns por `agruparPorLetra`.
- Busca: compara `normalizarTexto` do nome com `normalizarTexto` do texto digitado (contém). Esconde seções vazias. Sem resultado: "Nada encontrado".
- "Nova playlist": diálogo com campo e botão "Criar"; com nome vazio o botão fica desabilitado.
- "..." só nas playlists do usuário: bottom sheet "Renomear" (diálogo como o de criar) e "Excluir" (confirmação "Excluir playlist?").
- Capas de álbum: `QueryArtworkWidget(id: album.id, type: ArtworkType.ALBUM, nullArtworkWidget: Icon(Icons.album, ...))`.
- Contagem: "1 música" / "N músicas".

- [ ] **Step 1: Testes que falham** (com fakes da Task 6):
  - `'mostra Favoritos, playlists e álbuns agrupados'`: fake com álbuns "Abbey Road" e "Zé Ramalho"; `pastaService.criar('Treino')` antes; espera textos `Favoritos`, `Treino`, `Abbey Road`, `A`, `Z`.
  - `'busca filtra sem acento'`: digita `ze` no campo; espera `Zé Ramalho` e não espera `Abbey Road`.
  - `'cria playlist pelo diálogo e recusa vazio'`: toca "Nova playlist"; com campo vazio o botão "Criar" está desabilitado; digita "Foco"; toca "Criar"; espera `Foco` na lista.
  - `'permissão negada mostra botão'`: fake com `garantirPermissao` → `false`; espera `Permitir acesso`.
- [ ] **Step 2:** `flutter test test/biblioteca_screen_test.dart` → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `flutter test` → passa.
- [ ] **Step 5: Checkpoint** — `flutter analyze` limpo.

---

### Task 8: Tela de lista de músicas

**Files:**
- Create: `lib/lista_musicas_screen.dart`
- Test: `test/lista_musicas_screen_test.dart`

**Interfaces:**
- Consumes: `MusicaService.buscarMusicas`, `musicasDoAlbum`, `resolverMusicas`, `PastaService`, `PlayerService.tocarFila`, `aoIniciarReproducao`.
- Produces: `ListaMusicasScreen.album({required AlbumDispositivoModel album, ...services, required VoidCallback aoIniciarReproducao})` e `ListaMusicasScreen.pasta({required String pastaId, ...})`.

Comportamento:
- Título: nome do álbum ou playlist; botão voltar com `Navigator.maybePop`.
- Playlist: `resolverMusicas(pasta.musicas, todas)`; se os ids mudaram, `atualizarRefs`. Playlist vazia: "Nenhuma música ainda".
- Tocar numa música: `tocarFila(listaVisivel, indice)`, `Navigator.pop`, `aoIniciarReproducao()`.
- "..." da música: "Adicionar à playlist" (lista das playlists do usuário; se não houver, opção "Nova playlist" que cria e adiciona), "Favoritar"/"Desfavoritar", e "Remover da playlist" só quando aberta de uma playlist.
- Reage a mudanças do `PastaService` (`ListenableBuilder`).

- [ ] **Step 1: Testes que falham:**
  - `'favoritar pelo menu muda o texto'`: abre álbum com 1 música; "..." → "Favoritar"; "..." de novo mostra "Desfavoritar"; `pastaService.ehFavorito(id)` é `true`.
  - `'remover da playlist'`: playlist com 1 música; "..." → "Remover da playlist"; espera "Nenhuma música ainda".
  - `'tocar chama tocarFila com índice certo'`: álbum com 2 músicas; toca a segunda; fake registrou `indice == 1`.
- [ ] **Step 2:** FAIL. **Step 3:** Implementar. **Step 4:** `flutter test` → passa.
- [ ] **Step 5: Checkpoint** — `flutter analyze` limpo.

---

### Task 9: Tela de reprodução ligada ao player

**Files:**
- Modify: `lib/reproducao_screen.dart`

Comportamento:
- Sem música: "Escolha uma música na biblioteca".
- Capa: `QueryArtworkWidget(id: atual.id, type: ArtworkType.AUDIO, ...)` no lugar de `Image.asset('')`.
- Título, "artista · álbum", slider ligado a `posicao`/`duracaoAtual` com `irPara`, tempos com `formatarDuracao` (atual e restante com `-`).
- Play/pause mostra o ícone conforme `tocando`. Anterior/próxima funcionam. Shuffle e repeat ficam como estão.
- `Icons.bolt` vira coração: `Icons.favorite` (cheio, `AppColors.primary`) se `ehFavorito`, senão `Icons.favorite_border`; toque chama `alternarFavorito`.
- Ouve `playerService.erros` e mostra SnackBar.

- [ ] **Step 1:** Implementar.
- [ ] **Step 2:** `flutter test` e `flutter analyze` limpos.
- [ ] **Step 3: Verificação no celular** — `flutter run`:
  1. Login → biblioteca abre com álbuns reais; voltar do Android não volta ao login.
  2. Criar playlist "Teste", abrir um álbum, adicionar 2 músicas nela e favoritar 1.
  3. Tocar uma música → vai para a aba Reprodução, som sai, slider anda, pause/próxima/anterior funcionam, coração reflete o favorito.
  4. Fechar o app de verdade (tirar dos recentes), abrir de novo → "Teste" com 2 músicas e Favoritos com 1.
  5. Apagar pelo gerenciador de arquivos uma música que está na fila, tocar ela → SnackBar e pula, sem travar.
  Expected: todos os 5 passam. Anotar qualquer falha antes de dar como pronto.
