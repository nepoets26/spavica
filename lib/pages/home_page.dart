import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../services/auth_service.dart';

import 'package:flutter/foundation.dart' as foundation;

//import 'dart:html' as html;


import '../services/video_card_service.dart';

import 'dart:async';
import '../services/deck_service.dart';
import 'Manage_Cards_Screen.dart';
import 'package:flutter_quill/flutter_quill.dart' hide text;
import '../widgets/settings_dialog.dart';
import '../services/user_service.dart';
import 'login_page.dart';

// Tạo helper class để kiểm tra và gọi các phương thức đặc biệt cho nền tảng web
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
//
//   static void setupWindowBlurListener(Function() callback) {
//     if (kIsWeb) {
//       html.window.onBlur.listen((event) {
//         html.document.activeElement?.blur();
//         if (callback != null) callback();
//       });
//     }
//   }
//
//   static void removeWindowBlurListener() {
//     if (kIsWeb) {
//       html.window.removeEventListener('blur', null);
//     }
//   }
// }

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.videoId});

  final String? videoId;


  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime? _lastCardAddedTime;
  late YoutubePlayerController _controller;
  final AuthService _authService = AuthService();
  List<VideoCard> adddCards = [];
  String? _currentVideoId; // Thêm biến để lưu trữ video ID hiện tại
  final VideoCardService _videoCardService = VideoCardService();
  late TextEditingController _videoUrlController;
  User? _currentUser;
  final UserService _userService = UserService();
  final DeckService _deckService = DeckService();

  StreamSubscription<User?>? _authStateSubscription;
  Timer? _playbackTimer;  // Thêm biến để theo dõi timer
  StreamSubscription? _controllerSubscription;  // Thêm biến để theo dõi YouTube controller subscription

  @override
  void initState() {
    super.initState();
    _currentUser = _authService.currentUser;

    _authStateSubscription = _authService.authStateChanges.listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
        // Kiểm tra và tạo default deck khi user đăng nhập

      }
    });

    // Thêm lắng nghe sự kiện blur để unfocus khi nhấp vào iframe YouTube (chỉ trên web)
    if (kIsWeb) {
      //HtmlHelper.setupWindowBlurListener(() {});
    }

    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: true,
        mute: false,
        showFullscreenButton: true,
        loop: false,

      ),
    );

    if (widget.videoId != null) {
      _controller.loadVideoById(videoId: widget.videoId!);
    }
    _controller.listen((event) {
      if (event is YoutubeVideoState) {
        _updateCurrentVideoId();
      }
    });
    _videoUrlController = TextEditingController();

    // Lưu subscription của controller
    _controllerSubscription = _controller.listen((event) {
      if (event is YoutubeVideoState && mounted) {
        _updateCurrentVideoId();
      }
    });
  }


  void _updateCurrentVideoId() async {
    try {
      final metadata = _controller.metadata;
      final videoId = metadata.videoId;
      if (videoId.isNotEmpty) {
        setState(() {
          _currentVideoId = videoId;
        });
        print('Updated current video ID: $_currentVideoId');
      } else {
        final url = await _controller.videoUrl;
        final extractedId = YoutubePlayerController.convertUrlToId(url);
        if (extractedId != null) {
          setState(() {
            _currentVideoId = extractedId;
          });
          print('Updated current video ID from URL: $_currentVideoId');
        }
      }
    } catch (e) {
      print('Error updating video ID: $e');
    }
  }
  void _loadNewVideo(String videoId) {
    setState(() {
      _currentVideoId = videoId;
    });
    _controller.loadVideoById(videoId: videoId);
    print('Loaded new video with ID: $videoId');
  }
  void _loadVideo() {
    final id = _cleanId(_videoUrlController.text);
    if (id != null) {
      _loadNewVideo(id);
    }
  }
  @override
  Widget build(BuildContext context) {
    return foundation.kIsWeb
        ? MediaQuery(
      data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.zero),
      child: YoutubePlayerScaffold(
        controller: _controller,
        builder: (context, player) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Spavica'),
              actions: [
                StreamBuilder<User?>(
                  stream: _authService.authStateChanges,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }

                    // Chỉ hiển thị các icon khi user đã đăng nhập
                    if (snapshot.hasData) {
                      return Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.manage_search),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ManageCardsScreen()),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings),
                            onPressed: () {
                              //HtmlHelper.disableIframeInteractions();
                              showDialog(
                                context: context,
                                builder: (context) => const SettingsDialog(),
                              ).then((_) {
                                //HtmlHelper.enableIframeInteractions();
                              });
                            },
                          ),
                          MenuAnchor(
                            builder: (context, controller, child) {
                              return IconButton(
                                icon: CircleAvatar(
                                  backgroundImage: NetworkImage(
                                    snapshot.data?.photoURL ?? '',
                                  ),
                                ),
                                onPressed: () {
                                  if (controller.isOpen) {
                                    controller.close();
                                  } else {
                                    controller.open();
                                  }
                                },
                              );
                            },
                            menuChildren: [
                              ListTile(
                                leading: const Icon(Icons.logout),
                                title: const Text('Sign Out'),
                                onTap: _handleSignOut,
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    // Nếu chưa đăng nhập, không hiển thị gì cả
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                if (kIsWeb && constraints.maxWidth > 650) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _videoUrlController,
                                      decoration: InputDecoration(
                                        border: const OutlineInputBorder(),
                                        hintText: 'Enter youtube video id or link',
                                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        filled: true,
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () => _videoUrlController.clear(),
                                        ),
                                      ),
                                      onSubmitted: (value) {
                                        _loadVideo();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: _loadVideo,
                                    child: const Text('Load'),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: AspectRatio(
                                aspectRatio: 16 / 9, // Giữ tỷ lệ 16:9 cho video
                                child: player,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: SingleChildScrollView(
                          child: Controls(
                            onaddCard: _addCard,
                            currentUser: _currentUser,
                          ),
                        ),
                      ),
                    ],
                  );
                }
                else {
                  // Mobile layout
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _videoUrlController,
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    hintText: 'Enter youtube video id or link',
                                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    filled: true,
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () => _videoUrlController.clear(),
                                    ),
                                  ),
                                  onSubmitted: (value) {
                                    _loadVideo();
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: _loadVideo,
                                child: const Text('Load'),
                              ),
                            ],
                          ),
                        ),
                        player,
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Controls(
                            onaddCard: _addCard,
                            currentUser: _currentUser,
                          ),
                        ),
                      ],
                    ),
                  );
                }



              },
            ),
          );
        },
      ),
        )
        : YoutubePlayerScaffold(
      controller: _controller,
      builder: (context, player) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Spavica'),
            actions: [
              StreamBuilder<User?>(
                stream: _authService.authStateChanges,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }

                  // Chỉ hiển thị các icon khi user đã đăng nhập
                  if (snapshot.hasData) {
                    return Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.manage_search),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ManageCardsScreen()),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings),
                          onPressed: () {
                            //HtmlHelper.disableIframeInteractions();
                            showDialog(
                              context: context,
                              builder: (context) => const SettingsDialog(),
                            ).then((_) {
                              //HtmlHelper.enableIframeInteractions();
                            });
                          },
                        ),
                        MenuAnchor(
                          builder: (context, controller, child) {
                            return IconButton(
                              icon: CircleAvatar(
                                backgroundImage: NetworkImage(
                                  snapshot.data?.photoURL ?? '',
                                ),
                              ),
                              onPressed: () {
                                if (controller.isOpen) {
                                  controller.close();
                                } else {
                                  controller.open();
                                }
                              },
                            );
                          },
                          menuChildren: [
                            ListTile(
                              leading: const Icon(Icons.logout),
                              title: const Text('Sign Out'),
                              onTap: _handleSignOut,
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  // Nếu chưa đăng nhập, không hiển thị gì cả
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              if (kIsWeb && constraints.maxWidth > 650) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _videoUrlController,
                                    decoration: InputDecoration(
                                      border: const OutlineInputBorder(),
                                      hintText: 'Enter youtube video id or link',
                                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      filled: true,
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () => _videoUrlController.clear(),
                                      ),
                                    ),
                                    onSubmitted: (value) {
                                      _loadVideo();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: _loadVideo,
                                  child: const Text('Load'),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 16 / 9, // Giữ tỷ lệ 16:9 cho video
                              child: player,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        child: Controls(
                          onaddCard: _addCard,
                          currentUser: _currentUser,
                        ),
                      ),
                    ),
                  ],
                );
              }
              else {
                // Mobile layout
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _videoUrlController,
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  hintText: 'Enter youtube video id or link',
                                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  filled: true,
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => _videoUrlController.clear(),
                                  ),
                                ),
                                onSubmitted: (value) {
                                  _loadVideo();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _loadVideo,
                              child: const Text('Load'),
                            ),
                          ],
                        ),
                      ),
                      player,
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Controls(
                          onaddCard: _addCard,
                          currentUser: _currentUser,
                        ),
                      ),
                    ],
                  ),
                );
              }



            },
          ),
        );
      },
    );

  }

  String? _cleanId(String source) {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return YoutubePlayerController.convertUrlToId(source);
    } else if (source.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid Source')),
      );
      return null;
    }
    return source;
  }





  void _addCard(double startTime, double endTime, String answer, String? deckId) async {
    if (!mounted) return;

    try {
      if (_currentVideoId != null && _currentVideoId!.isNotEmpty) {
        if (_authService.currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login to add video cards'),
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }

        if (!mounted) return;

        // Lấy speedAddCard từ user preferences
        final userPrefs = await _userService.getUserPreferences().first;
        final videoSpeed = userPrefs.speedAddCard;

        // Check time difference since last card addition
        if (_lastCardAddedTime != null) {
          final timeDifference = DateTime.now().difference(_lastCardAddedTime!);
          if (timeDifference.inSeconds < 20) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please wait at least 20 seconds between adding cards'),
                duration: Duration(seconds: 3),
              ),
            );
            return;
          }
        }

        final videoTitle = await _getVideoTitle() ?? 'Unknown Title';

        await _videoCardService.addVideoCard(
          videoId: _currentVideoId!,
          videoTitle: videoTitle,
          startTime: startTime,
          endTime: endTime,
          answer: answer,
          deckId: deckId,
          videoSpeed: videoSpeed,
        );

        if (!mounted) return;

        setState(() {
          _lastCardAddedTime = DateTime.now();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video card added successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add: Please ensure a video is loaded.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error in _addCard: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving card: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  Future<String?> _getVideoTitle() async {
    try {
      final metadata = await _controller.metadata;
      return metadata.title;
    } catch (e) {
      print('Error getting video title: $e');
      return null;
    }
  }




  @override
  void dispose() {
    // Loại bỏ lắng nghe sự kiện blur khi widget bị hủy (chỉ trên web)
    if (kIsWeb) {
      //HtmlHelper.removeWindowBlurListener();
    }

    // Hủy tất cả timers và subscriptions
    _playbackTimer?.cancel();
    _controllerSubscription?.cancel();
    _authStateSubscription?.cancel();

    // Đóng tất cả controllers
    _controller.close();
    _videoUrlController.dispose();

    super.dispose();
  }

 



  Future<void> _handleSignOut() async {
    try {
      // Hủy tất cả timers và subscriptions trước khi sign out
      _playbackTimer?.cancel();
      _controllerSubscription?.cancel();
      _authStateSubscription?.cancel();

      // Dừng video nếu đang phát
      _controller.pauseVideo();

      // Reset state
      setState(() {
        _currentUser = null;
        _currentVideoId = null;
        _lastCardAddedTime = null;
      });

      await _authService.signOut();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign out failed: $e')),
        );
      }
    }
  }

}

