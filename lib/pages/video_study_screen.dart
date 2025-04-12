import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/quill_delta.dart';
import '../services/deck_service.dart';
import '../services/user_service.dart';
import '../services/video_card_service.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'dart:async';
import '/widgets/edit_card_dialog.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'dart:async';
import 'dart:convert';
// Sử dụng conditional import
//import 'dart:html' as html;
import 'dart:math';

// Tạo helper class tương tự như trong home_page.dart
// class HtmlHelper {
//   static void disableIframeInteractions() {
//     if (kIsWeb) {
//       final iframes = html.document.getElementsByTagName('iframe');
//       for (var i = 0; i < iframes.length; i++) {
//         final iframe = iframes[i];
//         if (iframe is html.HtmlElement) {
//           iframe.style.pointerEvents = 'none';
//         }
//       }
//     }
//   }
//
//   static void enableIframeInteractions() {
//     if (kIsWeb) {
//       final iframes = html.document.getElementsByTagName('iframe');
//       for (var i = 0; i < iframes.length; i++) {
//         final iframe = iframes[i];
//         if (iframe is html.HtmlElement) {
//           iframe.style.pointerEvents = 'auto';
//         }
//       }
//     }
//   }
// }

class VideoStudyScreen extends StatefulWidget {
  final String deckId;
  final String deckName;
  final bool isSpeedDeck;


  const VideoStudyScreen({Key? key, required this.deckId, required this.deckName, required this.isSpeedDeck}) : super(key: key);


  @override
  _VideoStudyScreenState createState() => _VideoStudyScreenState();
}

