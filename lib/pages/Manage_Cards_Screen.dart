import 'package:flutter/material.dart';
import '../services/video_card_service.dart';
import '/widgets/edit_card_dialog.dart';
import '../services/deck_service.dart';
import 'package:intl/intl.dart';
import 'video_study_screen.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'dart:convert';
import 'dart:async';

class ManageCardsScreen extends StatefulWidget {
  const ManageCardsScreen({Key? key}) : super(key: key);

  @override
  State<ManageCardsScreen> createState() => _ManageCardsScreenState();
}

class _ManageCardsScreenState extends State<ManageCardsScreen> {
  DateTime? _lastDeckCreationTime;
  final VideoCardService _videoCardService = VideoCardService();
  final DeckService _deckService = DeckService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _newDeckController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  String? _selectedDeckId;
  final Map<String, bool> _expandedCards = {};
  OverlayEntry? _overlayEntry;
  String _sortField = 'videoTitle';
  bool _sortAscending = true;
  int _currentTabIndex = 0;
  final StreamController<String> _cardUpdateController = StreamController<String>.broadcast();

  @override
  void initState() {
    super.initState();
    // Kiểm tra và xóa vĩnh viễn các thẻ và bộ thẻ đã bị xóa tạm thời quá 30 ngày


  }

  @override
  void dispose() {
    _searchController.dispose();
    _newDeckController.dispose();
    _removeOverlay();
    _cardUpdateController.close();
    super.dispose();
  }
  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _isSearching = false;
    });
  }

  void _performSearch() {
    setState(() {
      _searchQuery = _searchController.text.trim();
      _isSearching = _searchQuery.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Cards'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search cards...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      suffixIcon: _isSearching
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                          : null,
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _performSearch,
                  child: const Text('Search'),
                ),
              ],
            ),
          ),

          // Content Section
          Expanded(
            child: _isSearching ? _buildSearchResults() : _buildDefaultView(),
          ),
        ],
      ),
    );
  }
  Widget _buildDefaultView() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: const [
              Tab(text: 'Deck\'s Cards'),
              Tab(text: 'Today\'s Cards'),
              Tab(text: 'Deleted Decks/Cards'),
            ],
            onTap: (index) {
              if (_currentTabIndex != index) {  // Chỉ cập nhật khi tab thực sự thay đổi
                setState(() {
                  _currentTabIndex = index;
                });
              }
            },
          ),
          Expanded(
            child: IndexedStack(  // Thay TabBarView bằng IndexedStack
              index: _currentTabIndex,
              children: [
                _buildDeckList(),
                _buildTodayCardsList(),
                _buildDeletedCardsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildTodayCardsList() {
    if (_currentTabIndex != 1) {
      return Container();
    }

    return Column(
      children: [
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  tabs: const [
                    Tab(text: 'New Cards'),
                    Tab(text: 'Reviewed Cards'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildTodayNewCardsList(),
                      _buildTodayReviewedCardsList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildTodayNewCardsList() {
    List<VideoCard>? currentCards;

    return StatefulBuilder(
      builder: (context, setState) {
        return StreamBuilder<List<VideoCard>>(
          stream: _videoCardService.getTodayVideoCards(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && currentCards == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            currentCards = snapshot.data ?? currentCards ?? [];

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Total cards: ${currentCards!.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: currentCards!.isEmpty
                      ? const Center(child: Text('No cards added today'))
                      : ListView.builder(
                          itemCount: currentCards!.length,
                          itemBuilder: (context, index) => _buildCardItem(
                            currentCards![index],
                            onEdit: () {
                              _showEditDialog(context, currentCards![index]).then((_) {

                              });
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        );
      }
    );
  }
  Widget _buildTodayReviewedCardsList() {
    List<VideoCard>? currentCards;

    return StatefulBuilder(
      builder: (context, setState) {
        return StreamBuilder<List<VideoCard>>(
          stream: _videoCardService.getTodayReviewedCards(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && currentCards == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            currentCards = snapshot.data ?? currentCards ?? [];

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Total cards: ${currentCards!.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: currentCards!.isEmpty
                      ? const Center(child: Text('No cards reviewed today'))
                      : ListView.builder(
                          itemCount: currentCards!.length,
                          itemBuilder: (context, index) => _buildCardItem(
                            currentCards![index],
                            onEdit: () {
                              _showEditDialog(context, currentCards![index]).then((_) {

                              });
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        );
      }
    );
  }
  Widget _buildSearchResults() {
    return StreamBuilder<List<VideoCard>>(
      stream: _videoCardService.searchVideoCards(_searchQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final cards = snapshot.data ?? [];
        if (cards.isEmpty) {
          return Center(child: Text('No cards found matching "$_searchQuery"'));
        }

        return ListView.builder(
          itemCount: cards.length,
          itemBuilder: (context, index) => _buildCardItem(cards[index]),
        );
      },
    );
  }
  Widget _buildDeckList() {
    if (_currentTabIndex != 0) {
      return Container(); // Không load stream nếu không ở tab Deck's Cards
    }

    return StreamBuilder<List<Deck>>(
      stream: _deckService.getDecks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        // Get decks and sort them by name
        final decks = snapshot.data ?? [];
        decks.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        return StreamBuilder<Map<String, DueCardInfo>>(
          stream: _videoCardService.getDueCardsInfoForDecks(),
          builder: (context, dueCardsSnapshot) {
            if (dueCardsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            _checkAndCleanupDeletedItems();
            final dueCardsInfo = dueCardsSnapshot.data ?? {};

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newDeckController,
                          decoration: InputDecoration(
                            hintText: 'Enter deck name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onSubmitted: (_) => _addNewDeck(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _addNewDeck,
                        child: const Text('Add Deck'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: decks.length,
                    itemBuilder: (context, index) {
                      final deck = decks[index];
                      final dueInfo = dueCardsInfo[deck.id] ?? DueCardInfo();
                      return ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: Text(deck.name)),
                                  if (deck.isSpeedDeck)
                                    const Icon(Icons.speed, size: 16, color: Color(0xFFFFC0CB)),
                                  _buildDueCardCount(dueInfo),
                                ],
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.format_list_bulleted),
                              onPressed: () => _showDeckCards(context, deck),
                              tooltip: 'View Cards',
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditDeckDialog(context, deck),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _showDeleteDeckDialog(context, deck),
                            ),
                          ],
                        ),
                        onTap: () => _navigateToVideoStudyScreen(deck),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDueCardCount(DueCardInfo dueInfo) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dueInfo.shortTermCount > 0)
          _buildCountText(dueInfo.shortTermCount, Colors.red),
        if (dueInfo.mediumTermCount > 0)
          _buildCountText(dueInfo.mediumTermCount, Colors.blue),
        if (dueInfo.longTermCount > 0)
          _buildCountText(dueInfo.longTermCount, Colors.green),
        if (dueInfo.extralongTermCount > 0)
          _buildCountText(dueInfo.extralongTermCount, Color(0xFFFFD700)),
        if (dueInfo.ultralongTermCount > 0)
          _buildCountText(dueInfo.ultralongTermCount, Colors.purple),
        if (dueInfo.infinitelylongTermCount > 0)
          _buildCountText(dueInfo.infinitelylongTermCount, Color(0xFFE5E4E2)), // Kim loại bạch kim
      ],
    );
  }

  Widget _buildCountText(int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Text(
        count.toString(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showDeckSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select a Deck'),
          content: StreamBuilder<List<Deck>>(
            stream: _deckService.getDecks(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('No decks available');
              }
              return SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    Deck deck = snapshot.data![index];
                    return ListTile(
                      title: Text(deck.name),
                      onTap: () {
                        Navigator.of(context).pop();
                        _navigateToVideoStudyScreen(deck);
                      },
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
  void _navigateToVideoStudyScreen(Deck deck) {
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoStudyScreen(
          deckId: deck.id,
          deckName: deck.name,
          isSpeedDeck: deck.isSpeedDeck,
        ),
      ),
    ).then((_) {
      // Khi user quay lại, clear cache để buộc getDueCardsInfoForDecks() fetch dữ liệu mới
      _videoCardService.clearCache();

      // Trigger rebuild để cập nhật UI

        setState(() {});

    });
  }
  void _showEditDeckDialog(BuildContext context, Deck deck) {
    final TextEditingController controller = TextEditingController(text: deck.name);
    bool isSpeedDeck = deck.isSpeedDeck;  // Giá trị ban đầu

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(  // Sử dụng StatefulBuilder để có thể cập nhật state của checkbox
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Deck'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Deck Name',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: isSpeedDeck,
                    onChanged: (bool? value) {
                      setState(() {
                        isSpeedDeck = value ?? false;
                      });
                    },
                  ),
                  const Text('Speed Deck'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  try {
                    await _deckService.updateDeck(
                      deck.id,
                      controller.text,
                      isSpeedDeck: isSpeedDeck,  // Thêm tham số isSpeedDeck
                    );
                    Navigator.pop(context);
                    _showSuccessSnackBar('Deck updated successfully');
                  } catch (e) {
                    _showErrorSnackBar('Failed to update deck: $e');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
  void _addNewDeck() async {
    if (_newDeckController.text.isEmpty) return;

    // Check if enough time has passed since last deck creation
    if (_lastDeckCreationTime != null) {
      final timeDifference = DateTime.now().difference(_lastDeckCreationTime!);
      if (timeDifference.inSeconds < 20) {
        _showErrorSnackBar('Each deck must be added at least 20 seconds apart');
        return;
      }
    }

    try {
      await _deckService.createDeck(_newDeckController.text);
      _lastDeckCreationTime = DateTime.now(); // Update last creation time
      _newDeckController.clear();
      _showSuccessSnackBar('Deck created successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to create deck: $e');
    }
  }

  void _showDeleteDeckDialog(BuildContext context, Deck deck) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Deck'),
        content: Text('All cards in this deck will be deleted, Are you sure you want to delete "${deck.name}"?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Delete'),
            onPressed: () async {
              try {
                await _deckService.deleteDeckTemp(deck.id);
                Navigator.pop(context);
                _showSuccessSnackBar('Deck deleted successfully');
              } catch (e) {
                _showErrorSnackBar('Failed to delete deck: $e');
              }
            },
          ),
        ],
      ),
    );
  }
  void _showDeckCards(BuildContext context, Deck deck) {
    final ScrollController scrollController = ScrollController();
    List<VideoCard>? currentCards;

    // Thêm hàm sắp xếp
    void sortCards(List<VideoCard> cards, String field, bool ascending) {
      cards.sort((a, b) {
        dynamic valueA;
        dynamic valueB;

        switch (field) {
          case 'videoId':
            valueA = a.videoId;
            valueB = b.videoId;
            break;
          case 'videoTitle':
            valueA = a.videoTitle;
            valueB = b.videoTitle;
            break;
          case 'answer':
            valueA = a.answer;
            valueB = b.answer;
            break;
          case 'createdAt':
            valueA = a.createdAt;
            valueB = b.createdAt;
            break;
          case 'reviewDates':
            valueA = a.reviewDates.isEmpty ? DateTime(1900) : a.reviewDates.last;
            valueB = b.reviewDates.isEmpty ? DateTime(1900) : b.reviewDates.last;
            break;
          case 'interval':
            valueA = a.interval;
            valueB = b.interval;
            break;
          case 'dueDate':
            valueA = a.dueDate;
            valueB = b.dueDate;
            break;
          case 'videoSpeed':
            valueA = a.videoSpeed;
            valueB = b.videoSpeed;
            break;
          case 'maxVideoSpeed':
            valueA = a.maxVideoSpeed;
            valueB = b.maxVideoSpeed;
            break;
          default:
            valueA = a.videoTitle;
            valueB = b.videoTitle;
        }

        int comparison = ascending ? 1 : -1;
        if (valueA == null) return -1 * comparison;
        if (valueB == null) return 1 * comparison;

        if (valueA is String && valueB is String) {
          return ascending ?
            valueA.toLowerCase().compareTo(valueB.toLowerCase()) :
            valueB.toLowerCase().compareTo(valueA.toLowerCase());
        }

        return ascending ?
          valueA.compareTo(valueB) :
          valueB.compareTo(valueA);
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, sheetController) {
                return Column(
                  children: [
                    AppBar(
                      title: Text('Cards in ${deck.name}'),
                      automaticallyImplyLeading: false,
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String>(
                              value: _sortField,
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setModalState(() {
                                    _sortField = newValue;
                                    if (currentCards != null) {
                                      sortCards(currentCards!, _sortField, _sortAscending);
                                    }
                                  });
                                }
                              },
                              items: <String>[
                                'videoId', 'videoTitle', 'answer', 'createdAt',
                                'reviewDates', 'interval', 'dueDate', 'videoSpeed', 'maxVideoSpeed'
                              ].map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<bool>(
                            value: _sortAscending,
                            onChanged: (bool? newValue) {
                              if (newValue != null) {
                                setModalState(() {
                                  _sortAscending = newValue;
                                  if (currentCards != null) {
                                    sortCards(currentCards!, _sortField, _sortAscending);
                                  }
                                });
                              }
                            },
                            items: <bool>[true, false].map<DropdownMenuItem<bool>>((bool value) {
                              return DropdownMenuItem<bool>(
                                value: value,
                                child: Text(value ? 'Ascending' : 'Descending'),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<String>(
                        stream: _cardUpdateController.stream,
                        builder: (context, _) {
                          return StreamBuilder<List<VideoCard>>(
                            stream: _videoCardService.getVideoCardsInDeck(deck.id),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting && currentCards == null) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              if (snapshot.hasError) {
                                return Center(child: Text('Error: ${snapshot.error}'));
                              }

                              // Cập nhật currentCards khi có dữ liệu mới từ stream
                              currentCards = snapshot.data ?? currentCards ?? [];

                              if (currentCards!.isEmpty) {
                                return const Center(child: Text('No cards in this deck'));
                              }

                              if (currentCards!.isNotEmpty) {
                                sortCards(currentCards!, _sortField, _sortAscending);
                              }

                              return ListView.builder(
                                controller: scrollController,
                                itemCount: currentCards!.length,
                                itemBuilder: (context, index) => _buildCardItem(
                                  currentCards![index],
                                  onEdit: () async {
                                    final edited = await _showEditDialog(context, currentCards![index]);
                                    if (edited == true) {
                                      // Thông báo ID của card đã được cập nhật
                                      _cardUpdateController.add(currentCards![index].id!);
                                    }
                                  },
                                  onDelete: () async {
                                    try {
                                      await _videoCardService.deleteVideoCardTemp(currentCards![index].id!);

                                        setModalState(() {});
                                        setState(() {});

                                      _showNotification('Card temporarily deleted successfully');
                                    } catch (e) {
                                      _showNotification('Error deleting card: ${e.toString()}');
                                    }
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    ).then((_) {
      scrollController.dispose();
    });
  }

  Widget _buildCardItem(VideoCard card, {VoidCallback? onEdit, VoidCallback? onDelete}) {
    String secondFieldValue = 'Speed: ${card.videoSpeed.toStringAsFixed(2)}x';

    switch (_sortField) {
      case 'videoTitle':
      case 'answer':
        secondFieldValue = 'videoSpeed: ${card.videoSpeed.toStringAsFixed(2)}x';
        break;
      case 'videoId':
        secondFieldValue = card.videoId;
        break;
      case 'createdAt':
        secondFieldValue = 'createdAt: ${DateFormat('yyyy-MM-dd HH:mm').format(card.createdAt)}';
        break;
      case 'reviewDates':
        secondFieldValue = 'reviewDates: ${card.reviewDates.isNotEmpty
            ? DateFormat('yyyy-MM-dd HH:mm').format(card.reviewDates.last)
            : 'No reviews'}';
        break;
      case 'interval':
        secondFieldValue = 'interval: ${card.interval} days';
        break;
      case 'dueDate':
        secondFieldValue = 'dueDate: ${DateFormat('yyyy-MM-dd HH:mm').format(card.dueDate)}';
        break;
      case 'videoSpeed':
        secondFieldValue = 'videoSpeed: ${card.videoSpeed.toStringAsFixed(2)}x';
        break;
      case 'maxVideoSpeed':
        secondFieldValue = 'maxVideoSpeed: ${card.maxVideoSpeed.toStringAsFixed(2)}x';
        break;
      default:
        secondFieldValue = 'Speed: ${card.videoSpeed.toStringAsFixed(2)}x';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(
          'Video Title: ${card.videoTitle}',
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$secondFieldValue',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Tạo mới QuillAnswerView mỗi khi card thay đổi
            QuillAnswerView(
              key: ValueKey(card.id! + card.answer), // Thêm key để force rebuild
              answer: card.answer,
              maxHeight: 50,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onEdit ?? () => _showEditDialog(context, card),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: onDelete ?? () async {
                try {
                  await _videoCardService.deleteVideoCardTemp(card.id!);
                  if (mounted) {
                    setState(() {});
                  }
                  _showNotification('Card temporarily deleted successfully');
                } catch (e) {
                  _showNotification('Error deleting card: ${e.toString()}');
                }
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Video ID: ${card.videoId}'),
                Text('Created At: ${DateFormat('yyyy-MM-dd HH:mm').format(card.createdAt)}'),
                Text('Last Review: ${card.reviewDates.isNotEmpty ? DateFormat('yyyy-MM-dd HH:mm').format(card.reviewDates.last) : 'Not reviewed'}'),
                Text('Interval: ${card.interval} days'),
                Text('Due Date: ${DateFormat('yyyy-MM-dd HH:mm').format(card.dueDate)}'),
                Text('Video Speed: ${card.videoSpeed.toStringAsFixed(2)}x'),
                Text('Max Video Speed: ${card.maxVideoSpeed.toStringAsFixed(2)}x'),
                const Text('Answer:'),
                // Tạo mới QuillAnswerView cho phần mở rộng
                QuillAnswerView(
                  key: ValueKey('expanded-${card.id!}-${card.answer}'), // Thêm key riêng cho phần mở rộng
                  answer: card.answer,
                ),
                if (card.deckName != null)
                  Text('Deck: ${card.deckName}'),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Future<bool?> _showEditDialog(BuildContext context, VideoCard card) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return EditCardDialog(
          card: card,
          onSave: (editedCard) async {
            try {
              await _videoCardService.updateVideoCard(editedCard);
              if (mounted) {
                setState(() {});
              }
              _showNotification('Card updated successfully.');
              // Sử dụng card ID làm key cho StreamController
              if (editedCard.id != null) {
                _cardUpdateController.add(editedCard.id!);
              }
            } catch (e) {
              _showNotification('Error updating card: ${e.toString()}');
            }
          },
        );
      },
    );

    // Trả về true nếu dialog trả về true, ngược lại trả về false

    return result;

  }

  void _showNotification(String message) {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).padding.bottom + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.black54),
                  onPressed: _removeOverlay,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    // Auto-dismiss after 4 seconds
    Future.delayed(Duration(seconds: 4), _removeOverlay);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        action: SnackBarAction(
          label: 'Close',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildDeletedCardsList() {
    if (_currentTabIndex != 2) {
      return Container();
    }

    return Column(
      children: [
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  tabs: const [
                    Tab(text: 'Deleted Cards'),
                    Tab(text: 'Deleted Decks'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildDeletedCardsTab(),
                      _buildDeletedDecksTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _checkAndCleanupDeletedItems() async {
    // Lấy danh sách các thẻ đã xóa và xóa vĩnh viễn nếu quá hạn
    final deletedCards = await _videoCardService.getDeletedCards().first;
    if (deletedCards.isNotEmpty) {
      await _checkAndPermanentlyDeleteCards(deletedCards);
    }
    
    // Lấy danh sách các bộ thẻ đã xóa và xóa vĩnh viễn nếu quá hạn
    final deletedDecks = await _deckService.getDeletedDecks().first;
    if (deletedDecks.isNotEmpty) {
      await _checkAndPermanentlyDeleteDecks(deletedDecks);
    }
  }

  Widget _buildDeletedCardsTab() {
    List<VideoCard>? currentCards;

    return StatefulBuilder(
      builder: (context, setState) {
        return StreamBuilder<List<VideoCard>>(
          stream: _videoCardService.getDeletedCards(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && currentCards == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            currentCards = snapshot.data ?? currentCards ?? [];
            
            // Đã xử lý trong initState nên không cần gọi lại ở đây
            // _checkAndPermanentlyDeleteCards(currentCards!);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Total deleted cards: ${currentCards!.length}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Cards will be automatically deleted permanently after 30 days',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: currentCards!.isEmpty
                      ? const Center(child: Text('No deleted cards'))
                      : ListView.builder(
                          itemCount: currentCards!.length,
                          itemBuilder: (context, index) => _buildDeletedCardItem(
                            currentCards![index],
                            onRestore: () {
                              _restoreCard(currentCards![index]).then((_) {
                                setState(() {}); // Trigger rebuild khi khôi phục xong
                              });
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        );
      }
    );
  }

  Widget _buildDeletedDecksTab() {
    List<Deck>? currentDecks;

    return StatefulBuilder(
      builder: (context, setState) {
        return StreamBuilder<List<Deck>>(
          stream: _deckService.getDeletedDecks(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && currentDecks == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            currentDecks = snapshot.data ?? currentDecks ?? [];
            
            // Đã xử lý trong initState nên không cần gọi lại ở đây
            // _checkAndPermanentlyDeleteDecks(currentDecks!);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Total deleted decks: ${currentDecks!.length}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Decks and their cards will be automatically deleted permanently after 30 days',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: currentDecks!.isEmpty
                      ? const Center(child: Text('No deleted decks'))
                      : ListView.builder(
                          itemCount: currentDecks!.length,
                          itemBuilder: (context, index) {
                            final deck = currentDecks![index];
                            return ListTile(
                              title: Text(deck.name),
                              subtitle: Text('Deleted at: ${DateFormat('yyyy-MM-dd HH:mm').format(deck.deletedAt!)}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.restore, color: Colors.green),
                                onPressed: () => _restoreDeck(deck),
                                tooltip: 'Restore deck',
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      }
    );
  }

  Widget _buildDeletedCardItem(VideoCard card, {VoidCallback? onRestore, VoidCallback? onDelete}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(
          'Video Title: ${card.videoTitle}',
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deleted at: ${DateFormat('yyyy-MM-dd HH:mm').format(card.deletedAt!)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            QuillAnswerView(
              key: ValueKey(card.id! + card.answer),
              answer: card.answer,
              maxHeight: 50,
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.restore, color: Colors.green),
          onPressed: onRestore,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Restore card',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Video ID: ${card.videoId}'),
                Text('Created At: ${DateFormat('yyyy-MM-dd HH:mm').format(card.createdAt)}'),
                Text('Last Review: ${card.reviewDates.isNotEmpty ? DateFormat('yyyy-MM-dd HH:mm').format(card.reviewDates.last) : 'Not reviewed'}'),
                Text('Interval: ${card.interval} days'),
                Text('Due Date: ${DateFormat('yyyy-MM-dd HH:mm').format(card.dueDate)}'),
                Text('Video Speed: ${card.videoSpeed.toStringAsFixed(2)}x'),
                Text('Max Video Speed: ${card.maxVideoSpeed.toStringAsFixed(2)}x'),
                const Text('Answer:'),
                QuillAnswerView(
                  key: ValueKey('expanded-deleted-${card.id!}-${card.answer}'),
                  answer: card.answer,
                ),
                if (card.deckName != null)
                  Text('Deck: ${card.deckName}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreCard(VideoCard card) async {
    try {
      await _videoCardService.restoreCard(card.id!);
      
      // Clear cache sau khi restore để refresh dữ liệu
      _videoCardService.clearCache();


      if (mounted) {
        _showSuccessSnackBar('Card restored successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to restore card: $e');
      }
    }
  }

  Future<void> _restoreDeck(Deck deck) async {
    try {
      await _deckService.restoreDeck(deck.id);

      if (mounted) {
        _showSuccessSnackBar('Deck restored successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to restore deck: $e');
      }
    }
  }

  Future<void> _checkAndPermanentlyDeleteCards(List<VideoCard> cards) async {
    final now = DateTime.now();
    final cardsToDelete = <VideoCard>[];

    // Tìm các thẻ đã xóa tạm thời quá 30 ngày
    for (var card in cards) {
      if (card.deletedAt != null) {
        final timeDifference = now.difference(card.deletedAt!);
        if (timeDifference.inDays >= 30) {
          cardsToDelete.add(card);
        }
      }
    }

    // Xóa vĩnh viễn các thẻ đã tìm thấy
    for (var card in cardsToDelete) {
      try {
        await _videoCardService.deleteVideoCard(card.id!);
        print('Permanently deleted card: ${card.id}');
      } catch (e) {
        print('Error permanently deleting card ${card.id}: $e');
      }
    }

    // Hiển thị thông báo nếu có thẻ bị xóa vĩnh viễn

  }

  Future<void> _checkAndPermanentlyDeleteDecks(List<Deck> decks) async {
    final now = DateTime.now();
    final decksToDelete = <Deck>[];

    // Tìm các deck đã xóa tạm thời quá 30 ngày
    for (var deck in decks) {
      if (deck.deletedAt != null) {
        final timeDifference = now.difference(deck.deletedAt!);
        if (timeDifference.inDays >= 30) {
          decksToDelete.add(deck);
        }
      }
    }

    // Xóa vĩnh viễn các deck đã tìm thấy
    for (var deck in decksToDelete) {
      try {
        await _deckService.deleteDeck(deck.id);
        print('Permanently deleted deck: ${deck.id}');
      } catch (e) {
        print('Error permanently deleting deck ${deck.id}: $e');
      }
    }

    // Hiển thị thông báo nếu có deck bị xóa vĩnh viễn

  }
}
class QuillAnswerView extends StatefulWidget {
  final String answer;

  final double? maxHeight;

  const QuillAnswerView({
    Key? key,
    required this.answer,

    this.maxHeight,
  }) : super(key: key);

  @override
  _QuillAnswerViewState createState() => _QuillAnswerViewState();
}

class _QuillAnswerViewState extends State<QuillAnswerView> {
  late QuillController controller;

  @override
  void initState() {
    super.initState();
    try {
      // Parse JSON string to Document
      final doc = Document.fromJson(jsonDecode(widget.answer));

      // Initialize QuillController and set readOnly in init
      controller = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      )..readOnly = true;

    } catch (e) {
      // Handle errors if JSON parsing or controller setup fails
      print('Error initializing QuillController: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: widget.maxHeight != null
          ? BoxConstraints(maxHeight: widget.maxHeight!)
          : null,
      child: QuillEditor.basic(
        controller: controller,


      ),
    );
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is removed from the widget tree
    controller.dispose();
    super.dispose();
  }
}