class Controls extends StatelessWidget {
  final Function(double startTime, double endTime, String answer, String? deckId) onaddCard;
  final User? currentUser;

  const Controls({
    super.key,
    required this.onaddCard,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VideoPositionSeeker(onaddCard: onaddCard, currentUser: currentUser),
        ],
      ),
    );
  }
}


class VideoPositionSeeker extends StatefulWidget {
  final Function(double startTime, double endTime, String answer, String? deckId) onaddCard;
  final User? currentUser;

  const VideoPositionSeeker({
    super.key,
    required this.onaddCard,
    required this.currentUser,
  });

  @override
  State<VideoPositionSeeker> createState() => _VideoPositionSeekerState();
}

class _VideoPositionSeekerState extends State<VideoPositionSeeker> {
  QuillController _quillController = QuillController.basic();
  FocusNode _quillFocusNode = FocusNode();

  final TextEditingController _startHoursController = TextEditingController(text: '0');
  final TextEditingController _startMinutesController = TextEditingController(text: '0');
  final TextEditingController _startSecondsController = TextEditingController(text: '0.0');

  final TextEditingController _endHoursController = TextEditingController(text: '0');
  final TextEditingController _endMinutesController = TextEditingController(text: '0');
  final TextEditingController _endSecondsController = TextEditingController(text: '0.0');


