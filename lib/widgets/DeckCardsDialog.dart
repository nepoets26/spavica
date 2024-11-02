import 'package:flutter/material.dart';
import '../services/deck_service.dart';
import '../services/video_card_service.dart';
import '/widgets/edit_card_dialog.dart';

class DeckCardsDialog extends StatelessWidget {
  final Deck deck;
  final DeckService deckService;
  final VideoCardService videoCardService;

  const DeckCardsDialog({
    Key? key,
    required this.deck,
    required this.deckService,
    required this.videoCardService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cards in ${deck.name}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: FutureBuilder<List<VideoCard>>(
                future: deckService.getCardsForDeck(deck.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No cards in this deck'),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final card = snapshot.data![index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(card.answer),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Video ID: ${card.videoId}'),
                              Text(
                                'Next review: ${_formatDate(card.dueDate)}',
                                style: TextStyle(
                                  color: _getDueDateColor(card.dueDate),
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showEditCardDialog(context, card),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _showDeleteCardDialog(context, card),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getDueDateColor(DateTime dueDate) {
    final now = DateTime.now();
    if (dueDate.isBefore(now)) {
      return Colors.red;
    } else if (dueDate.difference(now).inDays <= 3) {
      return Colors.orange;
    }
    return Colors.green;
  }

  void _showEditCardDialog(BuildContext context, VideoCard card) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EditCardDialog(
          card: card,
          onSave: (updatedCard) async {
            try {
              await videoCardService.updateVideoCard(updatedCard);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Card updated successfully')),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update card: $e')),
              );
            }
          },
        );
      },
    );
  }

  void _showDeleteCardDialog(BuildContext context, VideoCard card) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Card'),
          content: Text('Are you sure you want to delete this card?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () async {
                try {
                  await videoCardService.deleteVideoCard(card.id!);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Card deleted successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete card: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}