class _VideoStudyScreenState extends State<VideoStudyScreen> {
  final VideoCardService _videoCardService = VideoCardService();
  late YoutubePlayerController _controller;
  List<VideoCard> _cards = [];
  int _currentCardIndex = 0;
  bool _showanswer = false;
  bool _showRatingButtons = false;
  int _againCount = 0;
  bool _isLoading = true;
  bool _isRating = false;
  StreamSubscription? _cardsSubscription;
  QuillController? _quillController;
  late Stream<UserPreferences> _userPrefsStream;


  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: true,
        mute: false,
        showFullscreenButton: true,
        loop: false,
        strictRelatedVideos: true,
        enableCaption: false,
      ),
    );

    final userService = UserService();
    _userPrefsStream = userService.getUserPreferences();
    
    _loadDueCards();

  }
  void _initializeQuillController(String answer) {
    try {
      final json = jsonDecode(answer);
      _quillController = QuillController(
        document: Document.fromJson(json),
        selection: const TextSelection.collapsed(offset: 0),
      )..readOnly = true;
    } catch (e) {
      // Fallback for plain text if JSON parsing fails
      _quillController = QuillController(
        document: Document.fromDelta(
            Delta()..insert(answer)
        ),
        selection: const TextSelection.collapsed(offset: 0),
      )..readOnly = true;
    }
  }
  void _sortCards(String reviewOrder) {
    setState(() {
      if (reviewOrder == 'IntervalAscending') {
        _cards.sort((a, b) => a.interval.compareTo(b.interval));
      } else if (reviewOrder == 'OverdueDescending') {
        _cards.sort((a, b) => b.overdue.compareTo(a.overdue));
      }
      _currentCardIndex = 0;
      _againCount = 0;
      if (_cards.isNotEmpty) {
        _loadVideo(_cards[_currentCardIndex]);
      }
    });
  }
  void _editCurrentCard() {
    if (_cards.isEmpty || _currentCardIndex >= _cards.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No card available to edit')),
      );
      return;
    }
    
    //HtmlHelper.disableIframeInteractions();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EditCardDialog(
          card: _cards[_currentCardIndex],
          onSave: (updatedCard) async {
            await _videoCardService.updateVideoCard(updatedCard);


            setState(() {
              _cards[_currentCardIndex] = updatedCard;
              _initializeQuillController(updatedCard.answer);
            });

            //HtmlHelper.enableIframeInteractions();
          },
        );
      },
    ).then((_) {
      // Re-enable iframe if dialog is dismissed without saving
      //HtmlHelper.enableIframeInteractions();
    });
  }
  double _calculateEndTimeOffset(double speed) {
    // Điều chỉnh hệ số tuyến tính xuống (0.05) nhưng vẫn lớn hơn 0.04
    return 0.03 * pow(speed - 1.125, 2) + 0.06 * speed;
  }

  void _replayCurrentCard() async {
    if (_cards.isEmpty) return;

    setState(() {
      _againCount++;
    });

    final currentCard = _cards[_currentCardIndex];
    final adjustedEndTime = currentCard.endTime - _calculateEndTimeOffset(1.0);

    _controller.loadVideoById(
      videoId: currentCard.videoId,
      startSeconds: currentCard.startTime,
      endSeconds: adjustedEndTime,
    );

    _controller.setPlaybackRate(1.0);
    _controller.playVideo();
  }

  void _replayCurrentCardAtSlowSpeed() async {
    if (_cards.isEmpty) return;

    setState(() {
      _againCount++;
    });

    final currentCard = _cards[_currentCardIndex];
    final adjustedEndTime = currentCard.endTime - _calculateEndTimeOffset(0.25);

    _controller.loadVideoById(
      videoId: currentCard.videoId,
      startSeconds: currentCard.startTime,
      endSeconds: adjustedEndTime,
    );

    _controller.setPlaybackRate(0.25);
    _controller.playVideo();
  }

  void _replayCurrentCardAtCurrentSpeed() async {
    if (_cards.isEmpty) return;

    setState(() {
      _againCount++;
    });

    final currentCard = _cards[_currentCardIndex];
    final adjustedEndTime = currentCard.endTime - _calculateEndTimeOffset(currentCard.videoSpeed);

    _controller.loadVideoById(
      videoId: currentCard.videoId,
      startSeconds: currentCard.startTime,
      endSeconds: adjustedEndTime,
    );

    _controller.setPlaybackRate(currentCard.videoSpeed);
    _controller.playVideo();
  }

  bool _isValidPlaybackRate(double rate) {
    // YouTube supports these playback rates: 0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2
    final supportedRates = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2];
    return supportedRates.contains(rate);
  }

  void _showUnsupportedSpeedMessage(double speed) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playback speed $speed is not supported. Playing at normal speed.'),
        duration: Duration(seconds: 3),
      ),
    );
  }





  void _stopTimer() {
    // Xóa các biến Timer không cần thiết
  }

  void _loadDueCards() {
    print('VideoStudyScreen: _loadDueCards called');
    setState(() {
      _isLoading = true;
    });

    _cardsSubscription?.cancel();

    _cardsSubscription = _videoCardService.getDueVideoCards(widget.deckId).listen(
          (cards) {
        print('VideoStudyScreen: Received ${cards.length} due cards');
        if (!_isRating) {
          _userPrefsStream.listen((prefs) {
            setState(() {
              _cards = cards;
              _sortCards(prefs.reviewOrder);
              _isLoading = false;
              if (_cards.isNotEmpty) {
                _loadVideo(_cards[_currentCardIndex]);
              }
            });
          });
        }
      },
      onError: (error) {
        print('VideoStudyScreen: Error loading due cards: $error');
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load due cards: $error')),
          );
        }
      },
    );
  }


  void _loadVideo(VideoCard card) async {
    _initializeQuillController(card.answer);

    final adjustedEndTime = card.endTime - _calculateEndTimeOffset(card.videoSpeed);
    
    _controller.loadVideoById(
      videoId: card.videoId,
      startSeconds: card.startTime,
      endSeconds: adjustedEndTime,
    );

    _controller.setPlaybackRate(card.videoSpeed);
    _controller.playVideo();
  }
  Widget _buildAnswerDisplay() {
    if (_quillController == null) return Container();

    return QuillEditor.basic(
      controller: _quillController!,
    );
  }

  void _toggleShowanswer() {
    setState(() {
      _showanswer = !_showanswer;
      _showRatingButtons = _showanswer; // Show rating buttons when answer is shown
    });
  }
  void _rateCard(int rating, double newSpeed, int newInterval) async {
    try {
      setState(() {
        _isRating = true;
      });

      final currentCard = _cards[_currentCardIndex];
      await _videoCardService.updateVideoCardReview(
        currentCard.id!,
        rating,
        newSpeed,
        newInterval, // Add the new interval parameter
      );

      setState(() {
        _isRating = false;
        _showanswer = false;
        _showRatingButtons = false;
        _againCount = 0;
        _cards.removeAt(_currentCardIndex);

        if (_currentCardIndex >= _cards.length) {
          _currentCardIndex = 0;
        }
      });

      if (_cards.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No more cards to review. Great job!')),
          );
        }
      } else {
        _loadVideo(_cards[_currentCardIndex]);
      }

    } catch (e) {
      setState(() {
        _isRating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rate card: $e')),
        );
      }
    }
  }

  void _moveToNextCard() {
    if (_cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No more cards to review')),
      );
      return;
    }

    setState(() {
      _currentCardIndex = (_currentCardIndex + 1) % _cards.length;
      _againCount = 0;
      _showanswer = false;  // Reset show answer state
      _showRatingButtons = false;  // Reset rating buttons state
    });

    _loadVideo(_cards[_currentCardIndex]);
  }
  Widget _buildRatingButtons() {
    final currentInterval = _cards[_currentCardIndex].interval;
    final currentSpeed = _cards[_currentCardIndex].videoSpeed;
    final currentOverdue = _cards[_currentCardIndex].overdue;
    final ratingData = [
      {'label': 'Tough', 'color': Colors.red, 'rating': 1},
      {'label': 'Hard', 'color': Colors.orange, 'rating': 2},
      {'label': 'Average', 'color': Colors.blue, 'rating': 3},
      {'label': 'Good', 'color': Colors.lightGreen, 'rating': 4},
      {'label': 'Easy', 'color': Colors.green, 'rating': 5},
    ];

    int calculateNewInterval(int currentInterval, int rating) {
      if ((currentInterval + currentOverdue) <= 2) {
        return rating.clamp(1, 5);
      } else {

        switch (rating) {
          case 1:
            return 1;
          case 2:
            return (((currentInterval + currentOverdue) + 1) / 2 ).round();
          case 3:
            return (currentInterval + currentOverdue);
          case 4:
            return ((currentInterval + currentOverdue) * 2 );
          case 5:
            return ((currentInterval + currentOverdue) * 3 );
          default:
            return currentInterval;
        }
      }
    }
    double calculateNewSpeed(double currentSpeed, int rating) {
      double newSpeed;
      switch (rating) {
        case 1:
          newSpeed = (currentSpeed - 0.1).clamp(0.25, _cards[_currentCardIndex].maxVideoSpeed);
          break;
        case 2:
          newSpeed = (currentSpeed - 0.05).clamp(0.25, _cards[_currentCardIndex].maxVideoSpeed);
          break;
        case 3:
          return currentSpeed;
        case 4:
          newSpeed = (currentSpeed + 0.05).clamp(0.25, _cards[_currentCardIndex].maxVideoSpeed);
          break;
        case 5:
          newSpeed = (currentSpeed + 0.1).clamp(0.25, _cards[_currentCardIndex].maxVideoSpeed);
          break;
        default:
          return currentSpeed;
      }
      // Làm tròn đến 2 chữ số thập phân để tránh số như 0.899999999999
      return double.parse(newSpeed.toStringAsFixed(2));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row with current interval and speed
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                  'Current interval: $currentInterval ${currentInterval == 1 ? 'day' : 'days'}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)
              ),
              if (widget.isSpeedDeck) ...[
                SizedBox(width: 16),
                Text(
                    'Current speed: ${currentSpeed}x',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 10),
        // Rating buttons row
        LayoutBuilder(
          builder: (context, constraints) {
            final buttonWidth = (constraints.maxWidth - 32) / 5; // 32 is total horizontal padding
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ratingData.map((data) {
                  int newInterval = calculateNewInterval(currentInterval, data['rating'] as int);
                  double newSpeed = widget.isSpeedDeck
                      ? calculateNewSpeed(currentSpeed, data['rating'] as int)
                      : currentSpeed;
                  String speedChangeText = widget.isSpeedDeck ? '${newSpeed}x' : '';

                  return SizedBox(
                    width: buttonWidth - 4, // -4 for spacing between buttons
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () => _rateCard(data['rating'] as int, newSpeed, newInterval),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: data['color'] as Color,
                            foregroundColor: Colors.white,
                            minimumSize: Size(buttonWidth - 4, 36),
                            padding: EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              data['label'] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$newInterval ${newInterval == 1 ? 'day' : 'days'}',
                            style: TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (widget.isSpeedDeck) ...[
                          SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              speedChangeText,
                              style: TextStyle(fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Studying: ${widget.deckName}'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _cards.isEmpty
          ? Center(child: Text('No due cards at the moment. Great job!'))
          : LayoutBuilder(
        builder: (context, constraints) {
          if (kIsWeb && constraints.maxWidth > 650) {
            // Web layout
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Player section
                Expanded(
                  flex: 3,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double playerHeight = constraints.maxHeight - 20;
                      double aspectRatio = 16 / 9;
                      double playerWidth = playerHeight * aspectRatio;

                      return Container(
                        height: playerHeight,
                        width: playerWidth,
                        child: YoutubePlayer(
                          controller: _controller,
                        ),
                      );
                    },
                  ),
                ),
                // Controls and rating section
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Controls
                          _buildControlButtons(),
                          if (_showanswer) ...[
                            SizedBox(height: 16),
                            Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (_showRatingButtons) _buildRatingButtons(),
                                    const SizedBox(height: 16),
                                    _buildAnswerDisplay(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Mobile layout
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: YoutubePlayer(
                      controller: _controller,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildControlButtons(),
                        if (_showanswer) ...[
                          SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_showRatingButtons) _buildRatingButtons(),
                                  const SizedBox(height: 16),
                                  _buildAnswerDisplay(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
  Widget _buildControlButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: ElevatedButton(
            onPressed: _toggleShowanswer,
            child: Text(_showanswer ? 'Hide answer' : 'Show answer'),
          ),
        ),
        SizedBox(
          height: 36,
          child: ElevatedButton(
            onPressed: _replayCurrentCardAtCurrentSpeed,
            child: Text('Again at Video Speed (${_cards[_currentCardIndex].videoSpeed}x)'),
          ),
        ),
        SizedBox(
          height: 36,
          child: ElevatedButton(
            onPressed: _replayCurrentCard,
            child: Text('Again at 1x'),
          ),
        ),
        SizedBox(
          height: 36,
          child: ElevatedButton(
            onPressed: _replayCurrentCardAtSlowSpeed,
            child: Text('Again at 0.25x'),
          ),
        ),
        SizedBox(
          height: 36,
          child: ElevatedButton(
            onPressed: _editCurrentCard,
            child: Text('Edit Current Card'),
          ),
        ),
        SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Again count: $_againCount',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.close();
    _quillController?.dispose();
    _cardsSubscription?.cancel();
    super.dispose();
  }
}