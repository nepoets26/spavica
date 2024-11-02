import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/video_card_service.dart';
import '../services/deck_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_quill/flutter_quill.dart';


class EditCardDialog extends StatefulWidget {
  final VideoCard card;
  final Function(VideoCard) onSave;

  const EditCardDialog({Key? key, required this.card, required this.onSave}) : super(key: key);

  @override
  _EditCardDialogState createState() => _EditCardDialogState();
}

class _EditCardDialogState extends State<EditCardDialog> {
  late VideoCard _editedCard;
  String? _selectedDeckId;
  final DeckService _deckService = DeckService();
  late TextEditingController _answerController;
  late TextEditingController _videoTitleController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _videoSpeedController;
  final ScrollController _scrollController = ScrollController();
  double _selectedMaxVideoSpeed = 2.0;
  double _selectedVideoSpeed = 1.0;
  final List<double> _maxVideoSpeedOptions = [1.25, 1.50, 1.75, 2.0];
  final List<double> _videoSpeedOptions = [0.25, 0.3, 0.35, 0.4, 0.45, 0.5, 0.55, 0.6, 0.65, 0.7, 0.75, 0.8, 0.85, 0.9, 0.95, 1.0, 1.05, 1.1, 1.15, 1.2, 1.25, 1.3, 1.35, 1.4, 1.45, 1.5, 1.55, 1.6, 1.65, 1.7, 1.75, 1.8, 1.85, 1.9, 1.95, 2.0];
  QuillController _quillController = QuillController.basic();


  @override
  void initState() {
    super.initState();
    _editedCard = widget.card;
    _selectedDeckId = widget.card.deckId;
    _answerController = TextEditingController(text: _editedCard.answer);
    _videoTitleController = TextEditingController(text: _editedCard.videoTitle);
    _startTimeController = TextEditingController(text: _editedCard.startTime.toString());
    _endTimeController = TextEditingController(text: _editedCard.endTime.toString());
    _selectedVideoSpeed = _editedCard.videoSpeed;
    _selectedMaxVideoSpeed = _editedCard.maxVideoSpeed;
    var doc = Document();
    if (_editedCard.answer.isNotEmpty) {
      try {
        doc = Document.fromJson(jsonDecode(_editedCard.answer));
      } catch (e) {
        // If the answer is plain text, create a new document with the text
        doc = Document()..insert(0, _editedCard.answer);
      }
    }
    _quillController = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }


