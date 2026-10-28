# Biblioteca: álbuns, favoritos e playlists — design

Data: 2026-10-26
App: Luma (`luma_app`, Flutter, Android como alvo principal)

## Intenção

O Luma é um player de música local. Hoje as telas existem só como visual, com
dados fixos. Esta etapa liga a biblioteca às músicas reais do celular e deixa o
usuário organizar as músicas em favoritos e playlists que ficam salvas entre
aberturas do app.

Sucesso: o usuário faz login, cai na biblioteca, vê os álbuns do próprio
celular, cria uma playlist, adiciona músicas nela e nos favoritos, fecha o app,
abre de novo e tudo continua lá. Tocar numa música faz ela tocar.

## Objetivos

1. Biblioteca mostra os álbuns reais do aparelho, agrupados pela primeira letra
   do nome (A, B, C...). Nomes que não começam com letra vão no grupo `#`.
2. Usuário cria, renomeia e exclui playlists.
3. Existe uma playlist especial "Favoritos", criada automaticamente, que não
   pode ser renomeada nem excluída.
4. Favoritos e playlists persistem entre aberturas do app.
5. Busca no topo da biblioteca filtra álbuns e playlists pelo nome (sem
   diferenciar maiúsculas e acentos é desejável, não obrigatório).
6. Tocar num álbum ou playlist abre uma tela com a lista de músicas dele.
7. Tocar numa música começa a tocar e a tela de reprodução mostra a música
   atual, com play/pause, anterior, próxima e barra de progresso funcionando.
   A fila é o álbum ou playlist de onde a música foi aberta.

## Não-objetivos (nesta etapa)

- Tocar em segundo plano, notificação de mídia e tela bloqueada
  (`audio_service`). Fica para depois.
- Shuffle e repeat funcionando (os botões continuam visuais).
- Login com validação de verdade. O login continua existindo como está.
- Troca de tema.
- Sincronizar playlists na nuvem ou entre aparelhos.
- Editar álbuns do celular (renomear, excluir). Álbuns são só leitura.

## Anti-objetivos (seria falha mesmo funcionando)

- Perder playlists ou favoritos ao fechar o app ou atualizar a versão.
- Uma música apagada do celular derrubar o app ao abrir uma playlist. Ela deve
  simplesmente não aparecer.
- Pedir permissão de armazenamento toda vez que o app abre depois de concedida.
- Se a permissão for negada, a biblioteca ficar em branco sem explicação. Deve
  mostrar mensagem e um botão para pedir de novo.

## Decisões já tomadas

**Do usuário:**
- Músicas organizadas por álbum.
- Favoritos e playlists criados pelo usuário, e persistem.
- Login fica.
- Layout e fluxo da biblioteca descritos abaixo foram aprovados.

**Layout da biblioteca (aprovado):**
- Topo: título "BIBLIOTECA" e campo de busca.
- Botão "Nova playlist" (substitui "New Folder"): abre diálogo pedindo nome e
  cria playlist vazia.
- Seção "Favoritos" no topo da lista.
- Depois: playlists do usuário.
- Por fim: álbuns do celular agrupados por letra.
- Menu "..." aparece só em playlists do usuário: renomear e excluir (excluir
  pede confirmação). Favoritos e álbuns não têm esse menu.

**Navegação (aprovado):**
- Login leva para `MainScreen` (barra inferior: Biblioteca, Reprodução,
  Config), com Biblioteca como primeira aba. Login usa `pushReplacement` para
  não voltar ao login com o botão voltar.
- O menu lateral (`Drawer`) de `ReproducaoScreen` sai, porque duplica a barra
  inferior.
- Tela de lista de músicas (álbum ou playlist) é empurrada por cima da aba
  Biblioteca, com botão voltar.
- Tocar numa música inicia a reprodução e troca para a aba Reprodução.

## Escolhas do Claude (o usuário pode mudar)

- **Adicionar música:** coração na tela de reprodução liga/desliga favorito da
  música atual. Cada música na lista tem "..." com "Adicionar à playlist" (abre
  lista das playlists para escolher) e "Favoritar/Desfavoritar". Dentro de uma
  playlist, o "..." também tem "Remover da playlist". O ícone `Icons.bolt` atual
  da tela de reprodução vira o coração.
