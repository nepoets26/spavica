import 'package:flutter/material.dart';
import '../services/video_card_service.dart';
import '/widgets/edit_card_dialog.dart';
import '../services/deck_service.dart';
import 'package:intl/intl.dart';
import 'video_study_screen.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'dart:convert';

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

  @override
  void dispose() {
    _searchController.dispose();
    _newDeckController.dispose();
    _removeOverlay();
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
  void _showDeleteConfirmation(BuildContext context, VideoCard card) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Card'),
          content: Text('Are you sure you want to delete "${card.videoTitle}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Đóng dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Đóng dialog
                Navigator.of(context).pop();

                try {
                  // Thực hiện xóa
                  await _videoCardService.deleteVideoCard(card.id!);

                  // Hiển thị thông báo thành công
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Card deleted successfully.'),
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
                } catch (e) {
                  // Hiển thị thông báo lỗi nếu có
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting card: ${e.toString()}'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
              child: const Text('remove', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
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
          const TabBar(
            tabs: [
              Tab(text: 'Deck\'s Cards'),
              Tab(text: 'Today\'s New Cards'),
              Tab(text: 'Today\'s Reviewed Cards'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDeckList(),
                _buildTodayCardList(),
                _buildTodayReviewedCardList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildTodayReviewedCardList() {
    return StreamBuilder<List<VideoCard>>(
      stream: _videoCardService.getTodayReviewedCards(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final cards = snapshot.data ?? [];

        return Column(
          children: [
            // Header with card count
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Total cards: ${cards.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Card list
            Expanded(
              child: cards.isEmpty
                  ? const Center(child: Text('No cards reviewed today'))
                  : ListView.builder(
                itemCount: cards.length,
                itemBuilder: (context, index) => _buildCardItem(cards[index]),
              ),
            ),
          ],
        );
      },
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
  Widget _buildTodayCardList() {
    return StreamBuilder<List<VideoCard>>(
      stream: _videoCardService.getTodayVideoCards(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final cards = snapshot.data ?? [];

        return Column(
          children: [
            // Header với số lượng card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Total cards: ${cards.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Danh sách card
            Expanded(
              child: cards.isEmpty
                  ? const Center(child: Text('No cards added today'))
                  : ListView.builder(
                itemCount: cards.length,
                itemBuilder: (context, index) => _buildCardItem(cards[index]),
              ),
            ),
          ],
        );
      },
    );
  }
  Widget _buildDeckList() {
    return StreamBuilder<List<Deck>>(
      stream: _deckService.getDecks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final decks = snapshot.data ?? [];

        return StreamBuilder<Map<String, DueCardInfo>>(
          stream: _videoCardService.getDueCardsInfoForDecks(),
          builder: (context, dueCardsSnapshot) {
            if (dueCardsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
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
  void _navigateToVideoStudyScreen(Deck deck) async {
    // Tính toán overdue trước khi navigate
    final videoCardService = VideoCardService();
    await videoCardService.updateOverdueForDeck(deck.id);

    // Navigate đến VideoStudyScreen
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
    );
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
                await _deckService.deleteDeck(deck.id);
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
  void _showDeckCards(BuildContext context, Deck deck)async  {
    final videoCardService = VideoCardService();
    await videoCardService.updateOverdueForDeck(deck.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, controller) {
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
                                  setState(() {
                                    _sortField = newValue;
                                  });
                                }
                              },
                              items: <String>[
                                'videoId', 'videoTitle', 'answer', 'createdAt',
                                'reviewDates', 'interval', 'dueDate','overdue','videoSpeed', 'maxVideoSpeed'
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
                                setState(() {
                                  _sortAscending = newValue;
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
                      child: StreamBuilder<List<VideoCard>>(
                        stream: _videoCardService.getVideoCardsInDeck(deck.id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          }

                          var cards = snapshot.data ?? [];
                          if (cards.isEmpty) {
                            return const Center(child: Text('No cards in this deck'));
                          }

                          // Sort the cards based on the selected field and order
                          cards.sort((a, b) {
                            if (_sortField == 'reviewDates') {
                              // Xử lý đặc biệt cho reviewDates
                              DateTime? lastReviewA = a.reviewDates.isNotEmpty ? a.reviewDates.last : null;
                              DateTime? lastReviewB = b.reviewDates.isNotEmpty ? b.reviewDates.last : null;

                              // Nếu cả hai đều null
                              if (lastReviewA == null && lastReviewB == null) return 0;
                              // Nếu A null, B không null
                              if (lastReviewA == null) return _sortAscending ? 1 : -1;
                              // Nếu B null, A không null
                              if (lastReviewB == null) return _sortAscending ? -1 : 1;
                              // Cả hai đều có giá trị
                              return _sortAscending
                                  ? lastReviewA.compareTo(lastReviewB)
                                  : lastReviewB.compareTo(lastReviewA);
                            } else {
                              // Các trường khác giữ nguyên logic cũ
                              var aValue = a.toJson()[_sortField];
                              var bValue = b.toJson()[_sortField];

                              if (aValue == null && bValue == null) return 0;
                              if (aValue == null) return _sortAscending ? 1 : -1;
                              if (bValue == null) return _sortAscending ? -1 : 1;

                              if (aValue is String && bValue is String) {
                                return _sortAscending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
                              } else if (aValue is num && bValue is num) {
                                return _sortAscending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
                              } else if (aValue is DateTime && bValue is DateTime) {
                                return _sortAscending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
                              } else {
                                return 0;
                              }
                            }
                          });

                          return ListView.builder(
                            controller: controller,
                            itemCount: cards.length,
                            itemBuilder: (context, index) => _buildCardItem(cards[index]),
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
    );
  }

  Widget _buildCardItem(VideoCard card) {
    // Khởi tạo các biến secondField và secondFieldValue

    String secondFieldValue = 'Speed: ${card.videoSpeed.toStringAsFixed(2)}x';

    // Gán giá trị dựa trên _sortField (nếu bạn cần dựa vào sort)
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
      case 'overdue':
        secondFieldValue = 'overdue: ${card.overdue} days';
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
            // Limit height for preview
            QuillAnswerView(
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
              onPressed: () => _showEditDialog(context, card),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _showDeleteConfirmation(context, card),
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
                // Full height for expanded view
                QuillAnswerView(
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
  Widget _buildCardList(Stream<List<VideoCard>> cardStream, String emptyMessage) {
    return StreamBuilder<List<VideoCard>>(
      stream: cardStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final cards = snapshot.data ?? [];
        if (cards.isEmpty) {
          return Center(child: Text(emptyMessage));
        }

        return ListView.builder(
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('Video Title: ${card.videoTitle}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Speed: ${card.videoSpeed}'),
                    Text('Answer: ${card.answer}'),
                    if (card.deckName != null) Text('Deck: ${card.deckName}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditDialog(context, card),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _showDeleteConfirmation(context, card),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, VideoCard card) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EditCardDialog(
          card: card,
          onSave: (editedCard) async {
            try {
              await _videoCardService.updateVideoCard(editedCard);
              if (!context.mounted) return;
              Navigator.of(context).pop(true);
            } catch (e) {
              if (!context.mounted) return;
              Navigator.of(context).pop(false);
              _showNotification('Error updating card: ${e.toString()}');
            }
          },
        );
      },
    ).then((success) {
      if (success == true) {
        _showNotification('Card updated successfully.');
      }
    });
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