  @override
  void dispose() {
    _scrollController.dispose();
    _answerController.dispose();
    _videoTitleController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }
  Widget _buildQuillEditor() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          QuillToolbar(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.format_bold),
                  onPressed: () {
                    _quillController.formatSelection(Attribute.bold);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.format_italic),
                  onPressed: () {
                    _quillController.formatSelection(Attribute.italic);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.format_underline),
                  onPressed: () {
                    _quillController.formatSelection(Attribute.underline);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.format_color_fill),
                  onPressed: () async {
                    final List<Color> colors = [
                      Colors.black,
                      Colors.white,
                      Colors.grey,
                      Colors.brown,
                      Colors.red,
                      Colors.redAccent,
                      Colors.pink,
                      Colors.pinkAccent,
                      Colors.purple,
                      Colors.purpleAccent,
                      Colors.deepPurple,
                      Colors.deepPurpleAccent,
                      Colors.indigo,
                      Colors.indigoAccent,
                      Colors.blue,
                      Colors.blueAccent,
                      Colors.lightBlue,
                      Colors.lightBlueAccent,
                      Colors.cyan,
                      Colors.cyanAccent,
                      Colors.teal,
                      Colors.tealAccent,
                      Colors.green,
                      Colors.greenAccent,
                      Colors.lightGreen,
                      Colors.lightGreenAccent,
                      Colors.lime,
                      Colors.limeAccent,
                      Colors.yellow,
                      Colors.yellowAccent,
                      Colors.amber,
                      Colors.amberAccent,
                      Colors.orange,
                      Colors.orangeAccent,
                      Colors.deepOrange,
                      Colors.deepOrangeAccent,
                    ];

                    Color? selectedColor = await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Chọn màu'),
                          content: Container(
                            width: 350,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: colors.map((color) {
                                return InkWell(
                                  onTap: () {
                                    Navigator.of(context).pop(color);
                                  },
                                  child: Container(
                                    width: 45,
                                    height: 45,
                                    decoration: BoxDecoration(
                                      color: color,
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          actions: <Widget>[
                            TextButton(
                              child: const Text('Hủy'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        );
                      },
                    );

                    if (selectedColor != null) {
                      String hexColor = '#${selectedColor.value.toRadixString(16).substring(2)}';
                      _quillController.formatSelection(Attribute.fromKeyValue('color', hexColor));
                    }
                  },
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: QuillEditor.basic(
              controller: _quillController,

            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Card'),
      content: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 400,
        ),
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.only(right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Video ID',
                    labelStyle: TextStyle(color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.open_in_new),
                      onPressed: () async {
                        final startTime = double.tryParse(_startTimeController.text) ?? _editedCard.startTime;
                        final url = 'https://youtu.be/${_editedCard.videoId}?t=${startTime.round()}';
                        try {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        } catch (e) {
                          print('Error launching URL: $e');
                        }
                      },
                      tooltip: 'Open in YouTube',
                    ),
                  ),
                  controller: TextEditingController(text: _editedCard.videoId),
                  readOnly: true,  // Giữ readOnly nhưng bỏ enabled: false
                  style: TextStyle(color: Colors.grey[600]),
                ),

                TextField(
                  decoration: InputDecoration(labelText: 'Video Title'),
                  controller: _videoTitleController,
                ),
                TextField(
                  decoration: InputDecoration(labelText: 'Start Time'),
                  controller: _startTimeController,
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  decoration: InputDecoration(labelText: 'End Time'),
                  controller: _endTimeController,
                  keyboardType: TextInputType.number,
                ),
                Column(
                  children: [
                    // Thay TextField bằng _buildQuillEditor()
                    _buildQuillEditor(),
                  ],
                ),
                DropdownButtonFormField<double>(
                  value: _selectedVideoSpeed,
                  decoration: InputDecoration(labelText: 'Video Speed'),
                  items: _videoSpeedOptions.map((speed) {
                    return DropdownMenuItem<double>(
                      value: speed,
                      child: Text(speed.toStringAsFixed(2)),
                    );
                  }).toList(),
                  onChanged: (double? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedVideoSpeed = newValue;
                      });
                    }
                  },
                ),
                DropdownButtonFormField<double>(
                  value: _selectedMaxVideoSpeed,
                  decoration: InputDecoration(labelText: 'Max Video Speed (only for Speed Deck)'),
                  items: _maxVideoSpeedOptions.map((speed) {
                    return DropdownMenuItem<double>(
                      value: speed,
                      child: Text(speed.toString()),
                    );
                  }).toList(),
                  onChanged: (double? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedMaxVideoSpeed = newValue;
                      });
                    }
                  },
                ),
                StreamBuilder<List<Deck>>(
                  stream: _deckService.getDecks(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    }
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }
                    final decks = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      value: _selectedDeckId,
                      decoration: InputDecoration(labelText: 'Deck'),
                      items: decks.map((deck) {
                        return DropdownMenuItem<String>(
                          value: deck.id,
                          child: Text(deck.name),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedDeckId = newValue;
                        });
                      },
                    );
                  },
                ),
                SizedBox(height: 16),
                _buildReadOnlySection(),
                _buildReviewHistorySection(_editedCard),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: Text('Save'),
          onPressed: () {
            if (_selectedVideoSpeed > _selectedMaxVideoSpeed) {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Invalid Video Speed'),
                    content: Text('Video Speed cannot be greater than Max Video Speed.'),
                    actions: <Widget>[
                      TextButton(
                        child: Text('OK'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              );
            } else {
              // Convert the Quill document to JSON
              final json = jsonEncode(_quillController.document.toDelta().toJson());

              final updatedCard = _editedCard.copyWith(
                videoId: _editedCard.videoId,
                videoTitle: _videoTitleController.text,
                startTime: double.tryParse(_startTimeController.text) ?? _editedCard.startTime,
                endTime: double.tryParse(_endTimeController.text) ?? _editedCard.endTime,
                answer: json, // Store the JSON string instead of plain text
                deckId: _selectedDeckId,
                videoSpeed: _selectedVideoSpeed,
                maxVideoSpeed: _selectedMaxVideoSpeed,
                createdAt: _editedCard.createdAt ?? DateTime.now(),
                dueDate: _editedCard.dueDate ?? DateTime.now(),
                reviewDates: _editedCard.reviewDates ?? [],
                ratings: _editedCard.ratings ?? [],
                interval: _editedCard.interval ?? 0,
                overdue: _editedCard.overdue ?? 0,
              );
              widget.onSave(updatedCard);
              Navigator.of(context).pop(true);
            }
          },
        ),
      ],
    );
  }

  Widget _buildReadOnlySection() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text('Card Information',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16
                )
            ),
          ),
          _buildReadOnlyField('Created At', _formatDateTime(_editedCard.createdAt)),
          _buildReadOnlyField('Interval', '${_editedCard.interval} days'),
          _buildReadOnlyField('Overdue', '${_editedCard.overdue} days'),
          _buildReadOnlyField('Due Date', _formatDateTime(_editedCard.dueDate)),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildReviewHistorySection(VideoCard card) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text('Review History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        SizedBox(height: 8),
        for (int i = 0; i < card.reviewDates.length; i++)
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
            child: Text(
              '${_formatDateTime(card.reviewDates[i])} - Rating: ${_getRatingText(card.ratings[i])}',
              style: TextStyle(fontSize: 14),
            ),
          ),
      ],
    );
  }
  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'tough';
      case 2:
        return 'hard';
      case 3:
        return 'average';
      case 4:
        return 'good';
      case 5:
        return 'easy';
      default:
        return 'unknown';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  }
}