- **Persistência:** `shared_preferences`, guardando as playlists como um JSON
  numa única chave. Playlist guarda só os ids das músicas (`MusicaModel.id`),
  nunca o arquivo. Ordem das músicas é a ordem em que foram adicionadas.
  Música repetida na mesma playlist não é adicionada de novo.
- **Estado:** sem pacote de gerência de estado. `ChangeNotifier` em services
  únicos (ex.: `PlaylistService`, `PlayerService`) e `ListenableBuilder` nas
  telas. Instância única criada no `main` e passada adiante (ou singleton
  simples).
- **Áudio:** `just_audio`, tocando pelo caminho do arquivo (`MusicaModel.caminho`)
  ou pela URI do `on_audio_query`, o que funcionar no Android alvo.
- **Capas:** `QueryArtworkWidget` do `on_audio_query`, com ícone de álbum como
  fallback. Remove o `Image.asset('')` da tela de reprodução, que hoje quebra.
- **Modelo:** `pasta_model.dart` vira `PlaylistModel` com `id` (string única),
  `nome`, `musicas` (lista de referências), `ehFavoritos` (bool). Um
  `AlbumModel` novo com `id`, `nome`, `artista`, `quantidadeMusicas`.
- **Referência de música salva:** o id do MediaStore muda quando o arquivo é
  movido, renomeado, reescaneado ou restaurado em outro celular. Por isso cada
  música na playlist é salva como `{id, titulo, artista, duracao}`. Ao carregar,
  procura pelo `id`; se não achar, procura por `titulo` + `artista` + `duracao`
  e atualiza o `id` salvo. Se nada bater, a música some da tela mas continua
  salva (volta se o arquivo reaparecer).
- **Favoritos na biblioteca:** é um único item na seção "Favoritos" (a playlist
  especial), que abre a mesma tela de lista de músicas das playlists. Só
  músicas são favoritadas; álbuns não. O `AlbumFolder.isFavorite` do mock sai.
  A busca encontra "Favoritos" pelo nome como qualquer playlist.
- **Textos da tela em português** ("Favoritos", "Buscar", "Nova playlist"),
  substituindo os em inglês que estão no mock.

## Restrições

- Flutter com Dart `^3.12.2`, Android é o alvo que importa.
- `on_audio_query` 2.9.0 já está no projeto e é usado para músicas, álbuns,
  permissão e capas. Ele está sem manutenção há anos: o primeiro passo do
  construtor é confirmar que `querySongs`/`queryAlbums` e permissão funcionam
  num Android 13+. Se não funcionar, trocar para o fork `on_audio_query_forked`
  com a mesma API, e avisar.
- Teste em aparelho real: o celular Android do usuário, com músicas salvas,
  ligado por USB com depuração ativada. A verificação do `on_audio_query`
  (permissão, `querySongs`, `queryAlbums`) e da reprodução com `just_audio` é
  feita nele, antes de construir as telas. A versão do Android é lida pelo
  `adb` nessa hora.
- Manifest já declara `READ_EXTERNAL_STORAGE` e `READ_MEDIA_AUDIO`.
- Seguir o estilo atual: nomes em português, `AppColors` para cores, comentários
  de seção em bloco como nas telas existentes.
- `flutter analyze` sem problemas no final.

## Deixado para o construtor

- Estrutura exata de arquivos e nomes de métodos dos services.
- Como gerar o `id` da playlist (timestamp serve).
- Visual do diálogo de nova playlist, do bottom sheet do "..." e da tela de
  lista de músicas, seguindo `AppColors` e o estilo existente.
- Estado vazio de playlist sem músicas e de busca sem resultado.
- Testes: unitários para `PlaylistService` (criar, renomear, excluir, adicionar,
  remover, persistir e recarregar, Favoritos não pode ser excluído) e para o
  agrupamento por letra. Reescrever ou apagar o `test/widget_test.dart` do
  template, que hoje falha.