  late TextEditingController _videoUrlController;
  final DeckService _deckService = DeckService();
  String? _selectedDeckId;
  List<Deck> _decks = [];

  StreamSubscription<List<Deck>>? _deckStreamSubscription;
  Timer? _playbackTimer;

  Color? _selectedTextColor;

  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;

  bool _isH1 = false;
  bool _isH2 = false;
  bool _isH3 = false;

  final VideoCardService _videoCardService = VideoCardService();

  @override
  void initState() {
    super.initState();

    _quillController = QuillController.basic();
    _videoUrlController = TextEditingController();
    _setupDeckListener();
    _quillFocusNode = FocusNode();

    // Thêm lắng nghe sự kiện blur để unfocus khi nhấp vào iframe YouTube (chỉ trên web)
    if (kIsWeb) {
      //HtmlHelper.setupWindowBlurListener(() {});
    }

    // Lắng nghe sự thay đổi của QuillController
    _quillController.addListener(_updateTextStyles);
  }
  @override
  
  



  void _setupDeckListener() {
    _deckStreamSubscription?.cancel();

    try {
      _deckService.createDefaultDeckIfNeeded();
      _deckStreamSubscription = _deckService.getDecks().listen(
            (decks) {
          if (mounted) {
            // Sắp xếp các deck theo tên
            decks.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

            setState(() {
              _decks = decks;
              if (_selectedDeckId == null && decks.isNotEmpty) {
                _selectedDeckId = decks.first.id;
              } else if (!decks.any((deck) => deck.id == _selectedDeckId)) {
                _selectedDeckId = decks.isNotEmpty ? decks.first.id : null;
              }
            });
          }
        },
        onError: (error) {
          print('Error in deck listener: $error');
          _deckStreamSubscription?.cancel();
          if (mounted) {
            setState(() {
              _decks = [];
              _selectedDeckId = null;
            });
          }
        },
        cancelOnError: true, // Tự động hủy subscription khi có lỗi
      );
    } catch (e) {
      print('Error setting up deck listener: $e');
    }
  }
  // Thêm hàm tính offset
  double _calculateEndTimeOffset(double speed) {
    // Công thức giống với VideoStudyScreen
    return 0.03 * pow(speed - 1.125, 2) + 0.08 * speed;
  }

