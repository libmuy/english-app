import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:frontend/generated/l10n.dart';
import 'package:frontend/di/app_module.dart';
import 'package:frontend/models/sentence.dart';
import 'package:frontend/providers/learning_provider.dart';
import 'package:frontend/pages/learning_page.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:libmuy_audioplayer/export.dart'; // Assuming this exports the necessary player
import 'package:frontend/utils/constants.dart'; // For API_BASE_URL

// Simple in-memory cache for playback state
class PlaybackStateCache {
  static final Map<int, PlaybackState> _cache = {};

  static void saveState(int courseId, PlaybackState state) {
    _cache[courseId] = state;
  }

  static PlaybackState? getState(int courseId) {
    return _cache[courseId];
  }

  static void clearState(int courseId) {
    _cache.remove(courseId);
  }
}

class PlaybackState {
  final int sentenceIndex;
  final Duration position;
  final bool wasPlaying; // To know if we should auto-resume

  PlaybackState({required this.sentenceIndex, required this.position, required this.wasPlaying});
}

class CourseSentencesOverviewPage extends StatefulWidget {
  final int courseId;
  final String courseName;

  const CourseSentencesOverviewPage({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<CourseSentencesOverviewPage> createState() =>
      _CourseSentencesOverviewPageState();
}

class _CourseSentencesOverviewPageState
    extends State<CourseSentencesOverviewPage> {
  late Future<List<Sentence>> _sentencesFuture;
  final ScrollController _scrollController = ScrollController();
  List<Sentence> _sentences = [];
  int _offset = 0;
  final int _pageSize = 20;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  int? _currentlyPlayingIndex;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playbackEventSubscription;
  bool _isDisposed = false; // To prevent setState after dispose

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _fetchSentences();
    _scrollController.addListener(_onScroll);
    _restorePlaybackState();

    _playbackEventSubscription = _audioPlayer.playbackEventStream.listen((event) {
      if (_isDisposed) return;
      if (event.processingState == ProcessingState.completed) {
        // If it was the last sentence that completed, clear cache for this course
        if (_currentlyPlayingIndex != null && _currentlyPlayingIndex == _sentences.length - 1) {
          PlaybackStateCache.clearState(widget.courseId);
        }
        _playNextSentence();
      }
    });

    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      if (_isDisposed) return;
      if (_isPlaying && _currentlyPlayingIndex != null) {
        PlaybackStateCache.saveState(
          widget.courseId,
          PlaybackState(
            sentenceIndex: _currentlyPlayingIndex!,
            position: position,
            wasPlaying: true,
          ),
        );
      }
    });
  }

  void _fetchSentences() {
    // Ensure we don't try to fetch if a fetch is already in progress from initState
    if (mounted && _isLoadingMore) return;

    if (mounted) {
       setState(() {
        // To show loading indicator if it's the initial fetch via _sentencesFuture
        if (_sentences.isEmpty) {
          _sentencesFuture = _fetchSentencesData();
        } else if (_hasMore) { // For loading more
          _isLoadingMore = true;
        }
      });
    } else { // If not mounted, typically called from initState
       _sentencesFuture = _fetchSentencesData();
    }

    if (_sentences.isNotEmpty && _hasMore && mounted) { // Only call _fetchSentencesData if it's for loading more
      _fetchSentencesData().then((newSentences) {
        if (mounted) {
          setState(() {
            if (newSentences.isEmpty) {
              _hasMore = false;
            }
            _sentences.addAll(newSentences);
            _isLoadingMore = false;
          });
        }
      }).catchError((e) {
        if (mounted) {
          setState(() {
            _isLoadingMore = false;
          });
        }
        print("Error loading more sentences: $e");
      });
    }
  }

  Future<List<Sentence>> _fetchSentencesData() async {
    return getIt<LearningProvider>().fetchSentences(
      type: 'course',
      courseId: widget.courseId,
      pageSize: _pageSize,
      offset: _offset,
    );
  }

  void _loadMoreSentences() {
    if (_isLoadingMore || !_hasMore) return;
    _offset += _pageSize;
    _fetchSentences(); // This will now call _fetchSentencesData and handle state
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreSentences();
    }
  }

  Future<void> _playSentence(int index, {Duration? startPosition}) async {
    if (_isDisposed || index < 0 || index >= _sentences.length) {
      _stopPlayback(clearState: true); // Clear state if trying to play invalid index
      return;
    }
    try {
      final sentence = _sentences[index];
      final audioUrl = '$API_BASE_URL/audio/sentence_audio_by_id?id=${sentence.id}';

      // Stop current playback before starting new one
      await _audioPlayer.stop();

      await _audioPlayer.setUrl(audioUrl);
      if (startPosition != null) {
        await _audioPlayer.seek(startPosition);
      }
      _audioPlayer.play();
      if (!_isDisposed) {
        setState(() {
          _isPlaying = true;
          _currentlyPlayingIndex = index;
        });
      }
      PlaybackStateCache.saveState(
          widget.courseId,
          PlaybackState(sentenceIndex: index, position: startPosition ?? Duration.zero, wasPlaying: true),
      );
    } catch (e) {
      print("Error playing sentence $index: $e");
      if (!_isDisposed) {
        setState(() {
          _isPlaying = false;
          // Do not nullify _currentlyPlayingIndex here, so user can retry
        });
      }
    }
  }

  void _playNextSentence() {
    if (_isDisposed) return;
    if (_currentlyPlayingIndex != null) {
      int nextIndex = _currentlyPlayingIndex! + 1;
      if (nextIndex < _sentences.length) {
        _playSentence(nextIndex);
      } else {
        _stopPlayback(clearState: true); // Reached end of list, clear state
      }
    } else {
       _stopPlayback(clearState: true);
    }
  }

  void _togglePlayPause() {
    if (_isDisposed) return;
    if (_isPlaying) {
      _audioPlayer.pause();
      if (_currentlyPlayingIndex != null) {
        PlaybackStateCache.saveState(
            widget.courseId,
            PlaybackState(
                sentenceIndex: _currentlyPlayingIndex!,
                position: _audioPlayer.position,
                wasPlaying: false));
      }
      if (!_isDisposed) {
        setState(() {
          _isPlaying = false;
        });
      }
    } else {
      if (_currentlyPlayingIndex != null && _audioPlayer.processingState != ProcessingState.completed) {
        _audioPlayer.play();
         if (!_isDisposed) {
            setState(() {
              _isPlaying = true;
            });
         }
        PlaybackStateCache.saveState(
            widget.courseId,
            PlaybackState(
                sentenceIndex: _currentlyPlayingIndex!,
                position: _audioPlayer.position,
                wasPlaying: true));

      } else if (_sentences.isNotEmpty) {
        // If nothing is selected, or playback was completed, start from first or restored index
        int startIndex = _currentlyPlayingIndex ?? 0; // Default to 0 if null
        if (startIndex >= _sentences.length) startIndex = 0; // Boundary check
        _playSentence(startIndex);
      }
    }
  }

  void _stopPlayback({bool clearState = false}) {
    _audioPlayer.stop();
    if (clearState) {
      PlaybackStateCache.clearState(widget.courseId);
    } else if (_currentlyPlayingIndex != null) {
      // Save stopped state (paused at beginning)
       PlaybackStateCache.saveState(
          widget.courseId,
          PlaybackState(sentenceIndex: _currentlyPlayingIndex!, position: Duration.zero, wasPlaying: false),
        );
    }

    if (!_isDisposed) {
      setState(() {
        _isPlaying = false;
        // Don't reset _currentlyPlayingIndex here, so user knows where they left off
        // unless clearState is true, in which case it might be reset or handled by _restorePlaybackState
        if (clearState) _currentlyPlayingIndex = _sentences.isNotEmpty ? 0 : null;
      });
    }
  }

  void _restorePlaybackState() {
    final savedState = PlaybackStateCache.getState(widget.courseId);
    if (savedState != null && savedState.sentenceIndex < _sentences.length) {
      // Ensure sentences are loaded before trying to restore
      // This might need to be called after _sentencesFuture completes if _sentences is empty initially
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isDisposed) return;
        // Check if sentences are available, as _fetchSentencesData might not have completed
        if (_sentences.isNotEmpty && savedState.sentenceIndex < _sentences.length) {
            _currentlyPlayingIndex = savedState.sentenceIndex;
            if (savedState.wasPlaying) {
              // Important: setUrl before seek and play might be needed by some players
              // For now, assuming _playSentence handles this if called.
              // Let's play the sentence, which will also handle setUrl and seek.
              _playSentence(savedState.sentenceIndex, startPosition: savedState.position);
            } else {
              // If it wasn't playing, just set the index and prepare for manual play
              // We might need to load the URL into the player to show duration etc.
              // For simplicity, we'll just set the index. User can tap to play.
              final sentence = _sentences[savedState.sentenceIndex];
              final audioUrl = '$API_BASE_URL/audio/sentence_audio_by_id?id=${sentence.id}';
              _audioPlayer.setUrl(audioUrl).then((_) { // Preload for duration if possible
                _audioPlayer.seek(savedState.position);
                 if (!_isDisposed) setState(() { _isPlaying = false; });
              });

            }
            if (!_isDisposed) setState(() {}); // Update UI for highlighting
        } else if (_sentences.isEmpty) {
          // If sentences are not yet loaded, schedule a re-attempt after fetch
          _sentencesFuture.whenComplete(() {
            if (_isDisposed || _sentences.isEmpty) return;
            final recheckState = PlaybackStateCache.getState(widget.courseId);
            if (recheckState != null && recheckState.sentenceIndex < _sentences.length) {
               _currentlyPlayingIndex = recheckState.sentenceIndex;
               if (recheckState.wasPlaying) {
                 _playSentence(recheckState.sentenceIndex, startPosition: recheckState.position);
               } else {
                  final sentence = _sentences[recheckState.sentenceIndex];
                  final audioUrl = '$API_BASE_URL/audio/sentence_audio_by_id?id=${sentence.id}';
                  _audioPlayer.setUrl(audioUrl).then((_) {
                     _audioPlayer.seek(recheckState.position);
                     if (!_isDisposed) setState(() { _isPlaying = false; });
                  });
               }
               if (!_isDisposed) setState(() {});
            }
          });
        }
      });
    } else if (savedState == null && _sentences.isNotEmpty) {
        // Default to first sentence, paused, if no saved state
        _currentlyPlayingIndex = 0;
         if (!_isDisposed) setState(() { _isPlaying = false; });
    }
  }

  @override
  void deactivate() {
    if (_isPlaying) {
      // Pausing and saving state, but not stopping fully
      _audioPlayer.pause();
      if (_currentlyPlayingIndex != null) {
        PlaybackStateCache.saveState(
            widget.courseId,
            PlaybackState(
                sentenceIndex: _currentlyPlayingIndex!,
                position: _audioPlayer.position,
                wasPlaying: true)); // Mark as wasPlaying so it resumes if user comes back quickly
      }
      if (!_isDisposed) {
        setState(() { _isPlaying = false; }); // Visually show as paused
      }
    } else if (_currentlyPlayingIndex != null) {
      // Save position even if paused
       PlaybackStateCache.saveState(
            widget.courseId,
            PlaybackState(
                sentenceIndex: _currentlyPlayingIndex!,
                position: _audioPlayer.position,
                wasPlaying: false));
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _positionSubscription?.cancel();
    _playbackEventSubscription?.cancel();
    // If audio is playing, stop it and save final state.
    // Otherwise, player might continue playing even after dispose.
    if (_audioPlayer.playing) {
        _audioPlayer.stop();
         if (_currentlyPlayingIndex != null) {
            PlaybackStateCache.saveState(
                widget.courseId,
                PlaybackState(
                    sentenceIndex: _currentlyPlayingIndex!,
                    position: _audioPlayer.position, // This might be reset by stop, consider getting it before stop
                    wasPlaying: false // It's being stopped, so don't auto-resume
                )
            );
        }
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
      ),
      body: FutureBuilder<List<Sentence>>(
        future: _sentencesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _sentences.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError && _sentences.isEmpty) {
            return Center(
                child: Text(
                    '${S.of(context).failedToLoadSentences}: ${snapshot.error}'));
          } else if (snapshot.hasData && _sentences.isEmpty && !_isLoadingMore) {
             // Initial data loaded
            if (snapshot.data!.isEmpty && _offset == 0) {
               return Center(child: Text(S.of(context).noSentencesFound));
            }
            // Only assign if _sentences is still empty to avoid overwriting during loadMore
            _sentences = snapshot.data!;
          }
          // If snapshot has data but it's empty and _sentences is also empty (initial load resulted in no data)
          if (_sentences.isEmpty && snapshot.hasData && snapshot.data!.isEmpty && !_hasMore && !_isLoadingMore) {
             return Center(child: Text(S.of(context).noSentencesFound));
          }
          // If _sentences is empty after trying to load more and _hasMore is false
          if (_sentences.isEmpty && !_hasMore && !_isLoadingMore){
            return Center(child: Text(S.of(context).noSentencesFound));
          }


          return ListView.builder(
            controller: _scrollController,
            itemCount: _sentences.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _sentences.length) {
                return _isLoadingMore
                    ? const Center(child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ))
                    : const SizedBox.shrink();
              }
              final sentence = _sentences[index];
              final bool isCurrentlyPlaying = _currentlyPlayingIndex == index;
              return ListTile(
                tileColor: isCurrentlyPlaying ? Theme.of(context).highlightColor : null,
                title: Text(sentence.english, style: TextStyle(fontWeight: isCurrentlyPlaying ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text(sentence.chinese),
                trailing: IconButton(
                  icon: Icon(isCurrentlyPlaying && _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
                  onPressed: () {
                    if (isCurrentlyPlaying && _isPlaying) {
                      _togglePlayPause(); // Will pause
                    } else {
                      _playSentence(index); // Will play this specific sentence
                    }
                  },
                ),
                onTap: () {
                  final learningProvider = context.read<LearningProvider>();
                  final sentenceSrc = SentenceSrc(
                    sentences: _sentences, // Pass the current list including loaded ones
                    title: widget.courseName,
                    initialIndex: index,
                    onUpdateSentenceList: (List<Sentence> newSentences, int newInitialIndex) {
                      if (mounted) {
                        setState(() {
                          _sentences = List.from(newSentences);
                          // Optionally, adjust _currentlyPlayingIndex if needed based on changes
                        });
                      }
                    },
                  );
                  learningProvider.setSentenceSrc(sentenceSrc);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LearningPage(
                        sentenceSrc: sentenceSrc
                      ),
                    ),
                  ).then((_) { // Called when returning from LearningPage
                    if (_isDisposed) return;
                    // When returning from LearningPage, audio should have been paused by deactivate()
                    // Re-check the cached state or player state to update UI correctly.
                    final savedState = PlaybackStateCache.getState(widget.courseId);
                    if (savedState != null) {
                        _currentlyPlayingIndex = savedState.sentenceIndex;
                        // If it was playing before going to LearningPage, it should now be paused.
                        // The 'wasPlaying' in cache helps decide if we auto-resume on *page init*,
                        // but on returning from sub-page, it's safer to remain paused unless explicitly resumed.
                        if (_audioPlayer.playing) { // Should not be playing due to deactivate
                           _audioPlayer.pause();
                        }
                         if (!_isDisposed) {
                           setState(() { _isPlaying = false; }); // Always reflect paused state after returning
                         }
                         // Update highlight
                         if (!_isDisposed) setState(() {});

                    } else {
                       // If no saved state, ensure UI is reset
                        if (!_isDisposed) {
                          setState(() {
                            _isPlaying = false;
                            // _currentlyPlayingIndex = _sentences.isNotEmpty ? 0 : null; // Or keep last known
                          });
                        }
                    }
                  });
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _togglePlayPause,
        child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }
}
}