  // Cập nhật hàm playVideoWithEndTime
  void playVideoWithEndTime(double startTime, double endTime) async {
    final controller = context.ytController;

    // Hủy timer hiện tại nếu có
    _playbackTimer?.cancel();

    // Lấy tốc độ hiện tại của video
    final currentSpeed = await controller.playbackRate;

    // Tính toán endTime với offset dựa trên tốc độ
    final adjustedEndTime = endTime - _calculateEndTimeOffset(currentSpeed);

    controller.seekTo(seconds: startTime, allowSeekAhead: true);
    controller.playVideo();

    if (endTime > startTime) {
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (await controller.currentTime > adjustedEndTime) {
          controller.pauseVideo();
          timer.cancel();
        }
      });
    }
  }




  Widget _buildDeckDropdown() {
    if (_decks.isEmpty) {
      return const Text('No decks available');
    }
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Select Deck',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
      value: _selectedDeckId,
      items: _decks.map((deck) {
        return DropdownMenuItem<String>(
          value: deck.id,
          child: Text(deck.name, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedDeckId = newValue;
        });
      },
    );
  }

  void _updateTextStyles() {
    final selectionStyle = _quillController.getSelectionStyle();
    setState(() {
      _selectedTextColor = selectionStyle.attributes['color']?.value != null
          ? Color(int.parse(selectionStyle.attributes['color']!.value.substring(1), radix: 16) + 0xFF000000)
          : null;
      _isBold = selectionStyle.attributes.containsKey('bold');
      _isItalic = selectionStyle.attributes.containsKey('italic');
      _isUnderline = selectionStyle.attributes.containsKey('underline');
      _isH1 = selectionStyle.attributes.containsKey('header') && selectionStyle.attributes['header']!.value == 1;
      _isH2 = selectionStyle.attributes.containsKey('header') && selectionStyle.attributes['header']!.value == 2;
      _isH3 = selectionStyle.attributes.containsKey('header') && selectionStyle.attributes['header']!.value == 3;
    });
  }

  void _toggleAttribute(Attribute attribute, bool isActive) {
    if (isActive) {
      _quillController.formatSelection(Attribute.clone(attribute, null));
    } else {
      _quillController.formatSelection(attribute);
    }
  }

  @override
  void dispose() {
    // Loại bỏ lắng nghe sự kiện blur (chỉ trên web)
    if (kIsWeb) {
      //HtmlHelper.removeWindowBlurListener();
    }

    _deckStreamSubscription?.cancel();
    _playbackTimer?.cancel();
    _quillController.dispose();
    _quillFocusNode.dispose();
    _videoUrlController.dispose();
    _startHoursController.dispose();
    _startMinutesController.dispose();
    _startSecondsController.dispose();
    _endHoursController.dispose();
    _endMinutesController.dispose();
    _endSecondsController.dispose();

    super.dispose();
  }
  String _getQuillContentAsJson() {
    final json = jsonEncode(_quillController.document.toDelta().toJson());
    return json;
  }

  double _getTimeInSeconds(
      TextEditingController hours,
      TextEditingController minutes,
      TextEditingController seconds,
      ) {
    final h = int.tryParse(hours.text) ?? 0;
    final m = int.tryParse(minutes.text) ?? 0;
    final s = double.tryParse(seconds.text) ?? 0.0;
    return (h * 3600 + m * 60).toDouble() + s;
  }

  void _seekAndPlay() {
    final startTime = _getTimeInSeconds(
      _startHoursController,
      _startMinutesController,
      _startSecondsController,
    );

    final endTime = _getTimeInSeconds(
      _endHoursController,
      _endMinutesController,
      _endSecondsController,
    );

    // Remove the error message check and just play the video
    playVideoWithEndTime(startTime, endTime);
  }

  void _addCard() {
    // Kiểm tra deck
    if (_selectedDeckId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a deck before adding a card')),
      );
      return;
    }

    // Validate thời gian
    final startTime = _getTimeInSeconds(
      _startHoursController,
      _startMinutesController,
      _startSecondsController,
    );

    final endTime = _getTimeInSeconds(
      _endHoursController,
      _endMinutesController,
      _endSecondsController,
    );

    if (endTime < startTime+0.5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be at least 0.5 seconds greater than start time')),
      );
      return;
    }

    // Kiểm tra nội dung
    if (_quillController.document.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an answer before saving')),
      );
      return;
    }

    // Chuyển đổi nội dung Quill thành JSON và lưu
    final answerJson = _getQuillContentAsJson();

    // Unfocus trước khi clear
    _quillFocusNode.unfocus();

    // Gọi callback để thêm card
    widget.onaddCard(startTime, endTime, answerJson, _selectedDeckId);
    
    // Xóa nội dung của Quill editor sau khi đã thêm thành công
    _quillController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 200,
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
                      icon: Icon(
                        Icons.format_bold,
                        color: _isBold ? Colors.blue : Colors.grey,
                      ),
                      onPressed: () => _toggleAttribute(Attribute.bold, _isBold),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.format_italic,
                        color: _isItalic ? Colors.green : Colors.grey,
                      ),
                      onPressed: () => _toggleAttribute(Attribute.italic, _isItalic),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.format_underline,
                        color: _isUnderline ? Colors.red : Colors.grey,
                      ),
                      onPressed: () => _toggleAttribute(Attribute.underline, _isUnderline),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.palette,
                        color: _selectedTextColor ?? Colors.grey,
                      ),
                      onPressed: () async {
                        //HtmlHelper.disableIframeInteractions();

                        final currentColor = _quillController.getSelectionStyle().attributes['color']?.value;
                        if (currentColor != null) {
                          _quillController.formatSelection(Attribute.clone(Attribute.color, null));
                          _selectedTextColor = null;
                          //HtmlHelper.enableIframeInteractions();
                        } else {
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
                                title: const Text('Select color'),
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
                          //HtmlHelper.enableIframeInteractions();
                          if (selectedColor != null) {
                            String hexColor = '#${selectedColor.value.toRadixString(16).substring(2)}';
                            _quillController.formatSelection(Attribute.fromKeyValue('color', hexColor));
                            setState(() {
                              _selectedTextColor = selectedColor;
                            });
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: Text('H1',
                          style: TextStyle(
                              color: _isH1 ? Colors.purple : Colors.grey,
                              fontSize: 18
                          )
                      ),
                      onPressed: () => _toggleAttribute(Attribute.h1, _isH1),
                    ),
                    IconButton(
                      icon: Text('H2',
                          style: TextStyle(
                              color: _isH2 ? Colors.purple : Colors.grey,
                              fontSize: 16
                          )
                      ),
                      onPressed: () => _toggleAttribute(Attribute.h2, _isH2),
                    ),
                    IconButton(
                      icon: Text('H3',
                          style: TextStyle(
                              color: _isH3 ? Colors.purple : Colors.grey,
                              fontSize: 14
                          )
                      ),
                      onPressed: () => _toggleAttribute(Attribute.h3, _isH3),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GestureDetector(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    child: QuillEditor.basic(
                      controller: _quillController,
                      focusNode: _quillFocusNode,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildTimeInputRow('Start Time:', _startHoursController, _startMinutesController, _startSecondsController),
        const SizedBox(height: 10),
        _buildTimeInputRow('End Time:', _endHoursController, _endMinutesController, _endSecondsController),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _seekAndPlay,
                child: const Text('Play Range'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _addCard,
                child: const Text('Add Card'),
              ),
            ),


            const SizedBox(width: 10),
            Expanded(
              child: _buildDeckDropdown(),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTimeInputRow(
      String label,
      TextEditingController hoursController,
      TextEditingController minutesController,
      TextEditingController secondsController,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  _TimeInput(
                    controller: hoursController,
                    label: 'Hours',
                    isDecimal: false,
                    onUserInteraction: (focused) {
                    },
                  ),
                  const SizedBox(width: 8),
                  _TimeInput(
                    controller: minutesController,
                    label: 'Minutes',
                    isDecimal: false,
                    onUserInteraction: (focused) {
                    },
                  ),
                  const SizedBox(width: 8),
                  _TimeInput(
                    controller: secondsController,
                    label: 'Seconds',
                    isDecimal: true,
                    onUserInteraction: (focused) {
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: ElevatedButton(
                onPressed: () async {
                  final controller = context.ytController;
                  final currentTimeInSeconds = await controller.currentTime;

                  final hours = (currentTimeInSeconds ~/ 3600).toInt();
                  final minutes = ((currentTimeInSeconds % 3600) ~/ 60).toInt();
                  final seconds = currentTimeInSeconds % 60;

                  setState(() {
                    hoursController.text = hours.toString();
                    minutesController.text = minutes.toString();
                    secondsController.text = seconds.toStringAsFixed(1);
                  });
                },
                child: const Text('Now'),
              ),
            ),
          ],
        ),
      ],
    );
  }


}

class _TimeInput extends StatefulWidget {
  const _TimeInput({
    required this.controller,
    required this.label,
    required this.isDecimal,
    required this.onUserInteraction,
  });

  final TextEditingController controller;
  final String label;
  final bool isDecimal;
  final Function(bool) onUserInteraction;

  @override
  State<_TimeInput> createState() => _TimeInputState();
}

class _TimeInputState extends State<_TimeInput> {


  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextField(

        controller: widget.controller,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.numberWithOptions(
          decimal: widget.isDecimal,
          signed: false,
        ),


      ),
    );
  }
}
